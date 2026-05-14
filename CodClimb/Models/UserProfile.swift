// CodClimb/Models/UserProfile.swift
import Foundation
import FirebaseFirestore
import PhotosUI
import SwiftUI

// MARK: - UserProfile model

struct UserProfile: Identifiable, Codable {
    let id: String           // Firebase UID
    var displayName: String
    var bio: String          // max 150 chars
    var avatarURL: String?   // Firebase Storage download URL
    var joinDate: Date
    var reportCount: Int
    var totalThumbsUp: Int

    init(
        id: String,
        displayName: String = "",
        bio: String = "",
        avatarURL: String? = nil,
        joinDate: Date = .now,
        reportCount: Int = 0,
        totalThumbsUp: Int = 0
    ) {
        self.id = id
        self.displayName = displayName
        self.bio = bio
        self.avatarURL = avatarURL
        self.joinDate = joinDate
        self.reportCount = reportCount
        self.totalThumbsUp = totalThumbsUp
    }

    // MARK: - Derived

    var climberTitle: String {
        switch reportCount {
        case 0:        return "New to the Wall"
        case 1..<5:    return "Crag Scout"
        case 5..<25:   return "Trail Crusher"
        case 25..<50:  return "Route Setter's Eye"
        default:       return "Active Goat 🐐"
        }
    }

    var memberSince: String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: joinDate)
    }
}

// MARK: - UserProfileStore

@MainActor
final class UserProfileStore: ObservableObject {

    @Published private(set) var currentProfile: UserProfile?
    @Published private(set) var viewedProfile: UserProfile?
    @Published var isUploading = false

    private let firebase = FirebaseService.shared
    private let db = Firestore.firestore()

    // MARK: - Load own profile

    func loadCurrentProfile() async {
        guard !firebase.currentUserID.isEmpty else { return }
        currentProfile = await fetchProfile(uid: firebase.currentUserID)
    }

    // MARK: - Load another user's profile

    func loadProfile(for displayName: String) async {
        viewedProfile = nil
        // Query by displayName field
        do {
            let snap = try await db.collection("userProfiles")
                .whereField("displayName", isEqualTo: displayName)
                .limit(to: 1)
                .getDocuments()
            guard let doc = snap.documents.first else { return }
            viewedProfile = profileFrom(dict: doc.data(), id: doc.documentID)
        } catch {
            print("[UserProfileStore] loadProfile error: \(error)")
        }
    }

    // MARK: - Create / update profile

    func saveProfile(displayName: String, bio: String) async {
        let uid = firebase.currentUserID
        guard !uid.isEmpty else { return }

        var profile = currentProfile ?? UserProfile(
            id: uid,
            displayName: displayName,
            bio: bio,
            joinDate: .now
        )
        profile.displayName = displayName
        profile.bio = String(bio.prefix(150))

        do {
            try await db.collection("userProfiles")
                .document(uid)
                .setData(dictFrom(profile), merge: true)
            currentProfile = profile
        } catch {
            print("[UserProfileStore] saveProfile error: \(error)")
        }
    }

    // MARK: - Email alert opt-in

    func setEmailAlerts(enabled: Bool, email: String) async {
        let uid = firebase.currentUserID
        guard !uid.isEmpty else { return }
        do {
            try await db.collection("userProfiles")
                .document(uid)
                .setData(["emailAlertsEnabled": enabled, "alertEmail": email], merge: true)
        } catch {
            print("[UserProfileStore] setEmailAlerts error: \(error)")
        }
    }

    // MARK: - Upload avatar

    func uploadAvatar(_ imageData: Data) async {
        let uid = firebase.currentUserID
        guard !uid.isEmpty else { return }
        isUploading = true
        defer { isUploading = false }

        do {
            let url = try await firebase.uploadAvatar(imageData, uid: uid)
            try await db.collection("userProfiles")
                .document(uid)
                .setData(["avatarURL": url], merge: true)
            currentProfile?.avatarURL = url
        } catch {
            print("[UserProfileStore] uploadAvatar error: \(error)")
        }
    }

    // MARK: - Refresh report stats from Firestore

    func refreshStats(reports: [ConditionReport]) {
        guard let uid = currentProfile?.id ?? (firebase.currentUserID.isEmpty ? nil : firebase.currentUserID) else { return }
        let mine = reports.filter { $0.author == currentProfile?.displayName }
        let thumbsUp = mine.map(\.thumbsUp).reduce(0, +)
        currentProfile?.reportCount = mine.count
        currentProfile?.totalThumbsUp = thumbsUp

        Task {
            try? await db.collection("userProfiles")
                .document(uid)
                .setData(["reportCount": mine.count, "totalThumbsUp": thumbsUp], merge: true)
        }
    }

    // MARK: - Private helpers

    private func fetchProfile(uid: String) async -> UserProfile? {
        do {
            let doc = try await db.collection("userProfiles").document(uid).getDocument()
            guard doc.exists, let data = doc.data() else { return nil }
            return profileFrom(dict: data, id: uid)
        } catch {
            print("[UserProfileStore] fetchProfile error: \(error)")
            return nil
        }
    }

    private func profileFrom(dict: [String: Any], id: String) -> UserProfile {
        UserProfile(
            id: id,
            displayName: dict["displayName"] as? String ?? "",
            bio: dict["bio"] as? String ?? "",
            avatarURL: dict["avatarURL"] as? String,
            joinDate: (dict["joinDate"] as? Timestamp)?.dateValue() ?? .now,
            reportCount: dict["reportCount"] as? Int ?? 0,
            totalThumbsUp: dict["totalThumbsUp"] as? Int ?? 0
        )
    }

    private func dictFrom(_ p: UserProfile) -> [String: Any] {
        var d: [String: Any] = [
            "displayName": p.displayName,
            "bio": p.bio,
            "joinDate": Timestamp(date: p.joinDate),
            "reportCount": p.reportCount,
            "totalThumbsUp": p.totalThumbsUp,
        ]
        if let url = p.avatarURL { d["avatarURL"] = url }
        return d
    }
}
