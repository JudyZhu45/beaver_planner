//
//  WeeklyReviewView.swift
//  AI_planner
//
//  Created by AI Assistant on 3/4/26.
//

import SwiftUI

struct WeeklyReviewView: View {
    let tasks: [TodoTask]
    @Environment(\.dismiss) private var dismiss
    
    private let calendar = Calendar.current
    
    // MARK: - Computed Data
    
    private var thisWeekStart: Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -6, to: today) ?? today
    }
    
    private var lastWeekStart: Date {
        calendar.date(byAdding: .day, value: -13, to: calendar.startOfDay(for: Date())) ?? Date()
    }
    
    private var thisWeekTasks: [TodoTask] {
        tasks.filter { ($0.completedAt ?? $0.dueDate) >= thisWeekStart }
    }
    
    private var lastWeekTasks: [TodoTask] {
        tasks.filter {
            let date = $0.completedAt ?? $0.dueDate
            return date >= lastWeekStart && date < thisWeekStart
        }
    }
    
    private var thisWeekCompleted: Int {
        thisWeekTasks.filter(\.isCompleted).count
    }
    
    private var lastWeekCompleted: Int {
        lastWeekTasks.filter(\.isCompleted).count
    }
    
    private var changePercent: Int {
        guard lastWeekCompleted > 0 else { return thisWeekCompleted > 0 ? 100 : 0 }
        return Int(Double(thisWeekCompleted - lastWeekCompleted) / Double(lastWeekCompleted) * 100)
    }
    
    private var completionRate: Double {
        guard !thisWeekTasks.isEmpty else { return 0 }
        return Double(thisWeekCompleted) / Double(thisWeekTasks.count)
    }
    
    // Daily completion for bar chart (last 7 days)
    private var dailyCompletions: [(day: String, count: Int)] {
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let completed = tasks.filter {
                $0.isCompleted && calendar.isDate($0.completedAt ?? $0.dueDate, inSameDayAs: day)
            }.count
            return (formatter.string(from: day), completed)
        }
    }
    
    // Event type distribution
    private var typeDistribution: [(type: TodoTask.EventType, count: Int, color: Color)] {
        let allTypes: [TodoTask.EventType] = [.gym, .class_, .study, .meeting, .dinner, .other]
        return allTypes.compactMap { type in
            let count = thisWeekTasks.filter { $0.isCompleted && $0.eventType == type }.count
            guard count > 0 else { return nil }
            let eventColor = AppTheme.eventColors.first {
                $0.name.lowercased() == type.rawValue.lowercased()
            } ?? AppTheme.eventColors[5]
            return (type, count, eventColor.primary)
        }.sorted { $0.count > $1.count }
    }
    
    var body: some View {
        ZStack {
            AppTheme.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    
                    Spacer()
                    
                    Text("Weekly Review")
                        .font(AppTheme.Typography.headlineSmall)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Spacer()
                    
                    // Spacer for symmetry
                    Color.clear.frame(width: 24, height: 24)
                }
                .padding(AppTheme.Spacing.lg)
                .background(AppTheme.bgSecondary)
                .shadow(color: AppTheme.shadowColor, radius: 4, x: 0, y: 2)
                
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        // Summary Card
                        summaryCard
                        
                        // Daily Bar Chart
                        dailyBarChart
                        
                        // Type Distribution
                        if !typeDistribution.isEmpty {
                            typeDistributionSection
                        }
                        
                        // Productivity insights
                        productivityInsights
                        
                        // Beaver commentary
                        beaverSummary
                        
                        Spacer(minLength: AppTheme.Spacing.xxl)
                    }
                    .padding(.top, AppTheme.Spacing.lg)
                }
            }
        }
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            VStack(spacing: AppTheme.Spacing.xs) {
                Text("\(thisWeekCompleted)")
                    .font(AppTheme.Typography.displayLarge)
                    .foregroundColor(AppTheme.primaryDeepIndigo)
                Text("Completed")
                    .font(AppTheme.Typography.labelSmall)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider().frame(height: 40)
            
            VStack(spacing: AppTheme.Spacing.xs) {
                HStack(spacing: 4) {
                    Image(systemName: changePercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 14, weight: .bold))
                    Text("\(abs(changePercent))%")
                        .font(AppTheme.Typography.headlineMedium)
                }
                .foregroundColor(changePercent >= 0 ? AppTheme.secondaryTeal : AppTheme.accentCoral)
                
                Text("vs last week")
                    .font(AppTheme.Typography.labelSmall)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider().frame(height: 40)
            
            VStack(spacing: AppTheme.Spacing.xs) {
                Text("\(Int(completionRate * 100))%")
                    .font(AppTheme.Typography.headlineMedium)
                    .foregroundColor(AppTheme.secondaryTeal)
                Text("Rate")
                    .font(AppTheme.Typography.labelSmall)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(AppTheme.Spacing.xl)
        .background(AppTheme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                .stroke(AppTheme.borderColor, lineWidth: 1)
        )
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
    
    // MARK: - Daily Bar Chart
    
    private var dailyBarChart: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Daily Completions", icon: "chart.bar.fill")
                .padding(.horizontal, AppTheme.Spacing.lg)
            
            HStack(alignment: .bottom, spacing: AppTheme.Spacing.sm) {
                let maxCount = max(dailyCompletions.map(\.count).max() ?? 1, 1)
                
                ForEach(Array(dailyCompletions.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: AppTheme.Spacing.xs) {
                        Text("\(item.count)")
                            .font(AppTheme.Typography.labelSmall)
                            .foregroundColor(AppTheme.textTertiary)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.secondaryTeal, AppTheme.secondaryTeal.opacity(0.6)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: max(4, CGFloat(item.count) / CGFloat(maxCount) * 80))
                        
                        Text(item.day)
                            .font(AppTheme.Typography.labelSmall)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(AppTheme.Spacing.lg)
            .background(AppTheme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                    .stroke(AppTheme.borderColor, lineWidth: 1)
            )
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
    }
    
    // MARK: - Type Distribution
    
    private var typeDistributionSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Task Categories", icon: "chart.pie.fill")
                .padding(.horizontal, AppTheme.Spacing.lg)
            
            VStack(spacing: AppTheme.Spacing.sm) {
                let total = typeDistribution.map(\.count).reduce(0, +)
                
                ForEach(typeDistribution, id: \.type) { item in
                    HStack(spacing: AppTheme.Spacing.md) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 10, height: 10)
                        
                        Text(item.type.rawValue)
                            .font(AppTheme.Typography.bodyMedium)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Spacer()
                        
                        Text("\(item.count)")
                            .font(AppTheme.Typography.titleMedium)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(item.color.opacity(0.3))
                                .frame(width: total > 0 ? geo.size.width * Double(item.count) / Double(total) : 0)
                        }
                        .frame(width: 60, height: 6)
                    }
                }
            }
            .padding(AppTheme.Spacing.lg)
            .background(AppTheme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                    .stroke(AppTheme.borderColor, lineWidth: 1)
            )
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
    }
    
    // MARK: - Productivity Insights
    
    private var productivityInsights: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Insights", icon: "lightbulb.fill")
                .padding(.horizontal, AppTheme.Spacing.lg)
            
            VStack(spacing: AppTheme.Spacing.sm) {
                let topHours = BehaviorAnalyzer.shared.topProductiveHours(days: 7)
                if !topHours.isEmpty {
                    insightRow(
                        icon: "clock.badge.checkmark.fill",
                        text: "Most productive hours: \(topHours.map { "\($0):00" }.joined(separator: ", "))",
                        color: AppTheme.secondaryTeal
                    )
                }
                
                let slots = BehaviorAnalyzer.shared.productivitySlots(days: 7)
                if let best = slots.max(by: { $0.score < $1.score }), best.score > 0 {
                    insightRow(
                        icon: "sparkles",
                        text: "Peak productivity: \(best.label) (\(best.startHour):00-\(best.endHour):00)",
                        color: AppTheme.primaryDeepIndigo
                    )
                }
            }
            .padding(AppTheme.Spacing.lg)
            .background(AppTheme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                    .stroke(AppTheme.borderColor, lineWidth: 1)
            )
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
    }
    
    private func insightRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(text)
                .font(AppTheme.Typography.bodySmall)
                .foregroundColor(AppTheme.textPrimary)
            
            Spacer()
        }
    }
    
    // MARK: - Beaver Summary
    
    private var beaverSummary: some View {
        let commentary = BeaverPersonality.shared.statsCommentary(
            completionRate: completionRate,
            streak: UserProfileViewModel.shared.profile.streakData.currentStreak,
            completedCount: thisWeekCompleted
        )
        
        return HStack(spacing: AppTheme.Spacing.md) {
            Image("beaver-main")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            
            Text(commentary)
                .font(AppTheme.Typography.bodyMedium)
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.primaryDeepIndigo.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                .stroke(AppTheme.primaryDeepIndigo.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
}

#Preview {
    WeeklyReviewView(tasks: TodoViewModel.preview.todos)
}
