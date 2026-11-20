import Foundation
import Observation

@Observable
final class AppModel {
    var language: AppLanguage
    var profiles: [Profile]
    var activeProfileID: String?
    var playRequest: PlayRequest?
    let tmdb = TMDBCatalogModel()
    var contentDensity: ContentDensity
    var heroCarouselEnabled: Bool
    var sources: [ContentSource] = []
    var sourceRails: [SourceRail] = []
    var sourceSearch: [RemoteTitle] = []
    var sourcesLoading = false
    var remotePlay: RemotePlayback?
    var detailTitle: CatalogTitle?
    var detailRemote: RemoteTitle?
    var tastes: [String: String] = [:]
    var savedForLater: [String] = []

    private var lists: [String: [String]]
    private var progress: [String: [String: WatchProgress]]
    private var lastDiskWrite = Date.distantPast
    private let storageKey = "layl.state.v2"

    init() {
        Self.eraseLegacyAPIKeys()
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(SavedState.self, from: data),
           !saved.profiles.isEmpty {
            language = saved.language
            profiles = saved.profiles
            lists = saved.lists
            progress = saved.progress
            contentDensity = saved.contentDensity
            heroCarouselEnabled = saved.heroCarouselEnabled
        } else if let legacy = UserDefaults.standard.data(forKey: "layl.state.v1"),
                  let saved = try? JSONDecoder().decode(LegacySavedState.self, from: legacy),
                  !saved.profiles.isEmpty {
            language = saved.language
            profiles = saved.profiles
            lists = saved.lists
            progress = saved.progress
            contentDensity = .comfortable
            heroCarouselEnabled = true
        } else {
            language = .arabic
            profiles = Profile.defaults
            lists = [:]
            progress = [:]
            contentDensity = .comfortable
            heroCarouselEnabled = true
        }
        loadSources()
        tastes = UserDefaults.standard.dictionary(forKey: "layl.tastes.v1") as? [String: String] ?? [:]
        savedForLater = UserDefaults.standard.stringArray(forKey: "layl.downloads.v1") ?? []
    }

    func tasteKey(_ titleID: String) -> String {
        "\(activeProfileID ?? "none")|\(titleID)"
    }

    func taste(for titleID: String) -> String? {
        tastes[tasteKey(titleID)]
    }

    func setTaste(_ value: String, for titleID: String) {
        tastes[tasteKey(titleID)] = value
        UserDefaults.standard.set(tastes, forKey: "layl.tastes.v1")
    }

    func isSavedForLater(_ titleID: String) -> Bool {
        savedForLater.contains(titleID)
    }

    func toggleSavedForLater(_ titleID: String) {
        if let index = savedForLater.firstIndex(of: titleID) {
            savedForLater.remove(at: index)
        } else {
            savedForLater.insert(titleID, at: 0)
        }
        UserDefaults.standard.set(savedForLater, forKey: "layl.downloads.v1")
    }

    func loadSources() {
        guard let data = UserDefaults.standard.data(forKey: "layl.sources.v1"),
              let saved = try? JSONDecoder().decode([ContentSource].self, from: data) else {
            sources = []
            return
        }
        sources = saved
    }

    func saveSources() {
        if let data = try? JSONEncoder().encode(sources) {
            UserDefaults.standard.set(data, forKey: "layl.sources.v1")
        }
    }

