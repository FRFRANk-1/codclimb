// CodClimb/Services/FirebaseService.swift
import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

// MARK: - FirebaseService

@MainActor
final class FirebaseService: ObservableObject {

    static let shared = FirebaseService()

    // MARK: - Properties

    private let db = Firestore.firestore()
    @Published private(set) var currentUserID: String = ""
    @Published private(set) var isSignedIn: Bool = false
    @Published private(set) var isAnonymous: Bool = true
    @Published private(set) var userEmail: String? = nil

    // Firestore date en/decoding via seconds-since-1970
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    // MARK: - Init

    private init() {
        Task { await signInAnonymously() }
    }

    // MARK: - Auth

    func signInAnonymously() async {
        do {
            if let user = Auth.auth().currentUser {
                currentUserID = user.uid
                isSignedIn = true
                isAnonymous = user.isAnonymous
                userEmail = user.email
            } else {
                let result = try await Auth.auth().signInAnonymously()
                currentUserID = result.user.uid
                isSignedIn = true
                isAnonymous = true
                userEmail = nil
            }
        } catch {
            print("[FirebaseService] Auth error: \(error.localizedDescription)")
        }
    }

    /// Create a new account with email + password.
    func signUp(email: String, password: String, displayName: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        // Update display name in Firebase Auth profile
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()
        currentUserID = result.user.uid
        isSignedIn = true
        isAnonymous = false
        userEmail = email
    }

    /// Sign in with email + password.
    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        currentUserID = result.user.uid
        isSignedIn = true
        isAnonymous = false
        userEmail = result.user.email
    }

    /// Send a password reset email.
    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    /// Sign out — falls back to anonymous session.
    func signOut() async {
        do {
            try Auth.auth().signOut()
        } catch {
            print("[FirebaseService] Sign out error: \(error)")
        }
        await signInAnonymously()
    }

    // MARK: - Condition Reports

    /// Attach a real-time listener. Returns the registration so caller can remove it on deinit.
    func listenToReports(onChange: @escaping ([ConditionReport]) -> Void) -> ListenerRegistration {
        db.collection("conditionReports")
            .order(by: "date", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let docs = snapshot?.documents else {
                    if let error { print("[FirebaseService] Listener error: \(error)") }
                    return
                }
                let reports: [ConditionReport] = docs.compactMap { doc in
                    Self.reportFrom(dict: doc.data())
                }
                Task { @MainActor in onChange(reports) }
            }
    }

    /// Push a new report to Firestore.
    func addReport(_ report: ConditionReport) async throws {
        let dict = try Self.dictFrom(report)
        try await db.collection("conditionReports")
            .document(report.id)
            .setData(dict)
    }

    /// Increment thumbs-up atomically.
    func thumbsUp(reportID: String) async throws {
        try await db.collection("conditionReports")
            .document(reportID)
            .updateData(["thumbsUp": FieldValue.increment(Int64(1))])
    }

    /// Delete a report.
    func removeReport(id: String) async throws {
        try await db.collection("conditionReports")
            .document(id)
            .delete()
    }

    // MARK: - Photo Storage

    /// Upload avatar JPEG (~100KB compressed) and return download URL.
    /// Path: avatars/{uid}.jpg
    func uploadAvatar(_ imageData: Data, uid: String) async throws -> String {
        let ref = Storage.storage()
            .reference()
            .child("avatars/\(uid).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    /// Upload JPEG data to Firebase Storage and return the public download URL string.
    /// Path: reports/{reportID}.jpg  (legacy single-photo path)
    func uploadPhoto(_ imageData: Data, reportID: String) async throws -> String {
        let ref = Storage.storage()
            .reference()
            .child("reports/\(reportID).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    /// Upload up to 4 photos concurrently and return their download URLs in order.
    /// Path: reports/{reportID}_{index}.jpg
    func uploadPhotos(_ dataItems: [Data], reportID: String) async throws -> [String] {
        try await withThrowingTaskGroup(of: (Int, String).self) { group in
            for (index, data) in dataItems.prefix(4).enumerated() {
                group.addTask {
                    let ref = Storage.storage()
                        .reference()
                        .child("reports/\(reportID)_\(index).jpg")
                    let metadata = StorageMetadata()
                    metadata.contentType = "image/jpeg"
                    _ = try await ref.putDataAsync(data, metadata: metadata)
                    let url = try await ref.downloadURL()
                    return (index, url.absoluteString)
                }
            }
            var results: [(Int, String)] = []
            for try await pair in group { results.append(pair) }
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    // MARK: - Serialisation helpers

    /// Encode a ConditionReport → [String: Any] using JSONEncoder (secondsSince1970 for Date)
    static func dictFrom(_ report: ConditionReport) throws -> [String: Any] {
        let data = try encoder.encode(report)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "FirebaseService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Encoding failed"])
        }
        return dict
    }

    /// Decode [String: Any] → ConditionReport
    static func reportFrom(dict: [String: Any]) -> ConditionReport? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return try? decoder.decode(ConditionReport.self, from: data)
    }
}
