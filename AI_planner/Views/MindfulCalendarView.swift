import SwiftUI

struct MindfulCalendarView: View {
    @ObservedObject var viewModel: TodoViewModel
    @State private var currentMonth = Date()
    @State private var selectedDate = Date()
    @State private var showDailyDetail = false
    @State private var showAddEventSheet = false
    @State private var isMonthlyExpanded = false
    @Namespace private var calendarNamespace
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.bgSecondary,
                    AppTheme.bgPrimary,
                    AppTheme.bgTertiary.opacity(0.30)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                RadialGradient(
                    colors: [
                        AppTheme.accentGold.opacity(0.10),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 30,
                    endRadius: 260
                )
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Calendar")
                                .font(AppTheme.Typography.displayMedium)
                                .foregroundColor(AppTheme.primaryDeepIndigo)

                            Text(isMonthlyExpanded ? "See your rhythm, spot busy days." : "Your week at a glance.")
                                .font(AppTheme.Typography.bodySmall)
                                .foregroundColor(AppTheme.textSecondary)
                                .contentTransition(.opacity)
                        }

                        Spacer()

                        Text("\(CalendarHelper.getTasksForDay(viewModel.todos, date: selectedDate).count) plans")
                            .font(AppTheme.Typography.labelMedium)
                            .foregroundColor(AppTheme.primaryDeepIndigo)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(AppTheme.bgElevated)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(AppTheme.borderColor.opacity(0.8), lineWidth: 1)
                            )
                    }
                    
                    // Time Selector (Month/Year & Expand Toggle)
                    HStack {
                        Button(action: { previousTimePeriod() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.primaryDeepIndigo)
                                .frame(width: 38, height: 38)
                                .background(AppTheme.bgElevated)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(AppTheme.borderColor.opacity(0.8), lineWidth: 1))
                        }
                        
                        Spacer()
                        
                        // Tappable Header to Expand/Collapse the Grid vs Weekly Chart
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isMonthlyExpanded.toggle()
                                if isMonthlyExpanded { currentMonth = selectedDate }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Text(CalendarHelper.getMonthYearString(date: isMonthlyExpanded ? currentMonth : selectedDate))
                                    .font(AppTheme.Typography.headlineLarge)
                                    .foregroundColor(AppTheme.primaryDeepIndigo)
                                
                                Image(systemName: isMonthlyExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(AppTheme.accentGold)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: { nextTimePeriod() }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.primaryDeepIndigo)
                                .frame(width: 38, height: 38)
                                .background(AppTheme.bgElevated)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(AppTheme.borderColor.opacity(0.8), lineWidth: 1))
                        }
                    }
                }
                .padding(AppTheme.Spacing.lg)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(AppTheme.bgElevated.opacity(0.96)))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(AppTheme.borderColor.opacity(0.78), lineWidth: 1))
                .shadow(color: AppTheme.Shadows.md.color, radius: AppTheme.Shadows.md.radius, x: AppTheme.Shadows.md.x, y: AppTheme.Shadows.md.y)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.md)
                .zIndex(1)
                
                // Content Area
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppTheme.Spacing.xxl) {
                        if isMonthlyExpanded {
                            CalendarGridView(
                                currentMonth: $currentMonth,
                                selectedDate: $selectedDate,
                                showDailyDetail: $showDailyDetail,
                                tasks: viewModel.todos,
                                namespace: calendarNamespace
                            )
                            .padding(.horizontal, AppTheme.Spacing.lg)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.95)), removal: .opacity.combined(with: .scale(scale: 0.95))))
                        } else {
                            VerticalWeeklyChartView(
                                selectedDate: $selectedDate,
                                showDailyDetail: $showDailyDetail,
                                tasks: viewModel.todos,
                                namespace: calendarNamespace
                            )
                            .padding(.horizontal, AppTheme.Spacing.lg)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 1.05)), removal: .opacity.combined(with: .scale(scale: 1.05))))
                        }
                        
                        Spacer().frame(height: AppTheme.Spacing.lg)
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
        .sheet(isPresented: $showAddEventSheet) {
            AddEventSheet(viewModel: viewModel, isPresented: $showAddEventSheet, selectedDate: selectedDate)
        }
    }
    
    // MARK: - Navigation Logic
    func previousTimePeriod() {
        let calendar = Calendar.current
        withAnimation(.easeInOut) {
            if isMonthlyExpanded {
                if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
                    currentMonth = newMonth
                }
            } else {
                if let newWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) {
                    selectedDate = newWeek
                    currentMonth = selectedDate
                }
            }
        }
    }
    
    func nextTimePeriod() {
        let calendar = Calendar.current
        withAnimation(.easeInOut) {
            if isMonthlyExpanded {
                if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
                    currentMonth = newMonth
                }
            } else {
                if let newWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) {
                    selectedDate = newWeek
                    currentMonth = selectedDate
                }
            }
        }
    }
}

