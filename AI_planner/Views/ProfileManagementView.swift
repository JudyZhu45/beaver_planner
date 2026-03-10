//
//  ProfileManagementView.swift
//  AI_planner
//
//  Manage app profiles — switch, add, rename, delete.
//

import SwiftUI

struct ProfileManagementView: View {
    @ObservedObject private var profileManager = ProfileManager.shared
    @State private var showAddSheet = false
    @State private var editingProfile: AppProfile? = nil
    @State private var deleteTarget: AppProfile? = nil
    @State private var newProfileName = ""
    @State private var editName = ""

    var body: some View {
        List {
            // MARK: - Active Profile
            Section {
                HStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(AppTheme.primaryDeepIndigo)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(profileManager.activeProfile.name)
                            .font(AppTheme.Typography.headlineSmall)
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Active profile")
                            .font(AppTheme.Typography.labelSmall)
                            .foregroundColor(AppTheme.secondaryTeal)
                    }

                    Spacer()

                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(AppTheme.secondaryTeal)
                        .font(.system(size: 18))
                }
                .padding(.vertical, AppTheme.Spacing.xs)
            } header: {
                Text("Current Profile")
            }

            // MARK: - All Profiles
            Section {
                ForEach(profileManager.profiles) { profile in
                    HStack(spacing: AppTheme.Spacing.md) {
                        // Avatar circle with initial
                        ZStack {
                            Circle()
                                .fill(
                                    profile.id == profileManager.activeProfile.id
                                        ? AppTheme.primaryDeepIndigo.opacity(0.12)
                                        : AppTheme.bgTertiary
                                )
                                .frame(width: 40, height: 40)

                            Text(String(profile.name.prefix(1)).uppercased())
                                .font(AppTheme.Typography.titleMedium)
                                .foregroundColor(
                                    profile.id == profileManager.activeProfile.id
                                        ? AppTheme.primaryDeepIndigo
                                        : AppTheme.textSecondary
                                )
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(AppTheme.Typography.bodyMedium)
                                .foregroundColor(AppTheme.textPrimary)

                            Text("Created \(profile.createdAt, format: .dateTime.month(.abbreviated).day().year())")
                                .font(AppTheme.Typography.labelSmall)
                                .foregroundColor(AppTheme.textTertiary)
                        }

                        Spacer()

                        if profile.id == profileManager.activeProfile.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppTheme.secondaryTeal)
                                .font(.system(size: 16))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if profile.id != profileManager.activeProfile.id {
                            profileManager.switchTo(profile)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if profileManager.profiles.count > 1 {
                            Button(role: .destructive) {
                                deleteTarget = profile
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }

                        Button {
                            editingProfile = profile
                            editName = profile.name
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(AppTheme.accentGold)
                    }
                }
            } header: {
                Text("All Profiles")
            } footer: {
                Text("Tap a profile to switch. Swipe left to rename or delete.")
                    .font(AppTheme.Typography.labelSmall)
            }

            // MARK: - Add Profile
            Section {
                Button {
                    newProfileName = ""
                    showAddSheet = true
                } label: {
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.primaryDeepIndigo)

                        Text("Add New Profile")
                            .font(AppTheme.Typography.bodyMedium)
                            .foregroundColor(AppTheme.primaryDeepIndigo)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.bgPrimary.ignoresSafeArea())
        .navigationTitle("Profiles")
        .navigationBarTitleDisplayMode(.inline)
        // Add Profile Alert
        .alert("New Profile", isPresented: $showAddSheet) {
            TextField("Profile name", text: $newProfileName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                let trimmed = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                profileManager.addProfile(name: trimmed)
            }
        } message: {
            Text("Enter a name for the new profile.")
        }
        // Rename Alert
        .alert("Rename Profile", isPresented: Binding(
            get: { editingProfile != nil },
            set: { if !$0 { editingProfile = nil } }
        )) {
            TextField("Profile name", text: $editName)
            Button("Cancel", role: .cancel) { editingProfile = nil }
            Button("Save") {
                if let profile = editingProfile {
                    let trimmed = editName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    profileManager.renameProfile(profile, to: trimmed)
                }
                editingProfile = nil
            }
        } message: {
            Text("Enter a new name for this profile.")
        }
        // Delete Confirmation
        .confirmationDialog(
            "Delete Profile",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete \"\(deleteTarget?.name ?? "")\"", role: .destructive) {
                if let profile = deleteTarget {
                    profileManager.deleteProfile(profile)
                }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("This will permanently delete all data associated with this profile, including tasks, preferences, and chat history.")
        }
    }
}

#Preview {
    NavigationStack {
        ProfileManagementView()
    }
}
