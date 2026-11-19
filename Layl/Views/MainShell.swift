import SwiftUI

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case home
    case fresh
    case myList
    case search
    case profile

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .home: return language.t("الرئيسية", "Home")
        case .fresh: return language.t("جديد", "New")
        case .myList: return language.t("قائمتي", "My List")
        case .search: return language.t("بحث", "Search")
        case .profile: return language.t("حسابي", "Account")
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .fresh: return "flame.fill"
        case .myList: return "plus.rectangle.on.rectangle"
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
                HStack(spacing: 0) {
                    sidebar
                    Divider().overlay(Color.white.opacity(0.08))
                    stack(for: section)
                        .id(section)
                }
                .background(Color.black)
            } else {
                VStack(spacing: 0) {
                    stack(for: section)
                        .id(section)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    phoneTabBar
                }
                .background(Color.black)
            }
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

    private func stack(for section: AppSection) -> some View {
        NavigationStack {
            Group {
                switch section {
                case .home:
                    HomeView()
                case .fresh:
                    DiscoverView()
                case .myList:
                    MyListView()
                case .search:
                    SearchView()
                case .profile:
                    AccountView()
                }
            }
            .laylDestinations()
        }
    }

    private var phoneTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(AppSection.allCases) { item in
                    Button {
                        section = item
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 16, weight: .semibold))
                            Text(item.title(model.language))
                                .font(.caption2.weight(section == item ? .bold : .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(section == item ? Color.white : Color.white.opacity(0.45))
                        .frame(minWidth: 64)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
        .background(Color.black)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)
        }
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