// MARK: - Vertical Weekly Chart View
struct VerticalWeeklyChartView: View {
    @Binding var selectedDate: Date
    @Binding var showDailyDetail: Bool
    var tasks: [TodoTask]
    var namespace: Namespace.ID
    
    var currentWeek: [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(currentWeek.enumerated()), id: \.element) { index, date in
                let isSelected = CalendarHelper.isSameDay(date, selectedDate)
                let isToday = CalendarHelper.isSameDay(date, Date())
                let dayTasks = CalendarHelper.getTasksForDay(tasks, date: date)
                
                // Determine Weekday vs Weekend colors
                let weekday = Calendar.current.component(.weekday, from: date)
                let isWeekend = (weekday == 1 || weekday == 7) // 1 = Sun, 7 = Sat
                
                // Formal for weekdays, Exciting for weekends
                let baseColor = isWeekend ? AppTheme.accentGold : AppTheme.primaryDeepIndigo
                let baseOpacity = isWeekend ? 0.20 : 0.08
                let blockColor = baseColor.opacity(isSelected ? baseOpacity + 0.15 : baseOpacity)
                
                HStack(spacing: 0) {
                    // Left Column: Colored Block
                    VStack(spacing: 2) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(AppTheme.Typography.labelMedium)
                            .foregroundColor(isToday ? AppTheme.accentGold : AppTheme.textSecondary)
                        
                        Text(date.formatted(.dateTime.day()))
                            .font(AppTheme.Typography.titleMedium)
                            .foregroundColor(isToday ? AppTheme.accentGold : AppTheme.primaryDeepIndigo)
                    }
                    .frame(width: 70)
                    .frame(maxHeight: .infinity)
                    .background(blockColor)
                    
                    // Vertical Separator Line
                    Rectangle()
                        .fill(AppTheme.borderColor.opacity(0.8))
                        .frame(width: 1)
                    
                    // Right Column: Lined Space / Tasks
                    VStack(alignment: .leading, spacing: 8) {
                        if dayTasks.isEmpty {
                            Spacer()
                        } else {
                            ForEach(dayTasks.prefix(4)) { task in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(getEventColor(for: task).primary)
                                        .frame(width: 6, height: 6)
                                    Text(task.title)
                                        .font(AppTheme.Typography.bodySmall)
                                        .foregroundColor(AppTheme.textPrimary)
                                        .lineLimit(1)
                                }
                            }
                            if dayTasks.count > 4 {
                                Text("+\(dayTasks.count - 4) more")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(AppTheme.textTertiary)
                                    .padding(.leading, 14)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(isSelected ? AppTheme.bgTertiary.opacity(0.3) : Color.clear)
                }
                .frame(minHeight: 80) // Taller rows to fill up the newly available screen space
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDate = date
                        showDailyDetail = true // Open detail immediately
                    }
                }
                
