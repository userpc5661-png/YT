import Foundation

enum SourceClientError: LocalizedError {
    case badURL
    case status(Int)
    case empty

    var errorDescription: String? {
        switch self {
        case .badURL: return "Bad URL"
        case .status(let code): return "HTTP \(code)"
        case .empty: return "No items"
        }
    }
}

enum SourceFeed: Equatable {
    case movies
    case series
    case search(String)
}

enum SourceClient {
    static func load(
        _ source: ContentSource,
        feed: SourceFeed,
        page: Int? = nil,
        secret providedSecret: String? = nil
    ) async throws -> [RemoteTitle] {
        let secret = providedSecret ?? KeychainStore.get(account: source.id.uuidString) ?? ""
        let path: String
        let kind: TitleKind
        switch feed {
        case .movies:
            path = source.moviesPath
            kind = .movie
        case .series:
            path = source.seriesPath
            kind = .series
        case .search(_):
            path = source.searchPath
            kind = .movie
        }
        guard !path.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let query = switch feed {
        case .search(let text): text
        default: nil as String?
        }
        let pageNumber = page ?? (source.pageStyle == .none ? nil : source.pageStart)
        guard let url = source.resolved(path: path, query: query, page: pageNumber) else {
            throw SourceClientError.badURL
        }
        var request = authorized(url, source: source, secret: secret)
        request.timeoutInterval = 25
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw SourceClientError.status(http.statusCode)
        }
        let json = try JSONSerialization.jsonObject(with: data)
        return JSONPath.items(json, path: source.map.items).map { item in
            parse(item, source: source, fallbackKind: kind)
        }
    }

    static func episodes(for title: RemoteTitle, source: ContentSource) async -> [RemoteEpisode] {
        guard !source.episodesPath.isEmpty,
              let url = source.resolved(path: source.episodesPath, itemID: title.id) else {
            return title.episodes
        }
        let secret = KeychainStore.get(account: source.id.uuidString) ?? ""
        var request = authorized(url, source: source, secret: secret)
        request.timeoutInterval = 25
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return title.episodes
        }
        let rows = JSONPath.items(json, path: source.map.episodes.isEmpty ? source.map.items : source.map.episodes)
        let parsed = rows.enumerated().map { index, item in
            RemoteEpisode(
                id: JSONPath.string(item, "id") ?? "\(index)",
                title: JSONPath.string(item, source.map.episodeTitle) ?? "\(index + 1)",
                streamURL: mediaURL(JSONPath.string(item, source.map.episodeStream), prefix: source.map.imagePrefix)
            )
        }
        return parsed.isEmpty ? title.episodes : parsed
    }

    private static func authorized(_ url: URL, source: ContentSource, secret: String) -> URLRequest {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var request = URLRequest(url: url)
        let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return request }
        switch source.authKind {
        case .none:
            break
        case .header:
            request.setValue(trimmed, forHTTPHeaderField: source.authName.isEmpty ? "X-API-Key" : source.authName)
        case .query:
            var items = components?.queryItems ?? []
            items.append(URLQueryItem(name: source.authName.isEmpty ? "api_key" : source.authName, value: trimmed))
            components?.queryItems = items
            if let built = components?.url { request.url = built }
        case .bearer:
            request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private static func parse(_ item: [String: Any], source: ContentSource, fallbackKind: TitleKind) -> RemoteTitle {
        let map = source.map
        let id = JSONPath.string(item, map.id) ?? UUID().uuidString
        let showType = (JSONPath.string(item, "showType|media_type") ?? "").lowercased()
        let kind: TitleKind = showType == "series" || showType == "tv" ? .series : (showType == "movie" ? .movie : fallbackKind)
        let yearRaw = JSONPath.string(item, map.year) ?? ""
        let year = yearRaw.count >= 4 ? String(yearRaw.prefix(4)) : (yearRaw.isEmpty ? nil : yearRaw)
        let genres = genreNames(JSONPath.pick(item, map.genres))
        let episodes = JSONPath.items(item, path: map.episodes).enumerated().map { index, episode in
            RemoteEpisode(
                id: JSONPath.string(episode, "id") ?? "\(id)-\(index)",
                title: JSONPath.string(episode, map.episodeTitle) ?? "\(index + 1)",
                streamURL: mediaURL(JSONPath.string(episode, map.episodeStream), prefix: "")
            )
        }
        return RemoteTitle(
            sourceID: source.id,
            id: id,
            title: JSONPath.string(item, map.title) ?? id,
            overview: JSONPath.string(item, map.overview) ?? "",
            posterURL: mediaURL(JSONPath.string(item, map.poster), prefix: map.imagePrefix),
            backdropURL: mediaURL(JSONPath.string(item, map.backdrop), prefix: map.imagePrefix),
            year: year,
            genres: genres,
            rating: JSONPath.string(item, map.rating),
            streamURL: mediaURL(JSONPath.string(item, map.stream), prefix: ""),
            episodes: episodes,
            kind: kind
        )
    }

    private static func genreNames(_ value: Any?) -> [String] {
        if let list = value as? [String] { return list }
        if let list = value as? [[String: Any]] {
            return list.compactMap { item in
                if let name = item["name"] as? String { return name }
                if let id = item["id"] { return "\(id)" }
                return nil
            }
        }
        if let text = value as? String, !text.isEmpty { return [text] }
        return []
    }

    private static func mediaURL(_ raw: String?, prefix: String) -> URL? {
        guard var raw, !raw.isEmpty, raw != "<null>" else { return nil }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            guard let url = URL(string: raw), url.scheme?.lowercased() == "https" else { return nil }
            return url
        }
        if !prefix.isEmpty {
            let base = prefix.hasSuffix("/") ? String(prefix.dropLast()) : prefix
            if !raw.hasPrefix("/") { raw = "/" + raw }
            guard let url = URL(string: base + raw), url.scheme?.lowercased() == "https" else { return nil }
            return url
        }
        guard let url = URL(string: raw), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }
}
