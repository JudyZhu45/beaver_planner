//
//  ChatMemoryStore.swift
//  AI_planner
//
//  Created by AI Assistant on 3/5/26.
//

import Foundation

// MARK: - User Preference Memory

struct UserPreference: Codable, Identifiable {
    let id: UUID
    var category: PreferenceCategory
    var content: String
    var source: String
    var createdAt: Date
    var updatedAt: Date
    var confirmedCount: Int
    var isTemporary: Bool
    var expiresAt: Date?
    
    init(category: PreferenceCategory, content: String, source: String,
         isTemporary: Bool = false, ttlDays: Int? = nil) {
        self.id = UUID()
        self.category = category
        self.content = content
        self.source = source
        self.createdAt = Date()
        self.updatedAt = Date()
        self.confirmedCount = 1
        self.isTemporary = isTemporary
        if isTemporary {
            self.expiresAt = Calendar.current.date(
                byAdding: .day, value: ttlDays ?? 7, to: Date()
            )
        } else {
            self.expiresAt = nil
        }
    }
    
    // Backward-compatible decoding for existing data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        category = try container.decode(PreferenceCategory.self, forKey: .category)
        content = try container.decode(String.self, forKey: .content)
        source = try container.decode(String.self, forKey: .source)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        confirmedCount = try container.decode(Int.self, forKey: .confirmedCount)
        // New fields — old data may not have these
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        isTemporary = try container.decodeIfPresent(Bool.self, forKey: .isTemporary) ?? false
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
    }
}

enum PreferenceCategory: String, Codable {
    case schedule       // Schedule preferences
    case taskHabit      // Task habits
    case lifestyle      // Lifestyle
    case personality    // Personality / communication style
    case constraint     // Hard constraints
}

// MARK: - Structured Preferences (from onboarding / manual editing)

struct StructuredPreferences: Codable {
    var wakeUpTime: Date?
    var workStartTime: Date?
    var workEndTime: Date?
    var hasLunchBreak: Bool
    var preferredEventTypes: [String]
    var preferredDuration: String?
    var weekendPreference: String?
    var constraints: String?
    
    init() {
        self.hasLunchBreak = false
        self.preferredEventTypes = []
    }
}

// MARK: - AI Extraction Models

private struct AIExtractionResult: Codable {
    let preferences: [ExtractedPreference]
}

private struct ExtractedPreference: Codable {
    let category: String
    let content: String
    let source: String
    let is_temporary: Bool
    let ttl_days: Int?
    let replaces_id: String?
    let reinforces_id: String?
}

// MARK: - Chat Memory Store

class ChatMemoryStore {
    static let shared = ChatMemoryStore()
    
    private let storageKey = "ChatMemoryPreferences"
    private let structuredKey = "StructuredUserPreferences"
    private let maxPreferences = 50
    
    private(set) var preferences: [UserPreference] = []
    private(set) var structuredPreferences = StructuredPreferences()
    
    private init() {
        loadPreferences()
        loadStructuredPreferences()
        purgeExpired()
    }
    
    // MARK: - AI-Based Preference Extraction
    
