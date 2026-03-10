//
//  UserBehaviorStore.swift
//  AI_planner
//
//  Created by AI Assistant on 3/4/26.
//

import Foundation

// MARK: - Behavior Record Models

enum BehaviorType: String, Codable {
    case taskCreated
    case taskCompleted
    case taskDeleted
    case taskPostponed
    case taskUpdated
    case appOpened
    case tabSwitched
}

struct BehaviorRecord: Codable, Identifiable {
    let id: UUID
    let type: BehaviorType
    let timestamp: Date
    let eventType: TodoTask.EventType?
    let priority: TodoTask.TaskPriority?
    let hourOfDay: Int                    // 0-23, the hour when behavior occurred
    let context: BehaviorContext?
    
    init(
        type: BehaviorType,
        timestamp: Date = Date(),
        eventType: TodoTask.EventType? = nil,
        priority: TodoTask.TaskPriority? = nil,
        context: BehaviorContext? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.timestamp = timestamp
        self.eventType = eventType
        self.priority = priority
        self.hourOfDay = Calendar.current.component(.hour, from: timestamp)
        self.context = context
    }
}

struct BehaviorContext: Codable {
    var plannedHour: Int?           // Hour the task was originally scheduled for
    var actualCompletionHour: Int?  // Hour the task was actually completed
    var plannedDurationMinutes: Int? // Planned duration in minutes
    var taskAgeInDays: Int?         // How many days old the task was when acted on
    var fieldsChanged: [String]?    // Which fields were modified (for updates)
    var tabIndex: Int?              // Which tab was switched to
    var startTimeHour: Int?         // Start time hour for the created/updated event
    var endTimeHour: Int?           // End time hour for the created/updated event
}

// MARK: - User Behavior Store

class UserBehaviorStore {
    static let shared = UserBehaviorStore()
    
    private let baseStorageKey = "UserBehaviorRecords"
    private var storageKey: String { ProfileManager.activeScopedKey(baseStorageKey) }
    private let maxRecords = 500 // Keep last 500 records to manage storage
    
    private(set) var records: [BehaviorRecord] = []
    
    private init() {
        loadRecords()
        NotificationCenter.default.addObserver(
            forName: .profileDidSwitch,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadRecords()
        }
    }
    
    // MARK: - Record Behaviors
    
    func recordTaskCreated(task: TodoTask) {
        var context = BehaviorContext()
        if let start = task.startTime {
            context.startTimeHour = Calendar.current.component(.hour, from: start)
        }
        if let end = task.endTime {
            context.endTimeHour = Calendar.current.component(.hour, from: end)
        }
        if let start = task.startTime, let end = task.endTime {
            context.plannedDurationMinutes = Int(end.timeIntervalSince(start) / 60)
        }
        
        let record = BehaviorRecord(
            type: .taskCreated,
            eventType: task.eventType,
            priority: task.priority,
            context: context
        )
        addRecord(record)
    }
    
    func recordTaskCompleted(task: TodoTask) {
        var context = BehaviorContext()
        if let start = task.startTime {
            context.plannedHour = Calendar.current.component(.hour, from: start)
        }
        context.actualCompletionHour = Calendar.current.component(.hour, from: Date())
        
        let daysDiff = Calendar.current.dateComponents([.day], from: task.createdAt, to: Date()).day ?? 0
        context.taskAgeInDays = daysDiff
        
        let record = BehaviorRecord(
            type: .taskCompleted,
            eventType: task.eventType,
            priority: task.priority,
            context: context
        )
        addRecord(record)
    }
    
    func recordTaskDeleted(task: TodoTask) {
        var context = BehaviorContext()
        let daysDiff = Calendar.current.dateComponents([.day], from: task.createdAt, to: Date()).day ?? 0
        context.taskAgeInDays = daysDiff
        
        let record = BehaviorRecord(
            type: .taskDeleted,
            eventType: task.eventType,
            priority: task.priority,
            context: context
        )
        addRecord(record)
    }
    
    func recordTaskUpdated(task: TodoTask, fieldsChanged: [String]) {
        var context = BehaviorContext()
        context.fieldsChanged = fieldsChanged
        if let start = task.startTime {
            context.startTimeHour = Calendar.current.component(.hour, from: start)
        }
        
        let record = BehaviorRecord(
            type: .taskUpdated,
            eventType: task.eventType,
            priority: task.priority,
            context: context
        )
        addRecord(record)
    }
    
    func recordAppOpened() {
        let record = BehaviorRecord(type: .appOpened)
        addRecord(record)
    }
    
    func recordTabSwitched(to tabIndex: Int) {
        var context = BehaviorContext()
        context.tabIndex = tabIndex
        let record = BehaviorRecord(type: .tabSwitched, context: context)
        addRecord(record)
    }
    
    // MARK: - Query Helpers
    
    /// Get records filtered by type, optionally within a date range
    func records(ofType type: BehaviorType, from startDate: Date? = nil, to endDate: Date? = nil) -> [BehaviorRecord] {
        records.filter { record in
            guard record.type == type else { return false }
            if let start = startDate, record.timestamp < start { return false }
            if let end = endDate, record.timestamp > end { return false }
            return true
        }
    }
    
    /// Get records for a specific event type
    func records(forEventType eventType: TodoTask.EventType) -> [BehaviorRecord] {
        records.filter { $0.eventType == eventType }
    }
    
    /// Get the last N days of records
    func recentRecords(days: Int) -> [BehaviorRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return records.filter { $0.timestamp >= cutoff }
    }
    
    // MARK: - Persistence
    
    private func addRecord(_ record: BehaviorRecord) {
        records.append(record)
        
        // Trim to max size
        if records.count > maxRecords {
            records = Array(records.suffix(maxRecords))
        }
        
        saveRecords()
    }
    
    private func saveRecords() {
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadRecords() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([BehaviorRecord].self, from: data) {
            records = decoded
        }
    }
}
