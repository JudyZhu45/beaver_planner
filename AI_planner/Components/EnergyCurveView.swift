//
//  EnergyCurveView.swift
//  AI_planner
//
//  Created by Judy459 on 3/3/26.
//

import SwiftUI

struct EnergyCurveView: View {
    let profile: EnergyProfile
    
    private let chartHeight: CGFloat = 160
    private let labelWidth: CGFloat = 28
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Energy Curve", icon: "bolt.fill")
                .padding(.horizontal, AppTheme.Spacing.lg)
            
            if profile.hasSufficientData {
                chartContent
            } else {
                insufficientDataPlaceholder
            }
        }
    }
    
    // MARK: - Chart Content
    
    private var chartContent: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            // Peak & Valley summary
            HStack(spacing: AppTheme.Spacing.lg) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Circle()
                        .fill(AppTheme.accentCoral)
                        .frame(width: 8, height: 8)
                    Text("Peak: \(hourLabel(profile.peakHour))")
                        .font(AppTheme.Typography.labelLarge)
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                HStack(spacing: AppTheme.Spacing.xs) {
                    Circle()
                        .fill(AppTheme.primaryDeepIndigo.opacity(0.5))
                        .frame(width: 8, height: 8)
                    Text("Low: \(hourLabel(profile.valleyHour))")
                        .font(AppTheme.Typography.labelLarge)
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                Spacer()
            }
            
            // The chart
            GeometryReader { geo in
                let chartWidth = geo.size.width
                
                ZStack(alignment: .topLeading) {
                    // Horizontal grid lines
                    ForEach([0.25, 0.5, 0.75], id: \.self) { level in
                        Path { path in
                            let y = chartHeight * (1.0 - level)
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: chartWidth, y: y))
                        }
                        .stroke(AppTheme.borderColor, style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    }
                    
                    // Gradient fill under curve
                    EnergyCurveFillShape(dataPoints: profile.dataPoints, chartWidth: chartWidth, chartHeight: chartHeight)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.secondaryTeal.opacity(0.25),
                                    AppTheme.secondaryTeal.opacity(0.03)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // The curve line
                    EnergyCurveLineShape(dataPoints: profile.dataPoints, chartWidth: chartWidth, chartHeight: chartHeight)
                        .stroke(
                            LinearGradient(
                                colors: [AppTheme.secondaryTeal, AppTheme.primaryDeepIndigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )
                    
                    // Peak marker
                    peakMarker(chartWidth: chartWidth)
                    
                    // Valley marker
                    valleyMarker(chartWidth: chartWidth)
                }
            }
            .frame(height: chartHeight)
            
            // Hour labels
            hourLabels
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                .stroke(AppTheme.borderColor, lineWidth: 1)
        )
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
    
    // MARK: - Markers
    
    private func peakMarker(chartWidth: CGFloat) -> some View {
        let x = (CGFloat(profile.peakHour) / 23.0) * chartWidth
        let y = chartHeight * (1.0 - profile.dataPoints[profile.peakHour].value)
        
        return VStack(spacing: 2) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(AppTheme.accentCoral)
            
            Circle()
                .fill(AppTheme.accentCoral)
                .frame(width: 8, height: 8)
                .shadow(color: AppTheme.accentCoral.opacity(0.4), radius: 4)
        }
        .position(x: x, y: max(16, y - 6))
    }
    
    private func valleyMarker(chartWidth: CGFloat) -> some View {
        let x = (CGFloat(profile.valleyHour) / 23.0) * chartWidth
        let y = chartHeight * (1.0 - profile.dataPoints[profile.valleyHour].value)
        
        return VStack(spacing: 2) {
            Circle()
                .fill(AppTheme.primaryDeepIndigo.opacity(0.5))
                .frame(width: 8, height: 8)
                .shadow(color: AppTheme.primaryDeepIndigo.opacity(0.3), radius: 4)
            
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(AppTheme.primaryDeepIndigo.opacity(0.5))
        }
        .position(x: x, y: min(chartHeight - 16, y + 6))
    }
    
    // MARK: - Hour Labels
    
    private var hourLabels: some View {
        HStack {
            ForEach([0, 6, 12, 18, 23], id: \.self) { hour in
                if hour > 0 { Spacer() }
                Text(hourLabel(hour))
                    .font(AppTheme.Typography.labelSmall)
                    .foregroundColor(AppTheme.textTertiary)
                if hour < 23 { Spacer() }
            }
        }
    }
    
    private func hourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12a" }
        if hour == 12 { return "12p" }
        if hour < 12 { return "\(hour)a" }
        return "\(hour - 12)p"
    }
    
    // MARK: - Insufficient Data Placeholder
    
    private var insufficientDataPlaceholder: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 32))
                .foregroundColor(AppTheme.textTertiary)
            
            Text("Complete more tasks to see your energy curve")
                .font(AppTheme.Typography.bodySmall)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                .stroke(AppTheme.borderColor, lineWidth: 1)
        )
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
}

