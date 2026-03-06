//
//  AchievementSystem.swift
//  AI_planner
//
//  Created by AI Assistant on 3/4/26.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Achievement Definition

struct Achievement: Identifiable, Codable {
    let id: String
    let icon: String
    let title: String
    let description: String
    let requirement: Int        // Number needed to unlock
    let colorHex: String        // Hex color for the badge
    var isUnlocked: Bool = false
    var unlockedAt: Date? = nil
    var currentProgress: Int = 0
    
    var progressRatio: Double {
        guard requirement > 0 else { return 0 }
        return min(1.0, Double(currentProgress) / Double(requirement))
    }
    
    var color: Color {
        Color(hex: colorHex)
    }
}

// MARK: - Achievement System

class AchievementSystem: ObservableObject {
    static let shared = AchievementSystem()
    
    @Published var achievements: [Achievement] = []
    @Published var newlyUnlocked: Achievement? = nil
    
    private let storageKey = "AchievementData"
    
    private init() {
        loadAchievements()
        if achievements.isEmpty {
            achievements = Self.defaultAchievements
            saveAchievements()
        }
    }
    
    // MARK: - Default Achievements
    
    static let defaultAchievements: [Achievement] = [
        Achievement(
            id: "first_seed",
            icon: "🌱",
            title: "First Seed",
            description: "Create your first task",
            requirement: 1,
            colorHex: "#619D7A"
        ),
        Achievement(
            id: "streak_3",
            icon: "🔥",
            title: "Getting Started",
            description: "Complete tasks 3 days in a row",
            requirement: 3,
            colorHex: "#DD6F57"
        ),
        Achievement(
            id: "streak_7",
            icon: "🔥",
            title: "Weekly Warrior",
            description: "Complete tasks 7 days in a row",
            requirement: 7,
            colorHex: "#DD6F57"
        ),
        Achievement(
            id: "streak_30",
            icon: "💎",
            title: "Monthly Master",
            description: "Complete tasks 30 days in a row",
            requirement: 30,
            colorHex: "#5790B0"
        ),
        Achievement(
            id: "study_50",
            icon: "📚",
            title: "Study Achiever",
            description: "Complete 50 study tasks",
            requirement: 50,
            colorHex: "#619D7A"
        ),
        Achievement(
            id: "gym_30",
            icon: "🏃",
            title: "Fitness Enthusiast",
            description: "Complete 30 gym tasks",
            requirement: 30,
            colorHex: "#B07049"
        ),
        Achievement(
            id: "speed_10",
            icon: "⚡",
            title: "Productivity King",
            description: "Complete 10 tasks in a single day",
            requirement: 10,
            colorHex: "#D1A63C"
        ),
        Achievement(
            id: "total_100",
            icon: "🏆",
            title: "Century Club",
            description: "Complete 100 tasks total",
            requirement: 100,
            colorHex: "#D1A63C"
        ),
        Achievement(
            id: "beaver_30",
            icon: "🦫",
            title: "Beaver's Friend",
            description: "Use the app for 30 days",
            requirement: 30,
            colorHex: "#7D512D"
        ),
        Achievement(
            id: "planner_5",
            icon: "📋",
            title: "Plan Ahead",
            description: "Plan 5 full days in advance",
            requirement: 5,
            colorHex: "#5790B0"
        ),
    ]
    
    // MARK: - Check and Update Achievements
    
    func updateProgress(tasks: [TodoTask]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let profile = UserProfileViewModel.shared.profile
        
        for i in achievements.indices {
            guard !achievements[i].isUnlocked else { continue }
            
            let oldProgress = achievements[i].currentProgress
            
            switch achievements[i].id {
            case "first_seed":
                achievements[i].currentProgress = min(1, tasks.count)
                
            case "streak_3":
                achievements[i].currentProgress = profile.streakData.currentStreak
                
            case "streak_7":
                achievements[i].currentProgress = profile.streakData.currentStreak
                
            case "streak_30":
                achievements[i].currentProgress = profile.streakData.currentStreak
                
            case "study_50":
                achievements[i].currentProgress = tasks.filter { $0.isCompleted && $0.eventType == .study }.count
                
            case "gym_30":
                achievements[i].currentProgress = tasks.filter { $0.isCompleted && $0.eventType == .gym }.count
                
            case "speed_10":
                let todayCompleted = tasks.filter {
                    $0.isCompleted && calendar.isDate($0.completedAt ?? $0.dueDate, inSameDayAs: today)
                }.count
                achievements[i].currentProgress = todayCompleted
                
            case "total_100":
                achievements[i].currentProgress = tasks.filter(\.isCompleted).count
                
            case "beaver_30":
                let uniqueDays = Set(
                    UserBehaviorStore.shared.records(ofType: .appOpened)
                        .map { calendar.startOfDay(for: $0.timestamp) }
                ).count
                achievements[i].currentProgress = uniqueDays
                
            case "planner_5":
                // Count days that have 3+ tasks planned in advance
                let futureDays = Set(tasks.filter {
                    let dayDiff = calendar.dateComponents([.day], from: $0.createdAt, to: $0.dueDate).day ?? 0
                    return dayDiff >= 1 && $0.startTime != nil
                }.map { calendar.startOfDay(for: $0.dueDate) })
                achievements[i].currentProgress = futureDays.count
                
            default:
                break
            }
            
            // Check if newly unlocked
            if achievements[i].currentProgress >= achievements[i].requirement && oldProgress < achievements[i].requirement {
                achievements[i].isUnlocked = true
                achievements[i].unlockedAt = Date()
                newlyUnlocked = achievements[i]
            }
        }
        
        saveAchievements()
    }
    
    /// Get the next achievement closest to being unlocked
    func nextAchievement() -> Achievement? {
        achievements
            .filter { !$0.isUnlocked }
            .sorted { $0.progressRatio > $1.progressRatio }
            .first
    }
    
    var unlockedCount: Int {
        achievements.filter(\.isUnlocked).count
    }
    
    // MARK: - Persistence
    
    private func saveAchievements() {
        if let encoded = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadAchievements() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Achievement].self, from: data) {
            achievements = decoded
        }
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
