//
//  AIAPIService.swift
//  AI_planner
//
//  Created by Judy459 on 2/24/26.
//

import Foundation

// MARK: - Model Provider Selection

enum AIModelProvider: String, CaseIterable, Identifiable {
    case kimi = "Kimi"
    case gpt4 = "GPT-4o"
    
    var id: String { rawValue }
    
    var endpoint: String {
        switch self {
        case .kimi:  return "https://api.moonshot.cn/v1/chat/completions"
        case .gpt4:  return "https://api.openai.com/v1/chat/completions"
        }
    }
    
    var modelName: String {
        switch self {
        case .kimi:  return "moonshot-v1-32k"
        case .gpt4:  return "gpt-4o"
        }
    }
    
    var apiKey: String? {
        switch self {
        case .kimi:
            return Bundle.main.infoDictionary?["MOONSHOT_API_KEY"] as? String
        case .gpt4:
            return Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String
        }
    }
    
    var displayName: String { rawValue }
}

// MARK: - API Request/Response Models

struct KimiChatRequest: Encodable {
    let model: String
    let messages: [KimiMessage]
    let temperature: Double
    let stream: Bool
}

struct KimiMessage: Codable {
    let role: String   // "system", "user", "assistant"
    let content: String
}

struct KimiChatResponse: Decodable {
    let choices: [KimiChoice]
}

struct KimiChoice: Decodable {
    let message: KimiResponseMessage?
    let delta: KimiResponseMessage?
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case message, delta
        case finishReason = "finish_reason"
    }
}

struct KimiResponseMessage: Decodable {
    let role: String?
    let content: String?
}

// MARK: - Error Types

enum KimiAPIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case httpError(statusCode: Int, body: String)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API Key not configured. Please check Secrets.xcconfig."
        case .invalidURL:
            return "Invalid API URL."
        case .httpError(let code, let body):
            if code == 401 { return "Invalid API Key. Please check your configuration." }
            if code == 429 { return "Too many requests. Please try again later." }
            return "Server error (\(code)): \(body)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Service

class AIAPIService {
    static let shared = AIAPIService()

    /// Backward-compatibility alias so existing code referencing KimiAPIService.shared still compiles
    static var KimiAPIService: AIAPIService { shared }

    /// Current model provider — defaults to GPT-4o
    var activeProvider: AIModelProvider {
        get {
            let raw = UserDefaults.standard.string(forKey: "selectedAIModel") ?? AIModelProvider.gpt4.rawValue
            return AIModelProvider(rawValue: raw) ?? .gpt4
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "selectedAIModel")
        }
    }
    
    private init() {}
    
    // MARK: - Streaming Request
    
    func streamChat(messages: [KimiMessage], temperature: Double = 0.3) async throws -> AsyncThrowingStream<String, Error> {
        let provider = activeProvider
        guard let key = provider.apiKey, !key.isEmpty, !key.contains("your-api-key"), !key.contains("YOUR_API_KEY") else {
            throw KimiAPIError.missingAPIKey
        }
        guard let url = URL(string: provider.endpoint) else {
            throw KimiAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120
        
        let body = KimiChatRequest(
            model: provider.modelName,
            messages: messages,
            temperature: temperature,
            stream: true
        )
        request.httpBody = try JSONEncoder().encode(body)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KimiAPIError.networkError(URLError(.badServerResponse))
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
                if errorBody.count > 500 { break }
            }
            throw KimiAPIError.httpError(statusCode: httpResponse.statusCode, body: errorBody)
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonString = String(line.dropFirst(6))
                        
                        if jsonString == "[DONE]" {
                            continuation.finish()
                            return
                        }
                        
                        guard let jsonData = jsonString.data(using: .utf8) else { continue }
                        
                        do {
                            let chunk = try JSONDecoder().decode(KimiChatResponse.self, from: jsonData)
                            if let content = chunk.choices.first?.delta?.content {
                                continuation.yield(content)
                            }
                        } catch {
                            continue
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Non-streaming Request
    
    func sendChat(messages: [KimiMessage], temperature: Double = 0.3) async throws -> String {
        let provider = activeProvider
        guard let key = provider.apiKey, !key.isEmpty, !key.contains("your-api-key"), !key.contains("YOUR_API_KEY") else {
            throw KimiAPIError.missingAPIKey
        }
        guard let url = URL(string: provider.endpoint) else {
            throw KimiAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
        
        let body = KimiChatRequest(
            model: provider.modelName,
            messages: messages,
            temperature: temperature,
            stream: false
        )
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KimiAPIError.networkError(URLError(.badServerResponse))
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw KimiAPIError.httpError(statusCode: httpResponse.statusCode, body: body)
        }
        
        do {
            let decoded = try JSONDecoder().decode(KimiChatResponse.self, from: data)
            return decoded.choices.first?.message?.content ?? ""
        } catch {
            throw KimiAPIError.decodingError(error)
        }
    }
}

/// Backward-compatibility typealias — keeps existing code referencing `KimiAPIService` compiling
/// without requiring a mass rename throughout the project.
typealias KimiAPIService = AIAPIService
