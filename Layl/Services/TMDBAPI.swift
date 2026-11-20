import Foundation
import Observation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum TMDBAPIError: LocalizedError {
    case missingToken
    case invalidURL
    case badStatus(Int)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .missingToken: return "TMDB API Read Access Token is missing."
        case .invalidURL: return "Could not create the TMDB request."
        case .badStatus(let code): return "TMDB returned HTTP \(code)."
        case .decodeFailed: return "TMDB returned an unexpected response."
        }
    }
}

struct TMDBHomeCatalog: Sendable {
    let trending: [TMDBTitle]?
    let movies: [TMDBTitle]?
    let series: [TMDBTitle]?
    let anime: [TMDBTitle]?
    let error: String?
    let hasPartialFailure: Bool
}
actor TMDBAPI {
    private let session: URLSession
    private let baseURL = "https://api.themoviedb.org/3/"
    private var detailCache: [String: TMDBTitleDetails] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func trendingAll(language: String, accessToken: String) async throws -> [TMDBTitle] {
        let page: TMDBPage = try await request(
            path: "trending/all/week",
            query: [URLQueryItem(name: "language", value: language)],
            accessToken: accessToken
        )
        return page.results.filter { ["movie", "tv"].contains($0.kind) && $0.adult != true }
    }

    func search(query: String, language: String, accessToken: String) async throws -> [TMDBTitle] {
        let page: TMDBPage = try await request(
            path: "search/multi",
            query: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "include_adult", value: "false"),
                URLQueryItem(name: "language", value: language),
                URLQueryItem(name: "page", value: "1")
            ],
            accessToken: accessToken
        )
        return page.results.filter { ["movie", "tv"].contains($0.kind) && $0.adult != true }
    }

    func titleDetails(title: TMDBTitle, language: String, accessToken: String) async throws -> TMDBTitleDetails {
        let cacheKey = "\(title.kind)-\(title.tmdbID)-\(language)"
        if let cached = detailCache[cacheKey] { return cached }
        let mediaPath = title.kind == "tv" ? "tv" : "movie"
        let details: TMDBTitleDetails = try await request(
            path: "\(mediaPath)/\(title.tmdbID)",
            query: [URLQueryItem(name: "language", value: language)],
            accessToken: accessToken
        )
        detailCache[cacheKey] = details
        return details
    }

    func homeCatalog(language: String, accessToken: String) async -> TMDBHomeCatalog {
        async let trending = try? await trendingAll(language: language, accessToken: accessToken)
        async let movies = try? await discover(
            media: "movie",
            language: language,
            filters: [],
            accessToken: accessToken
        )
        async let series = try? await discover(
            media: "tv",
            language: language,
            filters: [],
            accessToken: accessToken
        )
        async let animeMovies = try? await discover(
            media: "movie",
            language: language,
            filters: animeFilters,
            accessToken: accessToken
        )
        async let animeSeries = try? await discover(
            media: "tv",
            language: language,
            filters: animeFilters,
            accessToken: accessToken
        )

        let (trendingResults, movieResults, seriesResults, animeMovieResults, animeSeriesResults) = await (
            trending, movies, series, animeMovies, animeSeries
        )
        let anime = Dictionary(
            ((animeMovieResults ?? []) + (animeSeriesResults ?? [])).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        .values
        .sorted { ($0.popularity ?? 0) > ($1.popularity ?? 0) }
        let animeResults: [TMDBTitle]? = animeMovieResults == nil && animeSeriesResults == nil ? nil : anime

        let failures = [
            trendingResults == nil,
            movieResults == nil,
            seriesResults == nil,
            animeMovieResults == nil,
            animeSeriesResults == nil
        ]
        return TMDBHomeCatalog(
            trending: trendingResults,
            movies: movieResults,
            series: seriesResults,
            anime: animeResults,
            error: failures.allSatisfy { $0 }
                ? "TMDB could not load the catalog. Check your connection or access token."
                : nil,
            hasPartialFailure: failures.contains(true) && !failures.allSatisfy { $0 }
        )
    }

    private var animeFilters: [URLQueryItem] {
        [
            URLQueryItem(name: "with_genres", value: "16"),
            URLQueryItem(name: "with_original_language", value: "ja")
        ]
    }

    private func discover(
        media: String,
        language: String,
        filters: [URLQueryItem],
        accessToken: String
    ) async throws -> [TMDBTitle] {
        let page: TMDBPage = try await request(
            path: "discover/\(media)",
            query: [
                URLQueryItem(name: "language", value: language),
                URLQueryItem(name: "include_adult", value: "false"),
                URLQueryItem(name: "sort_by", value: "popularity.desc"),
                URLQueryItem(name: "page", value: "1")
            ] + filters,
            accessToken: accessToken
        )
        return page.results.filter { $0.adult != true }
    }

    private func request<Response: Decodable>(
        path: String,
        query: [URLQueryItem],
        accessToken: String
    ) async throws -> Response {
        let token = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw TMDBAPIError.missingToken }
        guard var components = URLComponents(string: baseURL + path) else {
            throw TMDBAPIError.invalidURL
        }
        components.queryItems = query
        guard let url = components.url else { throw TMDBAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TMDBAPIError.badStatus(-1) }
        guard (200...299).contains(http.statusCode) else {
            throw TMDBAPIError.badStatus(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw TMDBAPIError.decodeFailed
        }
    }
}

