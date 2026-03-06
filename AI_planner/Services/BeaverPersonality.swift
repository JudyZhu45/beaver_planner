//
//  BeaverPersonality.swift
//  AI_planner
//
//  Created by AI Assistant on 3/4/26.
//

import Foundation

// MARK: - Beaver Mood

enum BeaverMood: String {
    case cheerful    // User performing well
    case encouraging // User making progress
    case caring      // User struggling
    case playful     // Normal interaction
    case proud       // Milestone achieved
    
    var emoji: String {
        switch self {
        case .cheerful: return "😊"
        case .encouraging: return "💪"
        case .caring: return "🤗"
        case .playful: return "🦫"
        case .proud: return "🎉"
        }
    }
}

// MARK: - Beaver Personality

class BeaverPersonality {
    static let shared = BeaverPersonality()
    
    private init() {}
    
    /// Determine beaver's current mood based on user's context
    func currentMood(tasks: [TodoTask]) -> BeaverMood {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let profile = UserProfileViewModel.shared.profile
        
        // Check streak milestones
        if profile.streakData.currentStreak >= 7 {
            return .proud
        }
        
        // Check today's completion
        let todayTasks = tasks.filter { calendar.isDate($0.dueDate, inSameDayAs: today) }
        let todayCompleted = todayTasks.filter(\.isCompleted).count
        
        if !todayTasks.isEmpty {
            let rate = Double(todayCompleted) / Double(todayTasks.count)
            if rate >= 0.8 { return .cheerful }
            if rate >= 0.5 { return .encouraging }
            if rate < 0.2 && todayTasks.count > 3 { return .caring }
        }
        
        // Check if user hasn't been active
        let store = UserBehaviorStore.shared
        let recentOpens = store.records(ofType: .appOpened)
        if let lastOpen = recentOpens.last {
            let daysSinceLastOpen = calendar.dateComponents([.day], from: lastOpen.timestamp, to: Date()).day ?? 0
            if daysSinceLastOpen >= 3 { return .caring }
        }
        
        return .playful
    }
    
    // MARK: - Greetings
    
    /// Generate time-appropriate greeting with beaver personality
    func greeting(tasks: [TodoTask]) -> (text: String, subtitle: String) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let today = calendar.startOfDay(for: Date())
        let mood = currentMood(tasks: tasks)
        
        let todayTasks = tasks.filter { calendar.isDate($0.dueDate, inSameDayAs: today) }
        let todayCount = todayTasks.count
        let completedCount = todayTasks.filter(\.isCompleted).count
        let remainingCount = todayCount - completedCount
        
        let timeGreeting: String
        let subtitle: String
        
        switch hour {
        case 5..<8:
            timeGreeting = "Early bird! Good morning"
            subtitle = earlyMorningSubtitle(mood: mood, remaining: remainingCount, total: todayCount)
        case 8..<12:
            timeGreeting = "Good morning"
            subtitle = morningSubtitle(mood: mood, remaining: remainingCount, total: todayCount)
        case 12..<14:
            timeGreeting = "Good afternoon"
            subtitle = noonSubtitle(mood: mood, remaining: remainingCount, completed: completedCount)
        case 14..<18:
            timeGreeting = "Good afternoon"
            subtitle = afternoonSubtitle(mood: mood, remaining: remainingCount, completed: completedCount, total: todayCount)
        case 18..<22:
            timeGreeting = "Good evening"
            subtitle = eveningSubtitle(mood: mood, remaining: remainingCount, completed: completedCount, total: todayCount)
        default:
            timeGreeting = "Burning the midnight oil?"
            subtitle = lateNightSubtitle(mood: mood, completed: completedCount)
        }
        
