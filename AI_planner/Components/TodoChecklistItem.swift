//
//  TodoChecklistItem.swift
//  AI_planner
//
//  Created by Judy459 on 2/19/26.
//

import SwiftUI

struct TodoChecklistItem: View {
    let task: TodoTask
    let onToggle: () -> Void
    let onDelete: () -> Void
    var onEdit: (() -> Void)? = nil
    @State private var completionProgress: CGFloat = 0
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            CheckboxButton(
                isChecked: task.isCompleted,
                action: onToggle
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(AppTheme.Typography.bodyMedium)
                    .foregroundColor(task.isCompleted ? AppTheme.textTertiary : AppTheme.textPrimary)
                    .strikethrough(task.isCompleted)
                
                if !task.description.isEmpty {
                    Text(task.description)
                        .font(AppTheme.Typography.bodySmall)
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(2)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onEdit?()
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.textTertiary)
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(
            ZStack {
                AppTheme.bgSecondary
                
                GeometryReader { geo in
                    Rectangle()
                        .fill(AppTheme.secondaryTeal.opacity(0.08))
                        .frame(width: geo.size.width * completionProgress)
                }
                .clipped()
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                .stroke(AppTheme.borderColor, lineWidth: 1)
        )
        .onAppear {
            completionProgress = task.isCompleted ? 1.0 : 0.0
        }
        .onChange(of: task.isCompleted) { _, newValue in
            withAnimation(.easeInOut(duration: 0.4)) {
                completionProgress = newValue ? 1.0 : 0.0
            }
        }
    }
}

#Preview {
    let vm = TodoViewModel.preview
    TodoChecklistItem(
        task: vm.todos.first!,
        onToggle: {},
        onDelete: {}
    )
    .padding()
}
