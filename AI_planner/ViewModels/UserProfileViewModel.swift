//
//  UserProfileViewModel.swift
//  AI_planner
//
//  Created by AI Assistant on 3/4/26.
//

import Foundation
import Combine

@MainActor
class UserProfileViewModel: ObservableObject {
    static let shared = UserProfileViewModel()
    
    @Published var profile: UserProfile = .empty
    
    private let baseStorageKey = "UserProfileData"
    private var storageKey: String { ProfileManager.activeScopedKey(baseStorageKey) }
    private let analyzer = BehaviorAnalyzer.shared
    
    private init() {
        loadProfile()
        NotificationCenter.default.addObserver(
            forName: .profileDidSwitch,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadProfile()
            }
        }
    }
    
    /// Rebuild user profile from behavior data and tasks
    func rebuildProfile(tasks: [TodoTask]) {
        let calendar = Calendar.current
        let store = UserBehaviorStore.shared
        
        // Peak productivity hours
        let topHours = analyzer.topProductiveHours(days: 30)
        
        // Preferred work hours (hours with any activity)
        let completionDist = analyzer.taskCompletionHourDistribution(days: 30)
        let activeHours = completionDist.filter { $0.count > 0 }.map(\.hour)
        
        // Event type preferences
        let typeStats = analyzer.eventTypeAnalysis(days: 30)
        var typePrefs: [String: UserProfile.TypePreference] = [:]
        for stat in typeStats {
            typePrefs[stat.eventType.rawValue] = UserProfile.TypePreference(
                totalCount: stat.totalCount,
                completedCount: stat.completedCount,
                completionRate: stat.completionRate,
                bestHours: stat.bestHours,
                avgCompletionHour: stat.avgCompletionHour
            )
        }
        
        // Average tasks per day (last 30 days)
        let recentTasks = tasks.filter {
            let daysAgo = calendar.dateComponents([.day], from: $0.createdAt, to: Date()).day ?? 0
            return daysAgo <= 30
        }
        let activeDays = Set(recentTasks.map { calendar.startOfDay(for: $0.createdAt) }).count
        let avgPerDay = activeDays > 0 ? Double(recentTasks.count) / Double(activeDays) : 0
        
        // Overall completion rate
        let completedCount = tasks.filter(\.isCompleted).count
        let completionRate = tasks.isEmpty ? 0.0 : Double(completedCount) / Double(tasks.count)
        
        // Procrastination patterns
        let patterns = analyzer.procrastinationPatterns(days: 30)
        let procInfo = patterns.map {
            UserProfile.ProcrastinationInfo(
                eventTypeRaw: $0.eventType.rawValue,
                avgDelayDays: $0.avgDelayDays,
                deleteRate: $0.deleteRate,
                description: $0.description
            )
        }
        
        // Streak data
        let streak = calculateStreak(tasks: tasks)
        
        // App open hour
        let openRecords = store.records(ofType: .appOpened)
        let avgOpenHour: Int?
        if openRecords.count >= 3 {
            avgOpenHour = openRecords.map(\.hourOfDay).reduce(0, +) / openRecords.count
        } else {
            avgOpenHour = nil
        }
        
        profile = UserProfile(
            preferredWorkHours: activeHours,
            peakProductivityHours: topHours,
            taskTypePreferences: typePrefs,
            averageTasksPerDay: avgPerDay,
            completionRate: completionRate,
            procrastinationPatterns: procInfo,
            streakData: streak,
            avgAppOpenHour: avgOpenHour,
            lastUpdated: Date()
        )
        
        saveProfile()
    }
    
    // MARK: - Streak Calculation
    
    private func calculateStreak(tasks: [TodoTask]) -> UserProfile.StreakInfo {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var daysWithCompletions = Set<Date>()
        for task in tasks where task.isCompleted {
            if let completedAt = task.completedAt {
                daysWithCompletions.insert(calendar.startOfDay(for: completedAt))
            } else {
                daysWithCompletions.insert(calendar.startOfDay(for: task.dueDate))
            }
        }
        
        guard !daysWithCompletions.isEmpty else {
            return UserProfile.StreakInfo(currentStreak: 0, longestStreak: 0, lastActiveDate: nil)
        }
        
        // Current streak
        var checkDate = today
        if !daysWithCompletions.contains(checkDate) {
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            if !daysWithCompletions.contains(checkDate) {
                // Find longest streak even if current is 0
                let longest = findLongestStreak(dates: daysWithCompletions, calendar: calendar)
                return UserProfile.StreakInfo(
                    currentStreak: 0,
                    longestStreak: longest,
                    lastActiveDate: daysWithCompletions.max()
                )
            }
        }
        
        var currentStreak = 0
        while daysWithCompletions.contains(checkDate) {
            currentStreak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }
        
        let longest = max(currentStreak, findLongestStreak(dates: daysWithCompletions, calendar: calendar))
        
        return UserProfile.StreakInfo(
            currentStreak: currentStreak,
            longestStreak: longest,
            lastActiveDate: daysWithCompletions.max()
        )
    }
    
    private func findLongestStreak(dates: Set<Date>, calendar: Calendar) -> Int {
        let sorted = dates.sorted()
        guard !sorted.isEmpty else { return 0 }
        
        var longest = 1
        var current = 1
        
        for i in 1..<sorted.count {
            let dayDiff = calendar.dateComponents([.day], from: sorted[i-1], to: sorted[i]).day ?? 0
            if dayDiff == 1 {
                current += 1
                longest = max(longest, current)
            } else if dayDiff > 1 {
                current = 1
            }
        }
        
        return longest
    }
    
    // MARK: - Persistence
    
    private func saveProfile() {
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadProfile() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = decoded
        }
    }
}
