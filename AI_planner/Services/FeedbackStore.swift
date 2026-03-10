//
//  FeedbackStore.swift
//  AI_planner
//
//  Beta feedback collector — stores user-reported AI response issues locally.
//  Persisted to UserDefaults as JSON. Export via `exportJSON()` for review during development.
//

import Foundation

// MARK: - Feedback Category

enum FeedbackCategory: String, Codable, CaseIterable, Identifiable {
    case wrongTime          = "Wrong time / conflict not avoided"
    case wrongTask          = "Created wrong task"
    case missedConfirm      = "Executed without confirmation"
    case misunderstood      = "Misunderstood my request"
    case tooManyTasks       = "Planned too many tasks"
    case tooFewTasks        = "Planned too few tasks"
    case badLanguage        = "Tone / language not right"
    case other              = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .wrongTime:      return "clock.badge.exclamationmark"
        case .wrongTask:      return "square.and.pencil.circle"
        case .missedConfirm:  return "checkmark.shield"
        case .misunderstood:  return "bubble.left.and.exclamationmark.bubble.right"
        case .tooManyTasks:   return "list.bullet.indent"
        case .tooFewTasks:    return "list.dash"
        case .badLanguage:    return "text.bubble"
        case .other:          return "ellipsis.bubble"
        }
    }
}

// MARK: - Feedback Entry

struct FeedbackEntry: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let userMessage: String      // The user turn that triggered the response
    let aiResponse: String       // The AI reply being reported (full text)
    let categories: [FeedbackCategory]
    let note: String?            // Optional free-text from user
    var appVersion: String

    init(userMessage: String, aiResponse: String, categories: [FeedbackCategory], note: String?) {
        self.id = UUID()
        self.createdAt = Date()
        self.userMessage = userMessage
        self.aiResponse = aiResponse
        self.categories = categories
        self.note = note?.isEmpty == true ? nil : note
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
}

// MARK: - Feedback Store

final class FeedbackStore {
    static let shared = FeedbackStore()
    private let baseStorageKey = "BetaFeedbackEntries"
    private var storageKey: String { ProfileManager.activeScopedKey(baseStorageKey) }

    private(set) var entries: [FeedbackEntry] = []

    private init() {
        load()
        NotificationCenter.default.addObserver(
            forName: .profileDidSwitch,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.load()
        }
    }

    // MARK: - Save

    func submit(_ entry: FeedbackEntry) {
        entries.append(entry)
        persist()
        // Also upload to Notion so the developer receives it in the cloud
        FeedbackUploader.shared.upload(entry)
    }

    // MARK: - Export as JSON string (for developer copy/paste)

    func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    // MARK: - Clear

    func clearAll() {
        entries = []
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    // MARK: - Persistence

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = (try? decoder.decode([FeedbackEntry].self, from: data)) ?? []
    }
}
