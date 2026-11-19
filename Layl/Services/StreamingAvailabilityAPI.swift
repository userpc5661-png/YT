import Foundation

enum StreamingAPIError: LocalizedError {
    case missingKey
    case invalidURL
    case badStatus(Int)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .missingKey: return "Missing API key"
        case .invalidURL: return "Invalid URL"
        case .badStatus(let code): return "HTTP \(code)"
        case .decodeFailed: return "Could not decode response"
        }
    }
}

actor StreamingAvailabilityAPI {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchByTitle(
        title: String,
        country: String,
        showType: TitleKind?,
        provider: StreamingAPIProvider,
        apiKey: String,
        outputLanguage: String
    ) async throws -> [StreamingShow] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "output_language", value: outputLanguage)
        ]
        if let showType {
            items.append(URLQueryItem(name: "show_type", value: showType == .movie ? "movie" : "series"))
        }
        return try await fetchShows(
            path: "shows/search/title",
            query: items,
            provider: provider,
            apiKey: apiKey
        )
    }

    func topShows(
        country: String,
        service: String,
        showType: TitleKind?,
        provider: StreamingAPIProvider,
        apiKey: String,
        outputLanguage: String
    ) async throws -> [StreamingShow] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "service", value: service),
            URLQueryItem(name: "output_language", value: outputLanguage)
        ]
        if let showType {
            items.append(URLQueryItem(name: "show_type", value: showType == .movie ? "movie" : "series"))
        }
        return try await fetchShows(
            path: "shows/top",
            query: items,
            provider: provider,
            apiKey: apiKey
        )
    }

    func show(
        id: String,
        country: String,
        provider: StreamingAPIProvider,
        apiKey: String,
        outputLanguage: String
    ) async throws -> StreamingShow {
        let items: [URLQueryItem] = [
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "output_language", value: outputLanguage)
        ]
        let list: [StreamingShow] = try await request(
            path: "shows/\(id)",
            query: items,
            provider: provider,
            apiKey: apiKey,
            asArray: false
        )
        if let first = list.first { return first }
        throw StreamingAPIError.decodeFailed
    }

    private func fetchShows(
        path: String,
        query: [URLQueryItem],
        provider: StreamingAPIProvider,
        apiKey: String
    ) async throws -> [StreamingShow] {
        try await request(path: path, query: query, provider: provider, apiKey: apiKey, asArray: true)
    }

    private func request(
        path: String,
        query: [URLQueryItem],
        provider: StreamingAPIProvider,
        apiKey: String,
        asArray: Bool
    ) async throws -> [StreamingShow] {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StreamingAPIError.missingKey
        }
        let base = switch provider {
        case .movieOfTheNight: "https://api.movieofthenight.com/v4/"
        case .rapidAPI: "https://streaming-availability.p.rapidapi.com/"
        }
        guard var components = URLComponents(string: base + path) else {
            throw StreamingAPIError.invalidURL
        }
        components.queryItems = query
        guard let url = components.url else { throw StreamingAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 25
        switch provider {
        case .movieOfTheNight:
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        case .rapidAPI:
            request.setValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
            request.setValue("streaming-availability.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw StreamingAPIError.badStatus(-1) }
        guard (200...299).contains(http.statusCode) else { throw StreamingAPIError.badStatus(http.statusCode) }

        let decoder = JSONDecoder()
        if asArray {
            return try decoder.decode([StreamingShow].self, from: data)
        }
        let single = try decoder.decode(StreamingShow.self, from: data)
        return [single]
    }
}