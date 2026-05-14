import Foundation

enum OpenMeteoError: Error {
    case badURL
    case badResponse
}

struct OpenMeteoClient {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(latitude: Double, longitude: Double) async throws -> WeatherBundle {
        // Disk cache (30-min TTL) — prevents rate-limit spikes during development
        // and reduces Open-Meteo calls for users who revisit the same crags.
        if let cached = readDiskCache(latitude: latitude, longitude: longitude) {
            return cached
        }

        // Build URL manually — URLComponents percent-encodes commas on iOS 26+,
        // but Open-Meteo requires literal commas in comma-separated parameters.
        let vars = "temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,cloud_cover,weather_code"
        let queryString =
            "latitude=\(latitude)" +
            "&longitude=\(longitude)" +
            "&current=\(vars)" +
            "&hourly=\(vars)" +
            "&past_days=2" +
            "&forecast_days=7" +
            "&temperature_unit=fahrenheit" +
            "&wind_speed_unit=mph" +
            "&precipitation_unit=inch" +
            "&timezone=auto"

        guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?\(queryString)")
        else { throw OpenMeteoError.badURL }

        print("[OpenMeteo] GET \(url)")
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse {
            print("[OpenMeteo] HTTP \(http.statusCode) for \(url.absoluteString.prefix(80))")
            guard (200..<300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "(no body)"
                print("[OpenMeteo] Error body: \(body)")
                throw OpenMeteoError.badResponse
            }
        }

        // Persist to disk before decoding so future launches skip the network call.
        writeDiskCache(data: data, latitude: latitude, longitude: longitude)

        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return payload.toBundle()
    }

    // MARK: - Disk cache

    private static let cacheTTL: TimeInterval = 30 * 60  // 30 minutes

    private var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("WeatherCache")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cacheURL(latitude: Double, longitude: Double) -> URL {
        // Use integer millidegrees so filenames are safe on all filesystems.
        let key = "weather_\(Int(latitude * 1000))_\(Int(longitude * 1000)).json"
        return cacheDirectory.appendingPathComponent(key)
    }

    private func readDiskCache(latitude: Double, longitude: Double) -> WeatherBundle? {
        let url = cacheURL(latitude: latitude, longitude: longitude)
        guard
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
            let modified = attrs[.modificationDate] as? Date,
            Date().timeIntervalSince(modified) < Self.cacheTTL,
            let data = try? Data(contentsOf: url),
            let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return nil }
        print("[OpenMeteo] Cache hit (\(Int(Date().timeIntervalSince((try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date ?? Date()) / 60))min old) for \(latitude),\(longitude)")
        return payload.toBundle()
    }

    private func writeDiskCache(data: Data, latitude: Double, longitude: Double) {
        let url = cacheURL(latitude: latitude, longitude: longitude)
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Response model

    private struct Payload: Decodable {
        let current: Current
        let hourly: Hourly

        struct Current: Decodable {
            let time: String
            let temperature_2m: Double
            let relative_humidity_2m: Double
            let precipitation: Double
            let wind_speed_10m: Double
            let cloud_cover: Double
            let weather_code: Int
        }

        struct Hourly: Decodable {
            let time: [String]
            let temperature_2m: [Double]
            let relative_humidity_2m: [Double]
            let precipitation: [Double]
            let wind_speed_10m: [Double]
            let cloud_cover: [Double]
            let weather_code: [Int]
        }

        func toBundle() -> WeatherBundle {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            let local = DateFormatter()
            local.dateFormat = "yyyy-MM-dd'T'HH:mm"
            local.timeZone = .current

            func parse(_ s: String) -> Date {
                local.date(from: s) ?? formatter.date(from: s + "Z") ?? Date()
            }

            let currentTime = parse(current.time)
            let currentSnapshot = WeatherSnapshot(
                time: currentTime,
                temperatureF: current.temperature_2m,
                humidityPct: current.relative_humidity_2m,
                precipitationIn: current.precipitation,
                windMph: current.wind_speed_10m,
                cloudCoverPct: current.cloud_cover,
                weatherCode: current.weather_code
            )

            var allHourly: [WeatherSnapshot] = []
            for i in 0..<hourly.time.count {
                allHourly.append(WeatherSnapshot(
                    time: parse(hourly.time[i]),
                    temperatureF: hourly.temperature_2m[i],
                    humidityPct: hourly.relative_humidity_2m[i],
                    precipitationIn: hourly.precipitation[i],
                    windMph: hourly.wind_speed_10m[i],
                    cloudCoverPct: hourly.cloud_cover[i],
                    weatherCode: hourly.weather_code[i]
                ))
            }

            let past = allHourly.filter { $0.time < currentTime }
            let future = allHourly.filter { $0.time >= currentTime }

            return WeatherBundle(current: currentSnapshot, hourly: future, pastHourly: past)
        }
    }
}
