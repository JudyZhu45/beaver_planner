//
//  HabitHeatmapView.swift
//  AI_planner
//
//  Created by AI Assistant on 3/4/26.
//

import SwiftUI

struct HabitHeatmapView: View {
    let tasks: [TodoTask]
    
    private let calendar = Calendar.current
    private let columns = 7 // days per row (Mon-Sun)
    private let totalWeeks = 12 // 12 weeks of history
    
    // MARK: - Computed Data
    
    /// Map of date -> completion count for fast lookup
    private var completionsByDate: [Date: Int] {
        var map: [Date: Int] = [:]
        for task in tasks where task.isCompleted {
            let day = calendar.startOfDay(for: task.completedAt ?? task.dueDate)
            map[day, default: 0] += 1
        }
        return map
    }
    
    /// All dates to display in the heatmap grid (12 weeks)
    private var dateGrid: [[Date]] {
        let today = calendar.startOfDay(for: Date())
        let totalDays = totalWeeks * 7
        
        // Find the Monday of the current week
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7 // Convert Sunday=1 to Monday-based
        let currentMonday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
        let startDate = calendar.date(byAdding: .day, value: -(totalDays - 7), to: currentMonday)!
        
        var weeks: [[Date]] = []
        var currentDate = startDate
        
        for _ in 0..<totalWeeks {
            var week: [Date] = []
            for _ in 0..<7 {
                week.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            weeks.append(week)
        }
        
        return weeks
    }
    
    /// Maximum completions in a single day (for color scaling)
    private var maxCompletions: Int {
        max(completionsByDate.values.max() ?? 1, 1)
    }
    
    /// Month labels for the top axis
    private var monthLabels: [(String, Int)] {
        var labels: [(String, Int)] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        
        var lastMonth = -1
        for (weekIndex, week) in dateGrid.enumerated() {
            guard let firstDay = week.first else { continue }
            let month = calendar.component(.month, from: firstDay)
            if month != lastMonth {
                labels.append((formatter.string(from: firstDay), weekIndex))
                lastMonth = month
            }
        }
        return labels
    }
    
    /// Stats summary
    private var totalCompletedLast12Weeks: Int {
        completionsByDate.values.reduce(0, +)
    }
    
    private var activeDays: Int {
        completionsByDate.count
    }
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Activity", icon: "square.grid.3x3.fill")
                .padding(.horizontal, AppTheme.Spacing.lg)
            
            VStack(spacing: AppTheme.Spacing.sm) {
                // Month labels
                HStack(spacing: 0) {
                    // Day label spacer
                    Color.clear.frame(width: 20)
                    
                    GeometryReader { geo in
                        let cellWidth = geo.size.width / CGFloat(totalWeeks)
                        ForEach(monthLabels, id: \.1) { label, weekIndex in
                            Text(label)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(AppTheme.textTertiary)
                                .position(
                                    x: CGFloat(weekIndex) * cellWidth + cellWidth / 2,
                                    y: 6
                                )
                        }
                    }
                }
                .frame(height: 14)
                
                // Heatmap grid
                HStack(alignment: .top, spacing: 0) {
                    // Day labels (Mon, Wed, Fri)
                    VStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            if dayIndex == 0 || dayIndex == 2 || dayIndex == 4 {
                                Text(dayLabel(for: dayIndex))
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(AppTheme.textTertiary)
                                    .frame(height: cellSize + 2)
                            } else {
                                Color.clear.frame(height: cellSize + 2)
                            }
                        }
                    }
                    .frame(width: 20)
                    
                    // Grid cells
                    HStack(spacing: 2) {
                        ForEach(0..<totalWeeks, id: \.self) { weekIndex in
                            VStack(spacing: 2) {
                                ForEach(0..<7, id: \.self) { dayIndex in
                                    let date = dateGrid[weekIndex][dayIndex]
                                    let count = completionsByDate[date] ?? 0
                                    let isFuture = date > Date()
                                    
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(isFuture ? AppTheme.bgTertiary.opacity(0.3) : cellColor(for: count))
                                        .frame(width: cellSize, height: cellSize)
                                }
                            }
                        }
                    }
                }
                
                // Legend
                HStack(spacing: AppTheme.Spacing.sm) {
                    Text("Less")
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.textTertiary)
                    
                    ForEach(0..<5, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(legendColor(for: level))
                            .frame(width: 10, height: 10)
                    }
                    
                    Text("More")
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.textTertiary)
                    
                    Spacer()
                    
                    Text("\(totalCompletedLast12Weeks) tasks in \(activeDays) days")
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.textTertiary)
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
    
    // MARK: - Helpers
    
    private var cellSize: CGFloat { 12 }
    
    private func cellColor(for count: Int) -> Color {
        if count == 0 {
            return AppTheme.bgTertiary
        }
        let ratio = min(Double(count) / Double(maxCompletions), 1.0)
        if ratio <= 0.25 {
            return AppTheme.secondaryTeal.opacity(0.25)
        } else if ratio <= 0.5 {
            return AppTheme.secondaryTeal.opacity(0.5)
        } else if ratio <= 0.75 {
            return AppTheme.secondaryTeal.opacity(0.75)
        } else {
            return AppTheme.secondaryTeal
        }
    }
    
    private func legendColor(for level: Int) -> Color {
        switch level {
        case 0: return AppTheme.bgTertiary
        case 1: return AppTheme.secondaryTeal.opacity(0.25)
        case 2: return AppTheme.secondaryTeal.opacity(0.5)
        case 3: return AppTheme.secondaryTeal.opacity(0.75)
        case 4: return AppTheme.secondaryTeal
        default: return AppTheme.bgTertiary
        }
    }
    
    private func dayLabel(for index: Int) -> String {
        switch index {
        case 0: return "M"
        case 2: return "W"
        case 4: return "F"
        default: return ""
        }
    }
}

#Preview {
    HabitHeatmapView(tasks: TodoViewModel.preview.todos)
}
