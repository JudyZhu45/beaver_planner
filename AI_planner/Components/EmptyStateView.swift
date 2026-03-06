//
//  EmptyStateView.swift
//  AI_planner
//
//  Created by Judy459 on 2/24/26.
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var assetImage: String? = nil
    var buttonTitle: String? = nil
    var onAction: (() -> Void)? = nil
    var compact: Bool = false
    var smartSuggestions: [SmartSuggestion]? = nil
    
    var body: some View {
        VStack(spacing: compact ? AppTheme.Spacing.md : AppTheme.Spacing.lg) {
            if let assetImage {
                Image(assetImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: compact ? 60 : 80, height: compact ? 60 : 80)
            } else {
                Image(systemName: icon)
                    .font(.system(size: compact ? 36 : 48, weight: .light))
                    .foregroundColor(AppTheme.secondaryTeal.opacity(0.4))
            }
            
            VStack(spacing: AppTheme.Spacing.sm) {
                Text(title)
                    .font(compact ? AppTheme.Typography.bodyMedium : AppTheme.Typography.headlineSmall)
                    .foregroundColor(AppTheme.textPrimary)
                
                Text(subtitle)
                    .font(AppTheme.Typography.bodySmall)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Smart suggestions based on user behavior
            if let smartSuggestions, !smartSuggestions.isEmpty {
                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(smartSuggestions) { suggestion in
                        HStack(spacing: AppTheme.Spacing.sm) {
                            Image(systemName: suggestion.icon)
                                .font(.system(size: 12))
                                .foregroundColor(suggestion.color)
                                .frame(width: 20)
                            
                            Text(suggestion.text)
                                .font(AppTheme.Typography.bodySmall)
                                .foregroundColor(AppTheme.textSecondary)
                            
                            Spacer()
                        }
                    }
                }
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.primaryDeepIndigo.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                .padding(.horizontal, AppTheme.Spacing.lg)
            }
            
            if let buttonTitle, let onAction {
                Button(action: onAction) {
                    Text(buttonTitle)
                        .font(AppTheme.Typography.titleMedium)
                        .foregroundColor(AppTheme.textInverse)
                        .padding(.horizontal, AppTheme.Spacing.xxl)
                        .padding(.vertical, AppTheme.Spacing.md)
                        .background(AppTheme.secondaryTeal)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                }
                .padding(.top, AppTheme.Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? AppTheme.Spacing.lg : AppTheme.Spacing.huge)
    }
}

// MARK: - Smart Suggestion Model

struct SmartSuggestion: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let color: Color
}

// MARK: - Smart Suggestion Generator

struct SmartSuggestionGenerator {
    
    /// Generate context-aware suggestions for empty states
    static func generateSuggestions(tasks: [TodoTask]) -> [SmartSuggestion] {
        var suggestions: [SmartSuggestion] = []
        let hour = Calendar.current.component(.hour, from: Date())
        let analyzer = BehaviorAnalyzer.shared
        
        // Time-based suggestion
        let timeSuggestion = timeBasedSuggestion(hour: hour)
        suggestions.append(timeSuggestion)
        
        // Behavior-based suggestion
        let topHours = analyzer.topProductiveHours(days: 14)
        if !topHours.isEmpty && topHours.contains(hour) {
            suggestions.append(SmartSuggestion(
                icon: "sparkles",
                text: "This is usually your most productive hour!",
                color: AppTheme.secondaryTeal
            ))
        }
        
        // Streak-based suggestion
        let profile = UserProfileViewModel.shared.profile
        if profile.streakData.currentStreak > 0 {
            suggestions.append(SmartSuggestion(
                icon: "flame.fill",
                text: "\(profile.streakData.currentStreak)-day streak! Add a task to keep it going.",
                color: AppTheme.accentCoral
            ))
        }
        
        // Type preference suggestion
        let typeStats = analyzer.eventTypeAnalysis(days: 14)
        if let topType = typeStats.max(by: { $0.totalCount < $1.totalCount }), topType.totalCount >= 3 {
            suggestions.append(SmartSuggestion(
                icon: "arrow.right.circle.fill",
                text: "You often schedule \(topType.eventType.rawValue) tasks. Add one?",
                color: AppTheme.primaryDeepIndigo
            ))
        }
        
        return Array(suggestions.prefix(3))
    }
    
    private static func timeBasedSuggestion(hour: Int) -> SmartSuggestion {
        switch hour {
        case 5..<9:
            return SmartSuggestion(
                icon: "sunrise.fill",
                text: "Morning is great for planning your day ahead.",
                color: Color.orange
            )
        case 9..<12:
            return SmartSuggestion(
                icon: "cup.and.saucer.fill",
                text: "Prime focus time — schedule your deep work now.",
                color: AppTheme.secondaryTeal
            )
        case 12..<14:
            return SmartSuggestion(
                icon: "fork.knife",
                text: "Lunch break — plan your afternoon tasks.",
                color: AppTheme.primaryDeepIndigo
            )
        case 14..<18:
            return SmartSuggestion(
                icon: "bolt.fill",
                text: "Afternoon push — tackle your remaining priorities.",
                color: Color.orange
            )
        case 18..<22:
            return SmartSuggestion(
                icon: "moon.stars.fill",
                text: "Evening — review today and plan for tomorrow.",
                color: AppTheme.primaryDeepIndigo
            )
        default:
            return SmartSuggestion(
                icon: "bed.double.fill",
                text: "It's late — rest well and plan tomorrow morning.",
                color: AppTheme.textTertiary
            )
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        EmptyStateView(
            icon: "sparkles",
            title: "No tasks for today",
            subtitle: "Tap the + button to add an event or task",
            buttonTitle: "Add Event",
            onAction: {},
            smartSuggestions: [
                SmartSuggestion(icon: "sunrise.fill", text: "Morning is great for planning.", color: .orange),
                SmartSuggestion(icon: "flame.fill", text: "3-day streak! Add a task to keep going.", color: .red)
            ]
        )
        
        Divider()
        
        EmptyStateView(
            icon: "calendar.badge.plus",
            title: "No events scheduled",
            subtitle: "Plan your day by adding events",
            compact: true
        )
    }
    .padding()
}
