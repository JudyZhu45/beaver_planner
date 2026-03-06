//
//  MindfulCalendarView.swift
//  AI_planner
//
//  Created by Judy459 on 2/19/26.
//

import SwiftUI

struct MindfulCalendarView: View {
    @ObservedObject var viewModel: TodoViewModel
    @State private var currentMonth = Date()
    @State private var selectedDate = Date()
    @State private var showDailyDetail = false
    @Namespace private var calendarNamespace
    
    var body: some View {
        ZStack {
            AppTheme.bgPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text("Calendar")
                        .font(AppTheme.Typography.displayMedium)
                        .foregroundColor(AppTheme.primaryDeepIndigo)
                    
                    // Month/Year Selector
                    HStack {
                        Button(action: { previousMonth() }) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.secondaryTeal)
                        }
                        
                        Spacer()
                        
                        Text(CalendarHelper.getMonthYearString(date: currentMonth))
                            .font(AppTheme.Typography.headlineLarge)
                            .foregroundColor(AppTheme.primaryDeepIndigo)
                        
                        Spacer()
                        
                        Button(action: { nextMonth() }) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.secondaryTeal)
                        }
                    }
                }
                .padding(AppTheme.Spacing.lg)
                .background(AppTheme.bgSecondary)
                .shadow(color: AppTheme.shadowColor, radius: 4, x: 0, y: 2)
                
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.xxl) {
                        // Calendar Grid
                        CalendarGridView(
                            currentMonth: $currentMonth,
                            selectedDate: $selectedDate,
                            tasks: viewModel.todos,
                            namespace: calendarNamespace,
                            showDailyDetail: $showDailyDetail
                        )
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        
                        // Selected Day Preview
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                            SectionHeader(title: "Day Preview", icon: "calendar.circle.fill")
                                .padding(.horizontal, AppTheme.Spacing.lg)
                            
                            SelectedDayPreviewView(
                                date: selectedDate,
                                tasks: CalendarHelper.getTasksForDay(viewModel.todos, date: selectedDate),
                                namespace: calendarNamespace,
                                showDailyDetail: $showDailyDetail
                            )
                            .padding(.horizontal, AppTheme.Spacing.lg)
                        }
                        
                        Spacer()
                            .frame(height: AppTheme.Spacing.lg)
                    }
                    .padding(.top, AppTheme.Spacing.lg)
                }
            }
        }
        .sheet(isPresented: $showDailyDetail) {
            DailyDetailView(
                date: selectedDate,
                tasks: CalendarHelper.getTasksForDay(viewModel.todos, date: selectedDate),
                viewModel: viewModel,
                isPresented: $showDailyDetail,
                namespace: calendarNamespace
            )
        }
    }
    
    func previousMonth() {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    func nextMonth() {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
        }
    }
}

// MARK: - Calendar Grid View
struct CalendarGridView: View {
    @Binding var currentMonth: Date
    @Binding var selectedDate: Date
    var tasks: [TodoTask]
    var namespace: Namespace.ID
    @Binding var showDailyDetail: Bool
    
    let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Day Labels
            HStack(spacing: 0) {
                ForEach(dayLabels, id: \.self) { day in
                    VStack {
                        Text(day)
                            .font(AppTheme.Typography.labelMedium)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                }
            }
            
            // Calendar Days
            let daysInMonth = CalendarHelper.getDaysInMonth(date: currentMonth)
            let firstDay = CalendarHelper.getFirstDayOfMonth(date: currentMonth)
            let dayRange = 1...daysInMonth
            
            let columns = Array(repeating: GridItem(.flexible()), count: 7)
            
            LazyVGrid(columns: columns, spacing: AppTheme.Spacing.md) {
                // Empty cells for days before month starts
                ForEach(0..<firstDay, id: \.self) { _ in
                    Color.clear
                        .frame(height: 60)
                }
                
                // Days of month
                ForEach(dayRange, id: \.self) { day in
                    let date = CalendarHelper.getDateFromDay(day, in: currentMonth)
                    let isSelected = CalendarHelper.isSameDay(date, selectedDate)
                    let isToday = CalendarHelper.isSameDay(date, Date())
                    let dayTasks = CalendarHelper.getTasksForDay(tasks, date: date)
                    
                    ZStack {
                        // Selected background
                        if isSelected {
                            RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                                .fill(AppTheme.secondaryTeal.opacity(0.15))
                                .matchedGeometryEffect(id: "selectedCircle", in: namespace)
                        } else if isToday {
                            RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                                .stroke(AppTheme.secondaryTeal, lineWidth: 2)
                        }
                        
                        VStack(spacing: 4) {
                            Text("\(day)")
                                .font(AppTheme.Typography.headlineSmall)
                                .foregroundColor(isSelected ? AppTheme.secondaryTeal : AppTheme.textPrimary)
                            
                            // Task indicators
                            if !dayTasks.isEmpty {
                                HStack(spacing: 2) {
                                    ForEach(0..<min(3, dayTasks.count), id: \.self) { index in
                                        Circle()
                                            .fill(getEventColor(for: dayTasks[index]).primary)
                                            .frame(width: 4, height: 4)
                                    }
                                    
                                    if dayTasks.count > 3 {
                                        Text("+\(dayTasks.count - 3)")
                                            .font(AppTheme.Typography.labelSmall)
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: 60)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDate = date
                        }
                    }
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                .stroke(AppTheme.borderColor, lineWidth: 1)
        )
    }
    
    func getEventColor(for task: TodoTask) -> EventColor {
        return AppTheme.eventColors.first { $0.name.lowercased() == task.eventType.rawValue.lowercased() } ?? AppTheme.eventColors[5]
    }
}

// MARK: - Selected Day Preview
struct SelectedDayPreviewView: View {
    var date: Date
    var tasks: [TodoTask]
    var namespace: Namespace.ID
    @Binding var showDailyDetail: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date, format: .dateTime.weekday(.wide))
                        .font(AppTheme.Typography.headlineSmall)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text(date, format: .dateTime.month().day().year())
                        .font(AppTheme.Typography.bodySmall)
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                Spacer()
                
                Button(action: { showDailyDetail = true }) {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(AppTheme.Typography.labelMedium)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.secondaryTeal)
                }
            }
            
            if tasks.isEmpty {
                EmptyStateView(type: .calendar) { }
                .background(AppTheme.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
            } else {
                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(tasks, id: \.id) { task in
                        let color = getEventColor(for: task)
                        
                        HStack(spacing: AppTheme.Spacing.md) {
                            Image(systemName: color.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(color.primary)
                                .frame(width: 28, height: 28)
                                .background(color.light)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(AppTheme.Typography.bodyMedium)
                                    .foregroundColor(AppTheme.textPrimary)
                                
                                if let startTime = task.startTime {
                                    Text(CalendarHelper.timeString(from: startTime))
                                        .font(AppTheme.Typography.labelSmall)
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(AppTheme.Spacing.md)
                        .background(color.light)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    }
                }
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                .stroke(AppTheme.borderColor, lineWidth: 1)
        )
    }
    
    func getEventColor(for task: TodoTask) -> EventColor {
        return AppTheme.eventColors.first { $0.name.lowercased() == task.eventType.rawValue.lowercased() } ?? AppTheme.eventColors[5]
    }
}

#Preview {
    MindfulCalendarView(viewModel: .preview)
}
