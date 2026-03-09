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
    let content: String          // The preference itself
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
    case schedule       // Schedule preferences: "doesn't like waking early", "prefers afternoon exercise"
    case taskHabit      // Task habits: "likes segmented study", "gym on Wed/Fri"
    case lifestyle      // Lifestyle: "no work on weekends", "1-hour lunch break"
    case personality    // Personality: "prefers concise replies", "don't use too many emojis"
    case constraint     // Constraints: "has class Tue/Thu", "work starts at 9 AM"
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
            structuredLines.append("- [Schedule] Wake-up time: \(formatter.string(from: wake))")
        }
        if let start = sp.workStartTime, let end = sp.workEndTime {
            structuredLines.append("- [Constraint] Work/class hours: \(formatter.string(from: start))-\(formatter.string(from: end))")
        }
        if sp.hasLunchBreak {
            structuredLines.append("- [Schedule] User takes a lunch break")
        }
        if !sp.preferredEventTypes.isEmpty {
            structuredLines.append("- [Task Habit] Frequently scheduled types: \(sp.preferredEventTypes.joined(separator: ", "))")
        }
        if let duration = sp.preferredDuration {
            let durationText: String
            switch duration {
            case "short": durationText = "Short tasks (under 30 min)"
            case "medium": durationText = "Medium tasks (30–60 min)"
            case "long": durationText = "Long tasks (over 1 hour)"
            default: durationText = duration
            }
            structuredLines.append("- [Task Habit] Preferred task duration: \(durationText)")
        }
        if let weekend = sp.weekendPreference {
            let weekendText: String
            switch weekend {
            case "rest": weekendText = "Weekends are for rest — no work scheduled"
            case "work": weekendText = "Weekends include work/study"
            case "flexible": weekendText = "Weekends are flexible"
            default: weekendText = weekend
            }
            structuredLines.append("- [Lifestyle] \(weekendText)")
        }
        if let constraints = sp.constraints, !constraints.isEmpty {
            structuredLines.append("- [Constraint] \(constraints)")
        }
        
        if !structuredLines.isEmpty {
            lines.append("User Preferences:")
            lines.append(contentsOf: structuredLines)
        }
        
        // 2. Chat-extracted preferences
        if !preferences.isEmpty {
            if !lines.isEmpty { lines.append("") }
            lines.append("User Preference Memory (extracted from chat history):")
            
            let grouped = Dictionary(grouping: preferences, by: \.category)
            let categoryOrder: [PreferenceCategory] = [.constraint, .schedule, .taskHabit, .lifestyle, .personality]
            
            for category in categoryOrder {
                guard let prefs = grouped[category], !prefs.isEmpty else { continue }
                let label = categoryLabel(category)
                let sorted = prefs.sorted { $0.confirmedCount > $1.confirmedCount }
                for pref in sorted.prefix(3) {
                    let reinforced = pref.confirmedCount > 1 ? " (mentioned multiple times)" : ""
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
            ("don'?t.*like.*early", { _ in "User doesn't like waking up early — avoid scheduling tasks before 8 AM" }),
            ("no.*morning", { _ in "User doesn't want tasks scheduled in the morning" }),
            ("(like|prefer).*early", { _ in "User likes waking up early — morning tasks are OK" }),
            ("no.*(evening|night)", { _ in "User doesn't want tasks scheduled in the evening" }),
            ("lunch.*break", { _ in "User takes a lunch break — don't schedule tasks 12–2 PM" }),
            ("(nap|afternoon.*rest)", { _ in "User takes afternoon naps — don't schedule midday tasks" }),
        ]
        
        for (pattern, extractor) in schedulePatterns {
            if matchesPattern(message, pattern: pattern), let content = extractor(message) {
                addPreference(UserPreference(category: .schedule, content: content, source: userMessage))
            }
        }
        
        // Constraint patterns
        let constraintPatterns: [(pattern: String, extractor: (String) -> String?)] = [
            ("(have|has).*class.*(mon|tue|wed|thu|fri|sat|sun)", { msg in extractConstraint(msg, prefix: "User") }),
            ("work.*(from|at).*\\d", { msg in extractConstraint(msg, prefix: "User") }),
            ("every.*(mon|tue|wed|thu|fri|sat|sun)", { msg in extractWeeklyPattern(msg) }),
            ("fixed.*schedule", { msg in extractConstraint(msg, prefix: "User has a fixed schedule: ") }),
        ]
        
        for (pattern, extractor) in constraintPatterns {
            if matchesPattern(message, pattern: pattern), let content = extractor(userMessage) {
                addPreference(UserPreference(category: .constraint, content: content, source: userMessage))
            }
        }
        
        // Task habit patterns
        let habitPatterns: [(pattern: String, extractor: (String) -> String?)] = [
            ("study.*(segment|chunk|block)", { _ in "User prefers studying in shorter segments" }),
            ("(like|prefer).*1.*hour", { _ in "User prefers 1-hour task durations" }),
            ("(don'?t|no).*too.*long", { _ in "User doesn't like long individual tasks" }),
            ("pomodoro", { _ in "User uses the Pomodoro technique — 25 min work + 5 min break" }),
        ]
        
        for (pattern, extractor) in habitPatterns {
            if matchesPattern(message, pattern: pattern), let content = extractor(message) {
                addPreference(UserPreference(category: .taskHabit, content: content, source: userMessage))
            }
        }
        
        // Lifestyle patterns
        let lifestylePatterns: [(pattern: String, extractor: (String) -> String?)] = [
            ("weekend.*(no|don'?t).*(work|study)", { _ in "User doesn't want work/study scheduled on weekends" }),
            ("weekend.*rest", { _ in "User prefers to rest on weekends" }),
            ("weekend.*(exercise|gym|workout)", { _ in "User likes to exercise/work out on weekends" }),
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
        case .schedule: return "Schedule"
        case .taskHabit: return "Task Habit"
        case .lifestyle: return "Lifestyle"
        case .personality: return "Personality"
        case .constraint: return "Constraint"
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
    return "User's weekly schedule habit: \(trimmed.count > 50 ? String(trimmed.prefix(50)) + "..." : trimmed)"
}
