//
//  ChatMemoryStore.swift
//  AI_planner
//
//  Created by AI Assistant on 3/5/26.
//

import Foundation

// MARK: - User Preference Memory

/// A single preference extracted from conversation
struct UserPreference: Codable, Identifiable {
    let id: UUID
    let category: PreferenceCategory
    let content: String          // The preference itself (Chinese)
    let source: String           // What user said that led to this
    let createdAt: Date
    var confirmedCount: Int      // How many times this preference was reinforced
    
    init(category: PreferenceCategory, content: String, source: String) {
        self.id = UUID()
        self.category = category
        self.content = content
        self.source = source
        self.createdAt = Date()
        self.confirmedCount = 1
    }
}

enum PreferenceCategory: String, Codable {
    case schedule       // 时间偏好: "不喜欢早起", "喜欢下午运动"
    case taskHabit      // 任务习惯: "学习喜欢分段", "健身固定周三周五"
    case lifestyle      // 生活方式: "周末不安排工作", "午休1小时"
    case personality    // 个性化: "喜欢简洁的回复", "不要用太多emoji"
    case constraint     // 约束: "周二周四有课", "每天9点上班"
}

// MARK: - Structured Preferences (from onboarding / manual editing)

struct StructuredPreferences: Codable {
    var wakeUpTime: Date?
    var workStartTime: Date?
    var workEndTime: Date?
    var hasLunchBreak: Bool
    var preferredEventTypes: [String]   // e.g. ["Gym", "Study Session"]
    var preferredDuration: String?      // "short" / "medium" / "long"
    var weekendPreference: String?      // "rest" / "work" / "flexible"
    var constraints: String?            // Free-form text
    
    init() {
        self.hasLunchBreak = false
        self.preferredEventTypes = []
    }
}

// MARK: - Chat Memory Store

class ChatMemoryStore {
    static let shared = ChatMemoryStore()
    
    private let storageKey = "ChatMemoryPreferences"
    private let structuredKey = "StructuredUserPreferences"
    private let maxPreferences = 30
    
    private(set) var preferences: [UserPreference] = []
    private(set) var structuredPreferences = StructuredPreferences()
    
    private init() {
        loadPreferences()
        loadStructuredPreferences()
    }
    
    // MARK: - Add Preference
    
    func addPreference(_ preference: UserPreference) {
        // Check for duplicates — if similar preference exists, reinforce it
        if let existingIndex = preferences.firstIndex(where: {
            $0.category == preference.category && isSimilar($0.content, preference.content)
        }) {
            preferences[existingIndex].confirmedCount += 1
            savePreferences()
            return
        }
        
        preferences.append(preference)
        
        // Trim oldest if over limit
        if preferences.count > maxPreferences {
            preferences.sort { $0.confirmedCount > $1.confirmedCount }
            preferences = Array(preferences.prefix(maxPreferences))
        }
        
        savePreferences()
    }
    
    /// Remove a preference by ID
    func removePreference(id: UUID) {
        preferences.removeAll { $0.id == id }
        savePreferences()
    }
    
    // MARK: - Query
    
    func preferences(for category: PreferenceCategory) -> [UserPreference] {
        preferences.filter { $0.category == category }
    }
    
