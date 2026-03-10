//
//  FeedbackUploader.swift
//  AI_planner
//
//  Uploads beta feedback entries to a Notion database via the Notion API.
//  Configure NOTION_FEEDBACK_API_KEY and NOTION_FEEDBACK_DATABASE_ID in Secrets.xcconfig.
//
//  Required Notion database columns (exact names):
//    Name           → Title   (the entry ID / summary line)
//    Category       → Text
//    UserMessage    → Text
//    AIResponse     → Text
//    Note           → Text
//    AppVersion     → Text
//    SubmittedAt    → Date
//

import Foundation

final class FeedbackUploader {
    static let shared = FeedbackUploader()
    private init() {}

    // MARK: - Config

    private var apiKey: String? {
        let v = Bundle.main.infoDictionary?["NOTION_FEEDBACK_API_KEY"] as? String
        return (v?.isEmpty == false && v?.hasPrefix("YOUR_") == false) ? v : nil
    }

    private var databaseID: String? {
        let v = Bundle.main.infoDictionary?["NOTION_FEEDBACK_DATABASE_ID"] as? String
        return (v?.isEmpty == false && v?.hasPrefix("YOUR_") == false) ? v : nil
    }

    private let notionVersion = "2022-06-28"
    private let endpoint = URL(string: "https://api.notion.com/v1/pages")!

    // MARK: - Upload

    /// Fire-and-forget: creates a new page (row) in the Notion feedback database.
    func upload(_ entry: FeedbackEntry) {
        guard let apiKey, let databaseID else {
            print("⚠️ [FeedbackUploader] Notion keys not configured — skipping cloud upload.")
            return
        }

        let body = buildBody(entry: entry, databaseID: databaseID)
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)",  forHTTPHeaderField: "Authorization")
        request.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        request.setValue(notionVersion,        forHTTPHeaderField: "Notion-Version")
        request.httpBody = bodyData

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error {
                print("❌ [FeedbackUploader] Upload failed: \(error.localizedDescription)")
                return
            }
            guard let http = response as? HTTPURLResponse else { return }
            if http.statusCode == 200 {
                print("✅ [FeedbackUploader] Feedback saved to Notion successfully.")
            } else {
                print("⚠️ [FeedbackUploader] Notion responded with status \(http.statusCode)")
            }
        }.resume()
    }

    // MARK: - Notion Page Body Builder

    private func buildBody(entry: FeedbackEntry, databaseID: String) -> [String: Any] {
        let iso8601 = ISO8601DateFormatter()
        let categories = entry.categories.map { $0.rawValue }.joined(separator: ", ")

        return [
            "parent": ["database_id": databaseID],
            "properties": [
                "Name": [
                    "title": [
                        ["text": ["content": "[\(entry.categories.first?.rawValue ?? "Feedback")] \(String(entry.id.uuidString.prefix(8)))"]]
                    ]
                ],
                "Category": [
                    "rich_text": [
                        ["text": ["content": truncate(categories, to: 2000)]]
                    ]
                ],
                "UserMessage": [
                    "rich_text": [
                        ["text": ["content": truncate(entry.userMessage, to: 2000)]]
                    ]
                ],
                "AIResponse": [
                    "rich_text": [
                        ["text": ["content": truncate(entry.aiResponse, to: 2000)]]
                    ]
                ],
                "Note": [
                    "rich_text": [
                        ["text": ["content": truncate(entry.note ?? "", to: 2000)]]
                    ]
                ],
                "AppVersion": [
                    "rich_text": [
                        ["text": ["content": entry.appVersion]]
                    ]
                ],
                "SubmittedAt": [
                    "date": ["start": iso8601.string(from: entry.createdAt)]
                ]
            ]
        ]
    }

    private func truncate(_ string: String, to limit: Int) -> String {
        guard string.count > limit else { return string }
        return String(string.prefix(limit - 1)) + "…"
    }
}
