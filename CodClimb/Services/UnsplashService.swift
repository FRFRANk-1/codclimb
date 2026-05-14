// CodClimb/Services/UnsplashService.swift
//
// Fetches a relevant climbing photo URL from the Unsplash API for each crag.
// Compliant with Unsplash API Guidelines:
//   • Hotlinks photos directly from Unsplash CDN URLs (no re-hosting)
//   • Triggers the download endpoint when a photo is displayed
//   • Returns photographer attribution for display in the UI
//
// SETUP (one-time, free):
//   1. Go to https://unsplash.com/developers and create a free developer account.
//   2. Create a new application — pick "Demo" access to start.
//   3. Copy your Access Key and paste it in place of "YOUR_UNSPLASH_ACCESS_KEY" below.
//
// The free tier allows 50 requests/hour which is more than enough for
// crag photos that are cached in memory for the session.

import Foundation

/// All the info the UI needs from a single Unsplash photo response.
struct UnsplashPhotoInfo {
    let imageURL: URL
    /// Must be called when the photo is shown (Unsplash API requirement).
    let downloadTriggerURL: URL
    let photographerName: String
    let photographerProfileURL: URL?
}

@MainActor
final class UnsplashService: ObservableObject {

    static let shared = UnsplashService()

    // ── ⚠️  Paste your Unsplash Access Key here ─────────────────────────
    private let accessKey = "h6yVTihRpcIHt1IAIGyTCTxj72icHZt0RGUI2jyJUJ8"
    // ────────────────────────────────────────────────────────────────────

    /// Unsplash API key is set — enabled.
    var isConfigured: Bool { !accessKey.isEmpty && accessKey != "YOUR_UNSPLASH_ACCESS_KEY" }

    /// In-memory cache: cragID → photo info
    private var cache: [String: UnsplashPhotoInfo] = [:]

    private init() {}

    // MARK: - Public API

    /// Returns photo info for a crag, fetching from Unsplash if needed.
    /// Falls back to nil (caller should use local asset) if unconfigured or network fails.
    func photo(for crag: Crag) async -> UnsplashPhotoInfo? {
        guard isConfigured else { return nil }
        if let cached = cache[crag.id] { return cached }

        let query = searchQuery(for: crag)
        guard let url = buildURL(query: query) else { return nil }

        do {
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse {
                guard http.statusCode == 200 else {
                    print("[UnsplashService] HTTP \(http.statusCode) for \(crag.name)")
                    return nil
                }
            }

            let photo = try JSONDecoder().decode(UnsplashPhotoResponse.self, from: data)
            guard let imageURL = URL(string: photo.urls.regular),
                  let dlURL   = URL(string: photo.links.downloadLocation) else { return nil }

            let info = UnsplashPhotoInfo(
                imageURL: imageURL,
                downloadTriggerURL: dlURL,
                photographerName: photo.user.name,
                photographerProfileURL: URL(string: photo.user.links.html)
            )
            cache[crag.id] = info
            return info
        } catch {
            print("[UnsplashService] \(crag.name): \(error.localizedDescription)")
        }
        return nil
    }

    /// Call this when an Unsplash photo becomes visible on screen.
    /// Required by Unsplash API guidelines ("trigger downloads").
    func triggerDownload(for info: UnsplashPhotoInfo) {
        var request = URLRequest(url: info.downloadTriggerURL, timeoutInterval: 5)
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        // Fire-and-forget — we don't need the response
        URLSession.shared.dataTask(with: request).resume()
    }

    // MARK: - Helpers

    private func searchQuery(for crag: Crag) -> String {
        let rock = crag.rockType.split(separator: "/").first.map(String.init) ?? crag.rockType
        return "\(rock) rock climbing \(crag.region)"
    }

    private func buildURL(query: String) -> URL? {
        var components = URLComponents(string: "https://api.unsplash.com/photos/random")
        components?.queryItems = [
            URLQueryItem(name: "query",          value: query),
            URLQueryItem(name: "orientation",    value: "landscape"),
            URLQueryItem(name: "content_filter", value: "high"),
        ]
        return components?.url
    }
}

// MARK: - Unsplash response models

private struct UnsplashPhotoResponse: Decodable {
    struct URLs: Decodable {
        let regular: String        // ~1080px — hotlinked directly to Unsplash CDN
    }
    struct Links: Decodable {
        let downloadLocation: String
        enum CodingKeys: String, CodingKey {
            case downloadLocation = "download_location"
        }
    }
    struct User: Decodable {
        let name: String
        let links: UserLinks
        struct UserLinks: Decodable {
            let html: String       // Photographer's Unsplash profile page
        }
    }

    let id: String
    let urls: URLs
    let links: Links
    let user: User
}
