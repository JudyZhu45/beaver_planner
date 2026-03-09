//
//  ToastManager.swift
//  AI_planner
//
//  Created by Judy459 on 3/4/26.
//

import SwiftUI
import Observation

enum ToastType {
    case success
    case error
    case warning
    case info
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var assetIcon: String? {
        switch self {
        case .success: return "beaver-success"
        case .error: return "beaver-error"
        default: return nil
        }
    }
    
    var color: Color {
        switch self {
        case .success: return AppTheme.secondaryTeal
        case .error: return AppTheme.accentCoral
        case .warning: return Color(red: 0.820, green: 0.650, blue: 0.380) // Honey Gold
        case .info: return AppTheme.primaryDeepIndigo
        }
    }
}

struct ToastMessage: Identifiable {
    let id = UUID()
    let message: String
    let type: ToastType
    var undoAction: (() -> Void)?
}

@Observable
class ToastManager {
    static let shared = ToastManager()
    
    var currentToast: ToastMessage?
    private var dismissTask: DispatchWorkItem?
    
    private init() {}
    
    func show(_ message: String, type: ToastType = .success, undoAction: (() -> Void)? = nil) {
        // Cancel any pending dismissal
        dismissTask?.cancel()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentToast = ToastMessage(message: message, type: type, undoAction: undoAction)
        }
        
        // Auto-dismiss after duration (longer if undo is available)
        let duration: Double = undoAction != nil ? 4.0 : 2.0
        let task = DispatchWorkItem { [weak self] in
            withAnimation(.easeOut(duration: 0.3)) {
                self?.currentToast = nil
            }
        }
        dismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
    }
    
    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.3)) {
            currentToast = nil
        }
    }
}