    /// Generate a concise summary for AI system prompt injection
    func generateMemorySummary() -> String {
        var lines: [String] = []
        
        // 1. Structured preferences (from onboarding / manual settings)
        let sp = structuredPreferences
        var structuredLines: [String] = []
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        if let wake = sp.wakeUpTime {
            structuredLines.append("- [时间偏好] 起床时间：\(formatter.string(from: wake))")
        }
        if let start = sp.workStartTime, let end = sp.workEndTime {
            structuredLines.append("- [固定约束] 工作/上课时间：\(formatter.string(from: start))-\(formatter.string(from: end))")
        }
        if sp.hasLunchBreak {
            structuredLines.append("- [时间偏好] 用户有午休习惯")
        }
        if !sp.preferredEventTypes.isEmpty {
            structuredLines.append("- [任务习惯] 常做的任务类型：\(sp.preferredEventTypes.joined(separator: "、"))")
        }
        if let duration = sp.preferredDuration {
            let durationText: String
            switch duration {
            case "short": durationText = "短时任务（30分钟以内）"
            case "medium": durationText = "中等时长（30-60分钟）"
            case "long": durationText = "长时任务（1小时以上）"
            default: durationText = duration
            }
            structuredLines.append("- [任务习惯] 偏好任务时长：\(durationText)")
        }
        if let weekend = sp.weekendPreference {
            let weekendText: String
            switch weekend {
            case "rest": weekendText = "周末以休息为主，不安排工作"
            case "work": weekendText = "周末也会安排工作/学习"
            case "flexible": weekendText = "周末灵活安排"
            default: weekendText = weekend
            }
            structuredLines.append("- [生活方式] \(weekendText)")
        }
        if let constraints = sp.constraints, !constraints.isEmpty {
            structuredLines.append("- [固定约束] \(constraints)")
        }
        
        if !structuredLines.isEmpty {
            lines.append("用户自定义偏好设置：")
            lines.append(contentsOf: structuredLines)
        }
        
        // 2. Chat-extracted preferences
        if !preferences.isEmpty {
            if !lines.isEmpty { lines.append("") }
            lines.append("用户偏好记忆（从历史对话中提取）：")
            
            let grouped = Dictionary(grouping: preferences, by: \.category)
            let categoryOrder: [PreferenceCategory] = [.constraint, .schedule, .taskHabit, .lifestyle, .personality]
            
            for category in categoryOrder {
                guard let prefs = grouped[category], !prefs.isEmpty else { continue }
                let label = categoryLabel(category)
                let sorted = prefs.sorted { $0.confirmedCount > $1.confirmedCount }
                for pref in sorted.prefix(3) {
                    let reinforced = pref.confirmedCount > 1 ? "（多次提及）" : ""
                    lines.append("- [\(label)] \(pref.content)\(reinforced)")
                }
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Extract Preferences from Conversation
    
    /// Analyze user message and extract potential preferences
    func extractPreferences(from userMessage: String, aiResponse: String) {
        let message = userMessage.lowercased()
        
        // Schedule preferences
        let schedulePatterns: [(pattern: String, extractor: (String) -> String?)] = [
            ("不喜欢早起", { _ in "用户不喜欢早起，避免安排早上8点前的任务" }),
            ("不要.*早上", { _ in "用户不想在早上安排任务" }),
            ("喜欢.*早起", { _ in "用户喜欢早起，可以安排早间任务" }),
            ("晚上.*不要", { _ in "用户晚上不想被安排任务" }),
            ("午休", { _ in "用户有午休习惯，中午12-14点不安排任务" }),
            ("午睡", { _ in "用户有午睡习惯，中午不安排任务" }),
        ]
        
        for (pattern, extractor) in schedulePatterns {
            if matchesPattern(message, pattern: pattern), let content = extractor(message) {
                addPreference(UserPreference(category: .schedule, content: content, source: userMessage))
            }
        }
        
        // Constraint patterns
        let constraintPatterns: [(pattern: String, extractor: (String) -> String?)] = [
            ("周[一二三四五六日].*有课", { msg in extractConstraint(msg, prefix: "用户") }),
            ("每天.*点.*[上下]班", { msg in extractConstraint(msg, prefix: "用户") }),
            ("每周[一二三四五六日]", { msg in extractWeeklyPattern(msg) }),
            ("固定.*时间", { msg in extractConstraint(msg, prefix: "用户有固定安排：") }),
        ]
        
        for (pattern, extractor) in constraintPatterns {
            if matchesPattern(message, pattern: pattern), let content = extractor(userMessage) {
                addPreference(UserPreference(category: .constraint, content: content, source: userMessage))
            }
        }
        
        // Task habit patterns
        let habitPatterns: [(pattern: String, extractor: (String) -> String?)] = [
            ("学习.*分[段钟]", { _ in "用户学习时喜欢分段进行" }),
            ("喜欢.*[一1]个小时", { _ in "用户偏好1小时的任务时长" }),
            ("不要.*太长", { _ in "用户不喜欢安排太长时间的单个任务" }),
            ("番茄", { _ in "用户使用番茄工作法，建议25分钟学习+5分钟休息" }),
        ]
        
        for (pattern, extractor) in habitPatterns {
            if matchesPattern(message, pattern: pattern), let content = extractor(message) {
                addPreference(UserPreference(category: .taskHabit, content: content, source: userMessage))
            }
        }
        
        // Lifestyle patterns
        let lifestylePatterns: [(pattern: String, extractor: (String) -> String?)] = [
            ("周末.*不.*[工作学习上班]", { _ in "用户周末不想安排工作/学习" }),
            ("周末.*休息", { _ in "用户周末以休息为主" }),
            ("周末.*[运动健身]", { _ in "用户周末喜欢运动/健身" }),
        ]
        
        for (pattern, extractor) in lifestylePatterns {
            if matchesPattern(message, pattern: pattern), let content = extractor(message) {
                addPreference(UserPreference(category: .lifestyle, content: content, source: userMessage))
            }
        }
    }
    
    // MARK: - Structured Preferences Management
    
    /// Save structured preferences from onboarding or manual editing
    func setStructuredPreferences(_ prefs: StructuredPreferences) {
        structuredPreferences = prefs
        saveStructuredPreferences()
    }
    
    /// Get current structured preferences for pre-populating UI
    func getStructuredPreferences() -> StructuredPreferences {
        return structuredPreferences
    }
    
    /// Clear all preferences (both structured and chat-extracted)
    func clearAll() {
        preferences.removeAll()
        structuredPreferences = StructuredPreferences()
        savePreferences()
        saveStructuredPreferences()
    }
    
    private func saveStructuredPreferences() {
        if let encoded = try? JSONEncoder().encode(structuredPreferences) {
            UserDefaults.standard.set(encoded, forKey: structuredKey)
        }
    }
    
    private func loadStructuredPreferences() {
        if let data = UserDefaults.standard.data(forKey: structuredKey),
           let decoded = try? JSONDecoder().decode(StructuredPreferences.self, from: data) {
            structuredPreferences = decoded
        }
    }
    
    // MARK: - Helpers
    
    private func matchesPattern(_ text: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text.contains(pattern)
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
    
    private func isSimilar(_ a: String, _ b: String) -> Bool {
        // Simple similarity: check if one contains the other or they share > 50% characters
        if a.contains(b) || b.contains(a) { return true }
        let setA = Set(a)
        let setB = Set(b)
        let intersection = setA.intersection(setB)
        let union = setA.union(setB)
        return !union.isEmpty && Double(intersection.count) / Double(union.count) > 0.7
    }
    
    private func categoryLabel(_ category: PreferenceCategory) -> String {
        switch category {
        case .schedule: return "时间偏好"
        case .taskHabit: return "任务习惯"
        case .lifestyle: return "生活方式"
        case .personality: return "个性化"
        case .constraint: return "固定约束"
        }
    }
    
    private func savePreferences() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([UserPreference].self, from: data) {
            preferences = decoded
        }
    }
}

// MARK: - Free Functions for Pattern Extraction

private func extractConstraint(_ message: String, prefix: String) -> String? {
    // Just return the user's message as the constraint description
    let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if trimmed.count > 50 {
        return "\(prefix)\(String(trimmed.prefix(50)))..."
    }
    return "\(prefix)\(trimmed)"
}

private func extractWeeklyPattern(_ message: String) -> String? {
    let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return "用户的周计划习惯：\(trimmed.count > 50 ? String(trimmed.prefix(50)) + "..." : trimmed)"
}