// MARK: - Curve Line Shape (Catmull-Rom spline)

struct EnergyCurveLineShape: Shape {
    let dataPoints: [EnergyDataPoint]
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    
    func path(in rect: CGRect) -> Path {
        guard dataPoints.count >= 2 else { return Path() }
        
        let points = dataPoints.map { point in
            CGPoint(
                x: (CGFloat(point.hour) / 23.0) * chartWidth,
                y: chartHeight * (1.0 - point.value)
            )
        }
        
        var path = Path()
        path.move(to: points[0])
        
        for i in 1..<points.count {
            let p0 = points[max(0, i - 2)]
            let p1 = points[i - 1]
            let p2 = points[i]
            let p3 = points[min(points.count - 1, i + 1)]
            
            // Catmull-Rom to cubic bezier conversion
            let cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6.0,
                y: p1.y + (p2.y - p0.y) / 6.0
            )
            let cp2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6.0,
                y: p2.y - (p3.y - p1.y) / 6.0
            )
            
            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }
        
        return path
    }
}

// MARK: - Curve Fill Shape (closed path under curve)

struct EnergyCurveFillShape: Shape {
    let dataPoints: [EnergyDataPoint]
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = EnergyCurveLineShape(
            dataPoints: dataPoints,
            chartWidth: chartWidth,
            chartHeight: chartHeight
        ).path(in: rect)
        
        // Close along the bottom
        let lastX = (CGFloat(dataPoints.last?.hour ?? 23) / 23.0) * chartWidth
        path.addLine(to: CGPoint(x: lastX, y: chartHeight))
        path.addLine(to: CGPoint(x: 0, y: chartHeight))
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    let profile = EnergyProfile(
        dataPoints: (0..<24).map { hour in
            // Simulated energy curve: peak around 10am, dip at 2pm, second peak at 4pm
            let value: Double = {
                let x = Double(hour)
                let morning = exp(-pow(x - 10, 2) / 8.0)
                let afternoon = 0.7 * exp(-pow(x - 16, 2) / 10.0)
                let dip = -0.3 * exp(-pow(x - 14, 2) / 4.0)
                return max(0, min(1, (morning + afternoon + dip)))
            }()
            return EnergyDataPoint(hour: hour, value: value)
        },
        peakHour: 10,
        valleyHour: 14,
        hasSufficientData: true,
        efficientSlots: [10, 11, 16],
        procrastinationSlots: [14, 15]
    )
    
    ScrollView {
        VStack(spacing: AppTheme.Spacing.lg) {
            EnergyCurveView(profile: profile)
            
            // Test insufficient data
            EnergyCurveView(profile: EnergyProfile(
                dataPoints: (0..<24).map { EnergyDataPoint(hour: $0, value: 0) },
                peakHour: 12,
                valleyHour: 6,
                hasSufficientData: false,
                efficientSlots: [],
                procrastinationSlots: []
            ))
        }
        .padding(.vertical, AppTheme.Spacing.lg)
    }
    .background(AppTheme.bgPrimary)
}
