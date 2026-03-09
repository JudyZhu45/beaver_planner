import SwiftUI

struct QuickPrompt: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let prompt: String
}

private let quickPrompts: [QuickPrompt] = [
    QuickPrompt(icon: "sun.max", label: "Plan Today", prompt: "Help me plan my schedule for today."),
    QuickPrompt(icon: "calendar.badge.plus", label: "Plan Tomorrow", prompt: "Help me plan my schedule for tomorrow."),
    QuickPrompt(icon: "calendar", label: "Plan Week", prompt: "Help me plan the rest of this week."),
    QuickPrompt(icon: "book", label: "Study Plan", prompt: "Help me create a study plan."),
    QuickPrompt(icon: "figure.run", label: "Workout Plan", prompt: "Help me create a workout plan."),
    QuickPrompt(icon: "list.bullet", label: "Review Tasks", prompt: "Summarize all my current tasks.")
]

struct AIChatView: View {
    @ObservedObject var viewModel: TodoViewModel
    @ObservedObject var chatViewModel: ChatViewModel
    @StateObject private var speechService = SpeechRecognitionService()
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    @State private var micPulse = false
    
    // Environment for tracking app open/close
    @Environment(\.scenePhase) var scenePhase

    // Beta feedback
    @State private var reportingMessage: Message? = nil
    @State private var showFeedbackSheet = false
    
