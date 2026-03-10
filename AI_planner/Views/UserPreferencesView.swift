//
//  UserPreferencesView.swift
//  AI_planner
//
//  Created by AI Assistant on 3/5/26.
//

import SwiftUI

struct UserPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Schedule
    @State private var wakeUpTime = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    @State private var workStartTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var workEndTime = Calendar.current.date(from: DateComponents(hour: 17, minute: 0)) ?? Date()
    @State private var hasLunchBreak = false
    
    // Tasks
    @State private var selectedTypes: Set<String> = []
    @State private var preferredDuration = "medium"
    
    // Lifestyle
    @State private var weekendPreference = "flexible"
    @State private var constraints = ""
    
    // AI-learned preferences
    @State private var chatPreferences: [UserPreference] = []
    
    // Reset confirmation
    @State private var showResetAlert = false
    
    var body: some View {
        ZStack {
            AppTheme.bgPrimary.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Schedule section
                    scheduleSection
                    
                    // Task preferences section
                    taskSection
                    
                    // Lifestyle section
                    lifestyleSection
                    
                    // AI-learned preferences
                    aiLearnedSection
                    
                    // Reset
                    resetSection
                    
                    Spacer(minLength: AppTheme.Spacing.xxl)
                }
                .padding(.top, AppTheme.Spacing.lg)
            }
        }
        .navigationTitle("My Preferences")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    savePreferences()
                    dismiss()
                }
                .font(AppTheme.Typography.titleMedium)
                .foregroundColor(AppTheme.primaryDeepIndigo)
            }
        }
        .onAppear {
            loadCurrentPreferences()
        }
        .alert("Reset All Preferences?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetAllPreferences()
            }
        } message: {
            Text("This will clear all your preferences including AI-learned ones. The onboarding wizard will show again on next launch.")
        }
    }
    
    // MARK: - Schedule Section
    
    private var scheduleSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            sectionHeader(title: "Schedule", icon: "clock.fill")
            
            VStack(spacing: 0) {
                timeRow(icon: "sunrise.fill", label: "Wake up", color: AppTheme.accentCoral, selection: $wakeUpTime)
                Divider().padding(.leading, 48)
                timeRow(icon: "briefcase.fill", label: "Work starts", color: AppTheme.secondaryTeal, selection: $workStartTime)
                Divider().padding(.leading, 48)
                timeRow(icon: "moon.fill", label: "Work ends", color: AppTheme.primaryDeepIndigo, selection: $workEndTime)
                Divider().padding(.leading, 48)
                
                HStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.accentCoral)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.accentCoral.opacity(0.1))
                        .clipShape(Circle())
                    
                    Text("Lunch break")
                        .font(AppTheme.Typography.bodyMedium)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Spacer()
                    
                    Toggle("", isOn: $hasLunchBreak)
                        .labelsHidden()
                        .tint(AppTheme.secondaryTeal)
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.md)
            }
            .background(AppTheme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                    .stroke(AppTheme.borderColor, lineWidth: 1)
            )
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
    }
    
    private func timeRow(icon: String, label: String, color: Color, selection: Binding<Date>) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            Text(label)
                .font(AppTheme.Typography.bodyMedium)
                .foregroundColor(AppTheme.textPrimary)
            
            Spacer()
            
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(AppTheme.primaryDeepIndigo)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.sm)
    }
    
    // MARK: - Task Section
    
    private var taskSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            sectionHeader(title: "Task Preferences", icon: "checklist")
            
            VStack(spacing: AppTheme.Spacing.lg) {
                // Event types
                VStack(spacing: AppTheme.Spacing.sm) {
                    HStack {
                        Text("Frequent task types")
                            .font(AppTheme.Typography.titleMedium)
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                    }
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: AppTheme.Spacing.sm) {
                        ForEach(AppTheme.eventColors) { eventColor in
                            eventTypeChip(eventColor: eventColor)
                        }
                    }
                }
                
                Divider()
                
                // Duration
                VStack(spacing: AppTheme.Spacing.sm) {
                    HStack {
                        Text("Preferred duration")
                            .font(AppTheme.Typography.titleMedium)
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                    }
                    
                    HStack(spacing: AppTheme.Spacing.sm) {
                        durationChip(value: "short", label: "Short", sublabel: "< 30min")
                        durationChip(value: "medium", label: "Medium", sublabel: "30-60min")
                        durationChip(value: "long", label: "Long", sublabel: "> 1 hour")
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
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
    }
    
    private func eventTypeChip(eventColor: EventColor) -> some View {
        let isSelected = selectedTypes.contains(eventColor.name)
        return Button {
            if isSelected {
                selectedTypes.remove(eventColor.name)
            } else {
                selectedTypes.insert(eventColor.name)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: eventColor.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(eventColor.name)
                    .font(AppTheme.Typography.labelMedium)
            }
            .foregroundColor(isSelected ? .white : eventColor.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(isSelected ? eventColor.primary : eventColor.light)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
        }
    }
    
    private func durationChip(value: String, label: String, sublabel: String) -> some View {
        let isSelected = preferredDuration == value
        return Button {
            preferredDuration = value
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(AppTheme.Typography.titleMedium)
                Text(sublabel)
                    .font(AppTheme.Typography.labelSmall)
            }
            .foregroundColor(isSelected ? .white : AppTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(isSelected ? AppTheme.primaryDeepIndigo : AppTheme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
        }
    }
    
    // MARK: - Lifestyle Section
    
    private var lifestyleSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            sectionHeader(title: "Lifestyle", icon: "leaf.fill")
            
            VStack(spacing: AppTheme.Spacing.lg) {
                // Weekend
                VStack(spacing: AppTheme.Spacing.sm) {
                    HStack {
                        Text("Weekend style")
                            .font(AppTheme.Typography.titleMedium)
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                    }
                    
                    HStack(spacing: AppTheme.Spacing.sm) {
                        weekendChip(value: "rest", icon: "cup.and.saucer.fill", label: "Rest")
                        weekendChip(value: "flexible", icon: "arrow.left.arrow.right", label: "Flexible")
                        weekendChip(value: "work", icon: "laptopcomputer", label: "Work")
                    }
                }
                
                Divider()
                
                // Constraints
                VStack(spacing: AppTheme.Spacing.sm) {
                    HStack {
                        Text("Fixed weekly commitments")
                            .font(AppTheme.Typography.titleMedium)
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                    }
                    
                    TextField("e.g. \"Tue & Thu classes 9-12\"", text: $constraints, axis: .vertical)
                        .font(AppTheme.Typography.bodyMedium)
                        .padding(AppTheme.Spacing.md)
                        .background(AppTheme.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                        .lineLimit(2...5)
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
        }
    }
    
    private func weekendChip(value: String, icon: String, label: String) -> some View {
        let isSelected = weekendPreference == value
        return Button {
            weekendPreference = value
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(AppTheme.Typography.titleMedium)
            }
            .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(isSelected ? AppTheme.secondaryTeal : AppTheme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
        }
    }
    
    // MARK: - AI-Learned Section
    
    private var aiLearnedSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            sectionHeader(title: "AI-Learned Preferences", icon: "brain.head.profile")
            
            VStack(spacing: 0) {
                if chatPreferences.isEmpty {
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.textTertiary)
                        
                        Text("No preferences learned yet. Chat with your AI assistant and it will automatically pick up on your habits!")
                            .font(AppTheme.Typography.bodySmall)
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    .padding(AppTheme.Spacing.lg)
                } else {
                    ForEach(Array(chatPreferences.enumerated()), id: \.element.id) { index, pref in
                        if index > 0 {
                            Divider().padding(.leading, AppTheme.Spacing.lg)
                        }
                        
                        HStack(spacing: AppTheme.Spacing.md) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pref.content)
                                    .font(AppTheme.Typography.bodyMedium)
                                    .foregroundColor(AppTheme.textPrimary)
                                
                                HStack(spacing: 4) {
                                    Text(categoryDisplayName(pref.category))
                                        .font(AppTheme.Typography.labelSmall)
                                        .foregroundColor(AppTheme.textTertiary)
                                    
                                    if pref.confirmedCount > 1 {
                                        Text("x\(pref.confirmedCount)")
                                            .font(AppTheme.Typography.labelSmall)
                                            .foregroundColor(AppTheme.secondaryTeal)
                                    }
                                    
                                    if pref.isTemporary {
                                        Text("Temporary")
                                            .font(AppTheme.Typography.labelSmall)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(AppTheme.accentCoral.opacity(0.8))
                                            .clipShape(Capsule())
                                    }
                                    
                                    if let expires = pref.expiresAt {
                                        Text("expires \(expires, format: .dateTime.month().day())")
                                            .font(AppTheme.Typography.labelSmall)
                                            .foregroundColor(AppTheme.textTertiary)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Button {
                                ChatMemoryStore.shared.removePreference(id: pref.id)
                                chatPreferences.removeAll { $0.id == pref.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(AppTheme.textTertiary.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.vertical, AppTheme.Spacing.md)
                    }
                }
            }
            .background(AppTheme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                    .stroke(AppTheme.borderColor, lineWidth: 1)
            )
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
    }
    
    // MARK: - Reset Section
    
    private var resetSection: some View {
        Button {
            showResetAlert = true
        } label: {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .semibold))
                Text("Reset All Preferences")
                    .font(AppTheme.Typography.titleMedium)
            }
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
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.primaryDeepIndigo)
            
            Text(title)
                .font(AppTheme.Typography.headlineSmall)
                .foregroundColor(AppTheme.primaryDeepIndigo)
            
            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
    
    private func categoryDisplayName(_ category: PreferenceCategory) -> String {
        switch category {
        case .schedule: return "Schedule"
        case .taskHabit: return "Task Habit"
        case .lifestyle: return "Lifestyle"
        case .personality: return "Personality"
        case .constraint: return "Constraint"
        }
    }
    
    private func loadCurrentPreferences() {
        let sp = ChatMemoryStore.shared.getStructuredPreferences()
        if let wake = sp.wakeUpTime { wakeUpTime = wake }
        if let start = sp.workStartTime { workStartTime = start }
        if let end = sp.workEndTime { workEndTime = end }
        hasLunchBreak = sp.hasLunchBreak
        selectedTypes = Set(sp.preferredEventTypes)
        preferredDuration = sp.preferredDuration ?? "medium"
        weekendPreference = sp.weekendPreference ?? "flexible"
        constraints = sp.constraints ?? ""
        
        chatPreferences = ChatMemoryStore.shared.preferences
    }
    
    private func savePreferences() {
        var prefs = StructuredPreferences()
        prefs.wakeUpTime = wakeUpTime
        prefs.workStartTime = workStartTime
        prefs.workEndTime = workEndTime
        prefs.hasLunchBreak = hasLunchBreak
        prefs.preferredEventTypes = Array(selectedTypes)
        prefs.preferredDuration = preferredDuration
        prefs.weekendPreference = weekendPreference
        prefs.constraints = constraints.isEmpty ? nil : constraints
        
        ChatMemoryStore.shared.setStructuredPreferences(prefs)
    }
    
    private func resetAllPreferences() {
        ChatMemoryStore.shared.clearAll()
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        
        // Reset local state
        wakeUpTime = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
        workStartTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
        workEndTime = Calendar.current.date(from: DateComponents(hour: 17, minute: 0)) ?? Date()
        hasLunchBreak = false
        selectedTypes = []
        preferredDuration = "medium"
        weekendPreference = "flexible"
        constraints = ""
        chatPreferences = []
    }
}

#Preview {
    NavigationStack {
        UserPreferencesView()
    }
}
