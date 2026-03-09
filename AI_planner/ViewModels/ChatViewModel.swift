//
//  ChatViewModel.swift
//  AI_planner
//
//  Created by Judy459 on 2/24/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isTyping = false
    @Published var errorMessage: String?
    @Published var lastActionResults: [ActionResult] = []
    @Published var showConfirmButton = false
    
    let chatService = ChatService()
    
    /// Structured task cards derived from pendingActions — shown as rich previews before confirmation
    var pendingTaskCards: [PendingTaskCard] {
        chatService.pendingActions.flatMap { action -> [PendingTaskCard] in
            switch action {
            case .createTask(let data):
                return [makeCard(.create(data), data: data, actionBadge: "plus.circle.fill", actionLabel: "Add")]
            case .createMultipleTasks(let list):
                return list.map { makeCard(.create($0), data: $0, actionBadge: "plus.circle.fill", actionLabel: "Add") }
            case .updateTask(let id, let data):
                // If AI omitted the title (partial update), fall back to the existing task's title
                var displayData = data
                if displayData.title.isEmpty {
                    displayData.title = chatService.todoViewModel?.todos.first(where: { $0.id.uuidString == id })?.title ?? "Task"
                }
                return [makeCard(.update(displayData), data: displayData, actionBadge: "pencil.circle.fill", actionLabel: "Update")]
            case .deleteTask(let id):
                let title = chatService.todoViewModel?.todos.first(where: { $0.id.uuidString == id })?.title ?? "Task"
                return [makeDeleteCard(kind: .delete(title: title), title: title, badge: "trash.circle.fill", label: "Delete")]
            case .completeTask(let id):
                let title = chatService.todoViewModel?.todos.first(where: { $0.id.uuidString == id })?.title ?? "Task"
                return [makeDeleteCard(kind: .complete(title: title), title: title, badge: "checkmark.circle.fill", label: "Complete")]
            }
        }
    }

    // MARK: - Card builders

    private func makeCard(_ kind: PendingTaskCard.CardKind, data: AITaskData, actionBadge: String, actionLabel: String) -> PendingTaskCard {
        let color = resolveEventColor(data.eventType)
        let timeLabel = resolveTimeLabel(start: data.startTime, end: data.endTime)
        let durationLabel = resolveDuration(start: data.startTime, end: data.endTime)
        let dateLabel = resolveDateLabel(data.dueDate)
        return PendingTaskCard(
            kind: kind,
            title: data.title,
            subtitle: data.description?.isEmpty == false ? data.description : nil,
            dateLabel: dateLabel,
            timeLabel: timeLabel,
            durationLabel: durationLabel,
            eventColor: color,
            actionBadge: actionBadge,
            actionLabel: actionLabel
        )
    }

    private func makeDeleteCard(kind: PendingTaskCard.CardKind, title: String, badge: String, label: String) -> PendingTaskCard {
        PendingTaskCard(
            kind: kind,
            title: title,
            subtitle: nil,
            dateLabel: nil,
            timeLabel: nil,
            durationLabel: nil,
            eventColor: AppTheme.eventColors.last!,
            actionBadge: badge,
            actionLabel: label
        )
    }

    private func resolveEventColor(_ eventTypeStr: String?) -> EventColor {
        guard let raw = eventTypeStr?.lowercased() else { return AppTheme.eventColors.last! }
        return AppTheme.eventColors.first(where: { $0.name.lowercased() == raw })
            ?? AppTheme.eventColors.last!
    }

    private func resolveTimeLabel(start: String?, end: String?) -> String? {
        guard let start else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let display = DateFormatter()
        display.dateFormat = "h:mm a"
        guard let s = fmt.date(from: start) else { return start }
        let startStr = display.string(from: s)
        if let end, let e = fmt.date(from: end) {
            return "\(startStr) – \(display.string(from: e))"
        }
        return startStr
    }

    private func resolveDuration(start: String?, end: String?) -> String? {
        guard let start, let end else { return nil }
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
        guard let s = fmt.date(from: start), let e = fmt.date(from: end) else { return nil }
        let mins = Int(e.timeIntervalSince(s) / 60)
        guard mins > 0 else { return nil }
        return mins >= 60 ? "\(mins / 60)h\(mins % 60 > 0 ? " \(mins % 60)m" : "")" : "\(mins)m"
    }

    private func resolveDateLabel(_ dueDateStr: String?) -> String? {
        guard let dueDateStr else { return nil }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: dueDateStr) else { return dueDateStr }
        let display = DateFormatter(); display.dateFormat = "MMM d"
        return display.string(from: date)
    }
    
    private let chatHistoryKey = "SavedChatHistory"
    private var streamingObserver: AnyCancellable?
    
    init() {
        loadChatHistory()
        
        // Observe streaming text changes
        streamingObserver = chatService.$streamingText
            .receive(on: RunLoop.main)
            .sink { [weak self] newText in
                self?.updateStreamingMessage(with: newText)
            }
    }
    
    func configure(with todoViewModel: TodoViewModel) {
        chatService.todoViewModel = todoViewModel
    }
    
    // MARK: - Send Message
    
    func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Add user message
        let userMessage = Message(content: trimmed, sender: .user, timestamp: Date())
        messages.append(userMessage)
        
        // Add streaming placeholder
        let placeholder = Message(content: "", sender: .ai, timestamp: Date(), isStreaming: true)
        messages.append(placeholder)
        
        isTyping = true
        errorMessage = nil
        lastActionResults = []
        showConfirmButton = false
        
        Task {
            await chatService.sendMessage(trimmed)
            
            // Update final message
            if let lastIndex = messages.indices.last, messages[lastIndex].sender == .ai {
                if let error = chatService.lastError {
                    messages[lastIndex] = Message(
                        content: error,
                        sender: .ai,
                        timestamp: Date(),
                        isError: true
                    )
                    errorMessage = error
                } else {
                    let finalContent = chatService.streamingText
                    
                    messages[lastIndex] = Message(
                        content: finalContent,
                        sender: .ai,
                        timestamp: Date()
                    )
                    
                    // Store action results for interactive display
                    lastActionResults = chatService.executedActions
                    
                    // Show Confirm/Cancel buttons when AI has pending actions waiting for approval
                    showConfirmButton = !chatService.pendingActions.isEmpty
                }
            }
            
            isTyping = false
            saveChatHistory()
        }
    }
    
    // MARK: - Confirm Proposal
    
    func confirmProposal() {
        showConfirmButton = false
        // Directly execute cached pending actions — no extra API call needed
        chatService.executePendingActions()
        lastActionResults = chatService.executedActions
    }
    
    func cancelProposal() {
        showConfirmButton = false
        chatService.cancelPendingActions()
    }
    
    // MARK: - Undo Action
    
    func undoAction(_ result: ActionResult) {
        chatService.undoAction(result)
        lastActionResults.removeAll { $0.id == result.id }
    }
    
    // MARK: - Delete Message
    
    func deleteMessage(_ message: Message) {
        messages.removeAll { $0.id == message.id }
        saveChatHistory()
    }
    
    func copyMessageContent(_ message: Message) {
        UIPasteboard.general.string = message.content
    }
    
    // MARK: - Streaming Update
    
    private func updateStreamingMessage(with text: String) {
        guard isTyping,
              let lastIndex = messages.indices.last,
              messages[lastIndex].sender == .ai,
              messages[lastIndex].isStreaming else { return }
        
        messages[lastIndex] = Message(
            content: text,
            sender: .ai,
            timestamp: Date(),
            isStreaming: true
        )
    }
    
    // MARK: - Clear Chat
    
    func clearHistory() {
        chatService.resetConversation()
        UserDefaults.standard.removeObject(forKey: chatHistoryKey)
        messages = []
    }
    
    // MARK: - Persistence
    
    private func saveChatHistory() {
        // Only save last 50 messages, exclude streaming state
        let toSave = messages.suffix(50).map { msg -> Message in
            Message(
                content: msg.content,
                sender: msg.sender,
                timestamp: msg.timestamp,
                isStreaming: false,
                isError: msg.isError
            )
        }
        if let encoded = try? JSONEncoder().encode(Array(toSave)) {
            UserDefaults.standard.set(encoded, forKey: chatHistoryKey)
        }
    }
    
    private func loadChatHistory() {
        if let data = UserDefaults.standard.data(forKey: chatHistoryKey),
           let decoded = try? JSONDecoder().decode([Message].self, from: data) {
            messages = decoded
        }
    }
}
