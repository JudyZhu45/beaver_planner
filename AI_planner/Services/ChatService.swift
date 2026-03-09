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

enum AIAction {//Task type
    case createTask(AITaskData)
    case createMultipleTasks([AITaskData])
    case updateTask(id: String, fields: AITaskData)
    case deleteTask(id: String)
    case completeTask(id: String)
}

struct AITaskData { //task standardized data format from AI
    var title: String
    var description: String?
    var dueDate: String?      // "2026-02-25" ISO format
    var startTime: String?    // "15:00" 24hr format
    var endTime: String?      // "16:00"
    var priority: String?     // "low", "medium", "high"
    var eventType: String?    // "gym", "class", "study", "meeting", "dinner", "other"
}

// MARK: - Validation Result

enum ValidationResult {
    case valid
    case invalid(reason: String)
}

// MARK: - Pending Task Card (structured preview before confirmation)

/// Represents one pending action rendered as a card in the confirmation UI.
struct PendingTaskCard: Identifiable {
    let id = UUID()

    enum CardKind {
        case create(AITaskData)
        case update(AITaskData)
        case delete(title: String)
        case complete(title: String)
    }

    let kind: CardKind

    // Resolved display values (derived at creation time so view is dumb)
    let title: String
    let subtitle: String?         // description or nil
    let dateLabel: String?        // e.g. "Mar 9"
    let timeLabel: String?        // e.g. "9:00 AM – 10:00 AM"
    let durationLabel: String?    // e.g. "60m"
    let eventColor: EventColor
    let actionBadge: String       // SF Symbol for the action type (plus / pencil / trash / checkmark)
    let actionLabel: String       // "Add" / "Update" / "Delete" / "Complete"
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
        case deleteCreated(UUID)
        case restoreDeleted(TodoTask)
        case revertUpdate(TodoTask)
        case uncomplete(UUID)
    }
}

// MARK: - Step 1 Result: Time window extracted by AI

private struct TimeWindowResult {
    let startDate: String?  // "yyyy-MM-dd"
    let endDate: String?    // "yyyy-MM-dd"
    let isSchedulingRelated: Bool
}

// MARK: - Chat Service

@MainActor
class ChatService: ObservableObject {
    @Published var isLoading = false
    @Published var streamingText = ""
    @Published var lastError: String?
    @Published var executedActions: [ActionResult] = []
    
    /// Actions proposed by AI but not yet executed — waiting for user confirmation
    @Published private(set) var pendingActions: [AIAction] = []
    
    private let api = AIAPIService.shared
    private var conversationHistory: [KimiMessage] = []
    private let maxHistoryMessages = 20
    
    /// Cache the last time window so confirmation messages reuse it
    private var lastTimeWindow: TimeWindowResult?
    
    weak var todoViewModel: TodoViewModel?
    
    init() {}
    
    // MARK: - Execute Pending Actions (called when user taps Confirm)
    
    func executePendingActions() {
        let valid = validateAndFilterActions(pendingActions)
        executedActions = []
        for action in valid {
            executeAction(action)
        }
        pendingActions = []
    }
    
    // MARK: - Cancel Pending Actions
    
    func cancelPendingActions() {
        pendingActions = []
    }
    
    // MARK: - Step 1: Extract Time Window (AI call, non-streaming)
    
    private func extractTimeWindow(from userMessage: String) async -> TimeWindowResult {
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        
        let weekdayFormatter: DateFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "zh_CN")
        weekdayFormatter.dateFormat = "EEEE"
        let weekday = weekdayFormatter.string(from: Date())
        
        let prompt = """
        You are a time-range extraction engine for a scheduling app.
        Your ONLY job is to extract the date range the user is referring to.
        
        Current date: \(today) (\(weekday))
        
        Rules:
        1. Output ONLY a JSON object, nothing else.
        2. Extract the date range the user is referring to.
        3. If the user mentions a single day (e.g., "tomorrow", "March 10"), startDate and endDate should be the same day.
        4. If no date/time context at all (pure chat like "hello", "thank you"), set isSchedulingRelated to false and dates to null.
        5. If the user mentions a time but no date, default to today.
        6. For ANY scheduling request (plan, arrange, schedule), set isSchedulingRelated to true.
        7. If the user says "you decide the time" / "you pick the time", still extract the date from context and set isSchedulingRelated to true.
        8. IMPORTANT: Even if no exact time is given, if the user wants a task created or scheduled on a specific day, set isSchedulingRelated to true and extract that day.
        
        JSON shape:
        {
          "startDate": "yyyy-MM-dd or null",
          "endDate": "yyyy-MM-dd or null",
          "isSchedulingRelated": true/false
        }
        
        User input:
        \(userMessage)
        """
        
