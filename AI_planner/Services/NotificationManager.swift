//
//  NotificationManager.swift
//  AI_planner
//
//  Created by Judy459 on 2/24/26.
//

import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private let center = UNUserNotificationCenter.current()
    
    private init() {}
    
    // MARK: - Permission
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }
    
    // MARK: - Schedule Notifications
    
    /// Schedule a notification for a task. Events with startTime get a 15-min-before reminder.
    /// Todos without startTime get a morning reminder on the due date.
    func scheduleNotification(for task: TodoTask) {
        // Don't schedule for completed tasks or past dates
        guard !task.isCompleted else { return }
        
        // Cancel any existing notification for this task first
        cancelNotification(for: task)
        
        let content = UNMutableNotificationContent()
        content.title = task.title
        content.sound = .default
        
        let calendar = Calendar.current
        var triggerDate: Date?
        
        if let startTime = task.startTime {
            // Event with start time: remind 15 minutes before
            content.body = task.description.isEmpty
                ? "Starting in 15 minutes"
                : "\(task.description) — Starting in 15 minutes"
            triggerDate = calendar.date(byAdding: .minute, value: -15, to: startTime)
        } else {
            // Todo without start time: remind at 8:00 AM on due date
            content.body = task.description.isEmpty
                ? "Due today"
                : "\(task.description) — Due today"
            triggerDate = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: task.dueDate)
        }
        
        guard let fireDate = triggerDate, fireDate > Date() else { return }
        
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: task.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
    
    /// Cancel the notification for a specific task
    func cancelNotification(for task: TodoTask) {
        center.removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
    }
    
    /// Cancel all scheduled notifications
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }
    
    /// Reschedule notifications for all active tasks
    func rescheduleAll(tasks: [TodoTask]) {
        cancelAllNotifications()
        for task in tasks where !task.isCompleted {
            scheduleNotification(for: task)
        }
    }
    
    // MARK: - Smart Suggestion Notifications
    
    private let dailySuggestionKey = "LastDailySuggestionDate"
    private let maxDailySuggestions = 3
    private var dailySuggestionCount = 0
    
    /// Schedule a morning planning suggestion based on user's typical open time
    func scheduleMorningSuggestion(tasks: [TodoTask]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Don't schedule if already sent today
        if let lastDate = UserDefaults.standard.object(forKey: dailySuggestionKey) as? Date,
           calendar.isDate(lastDate, inSameDayAs: today) {
            return
        }
        
        let todayTasks = tasks.filter {
            !$0.isCompleted && calendar.isDate($0.dueDate, inSameDayAs: today)
        }
        guard !todayTasks.isEmpty else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Today's Plan"
        content.body = "You have \(todayTasks.count) tasks today. Start with the most important one!"
        content.sound = .default
        
        // Schedule for user's typical open time minus 5 min, or 8:00 AM default
        let profile = UserProfileViewModel.shared.profile
        let openHour = profile.avgAppOpenHour ?? 8
        let fireHour = max(6, openHour)
        
        guard let fireDate = calendar.date(bySettingHour: fireHour, minute: 0, second: 0, of: today),
              fireDate > Date() else {
            UserDefaults.standard.set(today, forKey: dailySuggestionKey)
            return
        }
        
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "morning_suggestion_\(today.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { [weak self] error in
            if error == nil {
                UserDefaults.standard.set(today, forKey: self?.dailySuggestionKey ?? "")
            }
        }
    }
    
    /// Schedule overdue task reminder
    func scheduleOverdueReminder(tasks: [TodoTask]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let overdueTasks = tasks.filter {
            !$0.isCompleted && $0.dueDate < today
        }
        guard overdueTasks.count >= 2 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Tasks Need Attention"
        content.body = "You have \(overdueTasks.count) overdue tasks. Would you like to reschedule them?"
        content.sound = .default
        
        // Schedule for 2 PM today
        guard let fireDate = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: Date()),
              fireDate > Date() else { return }
        
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "overdue_reminder_\(today.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        center.add(request)
    }
    
    /// Schedule a productivity peak reminder
    func schedulePeakHourReminder(tasks: [TodoTask]) {
        let profile = UserProfileViewModel.shared.profile
        guard !profile.peakProductivityHours.isEmpty else { return }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let peakHour = profile.peakProductivityHours[0]
        
        // Check if there are important uncompleted tasks
        let importantTasks = tasks.filter {
            !$0.isCompleted && calendar.isDate($0.dueDate, inSameDayAs: today) && $0.priority == .high
        }
        guard !importantTasks.isEmpty else { return }
        
        guard let fireDate = calendar.date(bySettingHour: peakHour, minute: 0, second: 0, of: Date()),
              fireDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Peak Productivity Time"
        content.body = "Now is your most productive hour! You have \(importantTasks.count) important tasks to tackle."
        content.sound = .default
        
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "peak_hour_\(today.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        center.add(request)
    }
    
    /// Schedule all smart notifications for the day
    func scheduleSmartNotifications(tasks: [TodoTask]) {
        scheduleMorningSuggestion(tasks: tasks)
        scheduleOverdueReminder(tasks: tasks)
        schedulePeakHourReminder(tasks: tasks)
    }
}
