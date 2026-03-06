//
//  BehaviorAnalyzer.swift
//  AI_planner
//
//  Created by AI Assistant on 3/4/26.
//

import Foundation

// MARK: - Analysis Result Models

struct HourlyDistribution {
    let hour: Int       // 0-23
    let count: Int
    let percentage: Double // 0-100
}

struct EventTypeStats {
    let eventType: TodoTask.EventType
    let totalCount: Int
    let completedCount: Int
    let deletedCount: Int
    let completionRate: Double   // 0.0-1.0
    let bestHours: [Int]         // Top 3 hours with highest completion
    let avgCompletionHour: Double?
}

struct ProcrastinationPattern {
    let eventType: TodoTask.EventType
    let avgDelayDays: Double     // Average days a task is postponed/delayed
    let deleteRate: Double       // 0.0-1.0 how often tasks of this type get deleted
    let description: String      // Human-readable description (Chinese)
}

struct ProductivitySlot {
    let startHour: Int
    let endHour: Int
    let score: Double           // 0.0-1.0 normalized productivity score
    let label: String           // Chinese label
}

// MARK: - Behavior Analyzer

class BehaviorAnalyzer {
    static let shared = BehaviorAnalyzer()
    
    private let store = UserBehaviorStore.shared
    
    private init() {}
    
    // MARK: - High Frequency Time Analysis
    
    /// Hours when user creates tasks most often
    func taskCreationHourDistribution(days: Int = 30) -> [HourlyDistribution] {
        let records = store.recentRecords(days: days).filter { $0.type == .taskCreated }
        return buildHourlyDistribution(from: records)
    }
    
    /// Hours when user completes tasks most often
    func taskCompletionHourDistribution(days: Int = 30) -> [HourlyDistribution] {
        let records = store.recentRecords(days: days).filter { $0.type == .taskCompleted }
        return buildHourlyDistribution(from: records)
    }
    
    /// Top productive hours (hours with most completions, weighted by priority)
    func topProductiveHours(days: Int = 30, topN: Int = 3) -> [Int] {
        let records = store.recentRecords(days: days).filter { $0.type == .taskCompleted }
        var hourScores = Array(repeating: 0.0, count: 24)
        
        for record in records {
            let hour = record.context?.actualCompletionHour ?? record.hourOfDay
            let weight: Double = {
                switch record.priority {
                case .high: return 3.0
                case .medium: return 2.0
                case .low: return 1.0
                case .none: return 1.0
                }
            }()
            hourScores[hour] += weight
        }
        
        // Only consider waking hours (6-23)
        let wakingHours = (6...22).sorted { hourScores[$0] > hourScores[$1] }
        return Array(wakingHours.prefix(topN))
    }
    
    /// Hours where tasks are most likely to be postponed or deleted (procrastination zones)
    func procrastinationHours(days: Int = 30, topN: Int = 3) -> [Int] {
        let deleted = store.recentRecords(days: days).filter { $0.type == .taskDeleted }
        var hourCounts = Array(repeating: 0, count: 24)
        
        for record in deleted {
            hourCounts[record.hourOfDay] += 1
        }
        
        let wakingHours = (6...22).sorted { hourCounts[$0] > hourCounts[$1] }
        return Array(wakingHours.filter { hourCounts[$0] > 0 }.prefix(topN))
    }
    
    // MARK: - Event Type Analysis
    
