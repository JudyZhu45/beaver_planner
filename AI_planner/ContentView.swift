//
//  ContentView.swift
//  AI_planner
//
//  Created by Judy459 on 2/19/26.
//

import SwiftUI

struct ContentView: View {
    var authManager: AuthManager
    @State private var selectedTab = 0
    @StateObject private var todoViewModel = TodoViewModel()
    @State private var showAddEventSheet = false
    @State private var showAddTodoSheet = false
    @State private var showFabMenu = false
    @State private var fabOffset = CGSize.zero
    @State private var fabPosition = CGPoint(x: UIScreen.main.bounds.width - 48, y: 60)
    
    var body: some View {
        ZStack {
            // Background
            AppTheme.bgPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Tab content
                if selectedTab == 0 {
                    TodayView(viewModel: todoViewModel)
                } else if selectedTab == 1 {
                    CalendarView(viewModel: todoViewModel)
                } else if selectedTab == 2 {
                    AIChatView(viewModel: todoViewModel)
                } else {
                    NavigationStack {
                        ProfileView(authManager: authManager, viewModel: todoViewModel)
                    }
                }
                
                // Custom Tab Bar
                CustomTabBar(selectedTab: $selectedTab)
            }
            
            // Draggable Floating Action Button
            ZStack {
                // Dim overlay when menu is open
                if showFabMenu {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showFabMenu = false
                            }
                        }
                }
                
                // Menu options (appear above FAB)
                if showFabMenu {
                    VStack(spacing: AppTheme.Spacing.sm) {
                        // Todo option
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showFabMenu = false
                            }
                            showAddTodoSheet = true
                        } label: {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("To Do")
                                    .font(AppTheme.Typography.titleMedium)
                            }
                            .foregroundColor(AppTheme.textInverse)
                            .padding(.horizontal, AppTheme.Spacing.lg)
                            .padding(.vertical, AppTheme.Spacing.md)
                            .background(AppTheme.secondaryTeal)
                            .clipShape(Capsule())
                            .shadow(color: AppTheme.secondaryTeal.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.5).combined(with: .opacity).combined(with: .offset(y: 20)),
                            removal: .scale(scale: 0.5).combined(with: .opacity)
                        ))
                        
                        // Event option
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showFabMenu = false
                            }
                            showAddEventSheet = true
                        } label: {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Event")
                                    .font(AppTheme.Typography.titleMedium)
                            }
                            .foregroundColor(AppTheme.textInverse)
                            .padding(.horizontal, AppTheme.Spacing.lg)
                            .padding(.vertical, AppTheme.Spacing.md)
                            .background(AppTheme.primaryDeepIndigo)
                            .clipShape(Capsule())
                            .shadow(color: AppTheme.primaryDeepIndigo.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.5).combined(with: .opacity).combined(with: .offset(y: 10)),
                            removal: .scale(scale: 0.5).combined(with: .opacity)
                        ))
                    }
                    .position(x: fabPosition.x, y: fabPosition.y - 80)
                }
                
                // FAB button
                Image(systemName: showFabMenu ? "xmark" : "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.textInverse)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                showFabMenu ? AppTheme.textSecondary : AppTheme.primaryDeepIndigo,
                                showFabMenu ? AppTheme.textSecondary.opacity(0.8) : AppTheme.primaryDeepIndigo.opacity(0.8)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: AppTheme.primaryDeepIndigo.opacity(0.4), radius: 12, x: 0, y: 6)
                    .rotationEffect(.degrees(showFabMenu ? 45 : 0))
                    .position(x: fabPosition.x + fabOffset.width, y: fabPosition.y + fabOffset.height)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if !showFabMenu {
                                    fabOffset = value.translation
                                }
                            }
                            .onEnded { value in
                                guard !showFabMenu else { return }
                                fabPosition.x += value.translation.width
                                fabPosition.y += value.translation.height
                                fabOffset = .zero
                                
                                // Snap to screen edges
                                let screenWidth = UIScreen.main.bounds.width
                                let screenHeight = UIScreen.main.bounds.height
                                let padding: CGFloat = 48
                                
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    // Snap to nearest horizontal edge
                                    fabPosition.x = fabPosition.x < screenWidth / 2 ? padding : screenWidth - padding
                                    // Clamp vertical position
                                    fabPosition.y = max(60, min(screenHeight - 140, fabPosition.y))
                                }
                            }
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showFabMenu.toggle()
                        }
                    }
            }
            
            // Toast overlay (topmost layer)
            ToastOverlay()
        }
        .sheet(isPresented: $showAddEventSheet) {
            AddEventSheet(viewModel: todoViewModel, isPresented: $showAddEventSheet)
        }
        .sheet(isPresented: $showAddTodoSheet) {
            AddTodoSheet(viewModel: todoViewModel)
        }
        .onChange(of: selectedTab) { _, newValue in
            UserBehaviorStore.shared.recordTabSwitched(to: newValue)
        }
    }
}

#Preview {
    ContentView(authManager: AuthManager())
}
