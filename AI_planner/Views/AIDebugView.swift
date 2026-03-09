//
//  AIDebugView.swift
//  AI_planner
//
//  Temporary debug view to test Step 1 (time window extraction) and task fetching.
//  Remove this file when debugging is complete.
//

import SwiftUI

struct AIDebugView: View {
    @ObservedObject var todoViewModel: TodoViewModel
    @ObservedObject var chatViewModel: ChatViewModel
    
    @State private var testInput = ""
    @State private var isLoading = false
    @State private var result: DebugResult?
    
    struct DebugResult {
        let startDate: String?
        let endDate: String?
        let isSchedulingRelated: Bool
        let tasks: [(title: String, dueDate: String, startTime: String, endTime: String, id: String)]
        let taskContextForAI: String
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    
                    // Input section
                    inputSection
                    
                    // Results
                    if isLoading {
                        ProgressView("Calling Step 1 AI...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    
                    if let result {
                        step1ResultSection(result)
                        taskListSection(result)
                        aiContextSection(result)
                    }
                }
                .padding()
            }
            .background(AppTheme.bgPrimary.ignoresSafeArea())
            .navigationTitle("AI Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Input Section
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Test Input")
                .font(AppTheme.Typography.headlineSmall)
                .foregroundColor(AppTheme.textPrimary)
            
            HStack(spacing: AppTheme.Spacing.sm) {
                TextField("e.g. 明天下午三点我想踢球", text: $testInput)
                    .textFieldStyle(.roundedBorder)
                
                Button("Run") {
                    runTest()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primaryDeepIndigo)
                .disabled(testInput.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
            
            // Quick test buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    quickButton("明天下午三点踢球")
                    quickButton("帮我安排明天")
                    quickButton("下周的计划")
                    quickButton("今天有什么任务")
                    quickButton("hello")
                }
            }
        }
        .padding()
        .background(AppTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
    }
    
    private func quickButton(_ text: String) -> some View {
        Button(text) {
            testInput = text
            runTest()
        }
        .font(AppTheme.Typography.labelSmall)
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, AppTheme.Spacing.xs)
        .background(AppTheme.bgTertiary)
        .clipShape(Capsule())
        .foregroundColor(AppTheme.textPrimary)
    }
    
    // MARK: - Step 1 Result
    
    private func step1ResultSection(_ r: DebugResult) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            sectionLabel("Step 1: Time Window (AI)")
            
            infoRow("startDate", r.startDate ?? "nil")
            infoRow("endDate", r.endDate ?? "nil")
            infoRow("isSchedulingRelated", r.isSchedulingRelated ? "true" : "false",
                     color: r.isSchedulingRelated ? AppTheme.secondaryTeal : AppTheme.accentCoral)
        }
        .padding()
        .background(AppTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
    }
    
    // MARK: - Task List
    
    private func taskListSection(_ r: DebugResult) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            sectionLabel("Fetched Tasks (\(r.tasks.count))")
            
            if r.tasks.isEmpty {
                Text("No tasks in this window")
                    .font(AppTheme.Typography.bodySmall)
                    .foregroundColor(AppTheme.textTertiary)
                    .italic()
            } else {
                ForEach(Array(r.tasks.enumerated()), id: \.offset) { _, task in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .font(AppTheme.Typography.labelLarge)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        HStack(spacing: AppTheme.Spacing.md) {
                            Label(task.dueDate, systemImage: "calendar")
                            if task.startTime != "nil" {
                                Label("\(task.startTime) – \(task.endTime)", systemImage: "clock")
                            } else {
                                Label("unscheduled", systemImage: "clock")
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                        }
                        .font(AppTheme.Typography.labelSmall)
                        .foregroundColor(AppTheme.textSecondary)
                        
                        Text("ID: \(task.id)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    .padding(AppTheme.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.bgTertiary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                }
            }
        }
        .padding()
        .background(AppTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
    }
    
    // MARK: - AI Context
    
    private func aiContextSection(_ r: DebugResult) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            sectionLabel("Context String Sent to AI")
            
            Text(r.taskContextForAI)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppTheme.textSecondary)
                .textSelection(.enabled)
        }
        .padding()
        .background(AppTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
    }
    
    // MARK: - Helpers
    
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppTheme.Typography.headlineSmall)
            .foregroundColor(AppTheme.primaryDeepIndigo)
    }
    
    private func infoRow(_ label: String, _ value: String, color: Color = AppTheme.textPrimary) -> some View {
        HStack {
            Text(label)
                .font(AppTheme.Typography.labelMedium)
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 160, alignment: .leading)
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(color)
        }
    }
    
    // MARK: - Run Test
    
    private func runTest() {
        guard !testInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        result = nil
        
        Task {
            let debugResult = await chatViewModel.chatService.debugExtractAndFetch(userMessage: testInput)
            result = debugResult
            isLoading = false
        }
    }
}

#Preview {
    AIDebugView(todoViewModel: .preview, chatViewModel: ChatViewModel())
}
