//
//  TimeRecommendationEngine.swift
//  AI_planner
//
//  Created by AI Assistant on 3/4/26.
//

import Foundation

struct TimeRecommendation: Identifiable {
    let id = UUID()
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int
    let confidence: Double      // 0.0-1.0
    let reason: String          // Chinese explanation
    let conflictWarning: String? // Optional conflict note
    
    var startTimeString: String {
        String(format: "%02d:%02d", startHour, startMinute)
    }
    
    var endTimeString: String {
        String(format: "%02d:%02d", endHour, endMinute)
    }
    
    /// Create a Date for the start time on a given date
    func startDate(on date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: date) ?? date
    }
    
    /// Create a Date for the end time on a given date
    func endDate(on date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: date) ?? date
    }
}

class TimeRecommendationEngine {
    static let shared = TimeRecommendationEngine()
    
    private let analyzer = BehaviorAnalyzer.shared
    private let profileVM = UserProfileViewModel.shared
    
    private init() {}
    
    /// Generate time recommendations for a given event type, duration, and date
    func recommend(
        eventType: TodoTask.EventType,
        durationMinutes: Int = 60,
        date: Date,
        existingTasks: [TodoTask]
    ) -> [TimeRecommendation] {
        let profile = profileVM.profile
        guard profile.hasSufficientData else {
            return defaultRecommendations(eventType: eventType, durationMinutes: durationMinutes, date: date, existingTasks: existingTasks)
        }
        
        let calendar = Calendar.current
        
        // Get occupied time slots on this date
        let dayTasks = existingTasks.filter { calendar.isDate($0.dueDate, inSameDayAs: date) }
        let occupiedSlots = dayTasks.compactMap { task -> (start: Int, end: Int)? in
            guard let start = task.startTime, let end = task.endTime else { return nil }
            let sh = calendar.component(.hour, from: start) * 60 + calendar.component(.minute, from: start)
            let eh = calendar.component(.hour, from: end) * 60 + calendar.component(.minute, from: end)
            return (sh, eh)
        }
        
        // Get best hours for this event type from user profile
        let typePref = profile.taskTypePreferences[eventType.rawValue]
        let bestHours = typePref?.bestHours ?? profile.peakProductivityHours
        
        // Generate candidate slots (every 30 min from 6:00-22:00)
        var candidates: [(startMin: Int, endMin: Int, score: Double, reason: String, conflict: String?)] = []
        
        let slotStep = 30 // every 30 minutes
        for startMin in stride(from: 6 * 60, through: 22 * 60 - durationMinutes, by: slotStep) {
            let endMin = startMin + durationMinutes
            
            // Check for conflicts
            let hasConflict = occupiedSlots.contains { slot in
                startMin < slot.end && endMin > slot.start
            }
            
            if hasConflict { continue } // Skip conflicting slots
            
            let startHour = startMin / 60
            var score = 0.5 // base score
            var reasons: [String] = []
            
            // Boost: matches best hours for this event type
            if bestHours.contains(startHour) {
                score += 0.3
                if let rate = typePref?.completionRate, rate > 0 {
                    reasons.append("你在这个时段完成\(eventType.rawValue)的成功率为\(Int(rate * 100))%")
                } else {
                    reasons.append("这是你效率最高的时段之一")
                }
            }
            
            // Boost: matches peak productivity hours
            if profile.peakProductivityHours.contains(startHour) && !bestHours.contains(startHour) {
                score += 0.15
                reasons.append("这是你的高效时段")
            }
            
            // Penalty: procrastination-prone hours
            let procrastinationTypes = profile.procrastinationPatterns
                .filter { $0.eventTypeRaw == eventType.rawValue && $0.deleteRate > 0.3 }
            if !procrastinationTypes.isEmpty {
                // Avoid scheduling during valley hours
                let energyProfile = EnergyAnalysisService.buildProfile(from: existingTasks)
                if energyProfile.procrastinationSlots.contains(startHour) {
                    score -= 0.2
                    reasons.append("此时段容易拖延，建议避开")
                }
            }
            
            // Slight preference for morning slots for study/class
            if (eventType == .study || eventType == .class_) && startHour >= 8 && startHour <= 11 {
                score += 0.05
            }
            
            // Slight preference for evening for dinner
            if eventType == .dinner && startHour >= 17 && startHour <= 20 {
                score += 0.1
            }
            
            // Slight preference for afternoon/evening for gym
            if eventType == .gym && startHour >= 16 && startHour <= 19 {
                score += 0.05
            }
            
            // Check nearby conflicts (prefer slots with buffer)
            let nearbyConflict = occupiedSlots.contains { slot in
                let bufferStart = startMin - 15
                let bufferEnd = endMin + 15
                return bufferStart < slot.end && bufferEnd > slot.start
            }
            
            let conflictWarning: String? = nearbyConflict ? "与其他事件间隔较近" : nil
            if nearbyConflict { score -= 0.05 }
            
            let reason = reasons.isEmpty ? "此时段空闲可用" : reasons.first!
            
            candidates.append((startMin, endMin, min(1.0, max(0.0, score)), reason, conflictWarning))
        }
        
        // Sort by score and take top 3
        let top = candidates.sorted { $0.score > $1.score }.prefix(3)
        
        return top.map { candidate in
            TimeRecommendation(
                startHour: candidate.startMin / 60,
                startMinute: candidate.startMin % 60,
                endHour: candidate.endMin / 60,
                endMinute: candidate.endMin % 60,
                confidence: candidate.score,
                reason: candidate.reason,
                conflictWarning: candidate.conflict
            )
        }
    }
    
