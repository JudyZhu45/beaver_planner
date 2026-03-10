//
//  NotificationSettingsView.swift
//  AI_planner
//

import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @ObservedObject var viewModel: TodoViewModel
    @Environment(\.dismiss) private var dismiss

    // Local copy of settings — saved on disappear
    @State private var settings: NotificationSettings = NotificationManager.shared.settings
    @State private var systemAuthorized = false
    @State private var showSystemAlert = false

    // minutesBefore picker options
    private let minuteOptions: [(label: String, value: Int?)] = [
        ("Off", nil),
        ("5 min", 5),
        ("10 min", 10),
        ("15 min", 15),
        ("30 min", 30),
        ("1 hour", 60),
    ]

    var body: some View {
        ZStack {
            AppTheme.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {

                    // ── System permission banner ───────────────────────
                    if !systemAuthorized {
                        permissionBanner
                    }

                    // ── Master toggle ──────────────────────────────────
                    masterToggleCard

                    // ── Reminder timing options ────────────────────────
                    if settings.isEnabled && systemAuthorized {
                        timingCard
                    }

                    Spacer(minLength: AppTheme.Spacing.xxl)
                }
                .padding(.top, AppTheme.Spacing.lg)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    save()
                    dismiss()
                }
                .font(AppTheme.Typography.titleMedium)
                .foregroundColor(AppTheme.primaryDeepIndigo)
            }
        }
        .task {
            await refreshSystemStatus()
        }
        .alert("Open Settings", isPresented: $showSystemAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable notifications for AI Planner in iOS Settings.")
        }
    }

    // MARK: - Permission Banner

    private var permissionBanner: some View {
        Button {
            Task {
                let granted = await NotificationManager.shared.requestAuthorization()
                if granted {
                    await refreshSystemStatus()
                } else {
                    showSystemAlert = true
                }
            }
        } label: {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.accentCoral)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications are off")
                        .font(AppTheme.Typography.titleMedium)
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Tap to enable in iOS Settings")
                        .font(AppTheme.Typography.labelSmall)
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textTertiary)
            }
            .padding(AppTheme.Spacing.lg)
            .background(AppTheme.accentCoral.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                    .stroke(AppTheme.accentCoral.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppTheme.Spacing.lg)
    }

    // MARK: - Master Toggle

    private var masterToggleCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.primaryDeepIndigo)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.primaryDeepIndigo.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Notifications")
                        .font(AppTheme.Typography.bodyMedium)
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Get reminded about your tasks")
                        .font(AppTheme.Typography.labelSmall)
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Toggle("", isOn: $settings.isEnabled)
                    .labelsHidden()
                    .tint(AppTheme.secondaryTeal)
            }
            .padding(AppTheme.Spacing.lg)
        }
        .background(AppTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                .stroke(AppTheme.borderColor.opacity(0.85), lineWidth: 1)
        )
        .padding(.horizontal, AppTheme.Spacing.lg)
    }

    // MARK: - Timing Card

    private var timingCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.secondaryTeal)
                Text("When to remind you")
                    .font(AppTheme.Typography.labelLarge)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)

            VStack(spacing: 0) {

                // ── Before start ──────────────────────────────────────
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "timer")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.accentGold)
                            .frame(width: 28, height: 28)
                            .background(AppTheme.accentGold.opacity(0.1))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Before a task starts")
                                .font(AppTheme.Typography.bodyMedium)
                                .foregroundColor(AppTheme.textPrimary)
                            Text("Remind me in advance")
                                .font(AppTheme.Typography.labelSmall)
                                .foregroundColor(AppTheme.textSecondary)
                        }

                        Spacer()
                    }

                    // Pill selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            ForEach(minuteOptions, id: \.label) { option in
                                let isSelected = settings.minutesBefore == option.value
                                Button {
                                    settings.minutesBefore = option.value
                                } label: {
                                    Text(option.label)
                                        .font(AppTheme.Typography.labelMedium)
                                        .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
                                        .padding(.horizontal, AppTheme.Spacing.md)
                                        .padding(.vertical, AppTheme.Spacing.sm)
                                        .background(
                                            isSelected
                                                ? AnyShapeStyle(AppTheme.accentGold)
                                                : AnyShapeStyle(AppTheme.bgTertiary)
                                        )
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(isSelected ? Color.clear : AppTheme.borderColor.opacity(0.6), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                .animation(.spring(response: 0.25), value: isSelected)
                            }
                        }
                        .padding(.leading, 44)
                    }
                }
                .padding(AppTheme.Spacing.lg)

                Divider().padding(.leading, 48)

                // ── When starts ───────────────────────────────────────
                timingToggleRow(
                    icon: "play.circle.fill",
                    iconColor: AppTheme.secondaryTeal,
                    title: "When a task starts",
                    subtitle: "Notify me at the exact start time",
                    isOn: $settings.notifyOnStart
                )

                Divider().padding(.leading, 48)

                // ── When finishes ─────────────────────────────────────
                timingToggleRow(
                    icon: "checkmark.circle.fill",
                    iconColor: AppTheme.primaryDeepIndigo,
                    title: "When a task finishes",
                    subtitle: "Notify me at the end time",
                    isOn: $settings.notifyOnFinish
                )
            }
            .background(AppTheme.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                    .stroke(AppTheme.borderColor.opacity(0.85), lineWidth: 1)
            )
            .padding(.horizontal, AppTheme.Spacing.lg)

            Text("Only tasks with a set start/end time will trigger start & finish reminders.")
                .font(AppTheme.Typography.labelSmall)
                .foregroundColor(AppTheme.textTertiary)
                .padding(.horizontal, AppTheme.Spacing.xl)
        }
    }

    private func timingToggleRow(icon: String, iconColor: Color,
                                  title: String, subtitle: String,
                                  isOn: Binding<Bool>) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.Typography.bodyMedium)
                    .foregroundColor(AppTheme.textPrimary)
                Text(subtitle)
                    .font(AppTheme.Typography.labelSmall)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AppTheme.secondaryTeal)
        }
        .padding(AppTheme.Spacing.lg)
    }

    // MARK: - Helpers

    private func refreshSystemStatus() async {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        systemAuthorized = s.authorizationStatus == .authorized
    }

    private func save() {
        NotificationManager.shared.settings = settings
        settings.save()
        if settings.isEnabled && systemAuthorized {
            NotificationManager.shared.rescheduleAll(tasks: viewModel.todos)
        } else if !settings.isEnabled {
            NotificationManager.shared.cancelAllNotifications()
        }
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView(viewModel: .preview)
    }
}
