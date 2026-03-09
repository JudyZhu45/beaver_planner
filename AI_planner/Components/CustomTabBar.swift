//
//  CustomTabBar.swift
//  AI_planner
//
//  Created by Judy459 on 2/19/26.
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TabBarItem(
                    icon: "clock.fill",
                    label: "Today",
                    isSelected: selectedTab == 0,
                    action: { 
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = 0 
                        }
                    }
                )
                
                Spacer()
                
                TabBarItem(
                    icon: "calendar.circle.fill",
                    label: "Calendar",
                    isSelected: selectedTab == 1,
                    action: { 
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = 1 
                        }
                    }
                )
                
                Spacer()
                
                TabBarItem(
                    icon: "sparkles",
                    label: "AI Chat",
                    isSelected: selectedTab == 2,
                    action: { 
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = 2 
                        }
                    }
                )
                
                Spacer()
                
                TabBarItem(
                    icon: "person.circle.fill",
                    label: "Profile",
                    isSelected: selectedTab == 3,
                    action: { 
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = 3 
                        }
                    }
                )
                
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.lg)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AppTheme.bgElevated.opacity(0.92))
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(AppTheme.borderColor.opacity(0.9), lineWidth: 1)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: AppTheme.Shadows.md.color, radius: AppTheme.Shadows.md.radius, x: AppTheme.Shadows.md.x, y: AppTheme.Shadows.md.y)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.sm)
        }
        .background(Color.clear)
    }
}

#Preview {
    CustomTabBar(selectedTab: .constant(0))
}
