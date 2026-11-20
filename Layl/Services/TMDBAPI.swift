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

actor TMDBAPI {
    private let session: URLSession
    private let baseURL = "https://api.themoviedb.org/3/"

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
    private(set) var searchResults: [TMDBTitle] = []
    private(set) var isLoading = false
    private(set) var isSearching = false
    private(set) var error: String?
    private(set) var searchError: String?

    @ObservationIgnored private let api = TMDBAPI()
    @ObservationIgnored private var loadedLanguage: String?
    @ObservationIgnored private var trendingTask: Task<Void, Never>?
    @ObservationIgnored private var activeTrendingRequestID: UUID?
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
        searchResults = []
        loadedLanguage = nil
        error = nil
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
