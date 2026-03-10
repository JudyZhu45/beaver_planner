//
//  ProfileView.swift
//  AI_planner
//
//  Created by Judy459 on 2/19/26.
//

import SwiftUI
import UserNotifications

struct ProfileView: View {
    var authManager: AuthManager
    @ObservedObject var viewModel: TodoViewModel
    @ObservedObject private var calendarSync = CalendarSyncService.shared
    @State private var notificationsEnabled = false
    @StateObject private var achievementSystem = AchievementSystem.shared
    @State private var showWeeklyReview = false
    
    // MARK: - Computed Stats
    
    private var totalHoursPlanned: Double {
        viewModel.todos.reduce(0.0) { total, task in
            guard let start = task.startTime, let end = task.endTime else { return total }
            return total + end.timeIntervalSince(start) / 3600.0
        }
    }
    
    private var completedTasksCount: Int {
        viewModel.todos.filter { $0.isCompleted }.count
    }
    
    private var completionRate: Double {
        guard !viewModel.todos.isEmpty else { return 0 }
        return Double(completedTasksCount) / Double(viewModel.todos.count)
    }
    
    private var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var daysWithCompletions = Set<Date>()
        for task in viewModel.todos where task.isCompleted {
            daysWithCompletions.insert(calendar.startOfDay(for: task.dueDate))
        }
        
        guard !daysWithCompletions.isEmpty else { return 0 }
        
        var checkDate = today
        if !daysWithCompletions.contains(checkDate) {
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            if !daysWithCompletions.contains(checkDate) {
                return 0
            }
        }
        