    /// Call after each conversation turn. Runs asynchronously, does not block chat.
    func extractPreferencesWithAI(
        userMessage: String,
        aiResponse: String
    ) async {
        purgeExpired()
        
        let existingJSON = buildExistingPreferencesJSON()
        
        let prompt = """
        You are a preference extraction engine for a scheduling app.
        
        Analyze the conversation below and extract any user preferences or habits mentioned.
        
        EXISTING PREFERENCES:
        \(existingJSON)
        
        CONVERSATION:
        User: \(userMessage)
        Assistant: \(aiResponse)
        
        Rules:
        1. Output ONLY a JSON object, nothing else.
        2. Extract preferences about: schedule habits, task habits, lifestyle, personality, constraints.
        3. For each preference, determine if it CONFLICTS with an existing one. If so, set "replaces_id" to the id of the old preference.
        4. Determine if the preference is TEMPORARY (exam week, vacation, illness, short-term plan, etc.) or PERMANENT.
        5. For temporary preferences, set ttl_days (default 7, max 30).
        6. If the user CONFIRMS or REINFORCES an existing preference, set "reinforces_id" to its id instead.
        7. If no new preferences found, return {"preferences": []}.
        8. Do NOT extract trivial or one-off requests as preferences (e.g. "schedule a meeting tomorrow" is NOT a preference).
        9. Only extract things that represent recurring habits, constraints, or lasting preferences.
        
        JSON shape:
        {
          "preferences": [
            {
              "category": "schedule|taskHabit|lifestyle|personality|constraint",
              "content": "concise description of the preference",
              "source": "the exact user quote that revealed this",
              "is_temporary": false,
              "ttl_days": null,
              "replaces_id": "UUID string or null",
              "reinforces_id": "UUID string or null"
            }
          ]
        }
        """
        
        let messages = [
            KimiMessage(role: "system", content: prompt),
            KimiMessage(role: "user", content: "Extract preferences from the conversation above.")
        ]
        
        do {
            let raw = try await AIAPIService.shared.sendChat(
                messages: messages, temperature: 0.0
            )
            await MainActor.run {
                processExtractionResult(raw)
            }
        } catch {
            print("[Memory] AI extraction failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Process AI Extraction Result
    
    private func processExtractionResult(_ rawJSON: String) {
        guard let jsonString = extractJSONObject(from: rawJSON),
              let data = jsonString.data(using: .utf8),
              let result = try? JSONDecoder().decode(
                  AIExtractionResult.self, from: data
              ) else {
            print("[Memory] Failed to parse extraction result")
            return
        }
        
        for extracted in result.preferences {
            guard let category = PreferenceCategory(rawValue: extracted.category) else {
                continue
            }
            
            // Case 1: Reinforces existing preference
            if let reinforcesIdStr = extracted.reinforces_id,
               let reinforcesId = UUID(uuidString: reinforcesIdStr),
               let index = preferences.firstIndex(where: { $0.id == reinforcesId }) {
                preferences[index].confirmedCount += 1
                preferences[index].updatedAt = Date()
                // If reinforced enough times, promote temporary to permanent
                if preferences[index].confirmedCount >= 3 && preferences[index].isTemporary {
                    preferences[index].isTemporary = false
                    preferences[index].expiresAt = nil
                }
                savePreferences()
                continue
            }
            
            // Case 2: Replaces conflicting preference
            if let replacesIdStr = extracted.replaces_id,
               let replacesId = UUID(uuidString: replacesIdStr) {
                preferences.removeAll { $0.id == replacesId }
            }
            
            // Case 3: Add new preference
            let newPref = UserPreference(
                category: category,
                content: extracted.content,
                source: extracted.source,
                isTemporary: extracted.is_temporary,
                ttlDays: extracted.ttl_days
            )
            addPreference(newPref)
        }
    }
    
    // MARK: - Add / Remove
    
    func addPreference(_ preference: UserPreference) {
        preferences.append(preference)
        
        if preferences.count > maxPreferences {
            // Remove oldest temporary first, then lowest-confirmed permanent
            let temporary = preferences.filter { $0.isTemporary }
                .sorted { $0.createdAt < $1.createdAt }
            let permanent = preferences.filter { !$0.isTemporary }
                .sorted { $0.confirmedCount < $1.confirmedCount }
            
            let prioritized = permanent + temporary
            preferences = Array(prioritized.suffix(maxPreferences))
        }
        
        savePreferences()
    }
    
    func removePreference(id: UUID) {
        preferences.removeAll { $0.id == id }
        savePreferences()
    }
    
    // MARK: - Purge Expired
    
    func purgeExpired() {
        let now = Date()
        let before = preferences.count
        preferences.removeAll { pref in
            if let expires = pref.expiresAt, expires < now {
                return true
            }
            return false
        }
        if preferences.count != before {
            savePreferences()
        }
    }
    
    // MARK: - Query
    
    func preferences(for category: PreferenceCategory) -> [UserPreference] {
        preferences.filter { $0.category == category }
    }
    
    // MARK: - Generate Memory Summary for System Prompt
    
    func generateMemorySummary() -> String {
        purgeExpired()
        
        var lines: [String] = []
        
        // 1. Structured preferences (from onboarding / manual settings)
        let sp = structuredPreferences
        var structuredLines: [String] = []
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        if let wake = sp.wakeUpTime {
            structuredLines.append(
                "- [Schedule] Wake-up time: \(formatter.string(from: wake))"
            )
        }
        if let start = sp.workStartTime, let end = sp.workEndTime {
            structuredLines.append(
                "- [Constraint] Work/class hours: \(formatter.string(from: start))-\(formatter.string(from: end))"
            )
        }
        if sp.hasLunchBreak {
            structuredLines.append("- [Schedule] User takes a lunch break")
        }
        if !sp.preferredEventTypes.isEmpty {
            structuredLines.append(
                "- [Task Habit] Frequently scheduled types: \(sp.preferredEventTypes.joined(separator: ", "))"
            )
        }
        if let duration = sp.preferredDuration {
            let durationText: String
            switch duration {
            case "short": durationText = "Short tasks (under 30 min)"
            case "medium": durationText = "Medium tasks (30–60 min)"
            case "long": durationText = "Long tasks (over 1 hour)"
            default: durationText = duration
            }
            structuredLines.append(
                "- [Task Habit] Preferred task duration: \(durationText)"
            )
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
        
        // 2. AI-learned preferences — permanent
        let permanent = preferences.filter { !$0.isTemporary }
        let temporary = preferences.filter { $0.isTemporary }
        
        if !permanent.isEmpty {
            if !lines.isEmpty { lines.append("") }
            lines.append("Learned User Preferences:")
            
            let grouped = Dictionary(grouping: permanent, by: \.category)
            let categoryOrder: [PreferenceCategory] = [
                .constraint, .schedule, .taskHabit, .lifestyle, .personality
            ]
            
            for category in categoryOrder {
                guard let prefs = grouped[category], !prefs.isEmpty else { continue }
                let label = categoryLabel(category)
                let sorted = prefs.sorted { $0.confirmedCount > $1.confirmedCount }
                for pref in sorted.prefix(5) {
                    let reinforced = pref.confirmedCount > 1
                        ? " (confirmed \(pref.confirmedCount)x)"
                        : ""
                    lines.append("- [\(label)] \(pref.content)\(reinforced)")
                }
            }
        }
        
        // 3. Temporary preferences
        if !temporary.isEmpty {
            if !lines.isEmpty { lines.append("") }
            lines.append("Temporary Preferences (short-term):")
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM/dd"
            for pref in temporary {
                let expiryStr = pref.expiresAt.map {
                    " (expires \(dateFormatter.string(from: $0)))"
                } ?? ""
                lines.append(
                    "- [\(categoryLabel(pref.category))] \(pref.content)\(expiryStr)"
                )
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Structured Preferences Management
    
    func setStructuredPreferences(_ prefs: StructuredPreferences) {
        structuredPreferences = prefs
        saveStructuredPreferences()
    }
    
    func getStructuredPreferences() -> StructuredPreferences {
        return structuredPreferences
    }
    
    func clearAll() {
        preferences.removeAll()
        structuredPreferences = StructuredPreferences()
        savePreferences()
        saveStructuredPreferences()
    }
    
    // MARK: - Helpers
    
    private func buildExistingPreferencesJSON() -> String {
        guard !preferences.isEmpty else { return "[]" }
        
        let items = preferences.map { pref -> [String: Any] in
            var dict: [String: Any] = [
                "id": pref.id.uuidString,
                "category": pref.category.rawValue,
                "content": pref.content,
                "is_temporary": pref.isTemporary
            ]
            if let expires = pref.expiresAt {
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                dict["expires"] = df.string(from: expires)
            }
            return dict
        }
        
        guard let data = try? JSONSerialization.data(
            withJSONObject: items, options: [.prettyPrinted]
        ) else { return "[]" }
        
        return String(data: data, encoding: .utf8) ?? "[]"
    }
    
    private func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        
        var depth = 0
        var inString = false
        var escaped = false
        
        for index in text[start...].indices {
            let char = text[index]
            
            if inString {
                if escaped {
                    escaped = false
                } else if char == "\\" {
                    escaped = true
                } else if char == "\"" {
                    inString = false
                }
                continue
            }
            
            if char == "\"" {
                inString = true
            } else if char == "{" {
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0 {
                    return String(text[start...index])
                }
            }
        }
        
        return nil
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
           let decoded = try? JSONDecoder().decode(
               [UserPreference].self, from: data
           ) {
            preferences = decoded
        }
    }
    
    private func saveStructuredPreferences() {
        if let encoded = try? JSONEncoder().encode(structuredPreferences) {
            UserDefaults.standard.set(encoded, forKey: structuredKey)
        }
    }
    
    private func loadStructuredPreferences() {
        if let data = UserDefaults.standard.data(forKey: structuredKey),
           let decoded = try? JSONDecoder().decode(
               StructuredPreferences.self, from: data
           ) {
            structuredPreferences = decoded
        }
    }
}
