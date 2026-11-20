import Combine
import Foundation

private let defaultFaselHost = "192.168.1.5"
private let faselPort = 8080

enum FaselConfig {
    static var host: String {
        get { UserDefaults.standard.string(forKey: "fasel.host") ?? defaultFaselHost }
        set { UserDefaults.standard.set(newValue, forKey: "fasel.host") }
    }

    static var baseURL: String { "http://\(host):\(faselPort)" }
}

enum FaselError: LocalizedError {
    case badURL
    case status(Int)

    var errorDescription: String? {
        switch self {
        case .badURL: return "Bad host"
        case .status(let code): return "HTTP \(code)"
        }
    }
}

struct FaselItem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let type: String
    let thumbnail: String
    let year: String
    let url: String
    let stream_url: String

    var imageURL: URL? {
        guard !thumbnail.isEmpty, thumbnail != "<null>" else { return nil }
        if thumbnail.hasPrefix("http") { return URL(string: thumbnail) }
        let base = FaselConfig.baseURL
        return URL(string: base + (thumbnail.hasPrefix("/") ? thumbnail : "/" + thumbnail))
    }
}

struct FaselPage: Codable {
    let total: Int
    let page: Int
    let pages: Int
    let results: [FaselItem]
}

@MainActor
final class FaselClient: ObservableObject {
    static let shared = FaselClient()

    @Published var items: [FaselItem] = []
    @Published var loading = false
    @Published var error: String?
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var total = 0

    func load(type: String = "", query: String = "", page: Int = 1, appending: Bool = false) async {
        loading = true
        error = nil

        var components = URLComponents(string: "\(FaselConfig.baseURL)/catalog/layl")
        var queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "40")
        ]
        if !type.isEmpty { queryItems.append(URLQueryItem(name: "type", value: type)) }
        if !query.isEmpty { queryItems.append(URLQueryItem(name: "q", value: query)) }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            error = FaselError.badURL.localizedDescription
            loading = false
            return
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw FaselError.status(http.statusCode)
            }
            let decoded = try JSONDecoder().decode(FaselPage.self, from: data)
            items = appending ? items + decoded.results : decoded.results
            currentPage = decoded.page
            totalPages = max(decoded.pages, 1)
            total = decoded.total
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    func prefetch(_ item: FaselItem) {
        guard let url = endpoint("/prefetch", item: item) else { return }
        Task.detached { try? await URLSession.shared.data(from: url) }
    }

    func resolveStream(_ item: FaselItem) async -> URL? {
        guard let url = endpoint("/stream", item: item) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 75
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let payload = try? JSONDecoder().decode(StreamResponse.self, from: data),
              let master = payload.master
        else { return nil }
        return URL(string: master)
    }

    private func endpoint(_ path: String, item: FaselItem) -> URL? {
        var components = URLComponents(string: FaselConfig.baseURL + path)
        components?.queryItems = [URLQueryItem(name: "url", value: item.url)]
        return components?.url
    }
}

private struct StreamResponse: Codable {
    let master: String?
    let error: String?
}
