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
            } else {
                let result = try await Auth.auth().signInAnonymously()
                currentUserID = result.user.uid
                isSignedIn = true
            }
        } catch {
            print("[FirebaseService] Auth error: \(error.localizedDescription)")
        }
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

    /// Upload JPEG data to Firebase Storage and return the public download URL string.
    /// Path: reports/{reportID}.jpg
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
