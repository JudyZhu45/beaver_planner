//
//  PendingTaskCardView.swift
//  AI_planner
//
//  A ScheduleCard-style preview card shown before the user confirms an AI proposal.
//  Mirrors the visual language of ScheduleCard but adds an action badge (Add / Delete …)
//  and a "not saved yet" dashed border treatment.
//

import SwiftUI

struct PendingTaskCardView: View {
    let card: PendingTaskCard

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {

            // ── Icon badge ────────────────────────────────────────────
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(iconBgColor)
                    .frame(width: 42, height: 42)

                Image(systemName: card.eventColor.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(iconFgColor)
                    .frame(width: 42, height: 42)

                // Action badge (plus / pencil / trash / checkmark) — bottom-right corner
                Image(systemName: card.actionBadge)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(actionBadgeColor)
                    .background(
                        Circle()
                            .fill(AppTheme.bgElevated)
                            .frame(width: 16, height: 16)
                    )
                    .offset(x: 6, y: 6)
            }
            .padding(.bottom, 6) // room for the badge overflow

            // ── Title + subtitle ──────────────────────────────────────
            VStack(alignment: .leading, spacing: 2) {
                Text(card.title)
                    .font(AppTheme.Typography.titleMedium)
                    .foregroundColor(AppTheme.textPrimary.opacity(0.85))
                    .lineLimit(1)

                if let subtitle = card.subtitle {
                    Text(subtitle)
                        .font(AppTheme.Typography.bodySmall)
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                // Action label pill (e.g. "Add", "Delete")
                Text(card.actionLabel)
                    .font(AppTheme.Typography.labelSmall)
                    .foregroundColor(actionBadgeColor.opacity(0.9))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(actionBadgeColor.opacity(0.10))
                    .clipShape(Capsule())
            }

            Spacer()

            // ── Time / date column ────────────────────────────────────
            VStack(alignment: .trailing, spacing: 4) {
                if let time = card.timeLabel {
                    Text(time)
                        .font(AppTheme.Typography.labelMedium)
                        .foregroundColor(AppTheme.textPrimary.opacity(0.75))
                        .multilineTextAlignment(.trailing)
                } else if let date = card.dateLabel {
                    Text(date)
                        .font(AppTheme.Typography.labelMedium)
                        .foregroundColor(AppTheme.textPrimary.opacity(0.75))
                }

                if let dur = card.durationLabel {
                    Text(dur)
                        .font(AppTheme.Typography.labelSmall)
                        .foregroundColor(AppTheme.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.bgSecondary.opacity(0.9))
                        .clipShape(Capsule())
                } else if card.timeLabel != nil, let date = card.dateLabel {
                    Text(date)
                        .font(AppTheme.Typography.labelSmall)
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .stroke(
                    card.eventColor.primary.opacity(0.28),
                    style: StrokeStyle(lineWidth: 1.2, dash: [5, 3])
                )
        )
        .shadow(
            color: AppTheme.Shadows.sm.color.opacity(0.7),
            radius: 8, x: 0, y: 4
        )
    }

    // MARK: - Derived colours

    private var iconBgColor: Color {
        isDestructive
            ? Color.red.opacity(0.10)
            : card.eventColor.primary.opacity(0.13)
    }

    private var iconFgColor: Color {
        isDestructive
            ? Color.red.opacity(0.7)
            : card.eventColor.primary.opacity(0.8)
    }

    private var actionBadgeColor: Color {
        switch card.kind {
        case .create:   return AppTheme.primaryDeepIndigo
        case .update:   return AppTheme.secondaryTeal
        case .delete:   return Color(red: 0.82, green: 0.27, blue: 0.27)
        case .complete: return AppTheme.secondaryTeal
        }
    }

    private var isDestructive: Bool {
        if case .delete = card.kind { return true }
        return false
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .fill(AppTheme.bgElevated)
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            card.eventColor.light.opacity(isDestructive ? 0.2 : 0.55),
                            AppTheme.bgElevated
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

// MARK: - Preview

#Preview {
    let gymCard = PendingTaskCard(
        kind: .create(AITaskData(title: "Morning Gym", description: "Chest + arms", dueDate: "2026-03-09", startTime: "07:00", endTime: "08:00", priority: "medium", eventType: "gym")),
        title: "Morning Gym",
        subtitle: "Chest + arms",
        dateLabel: "Mar 9",
        timeLabel: "7:00 AM – 8:00 AM",
        durationLabel: "1h",
        eventColor: AppTheme.eventColors[0],
        actionBadge: "plus.circle.fill",
        actionLabel: "Add"
    )
    let meetCard = PendingTaskCard(
        kind: .create(AITaskData(title: "Team Sync", description: nil, dueDate: "2026-03-09", startTime: "14:00", endTime: "15:00", priority: "high", eventType: "meeting")),
        title: "Team Sync",
        subtitle: nil,
        dateLabel: "Mar 9",
        timeLabel: "2:00 PM – 3:00 PM",
        durationLabel: "1h",
        eventColor: AppTheme.eventColors[3],
        actionBadge: "plus.circle.fill",
        actionLabel: "Add"
    )
    let delCard = PendingTaskCard(
        kind: .delete(title: "Old task"),
        title: "Old task",
        subtitle: nil,
        dateLabel: nil,
        timeLabel: nil,
        durationLabel: nil,
        eventColor: AppTheme.eventColors.last!,
        actionBadge: "trash.circle.fill",
        actionLabel: "Delete"
    )

    VStack(spacing: 12) {
        PendingTaskCardView(card: gymCard)
        PendingTaskCardView(card: meetCard)
        PendingTaskCardView(card: delCard)
    }
    .padding(16)
    .background(AppTheme.bgPrimary)
}
