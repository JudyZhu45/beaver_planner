//
//  UserProfile.swift
//  AI_planner
//
//  Created by AI Assistant on 3/4/26.
//

import Foundation

struct UserProfile: Codable {
    var preferredWorkHours: [Int]            // Hours user is most active (e.g., [9,10,14,15])
    var peakProductivityHours: [Int]         // Top 3 high-efficiency hours
    var taskTypePreferences: [String: TypePreference]  // Keyed by EventType.rawValue
    var averageTasksPerDay: Double
    var completionRate: Double               // 0.0-1.0 overall
    var procrastinationPatterns: [ProcrastinationInfo]
    var streakData: StreakInfo
    var avgAppOpenHour: Int?                 // Typical hour user opens the app
    var lastUpdated: Date
    
    struct TypePreference: Codable {
        var totalCount: Int
        var completedCount: Int
        var completionRate: Double
        var bestHours: [Int]
        var avgCompletionHour: Double?
    }
    
    struct ProcrastinationInfo: Codable {
        var eventTypeRaw: String
        var avgDelayDays: Double
        var deleteRate: Double
        var description: String
    }
    
    struct StreakInfo: Codable {
        var currentStreak: Int
        var longestStreak: Int
        var lastActiveDate: Date?
    }
    
    /// Whether there's enough data to make meaningful recommendations
    var hasSufficientData: Bool {
        averageTasksPerDay > 0 && completionRate > 0
    }
    
    static var empty: UserProfile {
        UserProfile(
            preferredWorkHours: [],
            peakProductivityHours: [],
            taskTypePreferences: [:],
            averageTasksPerDay: 0,
            completionRate: 0,
            procrastinationPatterns: [],
            streakData: StreakInfo(currentStreak: 0, longestStreak: 0, lastActiveDate: nil),
            avgAppOpenHour: nil,
            lastUpdated: Date()
        )
    }
}
