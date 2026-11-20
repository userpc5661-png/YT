import Foundation
import Observation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum AniListAPIError: LocalizedError {
    case invalidURL
    case badStatus(Int)
    case rateLimited(Int)
    case apiMessage(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Could not create the AniList request."
        case .badStatus(let code):
            return "AniList returned HTTP \(code)."
        case .rateLimited(let seconds):
            return "AniList is limiting requests. Please wait \(seconds) seconds before trying again."
        case .apiMessage(let message):
            return message
        case .emptyResponse:
            return "AniList returned an empty response."
        }
    }
}

struct AniListTitle: Decodable, Hashable, Identifiable, Sendable {
    let id: Int
    let title: AniListLocalizedTitle
    let coverImage: AniListCoverImage
    let bannerImage: String?
    let overview: String?
    let seasonYear: Int?
    let averageScore: Int?
    let episodes: Int?
    let format: String?
    let genres: [String]
    let isAdult: Bool?
    let tags: [AniListTag]?
    let siteURLString: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case coverImage
        case bannerImage
        case overview = "description"
        case seasonYear
        case averageScore
        case episodes
        case format
        case genres
        case isAdult
        case tags
        case siteURLString = "siteUrl"
    }

    var displayTitle: String {
        title.english ?? title.romaji ?? title.native ?? "Untitled anime"
    }

    var originalTitle: String? {
        guard let native = title.native,
              native.caseInsensitiveCompare(displayTitle) != .orderedSame else { return nil }
        return native
    }

    var bannerURL: URL? {
        guard let bannerImage, let url = URL(string: bannerImage), url.scheme == "https" else { return nil }
        return url
    }

    var coverURL: URL? {
        let value = coverImage.extraLarge ?? coverImage.large
        guard let value, let url = URL(string: value), url.scheme == "https" else { return nil }
        return url
    }

    var aniListURL: URL {
        if let siteURLString, let url = URL(string: siteURLString), url.scheme == "https" {
            return url
        }
        return URL(string: "https://anilist.co/anime/\(id)")!
    }

    var ratingText: String? {
        guard let averageScore, averageScore > 0 else { return nil }
        return String(format: "%.1f", Double(averageScore) / 10)
    }

    var safeForGeneralDiscovery: Bool {
        guard isAdult != true,
              tags?.contains(where: { $0.isAdult == true }) != true else { return false }
        return !genres.contains(where: { ["ecchi", "hentai"].contains($0.lowercased()) })
    }
}

struct AniListLocalizedTitle: Decodable, Hashable, Sendable {
    let romaji: String?
    let english: String?
    let native: String?
}

struct AniListCoverImage: Decodable, Hashable, Sendable {
    let large: String?
    let extraLarge: String?
}

struct AniListTag: Decodable, Hashable, Sendable {
    let name: String
    let isAdult: Bool?
}

private struct AniListEnvelope: Decodable {
    let data: AniListPayload?
    let errors: [AniListGraphQLError]?
}

private struct AniListGraphQLError: Decodable {
    let message: String
}

private struct AniListPayload: Decodable {
    let page: AniListPage?
    let media: AniListTitle?

    enum CodingKeys: String, CodingKey {
        case page = "Page"
        case media = "Media"
    }
}

private struct AniListPage: Decodable {
    let items: [AniListTitle]

    enum CodingKeys: String, CodingKey {
        case items = "media"
    }
}

