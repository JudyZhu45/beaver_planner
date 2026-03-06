//
//  TodoViewModel.swift
//  AI_planner
//
//  Created by Judy459 on 2/19/26.
//

import Foundation
import Combine
import SwiftUI

class TodoViewModel: ObservableObject {
    @Published var todos: [TodoTask] = []
    @Published var showAddTodoSheet = false
    
    private let todosKey = "SavedTodos"
    private let calendarSync = CalendarSyncService.shared
    private let behaviorStore = UserBehaviorStore.shared
    
    init() {
        loadTodos()
    }
    
    // MARK: - CRUD Operations
    
    func addTodo(title: String, description: String, dueDate: Date, priority: TodoTask.TaskPriority) {
        var newTodo = TodoTask(
            title: title,
            description: description,
            isCompleted: false,
            dueDate: dueDate,
            priority: priority,
            createdAt: Date()
        )
        if let eventId = calendarSync.saveToCalendar(newTodo) {
            newTodo.calendarEventId = eventId
        }
        todos.append(newTodo)
        saveTodos()
        NotificationManager.shared.scheduleNotification(for: newTodo)
        behaviorStore.recordTaskCreated(task: newTodo)
    }
    
    func updateTodo(_ todo: TodoTask) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            let oldTask = todos[index]
            var updatedTodo = todo
            // Track completion timestamp changes
            let wasCompleted = oldTask.isCompleted
            if updatedTodo.isCompleted && !wasCompleted {
                updatedTodo.completedAt = Date()
            } else if !updatedTodo.isCompleted && wasCompleted {
                updatedTodo.completedAt = nil
            }
            if let eventId = calendarSync.saveToCalendar(updatedTodo) {
                updatedTodo.calendarEventId = eventId
            }
            
            // Track which fields changed
            var fieldsChanged: [String] = []
            if oldTask.title != updatedTodo.title { fieldsChanged.append("title") }
            if oldTask.startTime != updatedTodo.startTime { fieldsChanged.append("startTime") }
            if oldTask.endTime != updatedTodo.endTime { fieldsChanged.append("endTime") }
            if oldTask.dueDate != updatedTodo.dueDate { fieldsChanged.append("dueDate") }
            if oldTask.priority != updatedTodo.priority { fieldsChanged.append("priority") }
            if oldTask.eventType != updatedTodo.eventType { fieldsChanged.append("eventType") }
            if !fieldsChanged.isEmpty {
                behaviorStore.recordTaskUpdated(task: updatedTodo, fieldsChanged: fieldsChanged)
            }
            
