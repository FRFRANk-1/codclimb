// CodClimb/Services/WeatherCacheClient.swift
//
// Fetches pre-computed weather for all crags from the CodClimb backend
// in a SINGLE network call, then serves results from memory.
//
// Fall-back chain:
//   1. Backend /api/weather/all-crags  (all crags, one round trip)
//   2. Direct Open-Meteo per-crag call (original behavior)
//
// The iOS app should call `WeatherCacheClient.shared.prefetch()` on launch.
// CragListViewModel reads from `snapshots(for:)` which is always instant.

import Foundation

@MainActor
final class WeatherCacheClient: ObservableObject {

    static let shared = WeatherCacheClient()

    // MARK: - Config

    /// Set to your deployed Railway/Render URL in production.
    /// Leave as localhost for simulator development.
    #if DEBUG
    static let backendBase = "http://localhost:4000"
    #else
    static let backendBase = "https://codclimb-backend.up.railway.app"
    #endif

    // MARK: - State

    @Published private(set) var isLoaded = false
    @Published private(set) var lastRefreshed: Date? = nil

    /// keyed by crag.id
    private var cache: [String: CachedCragWeather] = [:]

    private init() {}

    // MARK: - Prefetch (call once at launch)

    func prefetch() async {
        guard !isLoaded else { return }
        await loadFromBackend()
    }

    func refresh() async {
        await loadFromBackend()
    }

    // MARK: - Lookup

    /// Returns cached weather for a crag ID, or nil if not yet loaded.
    func weather(for cragID: String) -> CachedCragWeather? {
        cache[cragID]
    }

    /// All loaded entries as a dictionary.
    var allWeather: [String: CachedCragWeather] { cache }

    // MARK: - Backend fetch

    private func loadFromBackend() async {
        guard let url = URL(string: "\(Self.backendBase)/api/weather/all-crags") else { return }

        do {
            var request = URLRequest(url: url, timeoutInterval: 20)
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)

            // 202 = cache still warming — try again in 12 seconds
            if let http = response as? HTTPURLResponse, http.statusCode == 202 {
                print("[WeatherCacheClient] Backend warming, retrying in 12s...")
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                await loadFromBackend()
                return
            }

            let payload = try JSONDecoder().decode(AllCragsPayload.self, from: data)
            var newCache: [String: CachedCragWeather] = [:]
            for entry in payload.crags {
                newCache[entry.id] = entry
            }
            cache = newCache
            isLoaded = true
            lastRefreshed = Date()
            print("[WeatherCacheClient] Loaded \(cache.count) crags from backend")
        } catch {
            print("[WeatherCacheClient] Backend unavailable (\(error.localizedDescription)) — falling back to direct Open-Meteo")
            // Don't set isLoaded = true; CragListViewModel falls back to OpenMeteoClient
        }
    }
}

// MARK: - Response models

struct AllCragsPayload: Decodable {
    let count: Int
    let fetchedAt: String?
    let crags: [CachedCragWeather]
}

struct CachedCragWeather: Decodable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let current: BackendCurrentWeather
    let score: BackendScore
    let hourly: [BackendHourlySlot]
    let fetchedAt: String

    /// Converts backend payload → iOS WeatherBundle for use in existing views.
    func toWeatherBundle() -> WeatherBundle {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]

        func parseDate(_ s: String) -> Date {
            formatter.date(from: s) ?? fallback.date(from: s) ?? Date()
        }

        let currentSnap = WeatherSnapshot(
            time: parseDate(current.updatedAt),
            temperatureF: current.temp,
            humidityPct: current.humidity,
            precipitationIn: current.precipitation * 0.03937, // mm → in
            windMph: current.windSpeed,
            cloudCoverPct: current.cloudCover,
            weatherCode: current.weatherCode
        )

        let hourlySnaps = hourly.map { h in
            WeatherSnapshot(
                time: parseDate(h.time),
                temperatureF: h.temp,
                humidityPct: h.humidity,
                precipitationIn: h.precipitation * 0.03937,
                windMph: h.windSpeed,
                cloudCoverPct: h.cloudCover,
                weatherCode: h.weatherCode
            )
        }

        let now = currentSnap.time
        let past   = hourlySnaps.filter { $0.time < now }
        let future = hourlySnaps.filter { $0.time >= now }

        return WeatherBundle(current: currentSnap, hourly: future, pastHourly: past)
    }
}

struct BackendCurrentWeather: Decodable {
    let temp: Double
    let feelsLike: Double
    let humidity: Double
    let windSpeed: Double
    let windGust: Double
    let cloudCover: Double
    let precipitation: Double
    let weatherCode: Int
    let isDay: Bool
    let updatedAt: String
}

struct BackendScore: Decodable {
    let overall: Double
    let label: String
}

struct BackendHourlySlot: Decodable {
    let time: String
    let temp: Double
    let humidity: Double
    let windSpeed: Double
    let windGust: Double
    let precipitation: Double
    let cloudCover: Double
    let weatherCode: Int
    let score: Double
}
