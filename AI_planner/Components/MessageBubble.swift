//
//  MessageBubble.swift
//  AI_planner
//
//  Created by Judy459 on 2/19/26.
//

import SwiftUI

enum MessageSender: String, Codable {
    case user
    case ai
}

struct Message: Identifiable, Codable {
    let id: UUID
    var content: String
    let sender: MessageSender
    let timestamp: Date
    var isStreaming: Bool
    var isError: Bool
    
    init(
        content: String,
        sender: MessageSender,
        timestamp: Date,
        isStreaming: Bool = false,
        isError: Bool = false
    ) {
        self.id = UUID()
        self.content = content
        self.sender = sender
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.isError = isError
    }
}

struct MessageBubble: View {
    let message: Message
    var onCopy: (() -> Void)?
    var onDelete: (() -> Void)?
    var onReport: (() -> Void)?

    var isUserMessage: Bool {
        message.sender == .user
    }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: message.timestamp)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: AppTheme.Spacing.sm) {
            if !isUserMessage {
                // AI avatar
                aiAvatar
            }

            if isUserMessage {
                Spacer(minLength: 60)
            }

            VStack(alignment: isUserMessage ? .trailing : .leading, spacing: AppTheme.Spacing.xs) {
                if message.content.isEmpty && message.isStreaming {
                    // Streaming placeholder — animated dots
                    TypingIndicatorInline()
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.vertical, AppTheme.Spacing.md)
                        .background(AppTheme.bgElevated)
                        .clipShape(chatBubbleShape(isUser: false))
                        .overlay(
                            chatBubbleShape(isUser: false)
                                .stroke(AppTheme.borderColor.opacity(0.8), lineWidth: 1)
                        )
                        .shadow(color: AppTheme.Shadows.xs.color, radius: AppTheme.Shadows.xs.radius, x: AppTheme.Shadows.xs.x, y: AppTheme.Shadows.xs.y)
                } else {
                    bubbleContent
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.vertical, AppTheme.Spacing.md)
                        .background(
                            isUserMessage
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [AppTheme.primaryDeepIndigo, AppTheme.accentGold],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                : AnyShapeStyle(
                                    message.isError ? AppTheme.accentCoral.opacity(0.10) : AppTheme.bgElevated
                                )
                        )
                        .clipShape(chatBubbleShape(isUser: isUserMessage))
                        .overlay(
                            chatBubbleShape(isUser: isUserMessage)
                                .stroke(
                                    isUserMessage ? Color.white.opacity(0.12) : AppTheme.borderColor.opacity(0.85),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: AppTheme.Shadows.xs.color, radius: AppTheme.Shadows.xs.radius, x: AppTheme.Shadows.xs.x, y: AppTheme.Shadows.xs.y)
                        .contextMenu {
                            Button {
                                onCopy?()
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }

                            if !isUserMessage && !message.isStreaming && !message.isError {
                                Button {
                                    onReport?()
                                } label: {
                                    Label("Report response", systemImage: "flag")
                                }
                            }

                            Button(role: .destructive) {
                                onDelete?()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }

                // Bottom row: timestamp + report button (AI only)
                HStack(spacing: AppTheme.Spacing.sm) {
                    if isUserMessage { Spacer() }

                    Text(timeString)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundColor(AppTheme.textTertiary)

                    // 👎 Report button — only for completed AI messages
                    if !isUserMessage && !message.isStreaming && !message.isError && onReport != nil {
                        Button {
                            onReport?()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "flag")
                                    .font(.system(size: 9, weight: .medium))
                                Text("Report")
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(AppTheme.textTertiary.opacity(0.7))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppTheme.bgSecondary.opacity(0.6))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    if !isUserMessage { Spacer() }
                }
                .padding(.horizontal, isUserMessage ? AppTheme.Spacing.xs : 36)
            }

            if !isUserMessage {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }
    
    // MARK: - Bubble Content
    
    @ViewBuilder
    private var bubbleContent: some View {
        if isUserMessage {
            // User messages: plain text
            Text(message.content)
                .font(AppTheme.Typography.bodyMedium)
                .foregroundColor(AppTheme.textInverse)
        } else if message.isError {
            HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                Image("beaver-error")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                
                Text(message.content)
                    .font(AppTheme.Typography.bodyMedium)
                    .foregroundColor(AppTheme.accentCoral)
            }
        } else {
            // AI messages: render Markdown
            MarkdownTextView(text: message.content)
        }
    }
    
    // MARK: - AI Avatar
    
    private var aiAvatar: some View {
        ZStack {
            Circle()
                .fill(AppTheme.accentGold.opacity(0.12))
                .frame(width: 34, height: 34)

            Image("beaver-main")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .clipShape(Circle())
        }
    }
    
    // MARK: - Chat Bubble Shape
    
    private func chatBubbleShape(isUser: Bool) -> some Shape {
        ChatBubbleShape(isUser: isUser)
    }
}

