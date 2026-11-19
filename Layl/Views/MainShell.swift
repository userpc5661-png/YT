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
            if sizeClass == .regular {
                if #available(iOS 18, *) {
                    modernTabs
                } else {
                    legacySplit
                }
            } else {
                stack(for: section)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        floatingBar
                    }
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
        .sheet(item: Binding(get: { model.detailShow }, set: { model.detailShow = $0 })) { show in
            NavigationStack {
                StreamingShowDetailView(show: show)
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
        .modifier(LaylTabChrome())
    }

    private var legacySplit: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().overlay(Color.white.opacity(0.08))
            stack(for: section)
                .id(section)
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

    private var floatingBar: some View {
        LaylGlassGroup(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(AppSection.allCases) { item in
                    Button {
                        section = item
                    } label: {
                        VStack(spacing: 3) {
                            if item == .profile, let profile = model.activeProfile {
                                ProfileAvatar(profile: profile, size: 22, rounded: true)
                            } else {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Text(item.title(model.language))
                                .font(.caption2.weight(section == item ? .bold : .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(section == item ? Color.white : Color.white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
        .laylGlass(in: Capsule(), interactive: true)
        .padding(.horizontal, 28)
        .padding(.bottom, 6)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            BrandLockup(mark: 34)
                .padding(.bottom, 18)
            ForEach(AppSection.allCases) { item in
                Button {
                    section = item
                } label: {
                    Label(item.title(model.language), systemImage: item.symbol)
                        .font(.body.weight(section == item ? .bold : .regular))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(section == item ? Color.white.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button(action: model.toggleLanguage) {
                Text(model.language == .arabic ? "English" : "العربية")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(LaylTheme.muted)
            if let profile = model.activeProfile {
                Button(action: model.leaveProfile) {
                    HStack(spacing: 10) {
                        ProfileAvatar(profile: profile, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(.subheadline.weight(.semibold))
                            Text(model.language.t("تبديل", "Switch"))
                                .font(.caption2)
                                .foregroundStyle(LaylTheme.muted)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
        .padding(16)
        .frame(width: 250)
        .background(Color.black)
    }
}
