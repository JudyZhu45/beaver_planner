//
//  DemoView.swift
//  AI_planner
//
//  Created by AI Assistant on 3/5/26.
//  Demo view for new components
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
                    
                    Button("Reload") {
                        showLoading = true
                    }
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryTeal)
                }
                .padding()
                .background(AppTheme.bgSecondary)
                
                // Tab selector
                Picker("", selection: $selectedTab) {
                    Text("📝 Tasks").tag(0)
                    Text("📅 Calendar").tag(1)
                    Text("📊 Analytics").tag(2)
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
                    Text("✨ What's New")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• LoadingScreen - Launch animation")
                        Text("• EmptyStateView - Empty state design")
                        Text("• CelebrationView - Completion celebration effect")
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