                // Horizontal Divider Line between days
                if index < 6 {
                    Divider()
                        .background(AppTheme.borderColor.opacity(0.8))
                }
            }
        }
        .background(AppTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.lg).stroke(AppTheme.borderColor.opacity(0.9), lineWidth: 1))
        .shadow(color: AppTheme.Shadows.sm.color, radius: AppTheme.Shadows.sm.radius, x: AppTheme.Shadows.sm.x, y: AppTheme.Shadows.sm.y)
    }
    
    func getEventColor(for task: TodoTask) -> EventColor {
        return AppTheme.eventColors.first { $0.name.lowercased() == task.eventType.rawValue.lowercased() } ?? AppTheme.eventColors[5]
    }
}

// MARK: - Monthly Calendar Grid View
struct CalendarGridView: View {
    @Binding var currentMonth: Date
    @Binding var selectedDate: Date
    @Binding var showDailyDetail: Bool
    var tasks: [TodoTask]
    var namespace: Namespace.ID
    
    let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Day Labels
            HStack(spacing: 0) {
                ForEach(dayLabels, id: \.self) { day in
                    Text(day)
                        .font(AppTheme.Typography.labelMedium)
                        .foregroundColor(AppTheme.textSecondary)
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity)
                }
            }
            
            let daysInMonth = CalendarHelper.getDaysInMonth(date: currentMonth)
            let firstDayOffset = CalendarHelper.getFirstDayOfMonth(date: currentMonth)
            let columns = Array(repeating: GridItem(.flexible()), count: 7)
            
            LazyVGrid(columns: columns, spacing: AppTheme.Spacing.md) {
                if firstDayOffset > 0 {
                    ForEach(-firstDayOffset..<0, id: \.self) { _ in
                        Color.clear.frame(height: 60)
                    }
                }
                
                ForEach(1...daysInMonth, id: \.self) { day in
                    let date = CalendarHelper.getDateFromDay(day, in: currentMonth)
                    let isSelected = CalendarHelper.isSameDay(date, selectedDate)
                    let isToday = CalendarHelper.isSameDay(date, Date())
                    let dayTasks = CalendarHelper.getTasksForDay(tasks, date: date)
                    
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                                .fill(LinearGradient(colors: [AppTheme.accentGold.opacity(0.18), AppTheme.secondaryTeal.opacity(0.14)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        } else if isToday {
                            RoundedRectangle(cornerRadius: AppTheme.Radius.md).stroke(AppTheme.accentGold, lineWidth: 1.5)
                        } else {
                            RoundedRectangle(cornerRadius: AppTheme.Radius.md).fill(AppTheme.bgElevated.opacity(0.55))
                        }
                        
                        VStack(spacing: 4) {
                            Text("\(day)")
                                .font(AppTheme.Typography.headlineSmall)
                                .foregroundColor(isSelected ? AppTheme.primaryDeepIndigo : AppTheme.textPrimary)
                            
                            if !dayTasks.isEmpty {
                                HStack(spacing: 2) {
                                    ForEach(0..<min(3, dayTasks.count), id: \.self) { index in
                                        Circle()
                                            .fill(getEventColor(for: dayTasks[index]).primary)
                                            .frame(width: 4, height: 4)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: 60)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDate = date
                            showDailyDetail = true // Open detail immediately
                        }
                    }
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.lg).stroke(AppTheme.borderColor.opacity(0.9), lineWidth: 1))
        .shadow(color: AppTheme.Shadows.sm.color, radius: AppTheme.Shadows.sm.radius, x: AppTheme.Shadows.sm.x, y: AppTheme.Shadows.sm.y)
    }
    
    func getEventColor(for task: TodoTask) -> EventColor {
        return AppTheme.eventColors.first { $0.name.lowercased() == task.eventType.rawValue.lowercased() } ?? AppTheme.eventColors[5]
    }
}

#Preview {
    MindfulCalendarView(viewModel: .preview)
}
