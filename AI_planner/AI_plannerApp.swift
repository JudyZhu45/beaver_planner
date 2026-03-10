//
//  AI_plannerApp.swift
//  AI_planner
//
//  Created by Judy459 on 2/19/26.
//

import SwiftUI

@main
struct AI_plannerApp: App {
    @State private var authManager = AuthManager()
    @StateObject private var profileManager = ProfileManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoading {
                    // Splash / loading screen
                    ZStack {
                        AppTheme.bgPrimary
                            .ignoresSafeArea()
                        
                        VStack(spacing: AppTheme.Spacing.lg) {
                            Image("beaver-loading")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                            
                            Text("AI Planner")
                                .font(AppTheme.Typography.headlineLarge)
                                .foregroundColor(AppTheme.primaryDeepIndigo)
                        }
                    }
                } else if authManager.isSignedIn {
                    if profileManager.hasCompletedOnboarding {
                        ContentView(authManager: authManager)
                    } else {
                        OnboardingView {
                            profileManager.completeOnboarding()
                        }
                    }
                } else {
                    LoginView(authManager: authManager)
                }
            }
            .task {
                _ = await NotificationManager.shared.requestAuthorization()
                UserBehaviorStore.shared.recordAppOpened()
            }
        }
    }
}