    /// Completion rate and stats per event type
    func eventTypeAnalysis(days: Int = 30) -> [EventTypeStats] {
        let recent = store.recentRecords(days: days)
        let allTypes: [TodoTask.EventType] = [.gym, .class_, .study, .meeting, .dinner, .other]
        
        return allTypes.compactMap { type in
            let created = recent.filter { $0.type == .taskCreated && $0.eventType == type }
            let completed = recent.filter { $0.type == .taskCompleted && $0.eventType == type }
            let deleted = recent.filter { $0.type == .taskDeleted && $0.eventType == type }
            
            let totalCount = created.count + completed.count // approximate
            guard totalCount > 0 else { return nil }
            
            let completionRate = totalCount > 0 ? Double(completed.count) / Double(totalCount) : 0
            _ = totalCount > 0 ? Double(deleted.count) / Double(totalCount) : 0
            
            // Find best completion hours for this type
            var hourCounts = Array(repeating: 0, count: 24)
            for record in completed {
                let hour = record.context?.actualCompletionHour ?? record.hourOfDay
                hourCounts[hour] += 1
            }
            let bestHours = (6...22).sorted { hourCounts[$0] > hourCounts[$1] }
                .filter { hourCounts[$0] > 0 }
                .prefix(3)
            
            // Average completion hour
            let completionHours = completed.compactMap { $0.context?.actualCompletionHour ?? $0.hourOfDay }
            let avgHour = completionHours.isEmpty ? nil : Double(completionHours.reduce(0, +)) / Double(completionHours.count)
            
            return EventTypeStats(
                eventType: type,
                totalCount: totalCount,
                completedCount: completed.count,
                deletedCount: deleted.count,
                completionRate: completionRate,
                bestHours: Array(bestHours),
                avgCompletionHour: avgHour
            )
        }
    }
    
    // MARK: - Procrastination Analysis
    
    /// Identify procrastination patterns by event type
    func procrastinationPatterns(days: Int = 30) -> [ProcrastinationPattern] {
        let typeStats = eventTypeAnalysis(days: days)
        
        return typeStats.compactMap { stats in
            let deleted = store.recentRecords(days: days)
                .filter { $0.type == .taskDeleted && $0.eventType == stats.eventType }
            
            let avgDelay = deleted.compactMap { $0.context?.taskAgeInDays }
            let avgDelayDays = avgDelay.isEmpty ? 0.0 : Double(avgDelay.reduce(0, +)) / Double(avgDelay.count)
            
            let deleteRate = stats.totalCount > 0 ? Double(stats.deletedCount) / Double(stats.totalCount) : 0
            
            // Only report if there's a meaningful pattern
            guard deleteRate > 0.2 || avgDelayDays > 2 else { return nil }
            
            let description: String
            if deleteRate > 0.5 {
                description = "\(stats.eventType.rawValue)类任务经常被删除（删除率\(Int(deleteRate * 100))%），建议减少此类安排或调整时间"
            } else if avgDelayDays > 3 {
                description = "\(stats.eventType.rawValue)类任务平均延迟\(String(format: "%.1f", avgDelayDays))天，建议安排在高效时段"
            } else {
                description = "\(stats.eventType.rawValue)类任务有轻微拖延倾向"
            }
            
            return ProcrastinationPattern(
                eventType: stats.eventType,
                avgDelayDays: avgDelayDays,
                deleteRate: deleteRate,
                description: description
            )
        }
    }
    
    // MARK: - Productivity Slots
    
    /// Identify high/low productivity time slots (3-hour windows)
    func productivitySlots(days: Int = 30) -> [ProductivitySlot] {
        let completions = store.recentRecords(days: days).filter { $0.type == .taskCompleted }
        
        // Define 3-hour windows across waking hours
        let windows: [(start: Int, end: Int, label: String)] = [
            (6, 9, "清晨"),
            (9, 12, "上午"),
            (12, 15, "午后"),
            (15, 18, "下午"),
            (18, 21, "傍晚"),
            (21, 24, "深夜")
        ]
        
        var windowScores: [Double] = []
        for window in windows {
            var score = 0.0
            for record in completions {
                let hour = record.context?.actualCompletionHour ?? record.hourOfDay
                if hour >= window.start && hour < window.end {
                    let weight: Double = {
                        switch record.priority {
                        case .high: return 3.0
                        case .medium: return 2.0
                        case .low: return 1.0
                        case .none: return 1.0
                        }
                    }()
                    score += weight
                }
            }
            windowScores.append(score)
        }
        
        // Normalize
        let maxScore = windowScores.max() ?? 1.0
        let normalized = maxScore > 0 ? windowScores.map { $0 / maxScore } : windowScores
        
        return zip(windows, normalized).map { window, score in
            ProductivitySlot(
                startHour: window.start,
                endHour: window.end,
                score: score,
                label: window.label
            )
        }
    }
    
    // MARK: - Summary for AI Prompt
    
