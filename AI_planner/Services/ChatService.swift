//
//  ChatService.swift
//  AI_planner
//
//  Created by Judy459 on 2/24/26.
//

import Foundation
import SwiftUI
import Combine

// MARK: - AI Action Models

enum AIAction {
    case createTask(AITaskData)
    case createMultipleTasks([AITaskData])
    case updateTask(id: String, fields: AITaskData)
    case deleteTask(id: String)
    case completeTask(id: String)
}

struct AITaskData {
    var title: String
    var description: String?
    var dueDate: String?      // "2026-02-25" ISO format
    var startTime: String?    // "15:00" 24hr format
    var endTime: String?      // "16:00"
    var priority: String?     // "low", "medium", "high"
    var eventType: String?    // "gym", "class", "study", "meeting", "dinner", "other"
}

// MARK: - User Intent (NEW: AI-driven intent recognition)

enum UserIntent {
    case confirm      // User confirmed to execute
    case cancel       // User cancelled/rejected
    case clarify      // User wants to modify/clarify
    case neutral      // Normal conversation
}

// MARK: - Validation Result (NEW: Action validation)

enum ValidationResult {
    case valid
    case invalid(reason: String)
}

// MARK: - Action Result (for undo support)

struct ActionResult: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let taskId: UUID?
    let actionType: ActionResultType
    let undoData: UndoData?
    
    enum ActionResultType {
        case created, updated, deleted, completed, warning
    }
    
    enum UndoData {
        case deleteCreated(UUID)               // undo create → delete the task
        case restoreDeleted(TodoTask)          // undo delete → re-add the task
        case revertUpdate(TodoTask)            // undo update → restore old version
        case uncomplete(UUID)                  // undo complete → toggle back
    }
}

// MARK: - Chat Service

@MainActor
class ChatService: ObservableObject {
    @Published var isLoading = false
    @Published var streamingText = ""
    @Published var lastError: String?
    @Published var executedActions: [ActionResult] = []
    
    private let api = KimiAPIService.shared
    private var conversationHistory: [KimiMessage] = []
    private let maxHistoryMessages = 20 // keep last 20 non-system messages
    
    // NEW: Track last user message for smart context
    private var lastUserMessage: String = ""
    
    // NEW: Recently mentioned task IDs for context retention
    private var recentlyMentionedTaskIds: [UUID] = []
    private let maxRecentTasks = 3
    
    weak var todoViewModel: TodoViewModel?
    
    init() {}
    
    // MARK: - System Prompt
    
    private func buildSystemPrompt(userMessage: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let currentTime = timeFormatter.string(from: Date())
        
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "zh_CN")
        weekdayFormatter.dateFormat = "EEEE"
        let weekday = weekdayFormatter.string(from: Date())
        
        let tasksContext = buildSmartContext(userMessage: userMessage)
        let conflictContext = buildConflictContext()
        let userProfileSummary = BehaviorAnalyzer.shared.generateProfileSummary(days: 30)
        let beaverPersona = BeaverPersonality.shared.personaPrompt(tasks: todoViewModel?.todos ?? [])
        let chatMemory = ChatMemoryStore.shared.generateMemorySummary()
        
