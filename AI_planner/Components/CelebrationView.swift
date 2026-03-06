//
//  CelebrationView.swift
//  AI_planner
//
//  Created by AI Assistant on 3/5/26.
//

import SwiftUI

struct CelebrationView: View {
    @Binding var isActive: Bool
    let onComplete: (() -> Void)?
    
    @State private var particles: [CelebrationParticle] = []
    @State private var showMessage = false
    @State private var scale: CGFloat = 0
    
    let emojis = ["🎉", "✨", "🌟", "💫", "🦫", "🎊", "⭐", "🎈"]
    
    var body: some View {
        ZStack {
            if isActive {
                // Background flash
                AppTheme.primaryDeepIndigo
                    .opacity(0.1)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                // Particles
                ForEach(particles) { particle in
                    Text(particle.emoji)
                        .font(.system(size: particle.size))
                        .position(particle.position)
                        .rotationEffect(.degrees(particle.rotation))
                        .opacity(particle.opacity)
                        .animation(
                            .easeOut(duration: 1.5)
                            .delay(particle.delay),
                            value: particle.position
                        )
                }
                
                // Center celebration
                VStack(spacing: 12) {
                    Text("🎉")
                        .font(.system(size: 64))
                        .scaleEffect(scale)
                    
                    if showMessage {
                        VStack(spacing: 4) {
                            Text("太棒了！又完成一个！")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppTheme.secondaryTeal)
                            
                            Text("海狸为你骄傲 🦫✨")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
            }
        }
        .onChange(of: isActive) { newValue in
            if newValue {
                startCelebration()
            }
        }
    }
    
    private func startCelebration() {
        // Generate particles
        particles = (0..<15).map { i in
            CelebrationParticle(
                id: i,
                emoji: emojis.randomElement()!,
                position: CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY),
                targetPosition: CGPoint(
                    x: UIScreen.main.bounds.midX + CGFloat.random(in: -150...150),
                    y: UIScreen.main.bounds.midY + CGFloat.random(in: -200...100)
                ),
                size: CGFloat.random(in: 20...40),
                rotation: Double.random(in: 0...360),
                delay: Double.random(in: 0...0.3),
                opacity: 1.0
            )
        }
        
        // Animate center scale
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            scale = 1.2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                scale = 1.0
            }
        }
        
        // Show message
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.4)) {
                showMessage = true
            }
        }
        
        // Animate particles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for i in particles.indices {
                DispatchQueue.main.asyncAfter(deadline: .now() + particles[i].delay) {
                    particles[i].position = particles[i].targetPosition
                    particles[i].opacity = 0
                    particles[i].rotation += 180
                }
            }
        }
        
        // Cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                isActive = false
                showMessage = false
                scale = 0
                particles = []
            }
            onComplete?()
        }
    }
}

struct CelebrationParticle: Identifiable {
    let id: Int
    let emoji: String
    var position: CGPoint
    let targetPosition: CGPoint
    let size: CGFloat
    var rotation: Double
    let delay: Double
    var opacity: Double
}

// Usage helper
struct CelebrationModifier: ViewModifier {
    @Binding var isActive: Bool
    let onComplete: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .overlay(
                CelebrationView(isActive: $isActive, onComplete: onComplete)
            )
    }
}

extension View {
    func celebration(isActive: Binding<Bool>, onComplete: (() -> Void)? = nil) -> some View {
        modifier(CelebrationModifier(isActive: isActive, onComplete: onComplete))
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isCelebrating = true
        
        var body: some View {
            ZStack {
                AppTheme.bgPrimary
                    .ignoresSafeArea()
                
                Button("Celebrate") {
                    isCelebrating = true
                }
            }
            .celebration(isActive: $isCelebrating)
        }
    }
    
    return PreviewWrapper()
}