        let messages = [
            KimiMessage(role: "system", content: prompt),
            KimiMessage(role: "user", content: userMessage)
        ]
        
        do {
            let raw = try await api.sendChat(messages: messages, temperature: 0.0)
            guard let jsonString = extractJSONObject(from: raw),
                  let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return TimeWindowResult(startDate: nil, endDate: nil, isSchedulingRelated: false)
            }
            
            return TimeWindowResult(
                startDate: json["startDate"] as? String,
                endDate: json["endDate"] as? String,
                isSchedulingRelated: json["isSchedulingRelated"] as? Bool ?? false
            )
        } catch {
            return TimeWindowResult(startDate: nil, endDate: nil, isSchedulingRelated: false)
        }
    }
    
    // MARK: - Step 2: Build System Prompt with Window Tasks

    private func buildSystemPrompt(userMessage: String, windowTasks: [TodoTask]) -> String {
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
        
        let tasksContext = formatTasksForContext(windowTasks, dateFormatter: dateFormatter, timeFormatter: timeFormatter)
        let beaverPersona = BeaverPersonality.shared.personaPrompt(tasks: todoViewModel?.todos ?? [])
        let chatMemory = ChatMemoryStore.shared.generateMemorySummary()

        return """
        You are Beaver, a warm and playful schedule assistant in a task management app.

        You can:
        1. Chat naturally with the user
        2. Create, update, delete, complete tasks
        3. Plan daily or weekly schedules

        Current date: \(today) (\(weekday))  
        Current time: \(currentTime)  
        \(chatMemory.isEmpty ? "" : chatMemory)

        ## Existing Tasks (Editable)
        The following tasks exist and may need to be kept, moved, updated, or deleted depending on user request or AI adjustment:
        \(tasksContext)

        ## Core Rules

        1. Always check existing tasks before creating new tasks.
        2. Respect user peak hours, preferred durations, and task habits.
        3. Leave reasonable gaps; avoid overloading the schedule.
        4. 24-hour format HH:mm, date YYYY-MM-DD. event_type: gym, class, study, meeting, dinner, other. priority: low, medium, high.

        ## Conflict Detection (CRITICAL)

        - Any time overlap is a conflict.
        - If a conflict exists, propose conflict-free alternatives.
        - Include necessary update/delete actions in ACTION blocks.

        ## Proposal & ACTION Rules

        - Every proposed plan (including replan or AI adjustment) must include all required ACTION blocks implementing the final schedule.
        - ACTION blocks must include:
            - update_task for modified existing tasks
            - delete_task for removed tasks
            - create_task for new tasks
        - Always generate ACTION during proposal; do not wait for user confirmation.
        - User confirmation will be handled by frontend.
        - **If a user requests to move/reschedule a task, always use update_task with task_id.**
        - **If conflicts exist, include update/delete of conflicting tasks in the same proposal.**
        - Avoid duplicates; always check existing tasks before creating new ones.

        ## Replan / AI Adjustment

        - When replanning or AI proposes changes, treat it as **schedule modification**:
        1. Analyze existing tasks
        2. Decide which tasks to keep, move (update), or remove (delete)
        3. Create new tasks only if they don't exist
        - Avoid duplicate tasks; prefer update_task over create_task for similar tasks.

        ## Confirmation Flow

        1. Propose plan with natural language explanation
        2. Include all ACTION blocks representing final schedule
        3. End proposal with [PENDING] for frontend confirmation
        4. Upon confirmation, frontend executes ACTION blocks

        ## ACTION Format (single line JSON)

        Create one task:
        [ACTION]
        {"action":"create_task","task":{"title":"Meeting","description":"Team standup","due_date":"2026-02-25","start_time":"15:00","end_time":"16:00","priority":"high","event_type":"meeting"}}
        [/ACTION]

        Update task:
        [ACTION]
        {"action":"update_task","task_id":"UUID","task":{"start_time":"14:00","end_time":"15:00"}}
        [/ACTION]

        Delete task:
        [ACTION]
        {"action":"delete_task","task_id":"UUID"}
        [/ACTION]

        Complete task:
        [ACTION]
        {"action":"complete_task","task_id":"UUID"}
        [/ACTION]

        Create multiple tasks:
        [ACTION]
        {"action":"create_multiple","tasks":[{"title":"Gym","due_date":"2026-02-25","start_time":"08:00","end_time":"09:00","priority":"medium","event_type":"gym"}]}
        [/ACTION]

        ## Special Notes

        - Be concise, organized, and occasionally playful 🦫
        - Avoid creating duplicates
        - Always follow conflict detection and replan rules
        - Proposal must include final ACTION blocks; frontend handles confirmation
        """
    }
    
    // MARK: - Format Tasks for Context
    
    private func formatTasksForContext(_ tasks: [TodoTask], dateFormatter: DateFormatter, timeFormatter: DateFormatter) -> String {
        if tasks.isEmpty {
            return "No existing tasks in this time window."
        }
        
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: tasks) { calendar.startOfDay(for: $0.dueDate) }
        
        var lines: [String] = []
        lines.append("The following tasks already exist in the user's schedule for the relevant time period:")
        
        for date in grouped.keys.sorted() {
            let dayTasks = grouped[date, default: []].sorted {
                ($0.startTime ?? $0.dueDate) < ($1.startTime ?? $1.dueDate)
            }
            lines.append("### \(dateFormatter.string(from: date))")
            
            // Occupied time slots summary — helps AI avoid conflicts at a glance
            let timedTasks = dayTasks.filter { $0.startTime != nil && $0.endTime != nil }
            if !timedTasks.isEmpty {
                let slots = timedTasks.map { task -> String in
                    let s = timeFormatter.string(from: task.startTime!)
                    let e = timeFormatter.string(from: task.endTime!)
                    return "\(s)–\(e) [\(task.title)]"
                }.joined(separator: ", ")
                lines.append("⚠️ OCCUPIED SLOTS (do NOT schedule anything overlapping these): \(slots)")
            }
            
            for task in dayTasks {
                lines.append(formatTask(task, dateFormatter: dateFormatter, timeFormatter: timeFormatter))
            }
        }
        
        return lines.joined(separator: "\n")
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
    
    // MARK: - Fetch Tasks in Window
    
    /// Parse a date string that may be "yyyy-MM-dd" or "yyyy-MM-dd'T'HH:mm:ss" (or similar ISO variants).
    /// Always extracts just the date portion in the current calendar timezone.
    private func parseDateOnly(from str: String) -> Date? {
        // Try plain date first
        let plain = DateFormatter()
        plain.dateFormat = "yyyy-MM-dd"
        plain.timeZone = TimeZone.current
        if let d = plain.date(from: str) { return d }
        
        // AI sometimes returns ISO-8601 with time component — strip it
        let dateOnly = String(str.prefix(10)) // "2026-03-09T15:00:00" → "2026-03-09"
        return plain.date(from: dateOnly)
    }
    
    private func fetchTasksInWindow(startDate: String?, endDate: String?) -> [TodoTask] {
        guard let vm = todoViewModel else { return [] }
        
        let calendar = Calendar.current
        
        // If no date range, return today + tomorrow as default context
        guard let startStr = startDate,
              let start = parseDateOnly(from: startStr) else {
            let today = calendar.startOfDay(for: Date())
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            return vm.todos.filter {
                let due = calendar.startOfDay(for: $0.dueDate)
                return due >= today && due <= tomorrow
            }.sorted { ($0.startTime ?? $0.dueDate) < ($1.startTime ?? $1.dueDate) }
        }
        
        let end: Date
        if let endStr = endDate, let e = parseDateOnly(from: endStr) {
            end = e
        } else {
            end = start
        }
        
        let windowStart = calendar.startOfDay(for: start)
        let windowEnd = calendar.startOfDay(for: end)
        
        return vm.todos
            .filter {
                let due = calendar.startOfDay(for: $0.dueDate)
                return due >= windowStart && due <= windowEnd
            }
            .sorted {
                if $0.dueDate == $1.dueDate {
                    return ($0.startTime ?? $0.dueDate) < ($1.startTime ?? $1.dueDate)
                }
                return $0.dueDate < $1.dueDate
            }
    }
    
    // MARK: - Send Message (Main Entry Point)
    
    func sendMessage(_ userMessage: String) async {
        isLoading = true
        streamingText = ""
        lastError = nil
        executedActions = []
        
        // === Step 1: Extract time window ===
        // Always call AI to extract the time window for maximum accuracy.
        let timeWindow = await extractTimeWindow(from: userMessage)
        lastTimeWindow = timeWindow
        
        print("🔍 [Step1] timeWindow: start=\(timeWindow.startDate ?? "nil"), end=\(timeWindow.endDate ?? "nil"), isScheduling=\(timeWindow.isSchedulingRelated)")
        print("🔍 [Step1] todoViewModel has \(todoViewModel?.todos.count ?? -1) total tasks")
        
        // === Fetch existing tasks in that window ===
        let windowTasks: [TodoTask]
        if timeWindow.isSchedulingRelated {
            windowTasks = fetchTasksInWindow(startDate: timeWindow.startDate, endDate: timeWindow.endDate)
        } else {
            windowTasks = fetchTasksInWindow(startDate: nil, endDate: nil)
        }
        
        print("🔍 [Step1] windowTasks count: \(windowTasks.count)")
        let tf = DateFormatter(); tf.dateFormat = "HH:mm"; tf.timeZone = TimeZone.current
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"; df.timeZone = TimeZone.current
        for t in windowTasks {
            let startLocal = t.startTime.map { tf.string(from: $0) } ?? "nil"
            let endLocal = t.endTime.map { tf.string(from: $0) } ?? "nil"
            let dueLocal = df.string(from: t.dueDate)
            print("🔍   task: \(t.title) | dueLocal: \(dueLocal) | startLocal: \(startLocal) | endLocal: \(endLocal) | dueUTC: \(t.dueDate) | startUTC: \(t.startTime?.description ?? "nil")")
        }
        print("🔍 [Step1] System timezone: \(TimeZone.current.identifier)")
        
        // === Step 2: Send to AI with task context (streaming) ===
        let systemPrompt = buildSystemPrompt(userMessage: userMessage, windowTasks: windowTasks)
        
        // Log the full system prompt sent to AI
        print("📋 [Step2] Full system prompt sent to AI:\n\(systemPrompt)\n📋 [Step2] END of system prompt")
        
        if conversationHistory.isEmpty {
            conversationHistory.append(KimiMessage(role: "system", content: systemPrompt))
        } else {
            conversationHistory[0] = KimiMessage(role: "system", content: systemPrompt)
        }
        
        conversationHistory.append(KimiMessage(role: "user", content: userMessage))
        
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
            
            // Parse actions from AI response
            let actions = parseActions(from: fullResponse)
            let isPending = fullResponse.contains("[PENDING]")
            
            if !actions.isEmpty {
                // Always hold actions as pending — user must tap Confirm
                pendingActions = actions
            } else {
                pendingActions = []
            }
            
            // Extract user preferences for long-term memory
            ChatMemoryStore.shared.extractPreferences(from: userMessage, aiResponse: fullResponse)
            
            // Final clean display text
            if streamingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                streamingText = stripHiddenBlocks(from: fullResponse)
            }
            isLoading = false
        } catch {
            lastError = error.localizedDescription
            isLoading = false
            if conversationHistory.last?.role == "user" {
                conversationHistory.removeLast()
            }
        }
    }
    
    // MARK: - JSON Extraction
    
    private func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        
        var depth = 0
        var inString = false
        var escaped = false
        
        for index in text[start...].indices {
            let char = text[index]
            
            if inString {
                if escaped {
                    escaped = false
                } else if char == "\\" {
                    escaped = true
                } else if char == "\"" {
                    inString = false
                }
                continue
            }
            
            if char == "\"" {
                inString = true
            } else if char == "{" {
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0 {
                    return String(text[start...index])
                }
            }
        }
        
        return nil
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
                   let taskData = parseTaskDataForUpdate(from: taskDict) {
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

    /// Lenient parser for update_task — title is optional since we may only update specific fields.
    private func parseTaskDataForUpdate(from dict: [String: Any]) -> AITaskData? {
        // update_task may omit title; use empty string as sentinel — applyUpdates only overwrites non-nil fields
        let title = dict["title"] as? String ?? ""
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
    
    // MARK: - Strip Hidden Blocks
    
    func stripHiddenBlocks(from text: String) -> String {
        var result = text
        
        let actionPattern = "\\[ACTION\\][\\s\\S]*?\\[/ACTION\\]"
        if let regex = try? NSRegularExpression(pattern: actionPattern, options: []) {
            result = regex.stringByReplacingMatches(
                in: result, options: [],
                range: NSRange(location: 0, length: result.utf16.count),
                withTemplate: ""
            )
        }
        
        let incompleteActionPattern = "\\[ACTION\\][\\s\\S]*$"
        if let regex = try? NSRegularExpression(pattern: incompleteActionPattern, options: []) {
            result = regex.stringByReplacingMatches(
                in: result, options: [],
                range: NSRange(location: 0, length: result.utf16.count),
                withTemplate: ""
            )
        }
        
        let intentPattern = "\\[INTENT\\][\\s\\S]*?\\[/INTENT\\]"
        if let regex = try? NSRegularExpression(pattern: intentPattern, options: []) {
            result = regex.stringByReplacingMatches(
                in: result, options: [],
                range: NSRange(location: 0, length: result.utf16.count),
                withTemplate: ""
            )
        }
        
        // Strip [PENDING] marker
        result = result.replacingOccurrences(of: "[PENDING]", with: "")
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Action Validation
    
    private func validateAndFilterActions(_ actions: [AIAction]) -> [AIAction] {
        return actions.compactMap { action -> AIAction? in
            switch validateAction(action) {
            case .valid:
                return action
            case .invalid(let reason):
                print("Action validation failed: \(reason)")
                executedActions.append(ActionResult(
                    icon: "exclamationmark.triangle.fill",
                    label: "Blocked: \(reason)",
                    taskId: nil,
                    actionType: .warning,
                    undoData: nil
                ))
                return nil
            }
        }
    }
    
    private func validateAction(_ action: AIAction) -> ValidationResult {
        switch action {
        case .createTask(let data):
            if case .invalid(let reason) = validateTaskData(data) {
                return .invalid(reason: reason)
            }
            return .valid
        case .createMultipleTasks(let dataList):
            for data in dataList {
                if case .invalid(let reason) = validateTaskData(data) {
                    return .invalid(reason: "Task '\(data.title)': \(reason)")
                }
            }
            return .valid
        case .updateTask(let id, let data):
            if UUID(uuidString: id) == nil {
                return .invalid(reason: "Invalid task ID: \(id)")
            }
            // For update_task, title may be omitted (only changed fields are provided)
            // so we skip the empty-title check and only validate time range if present
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
    
    // MARK: - Action Execution
    
    private func executeAction(_ action: AIAction) {
        guard let vm = todoViewModel else { return }
        
        switch action {
        case .createTask(let data):
            let task = buildTodoTask(from: data)
            vm.addEvent(task)
            executedActions.append(ActionResult(
                icon: "plus.circle.fill",
                label: "Created: \(data.title)",
                taskId: task.id,
                actionType: .created,
                undoData: .deleteCreated(task.id)
            ))
            
        case .createMultipleTasks(let dataList):
            for data in dataList {
                let task = buildTodoTask(from: data)
                vm.addEvent(task)
                executedActions.append(ActionResult(
                    icon: "plus.circle.fill",
                    label: "Created: \(data.title)",
                    taskId: task.id,
                    actionType: .created,
                    undoData: .deleteCreated(task.id)
                ))
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
                    label: "Updated: \(updated.title)",
                    taskId: uuid,
                    actionType: .updated,
                    undoData: .revertUpdate(oldCopy)
                ))
            }
            
        case .deleteTask(let id):
            if let uuid = UUID(uuidString: id),
               let task = vm.todos.first(where: { $0.id == uuid }) {
                let copy = task
                vm.deleteTodoById(uuid)
                executedActions.append(ActionResult(
                    icon: "trash.circle.fill",
                    label: "Deleted: \(copy.title)",
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
                        label: "Completed: \(task.title)",
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
    
    // MARK: - Build TodoTask from AI Data
    
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
        // Only overwrite title when AI explicitly provided one (update_task may omit it)
        if !data.title.isEmpty { task.title = data.title }
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
    
    // MARK: - Reset
    
    func resetConversation() {
        conversationHistory = []
        streamingText = ""
        lastError = nil
        executedActions = []
        lastTimeWindow = nil
    }
    
    // MARK: - Context Trimming
    
    private func trimmedHistory() -> [KimiMessage] {
        guard conversationHistory.count > 1 else { return conversationHistory }
        
        let systemMessage = conversationHistory[0]
        let chatMessages = Array(conversationHistory.dropFirst())
        
        if chatMessages.count <= maxHistoryMessages {
            return conversationHistory
        }
        
        let trimmed = Array(chatMessages.suffix(maxHistoryMessages))
        return [systemMessage] + trimmed
    }

}
