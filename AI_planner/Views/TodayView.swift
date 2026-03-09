import SwiftUI

struct TodayView: View {
    @ObservedObject var viewModel: TodoViewModel
    @State private var showAddEventSheet = false
    @State private var showAddTodoSheet = false
    @State private var editingEvent: TodoTask?
    @State private var editingTodo: TodoTask?
    @State private var showSwipeHint: Bool = !UserDefaults.standard.bool(forKey: "hasShownSwipeHint")
    @State private var insights: [InsightCard] = []
    
    // MARK: - Computed Properties
    
    var todayScheduledEvents: [TodoTask] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return viewModel.todos
            .filter { calendar.isDate($0.dueDate, inSameDayAs: today) }
            .filter { $0.startTime != nil && $0.endTime != nil }
            .sorted { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }
    }
    
    var todayTodos: [TodoTask] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return viewModel.todos
            .filter { calendar.isDate($0.dueDate, inSameDayAs: today) }
            .filter { $0.startTime == nil }
            .sorted { !$0.isCompleted && $1.isCompleted }
    }
    
    var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: Date())
    }
    
    var completionPercentage: Int {
        let allTodayTasks = todayScheduledEvents + todayTodos
        let totalCount = allTodayTasks.count
        guard totalCount > 0 else { return 0 }
        let completedCount = allTodayTasks.filter { $0.isCompleted }.count
        return Int(Double(completedCount) / Double(totalCount) * 100)
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    AppTheme.bgSecondary,
                    AppTheme.bgPrimary,
                    AppTheme.bgTertiary.opacity(0.32)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                RadialGradient(
                    colors: [AppTheme.accentGold.opacity(0.10), Color.clear],
                    center: .topTrailing,
                    startRadius: 24,
                    endRadius: 220
                )
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Section
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Today")
                                .font(AppTheme.Typography.labelLarge)
                                .foregroundColor(AppTheme.accentGold)
                                .textCase(.uppercase)

                            Text(currentDateString)
                                .font(AppTheme.Typography.headlineLarge)
                                .foregroundColor(AppTheme.primaryDeepIndigo)
                        }

                        Spacer()

                        Text("\(todayScheduledEvents.count + todayTodos.count) items")
                            .font(AppTheme.Typography.labelMedium)
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(AppTheme.bgElevated.opacity(0.96))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(AppTheme.borderColor.opacity(0.8), lineWidth: 1)
                            )
                    }
                    
                    let greeting = BeaverPersonality.shared.greeting(tasks: viewModel.todos)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(greeting.text)
                            .font(AppTheme.Typography.titleMedium)
                            .foregroundColor(AppTheme.textPrimary)
                        Text(greeting.subtitle)
                            .font(AppTheme.Typography.bodySmall)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    
                    // Progress Bar
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        HStack {
                            Text("Today's Progress")
                                .font(AppTheme.Typography.titleSmall)
                                .foregroundColor(AppTheme.textSecondary)
                            
                            Spacer()
                            
                            Text("\(completionPercentage)%")
                                .font(AppTheme.Typography.labelLarge)
                                .foregroundColor(AppTheme.secondaryTeal)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.4), value: completionPercentage)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                                    .fill(AppTheme.bgTertiary.opacity(0.8))
                                
                                RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [AppTheme.secondaryTeal, AppTheme.accentGold.opacity(0.92)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * CGFloat(completionPercentage) / 100)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: completionPercentage)
                            }
                        }
                        .frame(height: 6)
                    }
                }
                .padding(AppTheme.Spacing.lg)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(AppTheme.bgElevated.opacity(0.96)))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(AppTheme.borderColor.opacity(0.75), lineWidth: 1))
                .shadow(color: AppTheme.Shadows.md.color, radius: AppTheme.Shadows.md.radius, x: AppTheme.Shadows.md.x, y: AppTheme.Shadows.md.y)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.md)
                
                // Insight Cards
                if !insights.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppTheme.Spacing.md) {
                            ForEach(insights) { insight in
                                InsightCardView(insight: insight) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        insights.removeAll { $0.id == insight.id }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.vertical, AppTheme.Spacing.sm)
                    }
                }
                
                List {
                    if showSwipeHint && (!todayScheduledEvents.isEmpty || !todayTodos.isEmpty) {
                        SwipeHintOverlay()
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
                            .onDisappear { showSwipeHint = false }
                    }
                    
                    // Schedule Section
                    Section(header:
                        HStack(spacing: 12) {
                            SectionHeader(title: "Schedule", icon: "clock.fill")
                                .font(.system(size: 24, weight: .bold)) // Larger Title
                            Button { showAddEventSheet = true } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(AppTheme.primaryDeepIndigo.opacity(0.7))
                            }
                        }
                        .padding(.vertical, 8)
                    ) {
                        ForEach(todayScheduledEvents) { task in
                            ScheduleCard(task: task, onDelete: { deleteTask(task) })
                                .contentShape(Rectangle())
                                .onTapGesture { editingEvent = task }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) { deleteTask(task) } label: {
                                        Label("Delete", systemImage: "trash.fill")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button { viewModel.toggleTodoCompletion(task) } label: {
                                        Label(task.isCompleted ? "Undo" : "Complete",
                                              systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark.circle.fill")
                                    }
                                    .tint(AppTheme.secondaryTeal)
                                }
                        }
                    }

                    // To Do Section
                    Section(header:
                        HStack(spacing: 12) {
                            SectionHeader(title: "To Do", icon: "checklist")
                                .font(.system(size: 24, weight: .bold)) // Larger Title
                            Button { showAddTodoSheet = true } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(AppTheme.secondaryTeal.opacity(0.7))
                            }
                        }
                        .padding(.vertical, 8)
                    ) {
                        ForEach(todayTodos) { task in
                            TodoChecklistItem(
                                task: task,
                                onToggle: { viewModel.toggleTodoCompletion(task) },
                                onDelete: { deleteTask(task) },
                                onEdit: { editingTodo = task }
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { deleteTask(task) } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button { viewModel.toggleTodoCompletion(task) } label: {
                                    Label(task.isCompleted ? "Undo" : "Complete",
                                          systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark.circle.fill")
                                }
                                .tint(AppTheme.secondaryTeal)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(.top, AppTheme.Spacing.md)
            }
        }
        .onAppear {
            insights = InsightGenerator.shared.generateInsights(tasks: viewModel.todos)
            UserProfileViewModel.shared.rebuildProfile(tasks: viewModel.todos)
        }
        .sheet(isPresented: $showAddEventSheet) { AddEventSheet(viewModel: viewModel, isPresented: $showAddEventSheet) }
        .sheet(isPresented: $showAddTodoSheet) { AddTodoSheet(viewModel: viewModel) }
        .sheet(item: $editingEvent) { task in
            AddEventSheet(viewModel: viewModel, isPresented: Binding(get: { editingEvent != nil }, set: { if !$0 { editingEvent = nil } }), editingTask: task)
        }
        .sheet(item: $editingTodo) { task in
            AddTodoSheet(viewModel: viewModel, editingTask: task)
        }
    }

    private func deleteTask(_ task: TodoTask) {
        if let index = viewModel.todos.firstIndex(where: { $0.id == task.id }) {
            let deletedTask = viewModel.todos[index]
            viewModel.deleteTodo(at: IndexSet(integer: index))
            ToastManager.shared.show("Task deleted", type: .error) {
                viewModel.addEvent(deletedTask)
            }
        }
    }
}

// MARK: - Insight Card View (Remains same)
struct InsightCardView: View {
    let insight: InsightCard
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Image(systemName: insight.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(insight.color)
                
                Text(insight.title)
                    .font(AppTheme.Typography.titleSmall)
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.textTertiary)
                        .padding(4)
                        .background(AppTheme.bgTertiary)
                        .clipShape(Circle())
                }
            }
            
            Text(insight.description)
                .font(AppTheme.Typography.bodySmall)
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppTheme.Spacing.md)
        .frame(width: 260)
        .background(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous).fill(AppTheme.bgElevated))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.md).stroke(insight.color.opacity(0.2), lineWidth: 1))
        .shadow(color: AppTheme.Shadows.xs.color, radius: AppTheme.Shadows.xs.radius, x: AppTheme.Shadows.xs.x, y: AppTheme.Shadows.xs.y)
    }
}

#Preview {
    TodayView(viewModel: .preview)
}
