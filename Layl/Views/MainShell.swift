import SwiftUI

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case home
    case clips
    case search
    case profile

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .home: return language.t("الرئيسية", "Home")
        case .clips: return language.t("مقاطع", "Clips")
        case .search: return language.t("بحث", "Search")
        case .profile: return language.t("ليل", "Layl")
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .clips: return "play.rectangle.on.rectangle.fill"
        case .search: return "magnifyingglass"
        case .profile: return "person.crop.circle"
        }
    }
}

struct MainShell: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var section: AppSection = .home

    var body: some View {
        Group {
            if #available(iOS 18, *) {
                modernTabs
            } else {
                legacyTabs
            }
        }
        .background(Color.black)
        .sheet(item: Binding(get: { model.detailTitle }, set: { model.detailTitle = $0 })) { title in
            NavigationStack {
                TitleDetailView(title: title)
            }
            .laylGlassSheet()
        }
        .sheet(item: Binding(get: { model.detailRemote }, set: { model.detailRemote = $0 })) { title in
            NavigationStack {
                RemoteDetailView(title: title)
            }
            .laylGlassSheet()
        }
        .fullScreenCover(
            item: Binding(get: { model.remotePlay }, set: { model.remotePlay = $0 })
        ) { playback in
            RemotePlayerScreen(title: playback.title, url: playback.url)
        }
        .fullScreenCover(
            item: Binding(
                get: { model.playRequest },
                set: { model.playRequest = $0 }
            )
        ) { request in
            if let title = Catalog.title(id: request.titleID),
               let episode = title.episodes.first(where: { $0.id == request.episodeID }) {
                PlayerScreen(title: title, episode: episode)
            } else {
                Color.black
            }
        }
    }

    @available(iOS 18, *)
    private var modernTabs: some View {
        TabView(selection: $section) {
            Tab(AppSection.home.title(model.language), systemImage: AppSection.home.symbol, value: AppSection.home) {
                stack(for: .home)
            }
            Tab(AppSection.clips.title(model.language), systemImage: AppSection.clips.symbol, value: AppSection.clips) {
                stack(for: .clips)
            }
            Tab(AppSection.search.title(model.language), systemImage: AppSection.search.symbol, value: AppSection.search) {
                stack(for: .search)
            }
            Tab(AppSection.profile.title(model.language), systemImage: AppSection.profile.symbol, value: AppSection.profile) {
                stack(for: .profile)
            }
        }
        .modifier(LaylTabChrome(regular: sizeClass == .regular))
    }

    private var legacyTabs: some View {
        TabView(selection: $section) {
            stack(for: .home)
                .tabItem { Label(AppSection.home.title(model.language), systemImage: AppSection.home.symbol) }
                .tag(AppSection.home)
            stack(for: .clips)
                .tabItem { Label(AppSection.clips.title(model.language), systemImage: AppSection.clips.symbol) }
                .tag(AppSection.clips)
            stack(for: .search)
                .tabItem { Label(AppSection.search.title(model.language), systemImage: AppSection.search.symbol) }
                .tag(AppSection.search)
            stack(for: .profile)
                .tabItem { Label(AppSection.profile.title(model.language), systemImage: AppSection.profile.symbol) }
                .tag(AppSection.profile)
        }
    }

    private func stack(for section: AppSection) -> some View {
        NavigationStack {
            Group {
                switch section {
                case .home:
                    HomeView()
                case .clips:
                    ClipsView()
                case .search:
                    SearchView()
                case .profile:
                    AccountView()
                }
            }
            .laylDestinations()
        }
    }
}