            todos[index] = updatedTodo
            saveTodos()
            if updatedTodo.isCompleted {
                NotificationManager.shared.cancelNotification(for: updatedTodo)
            } else {
                NotificationManager.shared.scheduleNotification(for: updatedTodo)
            }
        }
    }
    
    func deleteTodo(at indexSet: IndexSet) {
        for index in indexSet {
            behaviorStore.recordTaskDeleted(task: todos[index])
            calendarSync.removeFromCalendar(todos[index])
            NotificationManager.shared.cancelNotification(for: todos[index])
        }
        todos.remove(atOffsets: indexSet)
        saveTodos()
    }
    
    func toggleTodoCompletion(_ todo: TodoTask) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index].isCompleted.toggle()
            todos[index].completedAt = todos[index].isCompleted ? Date() : nil
            saveTodos()
            if todos[index].isCompleted {
                behaviorStore.recordTaskCompleted(task: todos[index])
                NotificationManager.shared.cancelNotification(for: todos[index])
                ToastManager.shared.show("Task completed", type: .success)
            } else {
                NotificationManager.shared.scheduleNotification(for: todos[index])
                ToastManager.shared.show("Task uncompleted", type: .info)
            }
        }
    }
    
    /// Add a fully-formed TodoTask (used by AI chat service)
    func addEvent(_ task: TodoTask) {
        var newTask = task
        newTask.id = UUID()
        newTask.createdAt = Date()
        if let eventId = calendarSync.saveToCalendar(newTask) {
            newTask.calendarEventId = eventId
        }
        todos.append(newTask)
        saveTodos()
        NotificationManager.shared.scheduleNotification(for: newTask)
        behaviorStore.recordTaskCreated(task: newTask)
    }
    
    /// Delete a task by its UUID (used by AI chat service)
    func deleteTodoById(_ id: UUID) {
        if let index = todos.firstIndex(where: { $0.id == id }) {
            behaviorStore.recordTaskDeleted(task: todos[index])
            calendarSync.removeFromCalendar(todos[index])
            NotificationManager.shared.cancelNotification(for: todos[index])
            todos.remove(at: index)
            saveTodos()
        }
    }
    
    // MARK: - Calendar Sync
    
    /// Sync all existing tasks to the iOS Calendar
    func syncAllTasksToCalendar() {
        todos = calendarSync.syncAllToCalendar(todos)
        saveTodos()
    }
    
    /// Remove all app events from iOS Calendar
    func removeAllTasksFromCalendar() {
        calendarSync.removeAllFromCalendar(todos)
        for i in todos.indices {
            todos[i].calendarEventId = nil
        }
        saveTodos()
    }
    
    // MARK: - Data Management
    
    private func saveTodos() {
        if let encoded = try? JSONEncoder().encode(todos) {
            UserDefaults.standard.set(encoded, forKey: todosKey)
        }
    }
    
    private func loadTodos() {
        if let data = UserDefaults.standard.data(forKey: todosKey),
           let decoded = try? JSONDecoder().decode([TodoTask].self, from: data) {
            todos = decoded
        }
    }
    
    // MARK: - Preview Support
    
    static var preview: TodoViewModel {
        let vm = TodoViewModel()
        let today = Date()
        let calendar = Calendar.current
        
        vm.todos = [
            TodoTask(
                title: "Gym",
                description: "Morning workout session",
                isCompleted: false,
                dueDate: today,
                startTime: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today),
                endTime: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today),
                priority: .medium,
                createdAt: today,
                eventType: .gym
            ),
            TodoTask(
                title: "Class",
                description: "Swift UI Advanced Techniques",
                isCompleted: false,
                dueDate: today,
                startTime: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today),
                endTime: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today),
                priority: .high,
                createdAt: today,
                eventType: .class_
            ),
            TodoTask(
                title: "Study Session",
                description: "Review new concepts from class",
                isCompleted: false,
                dueDate: today,
                startTime: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today),
                endTime: calendar.date(bySettingHour: 16, minute: 0, second: 0, of: today),
                priority: .medium,
                createdAt: today,
                eventType: .study
            ),
            TodoTask(
                title: "Meeting",
                description: "Team standup meeting",
                isCompleted: false,
                dueDate: today,
                startTime: calendar.date(bySettingHour: 17, minute: 0, second: 0, of: today),
                endTime: calendar.date(bySettingHour: 17, minute: 30, second: 0, of: today),
                priority: .high,
                createdAt: today,
                eventType: .meeting
            ),
            TodoTask(
                title: "Gym",
                description: "Evening cardio workout",
                isCompleted: false,
                dueDate: calendar.date(byAdding: .day, value: 1, to: today) ?? today,
                startTime: calendar.date(bySettingHour: 18, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 1, to: today) ?? today),
                endTime: calendar.date(bySettingHour: 19, minute: 30, second: 0, of: calendar.date(byAdding: .day, value: 1, to: today) ?? today),
                priority: .medium,
                createdAt: today,
                eventType: .gym
            ),
            TodoTask(
                title: "Dinner",
                description: "Dinner with friends at the new Italian restaurant",
                isCompleted: false,
                dueDate: calendar.date(byAdding: .day, value: 1, to: today) ?? today,
                startTime: calendar.date(bySettingHour: 19, minute: 30, second: 0, of: calendar.date(byAdding: .day, value: 1, to: today) ?? today),
                endTime: calendar.date(bySettingHour: 21, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 1, to: today) ?? today),
                priority: .medium,
                createdAt: today,
                eventType: .dinner
            ),
            TodoTask(
                title: "Class",
                description: "Data Structures and Algorithms",
                isCompleted: false,
                dueDate: calendar.date(byAdding: .day, value: 2, to: today) ?? today,
                startTime: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 2, to: today) ?? today),
                endTime: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 2, to: today) ?? today),
                priority: .high,
                createdAt: today,
                eventType: .class_
            ),
            TodoTask(
                title: "Study Session",
                description: "Practice algorithm problems",
                isCompleted: false,
                dueDate: calendar.date(byAdding: .day, value: 2, to: today) ?? today,
                startTime: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 2, to: today) ?? today),
                endTime: calendar.date(bySettingHour: 17, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 2, to: today) ?? today),
                priority: .high,
                createdAt: today,
                eventType: .study
            ),
            TodoTask(
                title: "Meeting",
                description: "Project planning session",
                isCompleted: false,
                dueDate: calendar.date(byAdding: .day, value: 3, to: today) ?? today,
                startTime: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 3, to: today) ?? today),
                endTime: calendar.date(bySettingHour: 11, minute: 30, second: 0, of: calendar.date(byAdding: .day, value: 3, to: today) ?? today),
                priority: .high,
                createdAt: today,
                eventType: .meeting
            ),
        ]
        return vm
    }
    
    // MARK: - Helper Methods
    
    func getActiveTodosCount() -> Int {
        todos.filter { !$0.isCompleted }.count
    }
    
    func getCompletedTodosCount() -> Int {
        todos.filter { $0.isCompleted }.count
    }
    
    func sortedTodos(by filter: TodoFilter) -> [TodoTask] {
        switch filter {
        case .all:
            return todos.sorted { $0.dueDate < $1.dueDate }
        case .active:
            return todos.filter { !$0.isCompleted }.sorted { $0.dueDate < $1.dueDate }
        case .completed:
            return todos.filter { $0.isCompleted }.sorted { $0.dueDate < $1.dueDate }
        }
    }
}

enum TodoFilter {
    case all
    case active
    case completed
}
