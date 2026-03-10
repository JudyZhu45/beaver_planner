//
//  ProfileManager.swift
//  AI_planner
//
//  Multi-profile manager — allows users to create, switch, edit, and delete
//  app profiles. Each profile isolates its own set of todos, preferences,
//  behavior data, and chat memory via a profile-scoped UserDefaults key prefix.
//

import Foundation
import Combine

// MARK: - App Profile Model

struct AppProfile: Identifiable, Codable {
    let id: UUID
    var name: String
    let createdAt: Date

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}

// MARK: - Profile Manager

@MainActor
final class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    /// All profiles the user has created.
    @Published var profiles: [AppProfile] = []

    /// The currently active profile.
    @Published var activeProfile: AppProfile

    /// Whether the active profile has completed onboarding (reactive).
    @Published var hasCompletedOnboarding: Bool = false

    // Persistence keys
    private let profilesKey = "AppProfiles"
    private let activeProfileIdKey = "ActiveProfileId"

    // Keys that should be scoped per profile
    static let scopedKeys: [String] = [
        "SavedTodos",
        "UserProfileData",
        "BetaFeedbackEntries",
        "UserBehaviorRecords",
        "ChatMemoryPreferences",
        "ChatMemoryConversationPairs",
        "StructuredPreferences",
        "hasCompletedOnboarding"
    ]

    private init() {
        // Load profiles list
        let loaded = Self.loadProfiles()
        if loaded.isEmpty {
            // First launch — create a default profile
            let defaultProfile = AppProfile(name: "Default")
            self.profiles = [defaultProfile]
            self.activeProfile = defaultProfile
            Self.saveProfiles([defaultProfile])
            UserDefaults.standard.set(defaultProfile.id.uuidString, forKey: activeProfileIdKey)
            // Migrate existing data to the default profile's scoped keys
            Self.migrateExistingData(to: defaultProfile)
        } else {
            self.profiles = loaded
            let savedId = UserDefaults.standard.string(forKey: activeProfileIdKey)
            self.activeProfile = loaded.first(where: { $0.id.uuidString == savedId }) ?? loaded[0]
        }
        // Load onboarding state for active profile
        refreshOnboardingState()
    }

    // MARK: - CRUD

    func addProfile(name: String) {
        let profile = AppProfile(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        profiles.append(profile)
        saveState()
    }

    func renameProfile(_ profile: AppProfile, to newName: String) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index].name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if activeProfile.id == profile.id {
            activeProfile.name = profiles[index].name
        }
        saveState()
    }

    func deleteProfile(_ profile: AppProfile) {
        guard profiles.count > 1 else { return } // Must keep at least one profile
        // Remove scoped data
        for key in Self.scopedKeys {
            UserDefaults.standard.removeObject(forKey: Self.scopedKey(key, for: profile))
        }
        profiles.removeAll { $0.id == profile.id }
        // If we deleted the active profile, switch to the first remaining one
        if activeProfile.id == profile.id {
            switchTo(profiles[0])
        }
        saveState()
    }

    func switchTo(_ profile: AppProfile) {
        guard profile.id != activeProfile.id else { return }
        activeProfile = profile
        UserDefaults.standard.set(profile.id.uuidString, forKey: activeProfileIdKey)
        refreshOnboardingState()
        // Notify the app to reload data for the new profile
        NotificationCenter.default.post(name: .profileDidSwitch, object: nil)
    }

    /// Mark the active profile's onboarding as completed.
    func completeOnboarding() {
        let key = Self.scopedKey("hasCompletedOnboarding", for: activeProfile)
        UserDefaults.standard.set(true, forKey: key)
        hasCompletedOnboarding = true
    }

    /// Reload onboarding state from UserDefaults for the active profile.
    private func refreshOnboardingState() {
        let key = Self.scopedKey("hasCompletedOnboarding", for: activeProfile)
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: key)
    }

    // MARK: - Scoped Key Helper

    /// Returns a UserDefaults key scoped to the given profile.
    static func scopedKey(_ baseKey: String, for profile: AppProfile) -> String {
        "profile_\(profile.id.uuidString)_\(baseKey)"
    }

    /// Returns a UserDefaults key scoped to the currently active profile.
    static func activeScopedKey(_ baseKey: String) -> String {
        scopedKey(baseKey, for: shared.activeProfile)
    }

    // MARK: - Persistence

    private func saveState() {
        Self.saveProfiles(profiles)
        UserDefaults.standard.set(activeProfile.id.uuidString, forKey: activeProfileIdKey)
    }

    private static func saveProfiles(_ profiles: [AppProfile]) {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: "AppProfiles")
        }
    }

    private static func loadProfiles() -> [AppProfile] {
        guard let data = UserDefaults.standard.data(forKey: "AppProfiles"),
              let decoded = try? JSONDecoder().decode([AppProfile].self, from: data) else {
            return []
        }
        return decoded
    }

    // MARK: - Migration

    /// On first launch, migrate un-scoped data to the default profile's scoped keys.
    private static func migrateExistingData(to profile: AppProfile) {
        for key in scopedKeys {
            if let existingData = UserDefaults.standard.object(forKey: key) {
                let newKey = scopedKey(key, for: profile)
                UserDefaults.standard.set(existingData, forKey: newKey)
                // Don't remove the old key — backwards compatibility in case of rollback
            }
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let profileDidSwitch = Notification.Name("profileDidSwitch")
}
