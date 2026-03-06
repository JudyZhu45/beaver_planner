//
//  EmptyStateView.swift
//  AI_planner
//
//  Created by AI Assistant on 3/5/26.
//

import SwiftUI

enum EmptyStateType {
    case tasks
    case calendar
    case analytics
    case notifications
    
    var config: EmptyStateConfig {
        switch self {
        case .tasks:
            return EmptyStateConfig(
                icon: "🦫",
                title: "今天还没有任务呢",
                description: "海狸已经准备好了，添加第一个任务开始吧！",
                actionText: "添加任务",
                tip: "💡 小贴士：把大任务拆成小步骤，更容易完成哦"
            )
        case .calendar:
            return EmptyStateConfig(
                icon: "📅",
                title: "日历空空如也",
                description: "规划你的时间，让每一天都充实起来",
                actionText: "创建日程",
                tip: "💡 小贴士：在高效时段安排重要任务"
            )
        case .analytics:
            return EmptyStateConfig(
                icon: "📊",
                title: "数据还在积累中",
                description: "使用一段时间后，这里会显示你的效率分析",
                actionText: "去添加任务",
                tip: "💡 小贴士：坚持记录，AI 会更懂你"
            )
        case .notifications:
            return EmptyStateConfig(
                icon: "🔔",
                title: "没有新通知",
                description: "海狸帮你盯着呢，有重要消息会第一时间告诉你",
                actionText: "查看设置",
                tip: "💡 小贴士：可以在设置里调整通知偏好"
            )
        }
    }
}

struct EmptyStateConfig {
    let icon: String
    let title: String
    let description: String
    let actionText: String
    let tip: String
}

struct EmptyStateView: View {
    let type: EmptyStateType
    let action: () -> Void
    
    @State private var isAnimating = false
    @State private var floatOffset: CGFloat = 0
    
    private var config: EmptyStateConfig { type.config }
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Animated illustration
            ZStack {
                // Background glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppTheme.primaryDeepIndigo.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                
                // Main icon with bounce
                Text(config.icon)
                    .font(.system(size: 64))
                    .offset(y: floatOffset)
                
                // Floating sparkles
                HStack(spacing: 50) {
                    Text("✨")
                        .font(.title3)
                        .opacity(isAnimating ? 1 : 0.5)
                        .offset(y: isAnimating ? -5 : 0)
                    
                    Spacer().frame(width: 60)
                    
                    Text("💭")
                        .font(.callout)
                        .opacity(isAnimating ? 0.8 : 0.4)
                        .offset(y: isAnimating ? -3 : 3)
                }
            }
            .frame(height: 100)
            
            // Title
            Text(config.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
            
            // Description
            Text(config.description)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            // Action button
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text(config.actionText)
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.831, green: 0.647, blue: 0.455),
                            Color(red: 0.769, green: 0.584, blue: 0.416)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(
                    color: AppTheme.primaryDeepIndigo.opacity(0.25),
                    radius: 8,
                    x: 0,
                    y: 4
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, 8)
            
            // Tip box
            HStack(spacing: 8) {
                Text(config.tip)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.bgElevated)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.borderColor, lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            Spacer()
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Float animation
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            floatOffset = -8
        }
        
        // Sparkle animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            isAnimating = true
        }
    }
}

// Custom button style for scale effect
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 20) {
        EmptyStateView(type: .tasks, action: {})
    }
    .background(AppTheme.bgPrimary)
}
