import Foundation

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case arabic
    case english

    var id: String { rawValue }

    func t(_ arabic: String, _ english: String) -> String {
        self == .arabic ? arabic : english
    }
}

struct L10n: Hashable, Codable {
    var ar: String
    var en: String

    func text(_ language: AppLanguage) -> String {
        language == .arabic ? ar : en
    }
}

enum Genre: String, Codable, CaseIterable, Identifiable, Hashable {
    case animation
    case comedy
    case family
    case fantasy
    case scienceFiction
    case action
    case drama
    case horror
    case thriller
    case classic
    case romance
    case experimental
    case adventure
    case crime
    case shortFilm

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .animation: return language.t("رسوم متحركة", "Animation")
        case .comedy: return language.t("كوميديا", "Comedy")
        case .family: return language.t("عائلي", "Family")
        case .fantasy: return language.t("خيال", "Fantasy")
        case .scienceFiction: return language.t("خيال علمي", "Sci-Fi")
        case .action: return language.t("أكشن", "Action")
        case .drama: return language.t("دراما", "Drama")
        case .horror: return language.t("رعب", "Horror")
        case .thriller: return language.t("إثارة", "Thriller")
        case .classic: return language.t("كلاسيكيات", "Classics")
        case .romance: return language.t("رومانسي", "Romance")
        case .experimental: return language.t("تجريبي", "Experimental")
        case .adventure: return language.t("مغامرة", "Adventure")
        case .crime: return language.t("جريمة", "Crime")
        case .shortFilm: return language.t("قصير", "Short")
        }
    }
}

enum TitleKind: String, Codable, Hashable {
    case movie
    case series
}

enum TransferQuality: String, Codable, Hashable {
    case hd
    case compact
    case archival
}

struct Episode: Identifiable, Hashable, Codable {
    let id: String
    let season: Int
    let number: Int
    let title: L10n
    let synopsis: L10n
    let minutes: Int
    let videoURL: String
    let stillAsset: String
}

struct CatalogTitle: Identifiable, Hashable, Codable {
    let id: String
    let title: L10n
    let synopsis: L10n
    let year: Int
    let score: Double
    let match: Int
    let maturity: L10n
    let genres: [Genre]
    let kind: TitleKind
    let minutes: Int
    let kids: Bool
    let posterAsset: String
    let backdropAsset: String
    let credit: L10n
    let cast: [L10n]
    let rights: String
    let rightsURL: String
    let archiveID: String
    let quality: TransferQuality
    let episodes: [Episode]
    let externalImdb: String?

    var archivePage: String { "https://archive.org/details/\(archiveID)" }

    func matches(_ rawQuery: String) -> Bool {
        let query = rawQuery.folded
        guard !query.isEmpty else { return true }
        let blob = (
            [title.ar, title.en, synopsis.ar, synopsis.en, credit.ar, credit.en]
            + cast.flatMap { [$0.ar, $0.en] }
            + genres.flatMap { [$0.title(.arabic), $0.title(.english)] }
            + episodes.flatMap { [$0.title.ar, $0.title.en, $0.synopsis.ar, $0.synopsis.en] }
        )
        .joined(separator: "\n")
        .folded
        return blob.contains(query)
    }
}

enum LaneStyle: String, Hashable, Codable {
    case poster
    case ranked
}

struct Lane: Identifiable, Hashable {
    let id: String
    let title: L10n
    let titleIDs: [String]
    let style: LaneStyle
}

struct Profile: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var colorHex: String
    var isKids: Bool

    static let palette = ["E50914", "4C8DFF", "F5A623", "2FBF71", "B06CFF", "FF6B8A", "22C1C3", "F2E24B"]

    static let defaults: [Profile] = [
        Profile(id: "p-abdullah", name: "عبدالله", colorHex: "E50914", isKids: false),
        Profile(id: "p-sarah", name: "سارة", colorHex: "4C8DFF", isKids: false),
        Profile(id: "p-fahd", name: "فهد", colorHex: "F5A623", isKids: false),
        Profile(id: "p-kids", name: "أطفال", colorHex: "2FBF71", isKids: true)
    ]
}

struct WatchProgress: Hashable, Codable {
    var titleID: String
    var episodeID: String
    var position: Double
    var duration: Double
    var updatedAt: Date

    var isResumable: Bool {
        guard duration > 1, position.isFinite, duration.isFinite else { return false }
        return position >= 8 && position / duration < 0.92
    }

    var fraction: Double {
        guard duration > 1 else { return 0 }
        return min(max(position / duration, 0), 1)
    }
}

struct ContinueItem: Identifiable, Hashable {
    var id: String { episode.id }
    let title: CatalogTitle
    let episode: Episode
    let progress: WatchProgress
}

struct PlayRequest: Identifiable, Equatable {
    let token: UUID
    let titleID: String
    let episodeID: String
    var id: UUID { token }
}

enum MediaURL {
    static func archive(identifier: String, file: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~/")
        let encoded = file.addingPercentEncoding(withAllowedCharacters: allowed) ?? file
        return "https://archive.org/download/\(identifier)/\(encoded)"
    }
}

extension String {
    var folded: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "ar"))
    }
}

enum Clock {
    static func text(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