// MARK: - Chat Bubble Shape (asymmetric corners)

struct ChatBubbleShape: Shape {
    let isUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let smallRadius: CGFloat = 4
        
        let topLeft = isUser ? radius : smallRadius
        let topRight = isUser ? smallRadius : radius
        let bottomLeft = radius
        let bottomRight = radius
        
        return Path { path in
            path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
                radius: topRight,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
            path.addArc(
                center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
                radius: bottomRight,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
            path.addArc(
                center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
                radius: bottomLeft,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
            path.addArc(
                center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
                radius: topLeft,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        }
    }
}

// MARK: - Inline Typing Indicator (for streaming placeholder)

struct TypingIndicatorInline: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 6) {
            Image("beaver-loading")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .rotationEffect(.degrees(animating ? -5 : 5))
                .animation(
                    .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true),
                    value: animating
                )
            
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(AppTheme.primaryDeepIndigo.opacity(0.35))
                        .frame(width: 5, height: 5)
                        .offset(y: animating ? -3 : 0)
                        .animation(
                            .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                            value: animating
                        )
                }
            }
        }
        .onAppear { animating = true }
    }
}

// MARK: - Markdown Text View

struct MarkdownTextView: View {
    let text: String
    
    var body: some View {
        let blocks = parseMarkdownBlocks(text)
        VStack(alignment: .leading, spacing: 6) {
            ForEach(blocks.indices, id: \.self) { index in
                renderBlock(blocks[index])
            }
        }
    }
    
    // MARK: - Block Types
    
    private enum MarkdownBlock {
        case heading(level: Int, text: String)
        case listItem(text: String)
        case numberedItem(number: String, text: String)
        case codeBlock(code: String)
        case blockquote(text: String)
        case paragraph(text: String)
    }
    
    // MARK: - Block Parser
    
    private func parseMarkdownBlocks(_ input: String) -> [MarkdownBlock] {
        let lines = input.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var inCodeBlock = false
        var codeLines: [String] = []
        var paragraphLines: [String] = []
        
        func flushParagraph() {
            let joined = paragraphLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty {
                blocks.append(.paragraph(text: joined))
            }
            paragraphLines = []
        }
        
        for line in lines {
            // Code block fence
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if inCodeBlock {
                    blocks.append(.codeBlock(code: codeLines.joined(separator: "\n")))
                    codeLines = []
                    inCodeBlock = false
                } else {
                    flushParagraph()
                    inCodeBlock = true
                }
                continue
            }
            
            if inCodeBlock {
                codeLines.append(line)
                continue
            }
            
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Empty line
            if trimmed.isEmpty {
                flushParagraph()
                continue
            }
            
            // Headings
            if let match = trimmed.wholeMatch(of: /^(#{1,3})\s+(.+)$/) {
                flushParagraph()
                blocks.append(.heading(level: match.1.count, text: String(match.2)))
                continue
            }
            
            // Bullet list
            if let match = trimmed.wholeMatch(of: /^[-*+]\s+(.+)$/) {
                flushParagraph()
                blocks.append(.listItem(text: String(match.1)))
                continue
            }
            
            // Numbered list
            if let match = trimmed.wholeMatch(of: /^(\d+)[.)]\s+(.+)$/) {
                flushParagraph()
                blocks.append(.numberedItem(number: String(match.1), text: String(match.2)))
                continue
            }
            
            // Blockquote
            if let match = trimmed.wholeMatch(of: /^>\s*(.+)$/) {
                flushParagraph()
                blocks.append(.blockquote(text: String(match.1)))
                continue
            }
            
            paragraphLines.append(line)
        }
        
