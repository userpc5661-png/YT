import SwiftUI

enum Section: String, CaseIterable, Identifiable, Hashable {
    case home
    case movies
    case series
    case myList
    case search

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .home: return language.t("الرئيسية", "Home")
        case .movies: return language.t("أفلام", "Movies")
        case .series: return language.t("مسلسلات", "Series")
        case .myList: return language.t("قائمتي", "My List")
        case .search: return language.t("بحث", "Search")
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .movies: return "film"
        case .series: return "rectangle.stack"
        case .myList: return "checkmark.rectangle.stack"
        case .search: return "magnifyingglass"
        }
    }
}

struct MainShell: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var section: Section = .home

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
                TabView(selection: $section) {
                    ForEach(Section.allCases) { item in
                        stack(for: item)
                            .tabItem { Label(item.title(model.language), systemImage: item.symbol) }
                            .tag(item)
                    }
                }
                .tint(.white)
                .toolbarBackground(.black, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(.dark, for: .tabBar)
            }
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

    private func stack(for section: Section) -> some View {
        NavigationStack {
            Group {
                switch section {
                case .home:
                    HomeView()
                case .movies:
                    BrowseView(mode: .movies)
                case .series:
                    BrowseView(mode: .series)
                case .myList:
                    MyListView()
                case .search:
                    SearchView()
                }
            }
            .laylDestinations()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            BrandLockup(mark: 34)
                .padding(.bottom, 18)
            ForEach(Section.allCases) { item in
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