    /// Default recommendations when insufficient data
    private func defaultRecommendations(
        eventType: TodoTask.EventType,
        durationMinutes: Int,
        date: Date,
        existingTasks: [TodoTask]
    ) -> [TimeRecommendation] {
        let defaults: [(hour: Int, reason: String)] = {
            switch eventType {
            case .gym:
                return [(8, "上午运动开启活力一天"), (17, "下午运动放松身心"), (19, "晚间运动消除疲劳")]
            case .class_:
                return [(9, "上午注意力集中适合上课"), (14, "午后可安排课程"), (10, "上午时段适合学习")]
            case .study:
                return [(9, "上午是学习的黄金时段"), (14, "午后适合深度学习"), (20, "晚上安静适合复习")]
            case .meeting:
                return [(10, "上午开会效率更高"), (14, "午后适合团队讨论"), (16, "下午安排简短会议")]
            case .dinner:
                return [(18, "标准晚餐时间"), (19, "稍晚的晚餐"), (17, "早一点的晚餐")]
            case .other:
                return [(10, "上午安排杂事效率高"), (14, "午后处理日常事务"), (16, "下午完成剩余事项")]
            }
        }()
        
        let calendar = Calendar.current
        let dayTasks = existingTasks.filter { calendar.isDate($0.dueDate, inSameDayAs: date) }
        let occupiedSlots = dayTasks.compactMap { task -> (start: Int, end: Int)? in
            guard let start = task.startTime, let end = task.endTime else { return nil }
            let sh = calendar.component(.hour, from: start) * 60 + calendar.component(.minute, from: start)
            let eh = calendar.component(.hour, from: end) * 60 + calendar.component(.minute, from: end)
            return (sh, eh)
        }
        
        return defaults.compactMap { (hour, reason) in
            let startMin = hour * 60
            let endMin = startMin + durationMinutes
            
            let hasConflict = occupiedSlots.contains { slot in
                startMin < slot.end && endMin > slot.start
            }
            
            return TimeRecommendation(
                startHour: hour,
                startMinute: 0,
                endHour: endMin / 60,
                endMinute: endMin % 60,
                confidence: 0.4,
                reason: reason,
                conflictWarning: hasConflict ? "与现有事件时间冲突" : nil
            )
        }.filter { $0.conflictWarning == nil } // Only show non-conflicting defaults
    }
}
