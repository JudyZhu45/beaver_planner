//
//  AI_plannerApp.swift
//  AI_planner
//
//  Created by Judy459 on 2/19/26.
//

import SwiftUI
import Amplify
import AWSCognitoAuthPlugin

@main
struct AI_plannerApp: App {
    @State private var authManager = AuthManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    init() {
        configureAmplify()
    }
    
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
                    if hasCompletedOnboarding {
                        ContentView(authManager: authManager)
                    } else {
                        OnboardingView {
                            hasCompletedOnboarding = true
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
    
    private func configureAmplify() {
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.configure()
        } catch {
            print("Failed to configure Amplify: \(error)")
        }
    }
}
