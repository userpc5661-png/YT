import Foundation
import Observation

@Observable
final class AppModel {
    var language: AppLanguage
    var profiles: [Profile]
    var activeProfileID: String?
    var playRequest: PlayRequest?

    private var lists: [String: [String]]
    private var progress: [String: [String: WatchProgress]]
    private var lastDiskWrite = Date.distantPast
    private let storageKey = "layl.state.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(SavedState.self, from: data),
           !saved.profiles.isEmpty {
            language = saved.language
            profiles = saved.profiles
            lists = saved.lists
            progress = saved.progress
        } else {
            language = .arabic
            profiles = Profile.defaults
            lists = [:]
            progress = [:]
        }
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
        let saved = SavedState(language: language, profiles: profiles, lists: lists, progress: progress)
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private struct SavedState: Codable {
        var language: AppLanguage
        var profiles: [Profile]
        var lists: [String: [String]]
        var progress: [String: [String: WatchProgress]]
    }
}