        // Flush remaining
        if inCodeBlock && !codeLines.isEmpty {
            blocks.append(.codeBlock(code: codeLines.joined(separator: "\n")))
        }
        flushParagraph()
        
        return blocks
    }
    
    // MARK: - Block Renderer
    
    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            inlineMarkdown(text)
                .font(level == 1 ? AppTheme.Typography.headlineSmall :
                       level == 2 ? AppTheme.Typography.titleLarge :
                       AppTheme.Typography.titleMedium)
                .foregroundColor(AppTheme.textPrimary)
            
        case .listItem(let text):
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                    .font(AppTheme.Typography.bodyMedium)
                    .foregroundColor(AppTheme.secondaryTeal)
                inlineMarkdown(text)
                    .font(AppTheme.Typography.bodyMedium)
                    .foregroundColor(AppTheme.textPrimary)
            }
            
        case .numberedItem(let number, let text):
            HStack(alignment: .top, spacing: 6) {
                Text("\(number).")
                    .font(AppTheme.Typography.bodyMedium)
                    .foregroundColor(AppTheme.secondaryTeal)
                    .frame(minWidth: 18, alignment: .trailing)
                inlineMarkdown(text)
                    .font(AppTheme.Typography.bodyMedium)
                    .foregroundColor(AppTheme.textPrimary)
            }
            
        case .blockquote(let text):
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(AppTheme.secondaryTeal.opacity(0.5))
                    .frame(width: 3)
                inlineMarkdown(text)
                    .font(AppTheme.Typography.bodyMedium)
                    .foregroundColor(AppTheme.textSecondary)
                    .italic()
            }
            .padding(.vertical, 2)
            
        case .codeBlock(let code):
            Text(code)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(AppTheme.textPrimary)
                .padding(AppTheme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
            
        case .paragraph(let text):
            inlineMarkdown(text)
                .font(AppTheme.Typography.bodyMedium)
                .foregroundColor(AppTheme.textPrimary)
        }
    }
    
    // MARK: - Inline Markdown (bold, italic, code, links)
    
    private func inlineMarkdown(_ text: String) -> Text {
        // Use SwiftUI's built-in Markdown support via AttributedString
        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(attributed)
        }
        return Text(text)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: AppTheme.Spacing.lg) {
            MessageBubble(message: Message(
                content: "Help me plan tomorrow's study schedule",
                sender: .user,
                timestamp: Date()
            ))
            
            MessageBubble(message: Message(
                content: """
                ### Tomorrow's Study Plan

                Based on your goals, here's my suggestion:

                **Morning (Peak Focus)**
                1. Math Review — 9:00~10:30
                2. English Reading — 10:45~12:00

                **Afternoon**
                - Complete *Physics* homework
                - Organize notes and review mistakes

                > Remember to take a 5–10 minute break every 45 minutes!

                ```
                Total study time: ~5 hours
                Break time: ~1 hour
                ```

                Would you like me to create these tasks for you?
                """,
                sender: .ai,
                timestamp: Date()
            ))
            
            MessageBubble(message: Message(
                content: "Yes, please create them",
                sender: .user,
                timestamp: Date()
            ))
        }
        .padding(AppTheme.Spacing.lg)
    }
    .background(AppTheme.bgPrimary)
}