    func upsert(_ source: ContentSource, secret: String?) {
        if let index = sources.firstIndex(where: { $0.id == source.id }) {
            sources[index] = source
        } else {
            sources.append(source)
        }
        if let secret {
            let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                KeychainStore.delete(account: source.id.uuidString)
            } else {
                KeychainStore.set(trimmed, account: source.id.uuidString)
            }
        }
        saveSources()
    }

    func deleteSource(_ source: ContentSource) {
        sources.removeAll { $0.id == source.id }
        KeychainStore.delete(account: source.id.uuidString)
        sourceRails.removeAll { $0.source.id == source.id }
        saveSources()
    }

    func reloadSourceRails() {
        let enabled = sources.filter(\.enabled)
        guard !enabled.isEmpty else {
            sourceRails = []
            return
        }
        sourcesLoading = true
        Task { @MainActor in
            var rails: [SourceRail] = []
            for source in enabled {
                if let titles = try? await SourceClient.load(source, feed: .movies), !titles.isEmpty {
                    rails.append(SourceRail(source: source, titles: Array(titles.prefix(20))))
                }
                if let series = try? await SourceClient.load(source, feed: .series), !series.isEmpty {
                    rails.append(SourceRail(source: source, titles: Array(series.prefix(20)), series: true))
                }
            }
            sourceRails = rails
            sourcesLoading = false
        }
    }

    func searchSources(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let enabled = sources.filter(\.enabled)
        guard trimmed.count >= 2, !enabled.isEmpty else {
            sourceSearch = []
            return
        }
        Task { @MainActor in
            var found: [RemoteTitle] = []
            for source in enabled where !source.searchPath.isEmpty {
                if let titles = try? await SourceClient.load(source, feed: .search(trimmed)) {
                    found.append(contentsOf: titles.prefix(12))
                }
            }
            sourceSearch = found
        }
    }

    func play(remote title: RemoteTitle) {
        guard let url = title.streamURL, title.directVideo else { return }
        remotePlay = RemotePlayback(url: url, title: title.title)
    }

    var tmdbLanguage: String { language == .arabic ? "ar-SA" : "en-US" }

    func updatePreferences(
        density: ContentDensity,
        heroCarousel: Bool
    ) {
        contentDensity = density
        heroCarouselEnabled = heroCarousel
        persist()
    }

    var activeProfile: Profile? {
        profiles.first { $0.id == activeProfileID }
    }

    var kidsOnly: Bool { activeProfile?.isKids == true }

    func select(_ profile: Profile) {
        activeProfileID = profile.id
    }

    func leaveProfile() {
        activeProfileID = nil
        playRequest = nil
    }

    func toggleLanguage() {
        language = language == .arabic ? .english : .arabic
        persist()
    }

    func addProfile(name: String, colorHex: String, isKids: Bool) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let profile = Profile(id: UUID().uuidString, name: String(trimmed.prefix(18)), colorHex: colorHex, isKids: isKids)
        profiles.append(profile)
        persist()
    }

    func deleteProfile(_ profile: Profile) {
        guard profiles.count > 1 else { return }
        profiles.removeAll { $0.id == profile.id }
        lists[profile.id] = nil
        progress[profile.id] = nil
        if activeProfileID == profile.id { activeProfileID = nil }
        persist()
    }

    func isSaved(_ titleID: String) -> Bool {
        guard let pid = activeProfileID else { return false }
        return lists[pid, default: []].contains(titleID)
    }

    func toggleSaved(_ titleID: String) {
        guard let pid = activeProfileID else { return }
        var ids = lists[pid, default: []]
        if let index = ids.firstIndex(of: titleID) {
            ids.remove(at: index)
        } else {
            ids.insert(titleID, at: 0)
        }
        lists[pid] = ids
        persist()
    }

    func myList() -> [CatalogTitle] {
        guard let pid = activeProfileID else { return [] }
        return Catalog.titles(ids: lists[pid, default: []]).filter(isVisible)
    }

    func continueWatching() -> [ContinueItem] {
        guard let pid = activeProfileID else { return [] }
        let map = progress[pid] ?? [:]
        return map.values
            .filter(\.isResumable)
            .sorted { $0.updatedAt > $1.updatedAt }
            .compactMap { item in
                guard let title = Catalog.title(id: item.titleID), isVisible(title),
                      let episode = title.episodes.first(where: { $0.id == item.episodeID }) else { return nil }
                return ContinueItem(title: title, episode: episode, progress: item)
            }
    }

    func progress(for episodeID: String) -> WatchProgress? {
        guard let pid = activeProfileID else { return nil }
        return progress[pid]?[episodeID]
    }

    func resumeTarget(for title: CatalogTitle) -> (Episode, WatchProgress)? {
        let matches = title.episodes.compactMap { episode -> (Episode, WatchProgress)? in
            guard let item = progress(for: episode.id), item.isResumable else { return nil }
            return (episode, item)
        }
        return matches.max { $0.1.updatedAt < $1.1.updatedAt }
    }

    func noteProgress(titleID: String, episodeID: String, position: Double, duration: Double, force: Bool) {
        guard let pid = activeProfileID, duration > 1, position.isFinite else { return }
        var bucket = progress[pid] ?? [:]
        bucket[episodeID] = WatchProgress(
            titleID: titleID,
            episodeID: episodeID,
            position: min(max(position, 0), duration),
            duration: duration,
            updatedAt: Date()
        )
        progress[pid] = bucket
        if force || Date().timeIntervalSince(lastDiskWrite) > 5 {
            persist()
        }
    }

    func clearProgress(episodeID: String) {
        guard let pid = activeProfileID else { return }
        var bucket = progress[pid] ?? [:]
        bucket[episodeID] = nil
        progress[pid] = bucket
        persist()
    }

    func play(title: CatalogTitle, episode: Episode? = nil) {
        guard isVisible(title) else { return }
        let chosen: Episode?
        if let episode {
            chosen = episode
        } else if let resume = resumeTarget(for: title)?.0 {
            chosen = resume
        } else {
            chosen = title.episodes.first
        }
        guard let chosen else { return }
        playRequest = PlayRequest(token: UUID(), titleID: title.id, episodeID: chosen.id)
    }

    func isVisible(_ title: CatalogTitle) -> Bool {
        !kidsOnly || title.kids
    }

    private func persist() {
        lastDiskWrite = Date()
        let saved = SavedState(
            language: language,
            profiles: profiles,
            lists: lists,
            progress: progress,
            contentDensity: contentDensity,
            heroCarouselEnabled: heroCarouselEnabled
        )
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private struct SavedState: Codable {
        var language: AppLanguage
        var profiles: [Profile]
        var lists: [String: [String]]
        var progress: [String: [String: WatchProgress]]
        var contentDensity: ContentDensity
        var heroCarouselEnabled: Bool
    }

    private struct LegacySavedState: Codable {
        var language: AppLanguage
        var profiles: [Profile]
        var lists: [String: [String]]
        var progress: [String: [String: WatchProgress]]
    }

    private static func eraseLegacyAPIKeys() {
        for key in ["layl.state.v1", "layl.state.v2"] {
            guard let data = UserDefaults.standard.data(forKey: key),
                  var saved = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  saved.removeValue(forKey: "apiKey") != nil,
                  let cleaned = try? JSONSerialization.data(withJSONObject: saved) else { continue }
            UserDefaults.standard.set(cleaned, forKey: key)
        }
        UserDefaults.standard.removeObject(forKey: "fasel.host")
    }
}
