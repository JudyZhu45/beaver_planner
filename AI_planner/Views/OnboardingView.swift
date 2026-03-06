//
//  OnboardingView.swift
//  AI_planner
//
//  Created by AI Assistant on 3/5/26.
//

import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void
    
    @State private var currentStep = 0
    
    // Step 2: Schedule
    @State private var wakeUpTime = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    @State private var workStartTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var workEndTime = Calendar.current.date(from: DateComponents(hour: 17, minute: 0)) ?? Date()
    @State private var hasLunchBreak = true
    
    // Step 3: Tasks
    @State private var selectedTypes: Set<String> = []
    @State private var preferredDuration = "medium"
    
    // Step 4: Lifestyle
    @State private var weekendPreference = "flexible"
    @State private var constraints = ""
    
    private let totalSteps = 4
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    AppTheme.bgPrimary,
                    AppTheme.primaryDeepIndigo.opacity(0.05)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(0..<totalSteps, id: \.self) { step in
                        Circle()
                            .fill(step <= currentStep ? AppTheme.primaryDeepIndigo : AppTheme.bgTertiary)
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
                .padding(.top, AppTheme.Spacing.xxl)
                .padding(.bottom, AppTheme.Spacing.lg)
                
                // Content
                TabView(selection: $currentStep) {
                    welcomeStep.tag(0)
                    scheduleStep.tag(1)
                    taskStep.tag(2)
                    lifestyleStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)
                
                // Navigation buttons
                HStack(spacing: AppTheme.Spacing.md) {
                    if currentStep > 0 {
                        Button {
                            withAnimation { currentStep -= 1 }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Back")
                                    .font(AppTheme.Typography.titleMedium)
                            }
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.horizontal, AppTheme.Spacing.xl)
                            .padding(.vertical, AppTheme.Spacing.md)
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        if currentStep < totalSteps - 1 {
                            withAnimation { currentStep += 1 }
                        } else {
                            saveAndComplete()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(currentStep == totalSteps - 1 ? "Get Started" : "Next")
                                .font(AppTheme.Typography.titleMedium)
                            if currentStep < totalSteps - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, AppTheme.Spacing.xxl)
                        .padding(.vertical, AppTheme.Spacing.md)
                        .background(AppTheme.primaryDeepIndigo)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.xl)
                .padding(.bottom, AppTheme.Spacing.xxl)
            }
        }
    }
    
    // MARK: - Step 1: Welcome
    
    private var welcomeStep: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xxxl) {
                Spacer(minLength: 40)
                
                Image("beaver-main")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .shadow(color: AppTheme.primaryDeepIndigo.opacity(0.15), radius: 12, x: 0, y: 6)
                
                VStack(spacing: AppTheme.Spacing.md) {
                    Text("Welcome!")
                        .font(AppTheme.Typography.displayLarge)
                        .foregroundColor(AppTheme.primaryDeepIndigo)
                    
                    Text("Let's personalize your experience")
                        .font(AppTheme.Typography.headlineSmall)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Text("Tell us a bit about your schedule and preferences so our AI can give you better planning suggestions.")
                        .font(AppTheme.Typography.bodyMedium)
                        .foregroundColor(AppTheme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.Spacing.xxl)
                }
                
                // Feature highlights
                VStack(spacing: AppTheme.Spacing.lg) {
                    featureRow(icon: "clock.fill", color: AppTheme.secondaryTeal, text: "Smart scheduling based on your routine")
                    featureRow(icon: "brain.head.profile", color: AppTheme.primaryDeepIndigo, text: "AI learns your preferences over time")
                    featureRow(icon: "slider.horizontal.3", color: AppTheme.accentCoral, text: "Customize anytime in Settings")
                }
                .padding(AppTheme.Spacing.xl)
                .background(AppTheme.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                        .stroke(AppTheme.borderColor, lineWidth: 1)
                )
                .padding(.horizontal, AppTheme.Spacing.lg)
                
                Spacer(minLength: 60)
            }
        }
    }
    
    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            Text(text)
                .font(AppTheme.Typography.bodyMedium)
                .foregroundColor(AppTheme.textPrimary)
            
            Spacer()
        }
    }
    
    // MARK: - Step 2: Schedule
    
    private var scheduleStep: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xxl) {
                Spacer(minLength: 20)
                
                VStack(spacing: AppTheme.Spacing.sm) {
                    Text("Your Schedule")
                        .font(AppTheme.Typography.displayMedium)
                        .foregroundColor(AppTheme.primaryDeepIndigo)
                    
                    Text("When do you usually start and end your day?")
                        .font(AppTheme.Typography.bodyMedium)
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                VStack(spacing: 0) {
                    // Wake up time
                    timePickerRow(
                        icon: "sunrise.fill",
                        label: "Wake up",
                        selection: $wakeUpTime
                    )
                    
                    Divider().padding(.leading, 48)
                    
                    // Work/School start
                    timePickerRow(
                        icon: "briefcase.fill",
                        label: "Work / School starts",
                        selection: $workStartTime
                    )
                    
                    Divider().padding(.leading, 48)
                    
                    // Work/School end
                    timePickerRow(
                        icon: "moon.fill",
                        label: "Work / School ends",
                        selection: $workEndTime
                    )
                    
                    Divider().padding(.leading, 48)
                    
                    // Lunch break
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
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                        .stroke(AppTheme.borderColor, lineWidth: 1)
                )
                .padding(.horizontal, AppTheme.Spacing.lg)
                
                Spacer(minLength: 60)
            }
        }
    }
    
    private func timePickerRow(icon: String, label: String, selection: Binding<Date>) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.secondaryTeal)
                .frame(width: 28, height: 28)
                .background(AppTheme.secondaryTeal.opacity(0.1))
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
    
    // MARK: - Step 3: Task Preferences
    
    private var taskStep: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xxl) {
                Spacer(minLength: 20)
                
                VStack(spacing: AppTheme.Spacing.sm) {
                    Text("Your Tasks")
                        .font(AppTheme.Typography.displayMedium)
                        .foregroundColor(AppTheme.primaryDeepIndigo)
                    
                    Text("What types of tasks do you usually schedule?")
                        .font(AppTheme.Typography.bodyMedium)
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                // Event type selection
                VStack(spacing: AppTheme.Spacing.md) {
                    Text("Select all that apply")
                        .font(AppTheme.Typography.labelMedium)
                        .foregroundColor(AppTheme.textTertiary)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: AppTheme.Spacing.md) {
                        ForEach(AppTheme.eventColors) { eventColor in
                            eventTypeChip(eventColor: eventColor)
                        }
                    }
                }
                .padding(AppTheme.Spacing.xl)
                .background(AppTheme.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                        .stroke(AppTheme.borderColor, lineWidth: 1)
                )
                .padding(.horizontal, AppTheme.Spacing.lg)
                
                // Duration preference
                VStack(spacing: AppTheme.Spacing.md) {
                    Text("Preferred task duration")
                        .font(AppTheme.Typography.titleMedium)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    HStack(spacing: AppTheme.Spacing.sm) {
                        durationOption(value: "short", label: "Short", sublabel: "< 30 min")
                        durationOption(value: "medium", label: "Medium", sublabel: "30-60 min")
                        durationOption(value: "long", label: "Long", sublabel: "> 1 hour")
                    }
                }
                .padding(AppTheme.Spacing.xl)
                .background(AppTheme.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                        .stroke(AppTheme.borderColor, lineWidth: 1)
                )
                .padding(.horizontal, AppTheme.Spacing.lg)
                
                Spacer(minLength: 60)
            }
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
            VStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: eventColor.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isSelected ? .white : eventColor.primary)
                
                Text(eventColor.name)
                    .font(AppTheme.Typography.labelMedium)
                    .foregroundColor(isSelected ? .white : AppTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.lg)
            .background(isSelected ? eventColor.primary : eventColor.light)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                    .stroke(isSelected ? eventColor.dark : Color.clear, lineWidth: 2)
            )
        }
    }
    
    private func durationOption(value: String, label: String, sublabel: String) -> some View {
        let isSelected = preferredDuration == value
        return Button {
            preferredDuration = value
        } label: {
            VStack(spacing: 4) {
                Text(label)
                    .font(AppTheme.Typography.titleMedium)
                    .foregroundColor(isSelected ? .white : AppTheme.textPrimary)
                Text(sublabel)
                    .font(AppTheme.Typography.labelSmall)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : AppTheme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(isSelected ? AppTheme.primaryDeepIndigo : AppTheme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        }
    }
    
    // MARK: - Step 4: Lifestyle
    
    private var lifestyleStep: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xxl) {
                Spacer(minLength: 20)
                
                VStack(spacing: AppTheme.Spacing.sm) {
                    Text("Your Lifestyle")
                        .font(AppTheme.Typography.displayMedium)
                        .foregroundColor(AppTheme.primaryDeepIndigo)
                    
                    Text("Help us understand your preferences")
                        .font(AppTheme.Typography.bodyMedium)
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                // Weekend preference
                VStack(spacing: AppTheme.Spacing.md) {
                    HStack {
                        Text("Weekend style")
                            .font(AppTheme.Typography.titleMedium)
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                    }
                    
                    HStack(spacing: AppTheme.Spacing.sm) {
                        weekendOption(value: "rest", icon: "cup.and.saucer.fill", label: "Rest")
                        weekendOption(value: "flexible", icon: "arrow.left.arrow.right", label: "Flexible")
                        weekendOption(value: "work", icon: "laptopcomputer", label: "Work")
                    }
                }
                .padding(AppTheme.Spacing.xl)
                .background(AppTheme.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                        .stroke(AppTheme.borderColor, lineWidth: 1)
                )
                .padding(.horizontal, AppTheme.Spacing.lg)
                
                // Constraints
                VStack(spacing: AppTheme.Spacing.md) {
                    HStack {
                        Text("Any fixed weekly commitments?")
                            .font(AppTheme.Typography.titleMedium)
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                    }
                    
                    Text("e.g. \"Tuesday & Thursday classes 9-12\", \"Gym every MWF\"")
                        .font(AppTheme.Typography.bodySmall)
                        .foregroundColor(AppTheme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    TextField("Optional — type your constraints here", text: $constraints, axis: .vertical)
                        .font(AppTheme.Typography.bodyMedium)
                        .padding(AppTheme.Spacing.md)
                        .background(AppTheme.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                        .lineLimit(3...6)
                }
                .padding(AppTheme.Spacing.xl)
                .background(AppTheme.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                        .stroke(AppTheme.borderColor, lineWidth: 1)
                )
                .padding(.horizontal, AppTheme.Spacing.lg)
                
                // Ready message
                VStack(spacing: AppTheme.Spacing.md) {
                    Image("beaver-main")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                    
                    Text("You're all set! You can always update these in Settings.")
                        .font(AppTheme.Typography.bodyMedium)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, AppTheme.Spacing.lg)
                
                Spacer(minLength: 60)
            }
        }
    }
    
    private func weekendOption(value: String, icon: String, label: String) -> some View {
        let isSelected = weekendPreference == value
        return Button {
            weekendPreference = value
        } label: {
            VStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
                
                Text(label)
                    .font(AppTheme.Typography.titleMedium)
                    .foregroundColor(isSelected ? .white : AppTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.lg)
            .background(isSelected ? AppTheme.secondaryTeal : AppTheme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        }
    }
    
    // MARK: - Save & Complete
    
    private func saveAndComplete() {
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
        onComplete()
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
