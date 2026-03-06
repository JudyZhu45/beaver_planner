//
//  DemoView.swift
//  AI_planner
//
//  Created by AI Assistant on 3/5/26.
//  演示新组件的使用方法
//

import SwiftUI

struct DemoView: View {
    @State private var showLoading = true
    @State private var selectedTab = 0
    @State private var celebrateTask = false
    @State private var celebrateCalendar = false
    
    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("🦫 Beaver Planner")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.primaryDeepIndigo)
                    
                    Spacer()
                    
                    Button("重新加载") {
                        showLoading = true
                    }
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryTeal)
                }
                .padding()
                .background(AppTheme.bgSecondary)
                
                // Tab selector
                Picker("", selection: $selectedTab) {
                    Text("📝 任务").tag(0)
                    Text("📅 日历").tag(1)
                    Text("📊 分析").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content area
                TabView(selection: $selectedTab) {
                    // Tasks tab
                    EmptyStateView(type: .tasks) {
                        celebrateTask = true
                    }
                    .tag(0)
                    
                    // Calendar tab
                    EmptyStateView(type: .calendar) {
                        celebrateCalendar = true
                    }
                    .tag(1)
                    
                    // Analytics tab
                    EmptyStateView(type: .analytics) {
                        celebrateCalendar = true
                    }
                    .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Text("✨ 本次更新内容")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• LoadingScreen - 启动页动画")
                        Text("• EmptyStateView - 空状态设计")
                        Text("• CelebrationView - 完成庆祝动效")
                    }
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.bgElevated)
                .cornerRadius(12)
                .padding()
            }
            
            // Loading screen overlay
            if showLoading {
                LoadingScreen {
                    showLoading = false
                }
                .transition(.opacity)
            }
        }
        // Celebration overlays
        .celebration(isActive: $celebrateTask)
        .celebration(isActive: $celebrateCalendar)
    }
}

#Preview {
    DemoView()
}