        return (timeGreeting, subtitle)
    }
    
    // MARK: - Subtitle Generators
    
    private func earlyMorningSubtitle(mood: BeaverMood, remaining: Int, total: Int) -> String {
        if total == 0 { return "A fresh day with a clean slate!" }
        return "You have \(total) tasks lined up today. Let's start strong!"
    }
    
    private func morningSubtitle(mood: BeaverMood, remaining: Int, total: Int) -> String {
        if total == 0 { return "No tasks yet. Want to plan your day?" }
        switch mood {
        case .cheerful, .proud:
            return "\(total) tasks today. You've got this! \(mood.emoji)"
        case .encouraging:
            return "\(remaining) tasks waiting. One step at a time!"
        case .caring:
            return "Take it easy. Start with the simplest task first."
        case .playful:
            return "\(remaining > 0 ? "\(remaining) tasks to go" : "All clear!"). \(mood.emoji)"
        }
    }
    
    private func noonSubtitle(mood: BeaverMood, remaining: Int, completed: Int) -> String {
        if completed > 0 {
            return "Nice progress! \(completed) done, \(remaining) to go."
        }
        return "\(remaining) tasks remaining this afternoon."
    }
    
    private func afternoonSubtitle(mood: BeaverMood, remaining: Int, completed: Int, total: Int) -> String {
        if total == 0 { return "A relaxed afternoon ahead." }
        let rate = total > 0 ? Int(Double(completed) / Double(total) * 100) : 0
        switch mood {
        case .cheerful, .proud:
            return "Already \(rate)% done! Keep up the momentum! \(mood.emoji)"
        case .encouraging:
            return "\(remaining) tasks left. You can finish strong!"
        case .caring:
            return "It's okay to take a break. \(remaining) tasks can wait."
        case .playful:
            return "\(completed) done, \(remaining) to go. Almost there!"
        }
    }
    
    private func eveningSubtitle(mood: BeaverMood, remaining: Int, completed: Int, total: Int) -> String {
        if total == 0 { return "Enjoy your evening!" }
        let rate = total > 0 ? Int(Double(completed) / Double(total) * 100) : 0
        if remaining == 0 {
            return "All done! Great job today! \(BeaverMood.proud.emoji)"
        }
        switch mood {
        case .cheerful, .proud:
            return "\(rate)% complete today. Excellent work! \(mood.emoji)"
        case .encouraging:
            return "\(remaining) tasks left. Finish strong or save for tomorrow."
        case .caring:
            return "You've done \(completed) tasks today. That's something!"
        case .playful:
            return "\(remaining) tasks left tonight. You decide the pace."
        }
    }
    
    private func lateNightSubtitle(mood: BeaverMood, completed: Int) -> String {
        if completed > 0 {
            return "You completed \(completed) tasks today. Time to rest!"
        }
        return "Don't forget to get some rest tonight."
    }
    
    // MARK: - Profile Commentary
    
    /// Generate beaver commentary for statistics
    func statsCommentary(completionRate: Double, streak: Int, completedCount: Int) -> String {
        if completionRate >= 0.9 && streak >= 7 {
            return "Incredible consistency! You're a planning master! 🦫"
        } else if completionRate >= 0.7 {
            return "Great completion rate! Keep building this habit! 💪"
        } else if streak >= 3 {
            return "Nice streak going! Let's keep it alive! 🔥"
        } else if completedCount >= 10 {
            return "You've built real momentum. Stay focused! ⚡"
        } else if completedCount > 0 {
            return "Every completed task counts. Keep going! 🌱"
        } else {
            return "Ready to start your productivity journey? 🦫"
        }
    }
    
    // MARK: - AI Persona Prompt
    
    /// Generate persona description for AI system prompt
    func personaPrompt(tasks: [TodoTask]) -> String {
        let mood = currentMood(tasks: tasks)
        let profile = UserProfileViewModel.shared.profile
        
        let moodDesc: String
        switch mood {
        case .cheerful:
            moodDesc = "开心（用户表现很好）"
        case .encouraging:
            moodDesc = "鼓励（用户正在进步）"
        case .caring:
            moodDesc = "关怀（用户可能遇到困难）"
        case .playful:
            moodDesc = "俏皮（日常互动）"
        case .proud:
            moodDesc = "骄傲（用户达成了里程碑，连续\(profile.streakData.currentStreak)天完成任务）"
        }
        
        return """
        你是"小河狸"，一个温暖、有条理的日程管家。
        你说话简洁友善，偶尔用河狸相关的表达。
        当前心情：\(moodDesc)。
        根据心情调整你的语气：开心时多鼓励，关怀时温和体贴，骄傲时表达赞赏。
        """
    }
}
