//
//  DailyDetailView.swift
//  AI_planner
//
//  Created by Judy459 on 2/19/26.
//

import SwiftUI

struct DailyDetailView: View {
    var date: Date
    var tasks: [TodoTask]
    @ObservedObject var viewModel: TodoViewModel
    @Binding var isPresented: Bool
    var namespace: Namespace.ID
    
    @State private var showAddEventSheet = false
    @State private var editingTask: TodoTask?
    @State private var taskToDelete: TodoTask?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        ZStack {
            AppTheme.bgPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { isPresented = false }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                        }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.secondaryTeal)
                    }
                    
                    Spacer()
                    
                    // Date Title
                    VStack(alignment: .center, spacing: 0) {
                        Text(date, format: .dateTime.weekday(.wide))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text(date, format: .dateTime.month().day())
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { showAddEventSheet = true }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.secondaryTeal)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.lg)
                
                Divider()
                    .background(AppTheme.dividerColor)
                
                // Time-block list
                ScrollView {
                    if tasks.isEmpty {
                        EmptyStateView(type: .calendar) {
                            showAddEventSheet = true
                        }
                    } else {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                            ForEach(tasks, id: \.id) { task in
                                TimeBlockCard(task: task, viewModel: viewModel, onDelete: {
                                    taskToDelete = task
                                    showDeleteConfirmation = true
                                })
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingTask = task
                                    }
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.vertical, AppTheme.Spacing.lg)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddEventSheet) {
            AddEventSheet(
                viewModel: viewModel,
                isPresented: $showAddEventSheet,
                selectedDate: date
            )
        }
        .sheet(item: $editingTask) { task in
            AddEventSheet(
                viewModel: viewModel,
                isPresented: Binding(
                    get: { editingTask != nil },
                    set: { if !$0 { editingTask = nil } }
                ),
                selectedDate: date,
                editingTask: task
            )
        }
        .confirmationDialog(
            "Delete \"\(taskToDelete?.title ?? "")\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let task = taskToDelete,
                   let index = viewModel.todos.firstIndex(where: { $0.id == task.id }) {
                    let deletedTask = viewModel.todos[index]
                    viewModel.deleteTodo(at: IndexSet(integer: index))
                    ToastManager.shared.show("Task deleted", type: .error) {
                        viewModel.addEvent(deletedTask)
                    }
                }
                taskToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                taskToDelete = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

// MARK: - Time Block Card
struct TimeBlockCard: View {
    var task: TodoTask
    @ObservedObject var viewModel: TodoViewModel
    var onDelete: (() -> Void)?
    
    var body: some View {
        let eventColor = getEventColor(for: task)
        
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(eventColor.dark)
                    
                    if !task.description.isEmpty {
                        Text(task.description)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                
                Spacer()
                
                // Time display
                if let startTime = task.startTime, let endTime = task.endTime {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(CalendarHelper.timeString(from: startTime))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(eventColor.dark)
                        
                        Text("to \(CalendarHelper.timeString(from: endTime))")
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
            
            // Completion toggle
            HStack {
                Button(action: {
                    var updatedTask = task
                    updatedTask.isCompleted.toggle()
                    viewModel.updateTodo(updatedTask)
                }) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(task.isCompleted ? AppTheme.secondaryTeal : AppTheme.textTertiary)
                        
                        Text(task.isCompleted ? "Completed" : "Mark Complete")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(task.isCompleted ? AppTheme.secondaryTeal : AppTheme.textSecondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    onDelete?()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.accentCoral)
                }
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(eventColor.light)
        .cornerRadius(AppTheme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                .stroke(eventColor.primary.opacity(0.3), lineWidth: 1)
        )
    }
    
    func getEventColor(for task: TodoTask) -> EventColor {
        return AppTheme.eventColors.first { $0.name.lowercased() == task.eventType.rawValue.lowercased() } ?? AppTheme.eventColors[4]
    }
}

#Preview {
    DailyDetailView(
        date: Date(),
        tasks: [],
        viewModel: .preview,
        isPresented: .constant(true),
        namespace: Namespace().wrappedValue
    )
}