    /// Generate a concise user behavior summary for injection into AI system prompts
    func generateProfileSummary(days: Int = 30) -> String {
        let records = store.recentRecords(days: days)
        guard records.count >= 3 else { return "数据不足，暂无用户画像" }
        
        var lines: [String] = ["用户画像："]
        
        // Top productive hours
        let topHours = topProductiveHours(days: days)
        if !topHours.isEmpty {
            let hourStrings = topHours.map { "\($0):00" }
            lines.append("- 高效时段：\(hourStrings.joined(separator: ", "))")
        }
        
        // Event type insights
        let typeStats = eventTypeAnalysis(days: days)
        for stats in typeStats where stats.completedCount > 2 {
            if !stats.bestHours.isEmpty {
                let bestHour = stats.bestHours[0]
                lines.append("- \(stats.eventType.rawValue)任务最佳时段：\(bestHour):00 附近（完成率\(Int(stats.completionRate * 100))%）")
            }
        }
        
        // Preferred task duration
        let createdRecords = records.filter { $0.type == .taskCreated }
        let durations = createdRecords.compactMap { $0.context?.plannedDurationMinutes }.filter { $0 > 0 }
        if durations.count >= 3 {
            let avgDuration = durations.reduce(0, +) / durations.count
            lines.append("- 用户偏好的任务时长：约\(avgDuration)分钟")
        }
        
        // Most common event types
        let typeCounts = Dictionary(grouping: createdRecords.compactMap(\.eventType), by: { $0 })
            .mapValues(\.count)
            .sorted { $0.value > $1.value }
        if let topType = typeCounts.first, topType.value >= 3 {
            let topTypes = typeCounts.prefix(2).map { "\($0.key.rawValue)(\($0.value)次)" }
            lines.append("- 最常安排的任务类型：\(topTypes.joined(separator: "、"))")
        }
        
        // Weekly activity pattern
        let completedRecords = records.filter { $0.type == .taskCompleted }
        if completedRecords.count >= 5 {
            let weekdayCounts = Array(repeating: 0, count: 7).enumerated().map { (index, _) in
                completedRecords.filter {
                    Calendar.current.component(.weekday, from: $0.timestamp) == index + 1
                }.count
            }
            let weekdayNames = ["日", "一", "二", "三", "四", "五", "六"]
            let activeDays = weekdayCounts.enumerated()
                .sorted { $0.element > $1.element }
                .prefix(3)
                .map { "周\(weekdayNames[$0.offset])" }
            if !activeDays.isEmpty {
                lines.append("- 最活跃的日子：\(activeDays.joined(separator: "、"))")
            }
        }
        
        // Procrastination warnings
        let patterns = procrastinationPatterns(days: days)
        for pattern in patterns.prefix(2) {
            lines.append("- ⚠️ \(pattern.description)")
        }
        
        // App usage pattern
        let openRecords = records.filter { $0.type == .appOpened }
        if openRecords.count >= 3 {
            let avgOpenHour = Double(openRecords.map(\.hourOfDay).reduce(0, +)) / Double(openRecords.count)
            lines.append("- 用户通常在 \(Int(avgOpenHour)):00 左右打开App")
        }
        
        // Completion rate trend (this week vs last week)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today)!
        let thisWeekCompleted = completedRecords.filter { $0.timestamp >= oneWeekAgo }.count
        let lastWeekCompleted = completedRecords.filter { $0.timestamp >= twoWeeksAgo && $0.timestamp < oneWeekAgo }.count
        if lastWeekCompleted > 0 {
            let change = thisWeekCompleted - lastWeekCompleted
            if change > 0 {
                lines.append("- 📈 本周完成量比上周多\(change)个，效率在提升")
            } else if change < 0 {
                lines.append("- 📉 本周完成量比上周少\(abs(change))个")
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Helpers
    
    private func buildHourlyDistribution(from records: [BehaviorRecord]) -> [HourlyDistribution] {
        var hourCounts = Array(repeating: 0, count: 24)
        for record in records {
            hourCounts[record.hourOfDay] += 1
        }
        let total = max(hourCounts.reduce(0, +), 1)
        
        return (0..<24).map { hour in
            HourlyDistribution(
                hour: hour,
                count: hourCounts[hour],
                percentage: Double(hourCounts[hour]) / Double(total) * 100
            )
        }
    }
}
