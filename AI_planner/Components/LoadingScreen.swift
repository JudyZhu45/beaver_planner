//
//  LoadingScreen.swift
//  AI_planner
//
//  Created by AI Assistant on 3/5/26.
//

import SwiftUI

struct LoadingScreen: View {
    @State private var progress: Double = 0
    @State private var loadingTextIndex = 0
    @State private var beaverOffset: CGFloat = 0
    @State private var sparkleRotation: Double = 0
    
    let loadingTexts = [
        "正在唤醒海狸...",
        "整理你的时间...",
        "准备智能建议...",
        "即将就绪..."
    ]
    
    let onComplete: () -> Void
    let minimumLoadTime: Double = 2.5
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    AppTheme.bgPrimary,
                    AppTheme.bgSecondary,
                    AppTheme.bgTertiary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Beaver Logo with animation
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(AppTheme.primaryDeepIndigo.opacity(0.15))
                        .frame(width: 140, height: 140)
                        .blur(radius: 20)
                        .scaleEffect(1 + sin(progress * .pi) * 0.2)
                    
                    // Beaver emoji with bounce
                    Text("🦫")
                        .font(.system(size: 72))
                        .offset(y: beaverOffset)
                        .rotationEffect(.degrees(sin(beaverOffset * 0.5) * 5))
                    
                    // Sparkles
                    HStack(spacing: 40) {
                        Text("✨")
                            .font(.title2)
                            .rotationEffect(.degrees(sparkleRotation))
                            .opacity(0.6 + sin(progress * 4) * 0.4)
                        
                        Spacer().frame(width: 80)
                        
                        Text("✨")
                            .font(.title2)
                            .rotationEffect(.degrees(-sparkleRotation))
                            .opacity(0.6 + cos(progress * 4) * 0.4)
                    }
                }
                .frame(height: 120)
                
                // App Name
                Text("Beaver Planner")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primaryDeepIndigo)
                
                // Tagline
                Text("懂你的时间管家")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                
                Spacer().frame(height: 20)
                
                // Loading text with fade transition
                Text(loadingTexts[loadingTextIndex])
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.primaryDeepIndigo)
                    .id(loadingTextIndex)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .animation(.easeInOut(duration: 0.3), value: loadingTextIndex)
                
                // Progress bar
                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppTheme.borderColor)
                                .frame(height: 8)
                            
                            // Fill with gradient
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.831, green: 0.647, blue: 0.455),
                                            Color(red: 0.769, green: 0.584, blue: 0.416),
                                            AppTheme.primaryDeepIndigo
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progress, height: 8)
                                .animation(.easeOut(duration: 0.2), value: progress)
                        }
                    }
                    .frame(width: 240, height: 8)
                    
                    // Percentage
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(AppTheme.textTertiary)
                }
                
                Spacer()
                
                // Footer quote
                Text("\"勤劳的海狸，聪明地建造\"")
                    .font(.caption)
                    .italic()
                    .foregroundColor(AppTheme.textTertiary)
                    .padding(.bottom, 32)
            }
            .padding()
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Beaver bounce animation
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            beaverOffset = -8
        }
        
        // Sparkle rotation
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            sparkleRotation = 360
        }
        
        // Progress animation
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if progress < 1.0 {
                // Non-linear progress for realism
                let increment = Double.random(in: 0.01...0.04)
                progress = min(progress + increment, 1.0)
            } else {
                timer.invalidate()
            }
        }
        
        // Text cycling
        Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { timer in
            if progress < 1.0 {
                loadingTextIndex = (loadingTextIndex + 1) % loadingTexts.count
            } else {
                timer.invalidate()
            }
        }
        
        // Completion callback
        DispatchQueue.main.asyncAfter(deadline: .now() + minimumLoadTime) {
            withAnimation(.easeInOut(duration: 0.5)) {
                onComplete()
            }
        }
    }
}

#Preview {
    LoadingScreen(onComplete: {})
}
