import Foundation

enum StreamingAPIProvider: String, Codable, CaseIterable, Identifiable {
    case movieOfTheNight
    case rapidAPI

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .movieOfTheNight:
            return language.t("Movie of the Night", "Movie of the Night")
        case .rapidAPI:
            return language.t("RapidAPI", "RapidAPI")
        }
    }
}

enum ContentDensity: String, Codable, CaseIterable, Identifiable {
    case comfortable
    case compact

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .comfortable: return language.t("مريح", "Comfortable")
        case .compact: return language.t("مضغوط", "Compact")
        }
    }
}

struct StreamingCountry: Identifiable, Hashable {
    let code: String
    let nameAR: String
    let nameEN: String

    var id: String { code }

    func name(_ language: AppLanguage) -> String {
        language == .arabic ? nameAR : nameEN
    }

    static let supported: [StreamingCountry] = [
        StreamingCountry(code: "sa", nameAR: "السعودية", nameEN: "Saudi Arabia"),
        StreamingCountry(code: "ae", nameAR: "الإمارات", nameEN: "United Arab Emirates"),
        StreamingCountry(code: "eg", nameAR: "مصر", nameEN: "Egypt"),
        StreamingCountry(code: "us", nameAR: "الولايات المتحدة", nameEN: "United States"),
        StreamingCountry(code: "gb", nameAR: "المملكة المتحدة", nameEN: "United Kingdom")
    ]
}

struct StreamingServiceChip: Identifiable, Hashable {
    let id: String
    let titleAR: String
    let titleEN: String

    func title(_ language: AppLanguage) -> String {
        language == .arabic ? titleAR : titleEN
    }

    static let featured: [StreamingServiceChip] = [
        StreamingServiceChip(id: "netflix", titleAR: "نتفليكس", titleEN: "Netflix"),
        StreamingServiceChip(id: "disney", titleAR: "ديزني+", titleEN: "Disney+"),
        StreamingServiceChip(id: "apple", titleAR: "Apple TV", titleEN: "Apple TV"),
        StreamingServiceChip(id: "prime", titleAR: "برايم", titleEN: "Prime Video"),
        StreamingServiceChip(id: "hbo", titleAR: "ماكس", titleEN: "Max")
    ]
}

struct StreamingOption: Identifiable, Hashable {
    let id: String
    let serviceName: String
    let serviceID: String
    let type: String
    let link: URL?
    let quality: String?
}

struct StreamingShow: Identifiable, Hashable, Codable {
    let id: String
    let imdbId: String
    let tmdbId: String?
    let title: String
    let overview: String
    let releaseYear: Int?
    let rating: Int?
    let showType: String
    let posterURL: String?
    let backdropURL: String?
    let streamingOptions: [StreamingOption]

    var kind: TitleKind { showType == "series" ? .series : .movie }

    enum CodingKeys: String, CodingKey {
        case id, imdbId, tmdbId, title, overview, releaseYear, firstAirYear, rating, showType, imageSet, streamingOptions
    }

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: CodingKeys.self)
        id = try root.decode(String.self, forKey: .id)
        imdbId = try root.decode(String.self, forKey: .imdbId)
        if let intId = try? root.decode(Int.self, forKey: .tmdbId) {
            tmdbId = String(intId)
        } else {
            tmdbId = try? root.decode(String.self, forKey: .tmdbId)
        }
        title = try root.decode(String.self, forKey: .title)
        overview = (try? root.decode(String.self, forKey: .overview)) ?? ""
        releaseYear = (try? root.decode(Int.self, forKey: .releaseYear))
            ?? (try? root.decode(Int.self, forKey: .firstAirYear))
        rating = try? root.decode(Int.self, forKey: .rating)
        showType = (try? root.decode(String.self, forKey: .showType)) ?? "movie"

        if let set = try? root.decode(ImageSet.self, forKey: .imageSet) {
            posterURL = set.verticalPoster?.w360 ?? set.verticalPoster?.w240
            backdropURL = set.horizontalBackdrop?.w1080 ?? set.horizontalBackdrop?.w720
        } else {
            posterURL = nil
            backdropURL = nil
        }

        let optionsMap = try? root.decode([String: [RawOption]].self, forKey: .streamingOptions)
        var flat: [StreamingOption] = []
        for list in optionsMap?.values ?? [:].values {
            for (index, raw) in list.enumerated() {
                let sid = raw.service.id
                flat.append(
                    StreamingOption(
                        id: "\(sid)-\(raw.type)-\(index)",
                        serviceName: raw.service.name,
                        serviceID: sid,
                        type: raw.type,
                        link: raw.link.flatMap(URL.init(string:)),
                        quality: raw.quality
                    )
                )
            }
        }
        streamingOptions = flat
    }

    func encode(to encoder: Encoder) throws {
        var root = encoder.container(keyedBy: CodingKeys.self)
        try root.encode(id, forKey: .id)
        try root.encode(imdbId, forKey: .imdbId)
        try root.encode(title, forKey: .title)
        try root.encode(overview, forKey: .overview)
        try root.encode(showType, forKey: .showType)
    }

    private struct ImageSet: Decodable {
        let verticalPoster: SizeMap?
        let horizontalBackdrop: SizeMap?
    }

    private struct SizeMap: Decodable {
        let w240: String?
        let w360: String?
        let w480: String?
        let w720: String?
        let w1080: String?
    }

    private struct RawOption: Decodable {
        let service: RawService
        let type: String
        let link: String?
        let quality: String?
    }

    private struct RawService: Decodable {
        let id: String
        let name: String
    }
}

struct DiscoverLane: Identifiable, Hashable {
    let id: String
    let title: L10n
    let shows: [StreamingShow]
}