        return """
        \(beaverPersona)
        
        你同时也是一个集成在任务管理App中的智能日程规划助手。你可以自然对话，也可以直接管理用户的任务。

        当前日期: \(today) (\(weekday))
        当前时间: \(currentTime)

        ## 用户行为画像
        \(userProfileSummary)
        \(chatMemory.isEmpty ? "" : "\n        \(chatMemory)")

        ## 你的能力
        1. 自然对话：回答问题、给建议
        2. 创建任务：当用户要求安排事项时
        3. 修改任务：修改已有任务的细节
        4. 删除任务：移除不需要的任务
        5. 完成任务：标记任务为已完成
        6. 规划日程：一次性创建多个任务（日计划/周计划）

        ## 用户当前的任务
        \(tasksContext)
        \(conflictContext.isEmpty ? "" : "\n        \(conflictContext)")

        ## 重要工作流程（必须严格遵守）

        ### 执行模式判断
        根据用户输入判断执行模式：

        **模式1：直接执行（跳过确认）**
        当满足以下任一条件时，直接输出 [ACTION]：
        - 用户明确说出了完整的任务信息（如"帮我在明天下午3点到4点安排一个会议"）
        - 用户要求完成或删除一个特定的已有任务（通过ID或明确标题）
        - 用户修改自己的现有任务（如"把明天3点的会议改到4点"）

        **模式2：先提案再确认**
        当涉及以下情况时，先提出方案，等待用户确认：
        - 用户请求模糊（如"帮我规划明天"）
        - 涉及多个任务的批量操作
        - 可能覆盖或删除重要数据的操作
        - AI 需要主动安排/推荐时间（如"帮我安排学习时间"）

        ### 两步确认流程（模式2使用）

        **第一步：提出方案**
        用自然语言描述你的方案，用清晰的列表格式展示计划内容。
        在方案末尾加上一句话，例如："如果没问题，请回复「确认」，我会立即为你添加。"
        这一步绝对不能包含 [ACTION] 块。

        **第二步：用户确认后执行**
        当用户回复确认意图时，输出 [ACTION] 块执行操作。
        同时输出 [INTENT]confirm[/INTENT] 标签表示已确认。

        ### 意图识别标签（重要！）
        每次回复时，根据用户消息判断意图并输出对应标签：

        - 用户确认执行 → 在回复末尾输出：[INTENT]confirm[/INTENT]
        - 用户取消/拒绝 → 在回复末尾输出：[INTENT]cancel[/INTENT]
        - 用户想修改/澄清 → 在回复末尾输出：[INTENT]clarify[/INTENT]
        - 普通对话或无明确意图 → 不输出 INTENT 标签

        确认关键词包括：确认、确定、好的、可以、行、没问题、是的、好、ok、yes、go、执行、添加
        取消关键词包括：取消、不要、算了、否、no、拒绝、别、删掉

        ## ACTION 格式（严格遵守，不要修改格式）

        创建单个任务：
        [ACTION]
        {"action":"create_task","task":{"title":"会议","description":"团队站会","due_date":"2026-02-25","start_time":"15:00","end_time":"16:00","priority":"high","event_type":"meeting"}}
        [/ACTION]

        批量创建任务（用于日计划/周计划）：
        [ACTION]
        {"action":"create_multiple","tasks":[{"title":"健身","due_date":"2026-02-25","start_time":"08:00","end_time":"09:00","priority":"medium","event_type":"gym"},{"title":"学习","due_date":"2026-02-25","start_time":"10:00","end_time":"12:00","priority":"high","event_type":"study"}]}
        [/ACTION]

        修改任务：
        [ACTION]
        {"action":"update_task","task_id":"UUID","task":{"title":"新标题","start_time":"14:00"}}
        [/ACTION]

        删除任务：
        [ACTION]
        {"action":"delete_task","task_id":"UUID"}
        [/ACTION]

        完成任务：
        [ACTION]
        {"action":"complete_task","task_id":"UUID"}
        [/ACTION]

        ## 规则
        - 始终使用用户所用的语言回复
        - [ACTION] 块中的 JSON 必须在一行内，不要换行
        - [INTENT] 标签放在回复最后，单独一行
        - 不要在对话文本中展示 JSON 代码，[ACTION] 块会被系统自动隐藏
        - 创建有时间的事件时，必须同时包含 start_time 和 end_time
        - 使用 24 小时制（HH:mm）和 ISO 日期格式（YYYY-MM-DD）
        - event_type 可选值：gym, class, study, meeting, dinner, other
        - priority 可选值：low, medium, high
        - "明天"= 从今天 \(today) 计算下一天
        - "下周"= 从下周一开始计算
        - 规划日程时，任务之间要留合理的休息/通勤时间
        - 检查已有任务，避免时间冲突
        - 如果用户请求模糊不清，先询问细节再规划
        - 参考用户画像中的高效时段和习惯，优先在高效时段安排重要任务
        - 如果用户画像显示某类任务有拖延倾向，给出温和提醒
        - 严格遵守用户偏好记忆中的约束和偏好（如"不喜欢早起"就不安排早上的任务）
        - 当用户表达新的偏好或习惯时，自然地确认并记住
        """
    }
    
    // MARK: - Smart Context (Token-efficient)
    
    private func buildSmartContext(userMessage: String) -> String {
        guard let vm = todoViewModel else { return "No tasks loaded." }
        if vm.todos.isEmpty { return "No tasks currently scheduled." }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        let sorted = vm.todos.sorted(by: { $0.dueDate < $1.dueDate })
        
        // 1. Today's tasks — always include in full
        let todayTasks = sorted.filter { calendar.isDate($0.dueDate, inSameDayAs: today) }
        
        // 2. Tasks on dates mentioned in user message
        let mentionedDates = extractDatesFromMessage(userMessage)
        let mentionedDateTasks = sorted.filter { task in
            mentionedDates.contains(where: { calendar.isDate(task.dueDate, inSameDayAs: $0) })
                && !calendar.isDate(task.dueDate, inSameDayAs: today)
        }
        
        // 3. Recently discussed tasks (from conversation history)
        let recentIDs = extractRecentlyMentionedTaskIDs(limit: 3)
        let recentTasks = sorted.filter { task in
            recentIDs.contains(task.id)
                && !calendar.isDate(task.dueDate, inSameDayAs: today)
                && !mentionedDates.contains(where: { d in calendar.isDate(task.dueDate, inSameDayAs: d) })
        }
        
        // 4. Everything else — summary only
        let includedIDs = Set(todayTasks.map(\.id))
            .union(mentionedDateTasks.map(\.id))
            .union(recentTasks.map(\.id))
        let otherTasks = sorted.filter { !includedIDs.contains($0.id) }
        let otherIncomplete = otherTasks.filter { !$0.isCompleted }
        let overdueCount = otherTasks.filter { $0.dueDate < today && !$0.isCompleted }.count
        
        var lines: [String] = []
        
        // Today
        lines.append("### 今日任务 (\(dateFormatter.string(from: today)))")
        if todayTasks.isEmpty {
            lines.append("  无任务")
        } else {
            for task in todayTasks {
                lines.append(formatTask(task, dateFormatter: dateFormatter, timeFormatter: timeFormatter))
            }
        }
        
        // Mentioned dates
        if !mentionedDateTasks.isEmpty {
            lines.append("### 用户提到日期的任务")
            for task in mentionedDateTasks {
                lines.append(formatTask(task, dateFormatter: dateFormatter, timeFormatter: timeFormatter))
            }
        }
        
        // Recently discussed
        if !recentTasks.isEmpty {
            lines.append("### 最近讨论过的任务")
            for task in recentTasks {
                lines.append(formatTask(task, dateFormatter: dateFormatter, timeFormatter: timeFormatter))
            }
        }
        
        // Summary of the rest
        if !otherTasks.isEmpty {
            lines.append("### 其他任务摘要")
            lines.append("  未完成: \(otherIncomplete.count) 个")
            if overdueCount > 0 {
                lines.append("  其中逾期: \(overdueCount) 个")
            }
            lines.append("  总计: \(vm.todos.count) 个任务")
        }
        
        return lines.joined(separator: "\n")
    }
    
    /// Extract dates referenced in user message (Chinese natural language + ISO format)
    private func extractDatesFromMessage(_ message: String) -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var dates: [Date] = []
        
        // Relative dates
        let relativeMap: [(String, Int)] = [
            ("今天", 0), ("明天", 1), ("后天", 2), ("大后天", 3)
        ]
        for (keyword, offset) in relativeMap {
            if message.contains(keyword), let d = calendar.date(byAdding: .day, value: offset, to: today) {
                dates.append(d)
            }
        }
        
        // 下周X
        let weekdayNames: [(String, Int)] = [
            ("下周一", 2), ("下周二", 3), ("下周三", 4), ("下周四", 5),
            ("下周五", 6), ("下周六", 7), ("下周日", 1)
        ]
        for (keyword, weekday) in weekdayNames {
            if message.contains(keyword) {
                var comps = DateComponents()
                comps.weekday = weekday
                if let nextDate = calendar.nextDate(after: today, matching: comps, matchingPolicy: .nextTime) {
                    let daysAhead = calendar.dateComponents([.day], from: today, to: nextDate).day ?? 0
                    if daysAhead <= 7 {
                        if let adjusted = calendar.date(byAdding: .day, value: 7, to: nextDate) {
                            dates.append(calendar.startOfDay(for: adjusted))
                        }
                    } else {
                        dates.append(calendar.startOfDay(for: nextDate))
                    }
                }
            }
        }
        
        // ISO format: 2026-03-05
        let isoPattern = "\\d{4}-\\d{2}-\\d{2}"
        if let regex = try? NSRegularExpression(pattern: isoPattern) {
            let nsString = message as NSString
            let matches = regex.matches(in: message, range: NSRange(location: 0, length: nsString.length))
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            for match in matches {
                let str = nsString.substring(with: match.range)
                if let d = df.date(from: str) { dates.append(calendar.startOfDay(for: d)) }
            }
        }
        
        // Chinese date: X月X日 / X月X号
        let cnPattern = "(\\d{1,2})月(\\d{1,2})[日号]"
        if let regex = try? NSRegularExpression(pattern: cnPattern) {
            let nsString = message as NSString
            let matches = regex.matches(in: message, range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                if match.numberOfRanges >= 3 {
                    let month = Int(nsString.substring(with: match.range(at: 1))) ?? 0
                    let day = Int(nsString.substring(with: match.range(at: 2))) ?? 0
                    var comps = calendar.dateComponents([.year], from: today)
                    comps.month = month
                    comps.day = day
                    if let d = calendar.date(from: comps) { dates.append(calendar.startOfDay(for: d)) }
                }
            }
        }
        
        return dates
    }
    
    /// Extract task UUIDs mentioned in recent conversation history
    private func extractRecentlyMentionedTaskIDs(limit: Int = 3) -> Set<UUID> {
        guard let vm = todoViewModel else { return [] }
        let allIDs = Set(vm.todos.map { $0.id.uuidString })
        var found: [UUID] = []
        
        // Search recent messages (newest first)
        let recentMessages = conversationHistory.suffix(10).reversed()
        for msg in recentMessages {
            for idStr in allIDs {
                if msg.content.contains(idStr), let uuid = UUID(uuidString: idStr), !found.contains(uuid) {
                    found.append(uuid)
                    if found.count >= limit { return Set(found) }
                }
            }
        }
        return Set(found)
    }
    
    private func formatTask(_ task: TodoTask, dateFormatter: DateFormatter, timeFormatter: DateFormatter) -> String {
        var parts = [
            "ID: \(task.id.uuidString)",
            "Title: \(task.title)",
            "Date: \(dateFormatter.string(from: task.dueDate))",
            "Priority: \(task.priority.rawValue)",
            "Type: \(task.eventType.rawValue)",
            "Completed: \(task.isCompleted)"
        ]
        if let start = task.startTime {
            parts.append("Start: \(timeFormatter.string(from: start))")
        }
        if let end = task.endTime {
            parts.append("End: \(timeFormatter.string(from: end))")
        }
        if !task.description.isEmpty {
            parts.append("Desc: \(task.description)")
        }
        return "- " + parts.joined(separator: " | ")
    }
    
    // MARK: - Send Message (Streaming)
    
    func sendMessage(_ userMessage: String) async {
        isLoading = true
        streamingText = ""
        lastError = nil
        executedActions = []
        lastUserMessage = userMessage
        
        // Refresh system prompt with latest task context
        if conversationHistory.isEmpty {
            conversationHistory.append(KimiMessage(role: "system", content: buildSystemPrompt(userMessage: userMessage)))
        } else {
            conversationHistory[0] = KimiMessage(role: "system", content: buildSystemPrompt(userMessage: userMessage))
        }
        
        conversationHistory.append(KimiMessage(role: "user", content: userMessage))
        
        // Trim conversation to keep token usage manageable
        let messagesToSend = trimmedHistory()
        
        do {
            let stream = try await api.streamChat(messages: messagesToSend)
            var fullResponse = ""
            
            for try await chunk in stream {
                fullResponse += chunk
                streamingText = stripHiddenBlocks(from: fullResponse)
            }
            
            // Store full response in history
            conversationHistory.append(KimiMessage(role: "assistant", content: fullResponse))
            
            // NEW: Parse user intent from AI response
            _ = parseIntent(from: fullResponse)
            
            // NEW: Parse and validate actions before execution
            let actions = parseActions(from: fullResponse)
            let validatedActions = validateAndFilterActions(actions)
            
            for action in validatedActions {
                executeAction(action)
            }
            
            // NEW: Update recently mentioned tasks
            updateRecentlyMentionedTasks(from: fullResponse)
            
            // Extract user preferences from conversation for long-term memory
            ChatMemoryStore.shared.extractPreferences(from: userMessage, aiResponse: fullResponse)
            
            // Update streaming text one final time (clean version)
            streamingText = stripHiddenBlocks(from: fullResponse)
            isLoading = false
        } catch {
            lastError = error.localizedDescription
            isLoading = false
            // Remove the failed user message so it can be retried
            if conversationHistory.last?.role == "user" {
                conversationHistory.removeLast()
            }
        }
    }
    
    // NEW: Parse user intent from AI response
    private func parseIntent(from response: String) -> UserIntent {
        if response.contains("[INTENT]confirm[/INTENT]") {
            return .confirm
        } else if response.contains("[INTENT]cancel[/INTENT]") {
            return .cancel
        } else if response.contains("[INTENT]clarify[/INTENT]") {
            return .clarify
        }
        return .neutral
    }
    
    // NEW: Validate actions before execution
    private func validateAndFilterActions(_ actions: [AIAction]) -> [AIAction] {
        return actions.compactMap { action -> AIAction? in
            switch validateAction(action) {
            case .valid:
                return action
            case .invalid(let reason):
                print("Action validation failed: \(reason)")
                return nil
            }
        }
    }
    
    // NEW: Validate individual action
    private func validateAction(_ action: AIAction) -> ValidationResult {
        switch action {
        case .createTask(let data):
            return validateTaskData(data)
        case .createMultipleTasks(let dataList):
            for data in dataList {
                if case .invalid(let reason) = validateTaskData(data) {
                    return .invalid(reason: "Batch task '\(data.title)': \(reason)")
                }
            }
            return .valid
        case .updateTask(_, let data):
            return validateTaskData(data)
        case .deleteTask(let id):
            if UUID(uuidString: id) == nil {
                return .invalid(reason: "Invalid task ID: \(id)")
            }
            return .valid
        case .completeTask(let id):
            if UUID(uuidString: id) == nil {
                return .invalid(reason: "Invalid task ID: \(id)")
            }
            return .valid
        }
    }
    
    // NEW: Validate task data
    private func validateTaskData(_ data: AITaskData) -> ValidationResult {
        if data.title.trimmingCharacters(in: .whitespaces).isEmpty {
            return .invalid(reason: "Task title cannot be empty")
        }
        
        if data.title.count > 200 {
            return .invalid(reason: "Task title too long (max 200 characters)")
        }
        
        if let startStr = data.startTime, let endStr = data.endTime {
            let startParts = startStr.split(separator: ":").compactMap { Int($0) }
            let endParts = endStr.split(separator: ":").compactMap { Int($0) }
            
            if startParts.count >= 2 && endParts.count >= 2 {
                let startMinutes = startParts[0] * 60 + startParts[1]
                let endMinutes = endParts[0] * 60 + endParts[1]
                
                if startMinutes >= endMinutes {
                    return .invalid(reason: "End time must be later than start time")
                }
            }
        }
        
        return .valid
    }
    
    // NEW: Update recently mentioned tasks
    private func updateRecentlyMentionedTasks(from response: String) {
        let pattern = "ID: ([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        
        let matches = regex.matches(in: response, options: [], range: NSRange(location: 0, length: response.utf16.count))
        
        for match in matches {
            if let range = Range(match.range(at: 1), in: response) {
                let idString = String(response[range])
                if let uuid = UUID(uuidString: idString) {
                    recentlyMentionedTaskIds.removeAll { $0 == uuid }
                    recentlyMentionedTaskIds.insert(uuid, at: 0)
                }
            }
        }
        
        if recentlyMentionedTaskIds.count > maxRecentTasks {
            recentlyMentionedTaskIds = Array(recentlyMentionedTaskIds.prefix(maxRecentTasks))
        }
    }
    
    // MARK: - Action Parsing
    
    func parseActions(from response: String) -> [AIAction] {
        var actions: [AIAction] = []
        
        let pattern = "\\[ACTION\\]\\s*([\\s\\S]*?)\\s*\\[/ACTION\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return actions
        }
        
        let nsString = response as NSString
        let matches = regex.matches(in: response, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            let jsonString = nsString.substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let jsonData = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let actionType = json["action"] as? String else { continue }
            
            switch actionType {
            case "create_task":
                if let taskDict = json["task"] as? [String: Any],
                   let taskData = parseTaskData(from: taskDict) {
                    actions.append(.createTask(taskData))
                }
                
            case "create_multiple":
                if let tasksArray = json["tasks"] as? [[String: Any]] {
                    let tasks = tasksArray.compactMap { parseTaskData(from: $0) }
                    if !tasks.isEmpty {
                        actions.append(.createMultipleTasks(tasks))
                    }
                }
                
            case "update_task":
                if let taskId = json["task_id"] as? String,
                   let taskDict = json["task"] as? [String: Any],
                   let taskData = parseTaskData(from: taskDict) {
                    actions.append(.updateTask(id: taskId, fields: taskData))
                }
                
            case "delete_task":
                if let taskId = json["task_id"] as? String {
                    actions.append(.deleteTask(id: taskId))
                }
                
            case "complete_task":
                if let taskId = json["task_id"] as? String {
                    actions.append(.completeTask(id: taskId))
                }
                
            default:
                break
            }
        }
        
        return actions
    }
    
    private func parseTaskData(from dict: [String: Any]) -> AITaskData? {
        guard let title = dict["title"] as? String else { return nil }
        return AITaskData(
            title: title,
            description: dict["description"] as? String,
            dueDate: dict["due_date"] as? String,
            startTime: dict["start_time"] as? String,
            endTime: dict["end_time"] as? String,
            priority: dict["priority"] as? String,
            eventType: dict["event_type"] as? String
        )
    }
    
    // OPTIMIZED: Strip both ACTION and INTENT blocks
    func stripHiddenBlocks(from text: String) -> String {
        var result = text
        
        // 1. Strip complete [ACTION]...[/ACTION] blocks
        let actionPattern = "\\[ACTION\\][\\s\\S]*?\\[/ACTION\\]"
        if let regex = try? NSRegularExpression(pattern: actionPattern, options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(location: 0, length: result.utf16.count),
                withTemplate: ""
            )
        }
        
        // 2. Strip incomplete [ACTION] block at the end (still streaming)
        let incompleteActionPattern = "\\[ACTION\\][\\s\\S]*$"
        if let regex = try? NSRegularExpression(pattern: incompleteActionPattern, options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(location: 0, length: result.utf16.count),
                withTemplate: ""
            )
        }
        
        // 3. Strip [INTENT]...[/INTENT] blocks
        let intentPattern = "\\[INTENT\\][\\s\\S]*?\\[/INTENT\\]"
        if let regex = try? NSRegularExpression(pattern: intentPattern, options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(location: 0, length: result.utf16.count),
                withTemplate: ""
            )
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Action Execution
    
    private func executeAction(_ action: AIAction) {
        guard let vm = todoViewModel else { return }
        
        switch action {
        case .createTask(let data):
            let task = buildTodoTask(from: data)
            vm.addEvent(task)
            executedActions.append(ActionResult(
                icon: "plus.circle.fill",
                label: "已创建: \(data.title)",
                taskId: task.id,
                actionType: .created,
                undoData: .deleteCreated(task.id)
            ))
            // Check conflicts for newly created task
            let conflicts = checkActionConflicts(for: task.id)
            for (a, b) in conflicts {
                let other = a.id == task.id ? b : a
                executedActions.append(ActionResult(
                    icon: "exclamationmark.triangle.fill",
                    label: "⚠️ 时间冲突: \"\(task.title)\" 与 \"\(other.title)\"",
                    taskId: task.id,
                    actionType: .warning,
                    undoData: nil
                ))
            }
            
        case .createMultipleTasks(let dataList):
            var createdIds: [UUID] = []
            for data in dataList {
                let task = buildTodoTask(from: data)
                vm.addEvent(task)
                createdIds.append(task.id)
            }
            for (i, data) in dataList.enumerated() {
                executedActions.append(ActionResult(
                    icon: "plus.circle.fill",
                    label: "已创建: \(data.title)",
                    taskId: createdIds[i],
                    actionType: .created,
                    undoData: .deleteCreated(createdIds[i])
                ))
            }
            // Check conflicts for all newly created tasks
            var reportedPairs: Set<String> = []
            for taskId in createdIds {
                let conflicts = checkActionConflicts(for: taskId)
                for (a, b) in conflicts {
                    let pairKey = [a.id.uuidString, b.id.uuidString].sorted().joined(separator: "-")
                    guard !reportedPairs.contains(pairKey) else { continue }
                    reportedPairs.insert(pairKey)
                    executedActions.append(ActionResult(
                        icon: "exclamationmark.triangle.fill",
                        label: "⚠️ 时间冲突: \"\(a.title)\" 与 \"\(b.title)\"",
                        taskId: taskId,
                        actionType: .warning,
                        undoData: nil
                    ))
                }
            }
            
        case .updateTask(let id, let fields):
            if let uuid = UUID(uuidString: id),
               let existing = vm.todos.first(where: { $0.id == uuid }) {
                let oldCopy = existing
                var updated = existing
                applyUpdates(fields, to: &updated)
                vm.updateTodo(updated)
                executedActions.append(ActionResult(
                    icon: "pencil.circle.fill",
                    label: "已更新: \(updated.title)",
                    taskId: uuid,
                    actionType: .updated,
                    undoData: .revertUpdate(oldCopy)
                ))
                // Check conflicts for updated task
                let conflicts = checkActionConflicts(for: uuid)
                for (a, b) in conflicts {
                    let other = a.id == uuid ? b : a
                    executedActions.append(ActionResult(
                        icon: "exclamationmark.triangle.fill",
                        label: "⚠️ 时间冲突: \"\(updated.title)\" 与 \"\(other.title)\"",
                        taskId: uuid,
                        actionType: .warning,
                        undoData: nil
                    ))
                }
            }
            
        case .deleteTask(let id):
            if let uuid = UUID(uuidString: id),
               let task = vm.todos.first(where: { $0.id == uuid }) {
                let copy = task
                vm.deleteTodoById(uuid)
                executedActions.append(ActionResult(
                    icon: "trash.circle.fill",
                    label: "已删除: \(copy.title)",
                    taskId: uuid,
                    actionType: .deleted,
                    undoData: .restoreDeleted(copy)
                ))
            }
            
        case .completeTask(let id):
            if let uuid = UUID(uuidString: id),
               let task = vm.todos.first(where: { $0.id == uuid }) {
                if !task.isCompleted {
                    vm.toggleTodoCompletion(task)
                    executedActions.append(ActionResult(
                        icon: "checkmark.circle.fill",
                        label: "已完成: \(task.title)",
                        taskId: uuid,
                        actionType: .completed,
                        undoData: .uncomplete(uuid)
                    ))
                }
            }
        }
    }
    
    // MARK: - Undo
    
    func undoAction(_ result: ActionResult) {
        guard let vm = todoViewModel, let undoData = result.undoData else { return }
        
        switch undoData {
        case .deleteCreated(let id):
            vm.deleteTodoById(id)
        case .restoreDeleted(let task):
            vm.addEvent(task)
        case .revertUpdate(let oldTask):
            vm.updateTodo(oldTask)
        case .uncomplete(let id):
            if let task = vm.todos.first(where: { $0.id == id }), task.isCompleted {
                vm.toggleTodoCompletion(task)
            }
        }
    }
    
    private func buildTodoTask(from data: AITaskData) -> TodoTask {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let dueDate = data.dueDate.flatMap { dateFormatter.date(from: $0) } ?? Date()
        
        var startTime: Date?
        var endTime: Date?
        
        if let startStr = data.startTime {
            let parts = startStr.split(separator: ":").compactMap { Int($0) }
            if parts.count >= 2 {
                startTime = calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: dueDate)
            }
        }
        if let endStr = data.endTime {
            let parts = endStr.split(separator: ":").compactMap { Int($0) }
            if parts.count >= 2 {
                endTime = calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: dueDate)
            }
        }
        
        let priority: TodoTask.TaskPriority = {
            switch data.priority?.lowercased() {
            case "high": return .high
            case "low": return .low
            default: return .medium
            }
        }()
        
        let eventType: TodoTask.EventType = {
            switch data.eventType?.lowercased() {
            case "gym": return .gym
            case "class": return .class_
            case "study": return .study
            case "meeting": return .meeting
            case "dinner": return .dinner
            default: return .other
            }
        }()
        
        return TodoTask(
            title: data.title,
            description: data.description ?? "",
            isCompleted: false,
            dueDate: dueDate,
            startTime: startTime,
            endTime: endTime,
            priority: priority,
            createdAt: Date(),
            eventType: eventType
        )
    }
    
    private func applyUpdates(_ data: AITaskData, to task: inout TodoTask) {
        task.title = data.title
        if let desc = data.description { task.description = desc }
        
        let calendar = Calendar.current
        if let dueDateStr = data.dueDate {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            if let d = df.date(from: dueDateStr) { task.dueDate = d }
        }
        if let startStr = data.startTime {
            let parts = startStr.split(separator: ":").compactMap { Int($0) }
            if parts.count >= 2 {
                task.startTime = calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: task.dueDate)
            }
        }
        if let endStr = data.endTime {
            let parts = endStr.split(separator: ":").compactMap { Int($0) }
            if parts.count >= 2 {
                task.endTime = calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: task.dueDate)
            }
        }
        if let p = data.priority?.lowercased() {
            switch p {
            case "high": task.priority = .high
            case "low": task.priority = .low
            default: task.priority = .medium
            }
        }
        if let e = data.eventType?.lowercased() {
            switch e {
            case "gym": task.eventType = .gym
            case "class": task.eventType = .class_
            case "study": task.eventType = .study
            case "meeting": task.eventType = .meeting
            case "dinner": task.eventType = .dinner
            default: task.eventType = .other
            }
        }
    }
    
    // MARK: - Conflict Detection
    
    /// Find all time-overlapping task pairs among given tasks
    private func findConflicts(among tasks: [TodoTask]) -> [(TodoTask, TodoTask)] {
        let timed = tasks.filter { $0.startTime != nil && $0.endTime != nil && !$0.isCompleted }
        var conflicts: [(TodoTask, TodoTask)] = []
        let calendar = Calendar.current
        
        for i in 0..<timed.count {
            for j in (i + 1)..<timed.count {
                let a = timed[i], b = timed[j]
                // Must be same day
                guard calendar.isDate(a.dueDate, inSameDayAs: b.dueDate),
                      let startA = a.startTime, let endA = a.endTime,
                      let startB = b.startTime, let endB = b.endTime else { continue }
                // Overlap: startA < endB && startB < endA
                if startA < endB && startB < endA {
                    conflicts.append((a, b))
                }
            }
        }
        return conflicts
    }
    
    /// Check if a specific task conflicts with any existing tasks
    private func checkActionConflicts(for taskId: UUID) -> [(TodoTask, TodoTask)] {
        guard let vm = todoViewModel,
              let target = vm.todos.first(where: { $0.id == taskId }) else { return [] }
        guard target.startTime != nil && target.endTime != nil else { return [] }
        
        let others = vm.todos.filter { $0.id != taskId }
        let allRelevant = [target] + others
        return findConflicts(among: allRelevant).filter { $0.0.id == taskId || $0.1.id == taskId }
    }
    
    /// Build conflict context string for system prompt
    private func buildConflictContext() -> String {
        guard let vm = todoViewModel else { return "" }
        let conflicts = findConflicts(among: vm.todos)
        if conflicts.isEmpty { return "" }
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var lines = ["## ⚠️ 当前存在时间冲突的任务："]
        for (a, b) in conflicts {
            let aStart = a.startTime.map { timeFormatter.string(from: $0) } ?? "?"
            let aEnd = a.endTime.map { timeFormatter.string(from: $0) } ?? "?"
            let bStart = b.startTime.map { timeFormatter.string(from: $0) } ?? "?"
            let bEnd = b.endTime.map { timeFormatter.string(from: $0) } ?? "?"
            lines.append("- \"\(a.title)\"(\(aStart)-\(aEnd)) 与 \"\(b.title)\"(\(bStart)-\(bEnd)) 在 \(dateFormatter.string(from: a.dueDate)) 冲突")
        }
        lines.append("请在规划新任务时避免上述时间段，或建议用户调整。")
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Reset
    
    func resetConversation() {
        conversationHistory = []
        streamingText = ""
        lastError = nil
        executedActions = []
        lastUserMessage = ""
        recentlyMentionedTaskIds = []
    }
    
    var conversationCount: Int {
        conversationHistory.filter { $0.role != "system" }.count
    }
    
    // MARK: - Context Trimming
    
    private func trimmedHistory() -> [KimiMessage] {
        guard conversationHistory.count > 1 else { return conversationHistory }
        
        let systemMessage = conversationHistory[0] // always system prompt
        let chatMessages = Array(conversationHistory.dropFirst())
        
        if chatMessages.count <= maxHistoryMessages {
            return conversationHistory
        }
        
        // Keep last N messages
        let trimmed = Array(chatMessages.suffix(maxHistoryMessages))
        return [systemMessage] + trimmed
    }
}