@Observable
final class TMDBCatalogModel {
    private(set) var accessToken: String
    private(set) var trending: [TMDBTitle] = []
    private(set) var movies: [TMDBTitle] = []
    private(set) var series: [TMDBTitle] = []
    private(set) var anime: [TMDBTitle] = []
    private(set) var searchResults: [TMDBTitle] = []
    private(set) var isLoading = false
    private(set) var isLoadingHome = false
    private(set) var isSearching = false
    private(set) var error: String?
    private(set) var homeError: String?
    private(set) var homeWarning = false
    private(set) var searchError: String?

    @ObservationIgnored private let api = TMDBAPI()
    @ObservationIgnored private var loadedLanguage: String?
    @ObservationIgnored private var loadedHomeLanguage: String?
    @ObservationIgnored private var loadedHomeDataLanguage: String?
    @ObservationIgnored private var trendingTask: Task<Void, Never>?
    @ObservationIgnored private var homeTask: Task<Void, Never>?
    @ObservationIgnored private var activeTrendingRequestID: UUID?
    @ObservationIgnored private var activeHomeRequestID: UUID?
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var activeSearchRequestID: UUID?

    init() {
        accessToken = KeychainStore.get(account: "tmdb.read-access-token") ?? ""
    }

    var isConfigured: Bool {
        !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func updateAccessToken(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        trendingTask?.cancel()
        trendingTask = nil
        activeTrendingRequestID = nil
        isLoading = false
        homeTask?.cancel()
        homeTask = nil
        activeHomeRequestID = nil
        isLoadingHome = false
        searchTask?.cancel()
        searchTask = nil
        activeSearchRequestID = nil
        isSearching = false
        accessToken = trimmed
        if trimmed.isEmpty {
            KeychainStore.delete(account: "tmdb.read-access-token")
        } else {
            KeychainStore.set(trimmed, account: "tmdb.read-access-token")
        }
        trending = []
        movies = []
        series = []
        anime = []
        searchResults = []
        loadedLanguage = nil
        loadedHomeLanguage = nil
        loadedHomeDataLanguage = nil
        error = nil
        homeError = nil
        homeWarning = false
        searchError = nil
    }

    func refreshTrending(language: String) async {
        while isLoading {
            guard !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        guard !Task.isCancelled else { return }
        loadTrending(language: language, forceRefresh: true)
        while isLoading {
            guard !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    func refreshHomeCatalog(language: String) async {
        while isLoadingHome {
            guard !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        guard !Task.isCancelled else { return }
        loadHomeCatalog(language: language, forceRefresh: true)
        while isLoadingHome {
            guard !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    func loadTrending(language: String, forceRefresh: Bool = false) {
        guard isConfigured else { return }
        if isLoading && !forceRefresh { return }
        guard forceRefresh || trending.isEmpty || loadedLanguage != language else { return }
        trendingTask?.cancel()
        let requestID = UUID()
        activeTrendingRequestID = requestID
        let token = accessToken
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
                let values = try await self.api.trendingAll(language: language, accessToken: token)
                guard !Task.isCancelled,
                      self.activeTrendingRequestID == requestID,
                      token == self.accessToken else { return }
                self.trending = values
                self.loadedLanguage = language
                self.error = nil
            } catch {
                guard self.activeTrendingRequestID == requestID, token == self.accessToken else { return }
                self.error = error.localizedDescription
            }
        }
    }

    func loadHomeCatalog(language: String, forceRefresh: Bool = false) {
        guard isConfigured else { return }
        if isLoadingHome && !forceRefresh { return }
        guard forceRefresh || loadedHomeLanguage != language else { return }
        homeTask?.cancel()
        let requestID = UUID()
        activeHomeRequestID = requestID
        let token = accessToken
        let previousLanguage = loadedHomeDataLanguage
        isLoadingHome = true
        homeError = nil
        homeWarning = false
        homeTask = Task { @MainActor in
            defer {
                if self.activeHomeRequestID == requestID {
                    self.isLoadingHome = false
                    self.homeTask = nil
                }
            }
            let catalog = await self.api.homeCatalog(language: language, accessToken: token)
            guard !Task.isCancelled,
                  self.activeHomeRequestID == requestID,
                  token == self.accessToken else { return }
            if let values = catalog.trending { self.trending = values }
            else if previousLanguage != language { self.trending = [] }
            if let values = catalog.movies { self.movies = values }
            else if previousLanguage != language { self.movies = [] }
            if let values = catalog.series { self.series = values }
            else if previousLanguage != language { self.series = [] }
            if let values = catalog.anime { self.anime = values }
            else if previousLanguage != language { self.anime = [] }
            self.loadedLanguage = language
            self.loadedHomeLanguage = catalog.error == nil && !catalog.hasPartialFailure ? language : nil
            if catalog.trending != nil || catalog.movies != nil || catalog.series != nil || catalog.anime != nil {
                self.loadedHomeDataLanguage = language
            }
            self.error = catalog.error
            self.homeError = catalog.error
            self.homeWarning = catalog.hasPartialFailure
        }
    }

    func titleDetails(for title: TMDBTitle, language: String) async throws -> TMDBTitleDetails {
        try await api.titleDetails(title: title, language: language, accessToken: accessToken)
    }

    func search(_ rawQuery: String, language: String, kidsOnly: Bool) {
        searchTask?.cancel()
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2, isConfigured, !kidsOnly else {
            activeSearchRequestID = nil
            searchTask = nil
            searchResults = []
            isSearching = false
            searchError = nil
            return
        }
        let requestID = UUID()
        activeSearchRequestID = requestID
        let token = accessToken
        searchResults = []
        isSearching = true
        searchError = nil
        searchTask = Task { @MainActor in
            defer {
                if self.activeSearchRequestID == requestID {
                    self.isSearching = false
                    self.searchTask = nil
                }
            }
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled,
                      self.activeSearchRequestID == requestID,
                      token == self.accessToken else { return }
                let values = try await self.api.search(query: query, language: language, accessToken: token)
                guard !Task.isCancelled,
                      self.activeSearchRequestID == requestID,
                      token == self.accessToken else { return }
                self.searchResults = values
                self.searchError = nil
            } catch {
                guard self.activeSearchRequestID == requestID, token == self.accessToken else { return }
                self.searchResults = []
                self.searchError = error.localizedDescription
            }
        }
    }
}