        var streak = 0
        while daysWithCompletions.contains(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }
        return streak
    }
    
    private var formattedHours: String {
        if totalHoursPlanned == 0 { return "0" }
        let rounded = (totalHoursPlanned * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", rounded)
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }
    
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
                    startRadius: 26,
                    endRadius: 260
                )
            )
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Profile")
                            .font(AppTheme.Typography.displayMedium)
                            .foregroundColor(AppTheme.primaryDeepIndigo)

                        Text("Your habits, achievements, and planning rhythm at a glance.")
                            .font(AppTheme.Typography.bodySmall)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding(AppTheme.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AppTheme.bgElevated.opacity(0.96))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(AppTheme.borderColor.opacity(0.8), lineWidth: 1)
                )
                .shadow(color: AppTheme.Shadows.md.color, radius: AppTheme.Shadows.md.radius, x: AppTheme.Shadows.md.x, y: AppTheme.Shadows.md.y)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.md)
                
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        // Profile Card
                        profileCard
                        
                        // Statistics
                        statisticsSection
                        
                        // Habit Heatmap
                        HabitHeatmapView(tasks: viewModel.todos)
                        
                        // Beaver Commentary
                        beaverCommentarySection
                        
                        // Achievements
                        achievementsSection
                        
                        // Energy Curve
                        energyCurveSection
                        
                        // Settings
                        settingsSection
                        
                        // Sign Out
                        signOutButton
                        
                        Spacer(minLength: AppTheme.Spacing.xxl)
                    }
                    .padding(.top, AppTheme.Spacing.lg)
                }
            }
        }
        .task {
            await checkNotificationStatus()
            achievementSystem.updateProgress(tasks: viewModel.todos)
        }
        .sheet(isPresented: $showWeeklyReview) {
            WeeklyReviewView(tasks: viewModel.todos)
        }
    }
    
    // MARK: - Profile Card
    
    private var profileCard: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // Avatar
            ZStack {
                Circle()
                    .fill(AppTheme.accentGold.opacity(0.12))
                    .frame(width: 118, height: 118)

                Circle()
                    .stroke(AppTheme.borderColor.opacity(0.7), lineWidth: 1)
                    .frame(width: 118, height: 118)

                Image("beaver-main")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppTheme.bgSecondary, lineWidth: 3)
                    )
                    .shadow(color: AppTheme.primaryDeepIndigo.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            
            VStack(spacing: AppTheme.Spacing.xs) {
                Text(ProfileManager.shared.activeProfile.name)
                    .font(AppTheme.Typography.headlineSmall)
                    .foregroundColor(AppTheme.textPrimary)
                
                Text(authManager.userEmail ?? "AI Planner User")
                    .font(AppTheme.Typography.bodySmall)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.xl)
    .background(AppTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
        .stroke(AppTheme.borderColor.opacity(0.85), lineWidth: 1)
        )
    .shadow(color: AppTheme.Shadows.sm.color, radius: AppTheme.Shadows.sm.radius, x: AppTheme.Shadows.sm.x, y: AppTheme.Shadows.sm.y)
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            HStack {
                SectionHeader(title: "Statistics", icon: "chart.bar.fill")
                Spacer()
                Button(action: { showWeeklyReview = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 12))
                        Text("Weekly")
                            .font(AppTheme.Typography.labelSmall)
                    }
                    .foregroundColor(AppTheme.primaryDeepIndigo)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background(AppTheme.bgElevated)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                            .stroke(AppTheme.borderColor.opacity(0.85), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            
            // 3-column stat cards
            HStack(spacing: AppTheme.Spacing.sm) {
                StatCard(
                    icon: "checkmark.circle.fill",
                    value: "\(completedTasksCount)",
                    label: "Completed",
                    color: AppTheme.secondaryTeal
                )
                
                StatCard(
                    icon: "clock.fill",
                    value: formattedHours,
                    label: "Hours",
                    color: AppTheme.secondaryTeal
                )
                
                StatCard(
                    icon: "flame.fill",
                    value: "\(currentStreak)",
                    label: "Day Streak",
                    color: AppTheme.accentCoral
                )
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            
            // Completion rate bar
            VStack(spacing: AppTheme.Spacing.sm) {
                HStack {
                    Text("Completion Rate")
                        .font(AppTheme.Typography.titleMedium)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Spacer()
                    
                    Text("\(Int(completionRate * 100))%")
                        .font(AppTheme.Typography.titleMedium)
                        .foregroundColor(AppTheme.primaryDeepIndigo)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppTheme.bgTertiary)
                            .frame(height: 10)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        AppTheme.secondaryTeal,
                                        AppTheme.primaryDeepIndigo
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geo.size.width * completionRate), height: 10)
                    }
                }
                .frame(height: 10)
                
                HStack {
                    Text("\(completedTasksCount) of \(viewModel.todos.count) tasks")
                        .font(AppTheme.Typography.bodySmall)
                        .foregroundColor(AppTheme.textTertiary)
                    Spacer()
                }
            }
            .padding(AppTheme.Spacing.lg)
            .background(AppTheme.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                    .stroke(AppTheme.borderColor.opacity(0.85), lineWidth: 1)
            )
            .shadow(color: AppTheme.Shadows.sm.color, radius: AppTheme.Shadows.sm.radius, x: AppTheme.Shadows.sm.x, y: AppTheme.Shadows.sm.y)
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
    }
    
    // MARK: - Energy Curve Section
    
    private var energyCurveSection: some View {
        let profile = EnergyAnalysisService.buildProfile(from: viewModel.todos)
        return EnergyCurveView(profile: profile)
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Settings", icon: "gear")
                .padding(.horizontal, AppTheme.Spacing.lg)
            
            VStack(spacing: 0) {
                // Calendar Sync Toggle
                SettingsToggleRow(
                    icon: "calendar.badge.clock",
                    label: "Sync to iOS Calendar",
                    subtitle: calendarSync.isAuthorized ? (calendarSync.isSyncEnabled ? "Enabled" : "Disabled") : "Not Authorized",
                    isOn: $calendarSync.isSyncEnabled
                )
                .onChange(of: calendarSync.isSyncEnabled) { _, newValue in
                    if newValue {
                        Task {
                            let granted = await calendarSync.requestAccess()
                            if granted {
                                viewModel.syncAllTasksToCalendar()
                            } else {
                                calendarSync.isSyncEnabled = false
                            }
                        }
                    } else {
                        viewModel.removeAllTasksFromCalendar()
                    }
                }
                
                Divider()
                    .padding(.leading, 48)
                
                // Notifications → NavigationLink to settings page
                NavigationLink {
                    NotificationSettingsView(viewModel: viewModel)
                } label: {
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.primaryDeepIndigo)
                            .frame(width: 28, height: 28)
                            .background(AppTheme.primaryDeepIndigo.opacity(0.1))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notifications")
                                .font(AppTheme.Typography.bodyMedium)
                                .foregroundColor(AppTheme.textPrimary)
                            Text(notificationsEnabled
                                 ? subtitleForNotificationSettings()
                                 : "Disabled")
                                .font(AppTheme.Typography.labelSmall)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.vertical, AppTheme.Spacing.md)
                }
                
                Divider()
                    .padding(.leading, 48)
                
                // Profiles row
                NavigationLink {
                    ProfileManagementView()
                } label: {
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.accentGold)
                            .frame(width: 28, height: 28)
                            .background(AppTheme.accentGold.opacity(0.1))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Profiles")
                                .font(AppTheme.Typography.bodyMedium)
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text(ProfileManager.shared.activeProfile.name)
                                .font(AppTheme.Typography.labelSmall)
                                .foregroundColor(AppTheme.textTertiary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.vertical, AppTheme.Spacing.md)
                }
                
                Divider()
                    .padding(.leading, 48)
                
                // Preferences row
                NavigationLink {
                    UserPreferencesView()
                } label: {
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.primaryDeepIndigo)
                            .frame(width: 28, height: 28)
                            .background(AppTheme.primaryDeepIndigo.opacity(0.1))
                            .clipShape(Circle())
                        
                        Text("My Preferences")
                            .font(AppTheme.Typography.bodyMedium)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.vertical, AppTheme.Spacing.md)
                }
                
                Divider()
                    .padding(.leading, 48)
                
                // About row
                HStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.secondaryTeal)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.secondaryTeal.opacity(0.1))
                        .clipShape(Circle())
                    
                    Text("About")
                        .font(AppTheme.Typography.bodyMedium)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Spacer()
                    
                    Text(appVersion)
                        .font(AppTheme.Typography.bodySmall)
                        .foregroundColor(AppTheme.textTertiary)
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.md)
            }
            .background(AppTheme.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                    .stroke(AppTheme.borderColor.opacity(0.85), lineWidth: 1)
            )
            .shadow(color: AppTheme.Shadows.sm.color, radius: AppTheme.Shadows.sm.radius, x: AppTheme.Shadows.sm.x, y: AppTheme.Shadows.sm.y)
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
    }
    
    // MARK: - Beaver Commentary
    
    private var beaverCommentarySection: some View {
        let commentary = BeaverPersonality.shared.statsCommentary(
            completionRate: completionRate,
            streak: currentStreak,
            completedCount: completedTasksCount
        )
        let tip = beaverProductivityTip
        
        return VStack(spacing: AppTheme.Spacing.md) {
            // Main commentary
            HStack(spacing: AppTheme.Spacing.md) {
                Image("beaver-main")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Beaver says:")
                        .font(AppTheme.Typography.labelSmall)
                        .foregroundColor(AppTheme.textTertiary)
                    
                    Text(commentary)
                        .font(AppTheme.Typography.bodyMedium)
                        .foregroundColor(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Productivity tip based on user data
            if let tip {
                Divider()
                
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    
                    Text(tip)
                        .font(AppTheme.Typography.bodySmall)
                        .foregroundColor(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.primaryDeepIndigo.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                .stroke(AppTheme.primaryDeepIndigo.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
    
    /// Generate a data-driven productivity tip
    private var beaverProductivityTip: String? {
        let analyzer = BehaviorAnalyzer.shared
        let topHours = analyzer.topProductiveHours(days: 30)
        let procrastination = analyzer.procrastinationHours(days: 30)
        
        if !topHours.isEmpty {
            let formattedHours = topHours.prefix(2).map { "\($0):00" }.joined(separator: " & ")
            return "Your peak hours are around \(formattedHours). Try scheduling important tasks then!"
        }
        
        if !procrastination.isEmpty {
            let hour = procrastination.first!
            return "You tend to postpone tasks around \(hour):00. Try breaking them into smaller steps."
        }
        
        if completionRate < 0.5 && completedTasksCount > 0 {
            return "Try starting with 2-3 small tasks to build momentum."
        }
        
        if currentStreak == 0 && completedTasksCount > 0 {
            return "Complete just one task today to restart your streak!"
        }
        
        return nil
    }
    
    // MARK: - Achievements Section
    
    private var achievementsSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            HStack {
                SectionHeader(title: "Achievements", icon: "trophy.fill")
                Spacer()
                Text("\(achievementSystem.unlockedCount)/\(achievementSystem.achievements.count)")
                    .font(AppTheme.Typography.labelMedium)
                    .foregroundColor(AppTheme.textTertiary)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            
            // Achievement grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: AppTheme.Spacing.md) {
                ForEach(achievementSystem.achievements) { achievement in
                    AchievementBadge(achievement: achievement)
                }
            }
            .padding(AppTheme.Spacing.lg)
            .background(AppTheme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                    .stroke(AppTheme.borderColor, lineWidth: 1)
            )
            .padding(.horizontal, AppTheme.Spacing.lg)
            
            // Next achievement
            if let next = achievementSystem.nextAchievement() {
                HStack(spacing: AppTheme.Spacing.md) {
                    Text(next.icon)
                        .font(.system(size: 20))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next: \(next.title)")
                            .font(AppTheme.Typography.titleSmall)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text("\(next.currentProgress)/\(next.requirement) — \(next.description)")
                            .font(AppTheme.Typography.labelSmall)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Mini progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(AppTheme.bgTertiary)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(next.color)
                                .frame(width: geo.size.width * next.progressRatio)
                        }
                    }
                    .frame(width: 60, height: 6)
                }
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                        .stroke(AppTheme.borderColor, lineWidth: 1)
                )
                .padding(.horizontal, AppTheme.Spacing.lg)
            }
        }
    }
    
    // MARK: - Sign Out
    
    private var signOutButton: some View {
        Button {
            Task {
                await authManager.signOut()
            }
        } label: {
            Text("Sign Out")
                .font(AppTheme.Typography.titleMedium)
                .foregroundColor(AppTheme.accentCoral)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.md)
                .background(AppTheme.accentCoral.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                        .stroke(AppTheme.accentCoral.opacity(0.2), lineWidth: 1)
                )
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
    
    // MARK: - Helpers
    
    private func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsEnabled = settings.authorizationStatus == .authorized
    }

    private func subtitleForNotificationSettings() -> String {
        let s = NotificationManager.shared.settings
        var parts: [String] = []
        if let mins = s.minutesBefore { parts.append("\(mins)m before") }
        if s.notifyOnStart  { parts.append("on start") }
        if s.notifyOnFinish { parts.append("on finish") }
        return parts.isEmpty ? "Enabled" : parts.joined(separator: " · ")
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            // Color stripe
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(height: 3)
            
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
                .padding(.top, AppTheme.Spacing.xs)
            
            Text(value)
                .font(AppTheme.Typography.headlineLarge)
                .foregroundColor(AppTheme.textPrimary)
            
            Text(label)
                .font(AppTheme.Typography.labelSmall)
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.bottom, AppTheme.Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .background(AppTheme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                .stroke(AppTheme.borderColor, lineWidth: 1)
        )
    }
}

// MARK: - Settings Toggle Row

struct SettingsToggleRow: View {
    let icon: String
    let label: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.secondaryTeal)
                .frame(width: 28, height: 28)
                .background(AppTheme.secondaryTeal.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppTheme.Typography.bodyMedium)
                    .foregroundColor(AppTheme.textPrimary)
                
                Text(subtitle)
                    .font(AppTheme.Typography.labelSmall)
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppTheme.secondaryTeal)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.md)
    }
}

// MARK: - Achievement Badge

struct AchievementBadge: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? achievement.color.opacity(0.15) : AppTheme.bgTertiary)
                    .frame(width: 44, height: 44)
                
                if achievement.isUnlocked {
                    Text(achievement.icon)
                        .font(.system(size: 22))
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textTertiary.opacity(0.5))
                }
            }
            
            Text(achievement.title)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(achievement.isUnlocked ? AppTheme.textSecondary : AppTheme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

#Preview {
    ProfileView(authManager: AuthManager(), viewModel: .preview)
}
