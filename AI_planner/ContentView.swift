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
    @StateObject private var chatViewModel = ChatViewModel()

    
    var body: some View {
        ZStack {
            backgroundLayer
            
            VStack(spacing: 0) {
                contentLayer
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(.easeInOut(duration: 0.25), value: selectedTab)
                
                CustomTabBar(selectedTab: $selectedTab)
            }
            
            ToastOverlay()
        }
        .onChange(of: selectedTab) { _, newValue in
            UserBehaviorStore.shared.recordTabSwitched(to: newValue)
        }
        .onAppear {
            chatViewModel.configure(with: todoViewModel)
        }
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                AppTheme.bgSecondary,
                AppTheme.bgPrimary,
                AppTheme.bgTertiary.opacity(0.52)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            RadialGradient(
                colors: [
                    AppTheme.accentLavender.opacity(0.16),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 320
            )
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var contentLayer: some View {
        ZStack {
            switch selectedTab {
            case 0:
                TodayView(viewModel: todoViewModel)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            case 1:
                CalendarView(viewModel: todoViewModel)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            case 2:
                AIChatView(viewModel: todoViewModel, chatViewModel: chatViewModel)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            case 3:
                NavigationStack {
                    ProfileView(authManager: authManager, viewModel: todoViewModel)
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            default:
                EmptyView()
            }
        }
    }


}

#Preview {
    ContentView(authManager: AuthManager())
}