    var body: some View {
        ZStack {
            // Background Layer
            LinearGradient(
                colors: [
                    AppTheme.bgSecondary,
                    AppTheme.bgPrimary,
                    AppTheme.bgTertiary.opacity(0.30)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                RadialGradient(
                    colors: [
                        AppTheme.accentGold.opacity(0.10),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 240
                )
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Messages
                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: AppTheme.Spacing.sm) {
                            ForEach(chatViewModel.messages) { message in
                                MessageBubble(
                                    message: message,
                                    onCopy: {
                                        chatViewModel.copyMessageContent(message)
                                    },
                                    onDelete: {
                                        withAnimation {
                                            chatViewModel.deleteMessage(message)
                                        }
                                    },
                                    onReport: message.sender == .ai && !message.isStreaming && !message.isError ? {
                                        reportingMessage = message
                                        showFeedbackSheet = true
                                    } : nil
                                )
                                .id(message.id)
                            }
                            
                            // Action results cards
                            if !chatViewModel.lastActionResults.isEmpty {
                                actionResultsView
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                            
                            // Confirm button — when AI proposes a plan
                            if chatViewModel.showConfirmButton {
                                confirmButtonView
                                    .transition(.opacity.combined(with: .scale))
                            }
                            
                            // Invisible anchor at the very bottom
                            Color.clear
                                .frame(height: 1)
                                .id("bottomAnchor")
                        }
                        .padding(.top, AppTheme.Spacing.md)
                        .padding(.bottom, AppTheme.Spacing.lg)
                    }
                    .onAppear {
                        scrollProxy.scrollTo("bottomAnchor", anchor: .bottom)
                    }
                    .onChange(of: chatViewModel.messages.count) {
                        scrollToBottom(scrollProxy)
                    }
                    .onChange(of: chatViewModel.messages.last?.content) {
                        scrollToBottom(scrollProxy)
                    }
                }
                
                // Unified Bottom Area (Prompts + Input)
                bottomContainerView
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Auto-clear conversation when reopening the app
            if newPhase == .active && oldPhase == .background {
                chatViewModel.clearHistory()
            }
        }
        .onChange(of: speechService.recognizedText) { _, newValue in
            if speechService.isRecording && !newValue.isEmpty {
                inputText = newValue
            }
        }
        .alert("Speech Recognition", isPresented: Binding(
            get: { speechService.errorMessage != nil },
            set: { if !$0 { speechService.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                speechService.errorMessage = nil
            }
        } message: {
            Text(speechService.errorMessage ?? "")
        }
        .sheet(isPresented: $showFeedbackSheet) {
            if let msg = reportingMessage {
                let aiIndex = chatViewModel.messages.firstIndex(where: { $0.id == msg.id }) ?? 0
                let userMsg = aiIndex > 0 ? chatViewModel.messages[aiIndex - 1].content : ""
                FeedbackReportSheet(
                    userMessage: userMsg,
                    aiResponse: msg.content,
                    onDismiss: { showFeedbackSheet = false }
                )
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // AI Avatar
            ZStack {
                Circle()
                    .fill(AppTheme.accentGold.opacity(0.12))
                    .frame(width: 48, height: 48)

                Circle()
                    .stroke(AppTheme.borderColor.opacity(0.8), lineWidth: 1)
                    .frame(width: 48, height: 48)

                Image("beaver-main")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Planner Beaver")
                    .font(AppTheme.Typography.headlineSmall)
                    .foregroundColor(AppTheme.primaryDeepIndigo)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(chatViewModel.isTyping ? AppTheme.accentGold : AppTheme.secondaryTeal)
                        .frame(width: 6, height: 6)
                    
                    Text(chatViewModel.isTyping ? "Thinking with you..." : "Warm, ready, online")
                        .font(AppTheme.Typography.labelSmall)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            
            Spacer()
            
            // Explicit Actions
            HStack(spacing: 8) {
                // New Chat Button
                Button {
                    withAnimation {
                        chatViewModel.clearHistory()
                    }
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.primaryDeepIndigo)
                        .frame(width: 38, height: 38)
                        .background(AppTheme.primaryDeepIndigo.opacity(0.08))
                        .clipShape(Circle())
                }
                
                // Clear Chat Button
                Button {
                    withAnimation {
                        chatViewModel.clearHistory()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.primaryDeepIndigo) // Changed to match New Chat
                        .frame(width: 38, height: 38)
                        .background(AppTheme.primaryDeepIndigo.opacity(0.08)) // Changed to match New Chat
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppTheme.bgElevated.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(AppTheme.borderColor.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: AppTheme.Shadows.md.color, radius: AppTheme.Shadows.md.radius, x: AppTheme.Shadows.md.x, y: AppTheme.Shadows.md.y)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.md)
    }
    
    // MARK: - Bottom Container (Prompts + Input)
    
    private var bottomContainerView: some View {
        VStack(spacing: 0) {
            // Quick prompts — show when only welcome message
            if showQuickPrompts {
                quickPromptsView
                    .padding(.bottom, AppTheme.Spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            // Text Input Area
            inputAreaView
        }
        .background(
            LinearGradient(
                colors: [
                    AppTheme.bgPrimary.opacity(0.94),
                    AppTheme.bgSecondary
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .shadow(color: AppTheme.shadowColor, radius: 8, x: 0, y: -4)
            .ignoresSafeArea(edges: .bottom) // Extends the background gradient behind the home bar
        )
    }
    
    // MARK: - Input Area
    
    private var inputAreaView: some View {
        HStack(alignment: .bottom, spacing: AppTheme.Spacing.sm) {
            ZStack(alignment: .topLeading) {
                // Placeholder
                if inputText.isEmpty {
                    Text(speechService.isRecording ? "Listening..." : "Ask me anything...")
                        .font(AppTheme.Typography.bodyMedium)
                        .foregroundColor(speechService.isRecording ? AppTheme.accentCoral : AppTheme.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                }
                
                TextEditor(text: $inputText)
                    .font(AppTheme.Typography.bodyMedium)
                    .foregroundColor(AppTheme.textPrimary)
                    .focused($isInputFocused)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 36, maxHeight: 120)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            
            // Microphone button
            Button {
                Task {
                    await speechService.toggleRecording()
                }
            } label: {
                Image(systemName: speechService.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 20))
                    .foregroundColor(
                        speechService.isRecording ? AppTheme.accentCoral : AppTheme.textSecondary
                    )
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(speechService.isRecording ? AppTheme.accentCoral.opacity(0.12) : AppTheme.bgTertiary.opacity(0.75))
                    )
                    .scaleEffect(micPulse ? 1.15 : 1.0)
            }
            .padding(.bottom, 2)
            .onChange(of: speechService.isRecording) { _, recording in
                withAnimation(recording
                    ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                    : .default
                ) {
                    micPulse = recording
                }
            }
            
            // Send button
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(
                        canSend
                            ? LinearGradient(
                                colors: [AppTheme.primaryDeepIndigo, AppTheme.accentGold],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [AppTheme.textTertiary, AppTheme.textTertiary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .scaleEffect(canSend ? 1.0 : 0.94)
            }
            .disabled(!canSend)
            .padding(.bottom, 2)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(AppTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    speechService.isRecording ? AppTheme.accentCoral :
                    isInputFocused ? AppTheme.secondaryTeal : AppTheme.borderColor,
                    lineWidth: speechService.isRecording ? 2.0 : 1
                )
        )
        .shadow(color: AppTheme.Shadows.sm.color, radius: AppTheme.Shadows.sm.radius, x: AppTheme.Shadows.sm.x, y: AppTheme.Shadows.sm.y)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.bottom, AppTheme.Spacing.md)
    }
    
    // MARK: - Helpers
    
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chatViewModel.isTyping
    }
    
    private func sendMessage() {
        guard canSend else { return }
        if speechService.isRecording {
            speechService.stopRecording()
        }
        let text = inputText
        inputText = ""
        withAnimation {
            chatViewModel.sendMessage(text)
        }
    }
    
    // MARK: - Action Results
    
    private var actionResultsView: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            ForEach(chatViewModel.lastActionResults) { result in
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: result.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(actionColor(for: result.actionType))
                        .frame(width: 24, height: 24)
                        .background(actionColor(for: result.actionType).opacity(0.1))
                        .clipShape(Circle())
                    
                    Text(result.label)
                        .font(AppTheme.Typography.labelMedium)
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if result.undoData != nil {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                chatViewModel.undoAction(result)
                            }
                        } label: {
                            Text("Undo")
                                .font(AppTheme.Typography.labelSmall)
                                .foregroundColor(AppTheme.accentCoral)
                                .padding(.horizontal, AppTheme.Spacing.sm)
                                .padding(.vertical, 3)
                                .background(AppTheme.accentCoral.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(AppTheme.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                        .stroke(actionColor(for: result.actionType).opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
    
    private func actionColor(for type: ActionResult.ActionResultType) -> Color {
        switch type {
        case .created: return AppTheme.secondaryTeal
        case .updated: return AppTheme.accentGold
        case .deleted: return AppTheme.accentCoral
        case .completed: return AppTheme.secondaryTeal
        case .warning: return AppTheme.accentGold
        }
    }
    
    // MARK: - Confirm Button
    
    private var confirmButtonView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            let cards = chatViewModel.pendingTaskCards
            if !cards.isEmpty {
                VStack(spacing: AppTheme.Spacing.sm) {
                    // Section label
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.accentGold)
                        Text("Pending — not saved yet")
                            .font(AppTheme.Typography.labelSmall)
                            .foregroundColor(AppTheme.textTertiary)
                        Spacer()
                        Text("\(cards.count) task\(cards.count == 1 ? "" : "s")")
                            .font(AppTheme.Typography.labelSmall)
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)

                    // Task cards
                    ForEach(cards) { card in
                        PendingTaskCardView(card: card)
                            .padding(.horizontal, AppTheme.Spacing.lg)
                    }
                }
            }

            // Cancel / Confirm buttons
            HStack(spacing: AppTheme.Spacing.md) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        chatViewModel.cancelProposal()
                    }
                } label: {
                    Text("Cancel")
                        .font(AppTheme.Typography.labelMedium)
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.horizontal, AppTheme.Spacing.xl)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(AppTheme.bgElevated)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.borderColor.opacity(0.8), lineWidth: 1))
                }

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        chatViewModel.confirmProposal()
                    }
                } label: {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                        Text("Confirm")
                            .font(AppTheme.Typography.labelMedium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, AppTheme.Spacing.xl)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.primaryDeepIndigo, AppTheme.accentGold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: AppTheme.primaryDeepIndigo.opacity(0.22), radius: 8, x: 0, y: 4)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
    }
    
    // MARK: - Quick Prompts
    
    private var showQuickPrompts: Bool {
        chatViewModel.messages.count <= 1 && !chatViewModel.isTyping
    }
    
    private var quickPromptsView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Quick Start")
                    .font(AppTheme.Typography.labelLarge)
                    .foregroundColor(AppTheme.accentGold)

                Text("Let Beaver organize your day, or quickly generate a new plan.")
                    .font(AppTheme.Typography.bodySmall)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(.horizontal, AppTheme.Spacing.xs)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                ForEach(quickPrompts) { prompt in
                    Button {
                        inputText = prompt.prompt
                        sendMessage()
                    } label: {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            Image(systemName: prompt.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.primaryDeepIndigo)
                                .frame(width: 24, height: 24)
                                .background(AppTheme.accentGold.opacity(0.12))
                                .clipShape(Circle())
                            
                            Text(prompt.label)
                                .font(AppTheme.Typography.labelMedium)
                                .foregroundColor(AppTheme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            Spacer()
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(AppTheme.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                                .stroke(AppTheme.borderColor.opacity(0.85), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.sm)
    }
    
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo("bottomAnchor", anchor: .bottom)
        }
    }
}

#Preview {
    AIChatView(viewModel: .preview, chatViewModel: ChatViewModel())
}