actor AniListAPI {
    private let session: URLSession
    private let endpoint = URL(string: "https://graphql.anilist.co")!
    private let minimumRequestInterval: TimeInterval = 2.1
    private var nextRequestAt: Date?
    private var retryNotBefore: Date?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func trending() async throws -> [AniListTitle] {
        let query = """
        query ($page: Int!, $perPage: Int!) {
          Page(page: $page, perPage: $perPage) {
            media(type: ANIME, isAdult: false, sort: TRENDING_DESC) {
              \(Self.mediaFields)
            }
          }
        }
        """
        let payload = try await request(query: query, variables: ["page": 1, "perPage": 20])
        return (payload.page?.items ?? []).filter(\.safeForGeneralDiscovery)
    }

    func search(_ queryText: String) async throws -> [AniListTitle] {
        let query = """
        query ($page: Int!, $perPage: Int!, $search: String!) {
          Page(page: $page, perPage: $perPage) {
            media(type: ANIME, isAdult: false, search: $search, sort: SEARCH_MATCH) {
              \(Self.mediaFields)
            }
          }
        }
        """
        let payload = try await request(
            query: query,
            variables: ["page": 1, "perPage": 20, "search": queryText]
        )
        return (payload.page?.items ?? []).filter(\.safeForGeneralDiscovery)
    }

    private static let mediaFields = """
    id
    title { romaji english native }
    coverImage { large extraLarge }
    bannerImage
    description(asHtml: false)
    seasonYear
    averageScore
    episodes
    format
    genres
    isAdult
    tags { name isAdult }
    siteUrl
    """

    private func request(query: String, variables: [String: Any]) async throws -> AniListPayload {
        try await reserveRequestSlot()
        try Task.checkCancellation()

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "query": query,
            "variables": variables
        ])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AniListAPIError.badStatus(-1)
        }
        let envelope = try? JSONDecoder().decode(AniListEnvelope.self, from: data)
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 429 {
                let seconds = min(max(Int(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 60, 1), 3_600)
                retryNotBefore = Date().addingTimeInterval(TimeInterval(seconds))
                throw AniListAPIError.rateLimited(seconds)
            }
            if let message = envelope?.errors?.first?.message {
                throw AniListAPIError.apiMessage(message)
            }
            throw AniListAPIError.badStatus(http.statusCode)
        }
        guard let envelope else { throw AniListAPIError.emptyResponse }
        if let message = envelope.errors?.first?.message {
            throw AniListAPIError.apiMessage(message)
        }
        guard let payload = envelope.data else { throw AniListAPIError.emptyResponse }
        return payload
    }

    private func reserveRequestSlot() async throws {
        while true {
            let now = Date()
            let scheduledStart = max(now, max(nextRequestAt ?? now, retryNotBefore ?? now))
            nextRequestAt = scheduledStart.addingTimeInterval(minimumRequestInterval)
            let delay = scheduledStart.timeIntervalSinceNow
            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            try Task.checkCancellation()
            if let retryNotBefore, retryNotBefore > Date() { continue }
            return
        }
    }
}

@Observable
final class AniListCatalogModel {
    private(set) var trending: [AniListTitle] = []
    private(set) var searchResults: [AniListTitle] = []
    private(set) var isLoading = false
    private(set) var isSearching = false
    private(set) var error: String?
    private(set) var searchError: String?

    @ObservationIgnored private let api = AniListAPI()
    @ObservationIgnored private var trendingTask: Task<Void, Never>?
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var activeTrendingRequestID: UUID?
    @ObservationIgnored private var activeSearchRequestID: UUID?
    @ObservationIgnored private var loadedAt: Date?

    func loadTrending(forceRefresh: Bool = false) {
        if isLoading && !forceRefresh { return }
        let cacheIsFresh = loadedAt.map { Date().timeIntervalSince($0) < 30 * 60 } ?? false
        guard forceRefresh || trending.isEmpty || !cacheIsFresh else { return }

        trendingTask?.cancel()
        let requestID = UUID()
        activeTrendingRequestID = requestID
        isLoading = true
        error = nil
        trendingTask = Task { @MainActor in
            defer {
                if self.activeTrendingRequestID == requestID {
                    self.isLoading = false
                    self.trendingTask = nil
                }
            }
            do {
                let titles = try await self.api.trending()
                guard !Task.isCancelled, self.activeTrendingRequestID == requestID else { return }
                self.trending = titles
                self.loadedAt = Date()
                self.error = nil
            } catch {
                guard self.activeTrendingRequestID == requestID else { return }
                self.error = error.localizedDescription
            }
        }
    }

    func refreshTrending() async {
        loadTrending(forceRefresh: true)
        let task = trendingTask
        await task?.value
    }

    func search(_ rawQuery: String) {
        searchTask?.cancel()
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            activeSearchRequestID = nil
            searchResults = []
            searchError = nil
            isSearching = false
            return
        }

        let requestID = UUID()
        activeSearchRequestID = requestID
        searchResults = []
        searchError = nil
        isSearching = true
        searchTask = Task { @MainActor in
            defer {
                if self.activeSearchRequestID == requestID {
                    self.isSearching = false
                    self.searchTask = nil
                }
            }
            do {
                try await Task.sleep(nanoseconds: 700_000_000)
                guard !Task.isCancelled, self.activeSearchRequestID == requestID else { return }
                let titles = try await self.api.search(query)
                guard !Task.isCancelled, self.activeSearchRequestID == requestID else { return }
                self.searchResults = titles
                self.searchError = nil
            } catch {
                guard self.activeSearchRequestID == requestID else { return }
                self.searchResults = []
                self.searchError = error.localizedDescription
            }
        }
    }
}
