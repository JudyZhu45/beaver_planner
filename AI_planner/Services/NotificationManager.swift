//
//  NotificationManager.swift
//  AI_planner
//
//  Created by Judy459 on 2/24/26.
//

import Foundation
import UserNotifications

// MARK: - Notification Settings Model

struct NotificationSettings: Codable {
    /// Master switch
    var isEnabled: Bool = true
    /// Remind X minutes before a task starts (nil = disabled)
    var minutesBefore: Int? = 15
    /// Fire a notification exactly when a task starts
    var notifyOnStart: Bool = false
    /// Fire a notification when a task's end time arrives
    var notifyOnFinish: Bool = false

    private static let storageKey = "NotificationSettingsV1"

    static func load() -> NotificationSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let s = try? JSONDecoder().decode(NotificationSettings.self, from: data)
        else { return NotificationSettings() }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: NotificationSettings.storageKey)
        }
    }
}

// MARK: - Notification Manager

class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    /// Live settings — mutate then call settings.save() to persist
    var settings: NotificationSettings = .load()

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

    /// Schedule all enabled notification types for a single task.
    func scheduleNotification(for task: TodoTask) {
        guard !task.isCompleted, settings.isEnabled else { return }
        cancelNotification(for: task)

        let calendar = Calendar.current

        // ── Before start ─────────────────────────────────────────────
        if let mins = settings.minutesBefore {
            let content = UNMutableNotificationContent()
            content.title = task.title
            content.sound = .default

            if let startTime = task.startTime {
                content.body = task.description.isEmpty
                    ? "Starting in \(mins) minute\(mins == 1 ? "" : "s")"
                    : "\(task.description) — Starting in \(mins) minute\(mins == 1 ? "" : "s")"
                if let fireDate = calendar.date(byAdding: .minute, value: -mins, to: startTime),
                   fireDate > Date() {
                    scheduleRequest(id: "\(task.id.uuidString)_before", content: content,
                                    fireDate: fireDate, calendar: calendar)
                }
            } else {
                // Todo without start time: morning reminder at 8 AM
                content.body = task.description.isEmpty ? "Due today" : "\(task.description) — Due today"
                if let fireDate = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: task.dueDate),
                   fireDate > Date() {
                    scheduleRequest(id: "\(task.id.uuidString)_before", content: content,
                                    fireDate: fireDate, calendar: calendar)
                }
            }
        }

        // ── On start ─────────────────────────────────────────────────
        if settings.notifyOnStart, let startTime = task.startTime, startTime > Date() {
            let content = UNMutableNotificationContent()
            content.title = "Starting now: \(task.title)"
            content.body = task.description.isEmpty ? "Time to begin!" : task.description
            content.sound = .default
            scheduleRequest(id: "\(task.id.uuidString)_start", content: content,
                            fireDate: startTime, calendar: calendar)
        }

        // ── On finish ────────────────────────────────────────────────
        if settings.notifyOnFinish, let endTime = task.endTime, endTime > Date() {
            let content = UNMutableNotificationContent()
            content.title = "Time's up: \(task.title)"
            content.body = "Did you finish? Mark it complete if you're done!"
            content.sound = .default
            scheduleRequest(id: "\(task.id.uuidString)_finish", content: content,
                            fireDate: endTime, calendar: calendar)
        }
    }

    private func scheduleRequest(id: String, content: UNMutableNotificationContent,
                                 fireDate: Date, calendar: Calendar) {
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request) { error in
            if let error { print("Failed to schedule '\(id)': \(error)") }
        }
    }

    /// Cancel all notifications (before/start/finish) for a specific task
    func cancelNotification(for task: TodoTask) {
        center.removePendingNotificationRequests(withIdentifiers: [
            task.id.uuidString,
            "\(task.id.uuidString)_before",
            "\(task.id.uuidString)_start",
            "\(task.id.uuidString)_finish"
        ])
    }

    /// Cancel all scheduled notifications
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    /// Reschedule notifications for all active tasks using current settings
    func rescheduleAll(tasks: [TodoTask]) {
        cancelAllNotifications()
        guard settings.isEnabled else { return }
        for task in tasks where !task.isCompleted {
            scheduleNotification(for: task)
        }
    }

    // MARK: - Smart Suggestion Notifications

    private let dailySuggestionKey = "LastDailySuggestionDate"

    func scheduleMorningSuggestion(tasks: [TodoTask]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let lastDate = UserDefaults.standard.object(forKey: dailySuggestionKey) as? Date,
           calendar.isDate(lastDate, inSameDayAs: today) { return }

        let todayTasks = tasks.filter {
            !$0.isCompleted && calendar.isDate($0.dueDate, inSameDayAs: today)
        }
        guard !todayTasks.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = "Today's Plan"
        content.body = "You have \(todayTasks.count) tasks today. Start with the most important one!"
        content.sound = .default

        let profile = UserProfileViewModel.shared.profile
        let fireHour = max(6, profile.avgAppOpenHour ?? 8)

        guard let fireDate = calendar.date(bySettingHour: fireHour, minute: 0, second: 0, of: today),
              fireDate > Date() else {
            UserDefaults.standard.set(today, forKey: dailySuggestionKey)
            return
        }
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: "morning_suggestion_\(today.timeIntervalSince1970)",
            content: content, trigger: trigger)
        center.add(request) { [weak self] error in
            if error == nil { UserDefaults.standard.set(today, forKey: self?.dailySuggestionKey ?? "") }
        }
    }

    func scheduleOverdueReminder(tasks: [TodoTask]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let overdue = tasks.filter { !$0.isCompleted && $0.dueDate < today }
        guard overdue.count >= 2 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Tasks Need Attention"
        content.body = "You have \(overdue.count) overdue tasks. Would you like to reschedule them?"
        content.sound = .default

        guard let fireDate = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: Date()),
              fireDate > Date() else { return }
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(
            identifier: "overdue_reminder_\(today.timeIntervalSince1970)",
            content: content, trigger: trigger))
    }

    func schedulePeakHourReminder(tasks: [TodoTask]) {
        let profile = UserProfileViewModel.shared.profile
        guard !profile.peakProductivityHours.isEmpty else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let important = tasks.filter {
            !$0.isCompleted && calendar.isDate($0.dueDate, inSameDayAs: today) && $0.priority == .high
        }
        guard !important.isEmpty else { return }

        guard let fireDate = calendar.date(bySettingHour: profile.peakProductivityHours[0],
                                           minute: 0, second: 0, of: Date()),
              fireDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Peak Productivity Time"
        content.body = "Now is your most productive hour! You have \(important.count) important tasks."
        content.sound = .default
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(
            identifier: "peak_hour_\(today.timeIntervalSince1970)",
            content: content, trigger: trigger))
    }

    func scheduleSmartNotifications(tasks: [TodoTask]) {
        scheduleMorningSuggestion(tasks: tasks)
        scheduleOverdueReminder(tasks: tasks)
        schedulePeakHourReminder(tasks: tasks)
    }
}
