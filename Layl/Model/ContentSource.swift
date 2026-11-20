import Foundation

enum SourceAuthKind: String, Codable, CaseIterable, Identifiable {
    case none
    case header
    case query
    case bearer

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .none: return language.t("بدون", "None")
        case .header: return language.t("مفتاح في الترويسة", "API key header")
        case .query: return language.t("مفتاح في الرابط", "Query parameter")
        case .bearer: return language.t("Bearer", "Bearer token")
        }
    }
}

enum SourcePageStyle: String, Codable, CaseIterable, Identifiable {
    case none
    case pageQuery

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .none: return language.t("بدون صفحات", "No paging")
        case .pageQuery: return language.t("رقم صفحة في الرابط", "Page query")
        }
    }
}

struct FieldMap: Codable, Hashable {
    var items: String
    var id: String
    var title: String
    var overview: String
    var poster: String
    var backdrop: String
    var year: String
    var genres: String
    var rating: String
    var stream: String
    var episodes: String
    var episodeTitle: String
    var episodeStream: String
    var imagePrefix: String

    static let empty = FieldMap(
        items: "results",
        id: "id",
        title: "title|name",
        overview: "overview",
        poster: "poster_path",
        backdrop: "backdrop_path",
        year: "release_date|first_air_date",
        genres: "genres",
        rating: "vote_average",
        stream: "",
        episodes: "",
        episodeTitle: "name",
        episodeStream: "",
        imagePrefix: ""
    )
}

struct ContentSource: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var enabled: Bool
    var baseURL: String
    var moviesPath: String
    var seriesPath: String
    var searchPath: String
    var episodesPath: String
    var authKind: SourceAuthKind
    var authName: String
    var pageStyle: SourcePageStyle
    var pageParameter: String
    var pageStart: Int
    var map: FieldMap

    func resolved(path: String, query: String? = nil, itemID: String? = nil, page: Int? = nil) -> URL? {
        var raw = path
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        if let query {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: unreserved) ?? query
            raw = raw.replacingOccurrences(of: "{query}", with: encoded)
        }
        if let itemID {
            let encoded = itemID.addingPercentEncoding(withAllowedCharacters: unreserved) ?? itemID
            raw = raw.replacingOccurrences(of: "{id}", with: encoded)
        }
        let base = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let suffix = raw.hasPrefix("http") ? raw : base + (raw.hasPrefix("/") ? raw : "/" + raw)
        guard var components = URLComponents(string: suffix) else { return nil }
        guard components.scheme?.lowercased() == "https", components.host != nil,
              components.user == nil, components.password == nil else { return nil }
        if pageStyle == .pageQuery, let page {
            var items = components.queryItems ?? []
            items.append(URLQueryItem(name: pageParameter.isEmpty ? "page" : pageParameter, value: String(page)))
            components.queryItems = items
        }
        return components.url
    }
}

struct RemoteEpisode: Identifiable, Hashable {
    var id: String
    var title: String
    var streamURL: URL?
}

struct RemoteTitle: Identifiable, Hashable {
    var sourceID: UUID
    var id: String
    var title: String
    var overview: String
    var posterURL: URL?
    var backdropURL: URL?
    var year: String?
    var genres: [String]
    var rating: String?
    var streamURL: URL?
    var episodes: [RemoteEpisode]
    var kind: TitleKind

    var directVideo: Bool {
        guard let streamURL, streamURL.scheme?.lowercased() == "https" else { return false }
        return ["mp4", "m3u8", "mov", "m4v"].contains(streamURL.pathExtension.lowercased())
    }
}

struct SourceRail: Identifiable, Hashable {
    var source: ContentSource
    var titles: [RemoteTitle]
    var series: Bool = false
    var id: String { "\(source.id.uuidString)-\(series ? "series" : "movies")" }
}

struct RemotePlayback: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let title: String
}

enum SourcePresets {
    static func tmdb() -> ContentSource {
        var map = FieldMap.empty
        map.imagePrefix = "https://image.tmdb.org/t/p/w500"
        map.genres = "genre_ids"
        return ContentSource(
            id: UUID(),
            name: "TMDB",
            enabled: true,
            baseURL: "https://api.themoviedb.org/3",
            moviesPath: "/movie/popular",
            seriesPath: "/tv/popular",
            searchPath: "/search/multi?query={query}",
            episodesPath: "",
            authKind: .bearer,
            authName: "Authorization",
            pageStyle: .pageQuery,
            pageParameter: "page",
            pageStart: 1,
            map: map
        )
    }

}
