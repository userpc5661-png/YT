import Foundation

struct TMDBTitle: Decodable, Hashable, Identifiable, Sendable {
    let tmdbID: Int
    let mediaType: String?
    let titleValue: String?
    let nameValue: String?
    let originalTitleValue: String?
    let originalNameValue: String?
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let voteCount: Int?
    let popularity: Double?
    let originalLanguage: String?
    let genreIDs: [Int]
    let adult: Bool?

    enum CodingKeys: String, CodingKey {
        case tmdbID = "id"
        case mediaType = "media_type"
        case titleValue = "title"
        case nameValue = "name"
        case originalTitleValue = "original_title"
        case originalNameValue = "original_name"
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case popularity
        case originalLanguage = "original_language"
        case genreIDs = "genre_ids"
        case adult
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        tmdbID = try values.decode(Int.self, forKey: .tmdbID)
        mediaType = try values.decodeIfPresent(String.self, forKey: .mediaType)
        titleValue = try values.decodeIfPresent(String.self, forKey: .titleValue)
        nameValue = try values.decodeIfPresent(String.self, forKey: .nameValue)
        originalTitleValue = try values.decodeIfPresent(String.self, forKey: .originalTitleValue)
        originalNameValue = try values.decodeIfPresent(String.self, forKey: .originalNameValue)
        overview = try values.decodeIfPresent(String.self, forKey: .overview) ?? ""
        posterPath = try values.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try values.decodeIfPresent(String.self, forKey: .backdropPath)
        releaseDate = try values.decodeIfPresent(String.self, forKey: .releaseDate)
        firstAirDate = try values.decodeIfPresent(String.self, forKey: .firstAirDate)
        voteAverage = try values.decodeIfPresent(Double.self, forKey: .voteAverage)
        voteCount = try values.decodeIfPresent(Int.self, forKey: .voteCount)
        popularity = try values.decodeIfPresent(Double.self, forKey: .popularity)
        originalLanguage = try values.decodeIfPresent(String.self, forKey: .originalLanguage)
        genreIDs = try values.decodeIfPresent([Int].self, forKey: .genreIDs) ?? []
        adult = try values.decodeIfPresent(Bool.self, forKey: .adult)
    }

    var kind: String {
        mediaType ?? ((firstAirDate != nil || nameValue != nil || originalNameValue != nil) ? "tv" : "movie")
    }

    var id: String { "\(kind)-\(tmdbID)" }

    var title: String {
        titleValue ?? nameValue ?? originalTitleValue ?? originalNameValue ?? "Untitled"
    }

    var originalTitle: String? {
        let value = originalTitleValue ?? originalNameValue
        guard let value, value.caseInsensitiveCompare(title) != .orderedSame else { return nil }
        return value
    }

    var year: String? {
        let raw = releaseDate ?? firstAirDate
        guard let raw, raw.count >= 4 else { return nil }
        return String(raw.prefix(4))
    }

    var posterURL: URL? { imageURL(path: posterPath, size: "w500") }
    var backdropURL: URL? { imageURL(path: backdropPath, size: "w1280") }
    var tmdbURL: URL {
        URL(string: "https://www.themoviedb.org/\(kind == "tv" ? "tv" : "movie")/\(tmdbID)")!
    }

    private func imageURL(path: String?, size: String) -> URL? {
        guard let path, path.hasPrefix("/"), !path.contains("..") else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }
}

struct TMDBPage: Decodable {
    let results: [TMDBTitle]
}

struct TMDBGenre: Decodable, Hashable, Identifiable, Sendable {
    let id: Int
    let name: String
}

struct TMDBTitleDetails: Decodable, Sendable {
    let genres: [TMDBGenre]
    let runtime: Int?
    let episodeRunTime: [Int]?
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?
    let status: String?
    let tagline: String?

    enum CodingKeys: String, CodingKey {
        case genres
        case runtime
        case episodeRunTime = "episode_run_time"
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case status
        case tagline
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        genres = try values.decodeIfPresent([TMDBGenre].self, forKey: .genres) ?? []
        runtime = try values.decodeIfPresent(Int.self, forKey: .runtime)
        episodeRunTime = try values.decodeIfPresent([Int].self, forKey: .episodeRunTime)
        numberOfSeasons = try values.decodeIfPresent(Int.self, forKey: .numberOfSeasons)
        numberOfEpisodes = try values.decodeIfPresent(Int.self, forKey: .numberOfEpisodes)
        status = try values.decodeIfPresent(String.self, forKey: .status)
        tagline = try values.decodeIfPresent(String.self, forKey: .tagline)
    }

    var episodeLength: Int? { runtime ?? episodeRunTime?.first }
}
