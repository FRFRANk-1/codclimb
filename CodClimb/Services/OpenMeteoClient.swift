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
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,cloud_cover,weather_code"),
            URLQueryItem(name: "hourly", value: "temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,cloud_cover,weather_code"),
            URLQueryItem(name: "past_days", value: "2"),
            URLQueryItem(name: "forecast_days", value: "3"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "wind_speed_unit", value: "mph"),
            URLQueryItem(name: "precipitation_unit", value: "inch"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        guard let url = components?.url else { throw OpenMeteoError.badURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw OpenMeteoError.badResponse
        }

        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return payload.toBundle()
    }

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
