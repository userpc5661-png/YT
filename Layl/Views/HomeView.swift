import Combine
import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.laylLayout) private var layout
    @State private var featuredIndex = 0
    @State private var showLicenses = false
    @State private var showSettings = false
    @State private var showGenres = false
    @State private var homeGenre: Genre?
    @State private var chip: HomeChip = .home

    var body: some View {
        let featured = filteredFeatured
        ScrollView {
            VStack(alignment: .leading, spacing: layout.rowSpacing) {
                Color.clear.frame(height: 86)
                if !featured.isEmpty {
                    hero(featured)
                        .padding(.top, -layout.safeTop)
                }
                if !model.continueWatching().isEmpty {
                    continueRail
                }
                if !model.myList().isEmpty {
                    myListRail
                }
                if chip == .series {
                    seriesRail
                } else if let homeGenre {
                    genreRail(homeGenre)
                } else {
                    ForEach(Catalog.homeLanes(kidsOnly: model.kidsOnly)) { lane in
                        MediaRail(lane: lane, posterWidth: layout.posterWidth)
                    }
                }
                sourceRails
            }
            .padding(.bottom, 28)
        }
        .overlay(alignment: .top) { topBar }
        .laylScreen()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { model.reloadSourceRails() }
        .sheet(isPresented: $showGenres) { genreSheet }
        .onReceive(Timer.publish(every: 8, on: .main, in: .common).autoconnect()) { _ in
            guard model.heroCarouselEnabled, featured.count > 1 else { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                featuredIndex = (featuredIndex + 1) % featured.count
            }
        }
        .onChange(of: model.activeProfileID) { _, _ in
            featuredIndex = 0
        }
        .navigationDestination(isPresented: $showLicenses) {
            LicensesView()
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var sideInset: CGFloat { layout.contentInset }

    private var filteredFeatured: [CatalogTitle] {
        let base = model.featuredTitles
        switch chip {
        case .series:
            return Catalog.all.filter { $0.kind == .series && model.isVisible($0) }
        case .movies:
            return base.filter { $0.kind == .movie }
        case .home, .categories:
            return base
        }
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                BrandLockup(mark: 28)
                Spacer()
                Button(action: model.toggleLanguage) {
                    Text(model.language == .arabic ? "EN" : "ع")
                        .font(.caption.weight(.heavy))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                if let profile = model.activeProfile {
                    Menu {
                        Button(model.language.t("تبديل الملف", "Switch profile"), systemImage: "person.2") {
                            model.leaveProfile()
                        }
                        Button {
                            showSettings = true
                        } label: {
                            Label(model.language.t("الإعدادات والمصادر", "Settings and sources"), systemImage: "gearshape")
                        }
                        Button(model.language.t("الحقوق", "Rights"), systemImage: "doc.text") {
                            showLicenses = true
                        }
                    } label: {
                        ProfileAvatar(profile: profile, size: 32, rounded: true)
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chipButton(.series, model.language.t("مسلسلات", "Series"))
                    chipButton(.movies, model.language.t("أفلام", "Movies"))
                    Button {
                        showGenres = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(homeGenre?.title(model.language) ?? model.language.t("التصنيفات", "Categories"))
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(homeGenre == nil ? Color.black.opacity(0.35) : Color.white, in: Capsule())
                        .foregroundStyle(homeGenre == nil ? Color.white : Color.black)
                        .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, sideInset)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            LinearGradient(colors: [.black.opacity(0.75), .black.opacity(0)], startPoint: .top, endPoint: .bottom)
        )
    }

    private func chipButton(_ value: HomeChip, _ title: String) -> some View {
        let selected = chip == value
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                chip = selected ? .home : value
                if value != .categories { homeGenre = nil }
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Color.white : Color.black.opacity(0.35), in: Capsule())
                .foregroundStyle(selected ? Color.black : Color.white)
                .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var genreSheet: some View {
        NavigationStack {
            List(Genre.allCases) { genre in
                Button(genre.title(model.language)) {
                    homeGenre = genre
                    chip = .categories
                    showGenres = false
                }
                .foregroundStyle(.white)
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle(model.language.t("التصنيفات", "Categories"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.language.t("الكل", "All")) {
                        homeGenre = nil
                        chip = .home
                        showGenres = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    private var seriesRail: some View {
        let ids = Catalog.all.filter { $0.kind == .series && model.isVisible($0) }.map(\.id)
        return MediaRail(
            lane: Lane(id: "series-home", title: L10n(ar: "مسلسلات", en: "Series"), titleIDs: ids, style: .poster),
            posterWidth: layout.posterWidth
        )
    }

    private func genreRail(_ genre: Genre) -> some View {
        let ids = Catalog.all.filter { $0.genres.contains(genre) && model.isVisible($0) }.map(\.id)
        return MediaRail(
            lane: Lane(id: "genre-\(genre.rawValue)", title: L10n(ar: genre.title(.arabic), en: genre.title(.english)), titleIDs: ids, style: .poster),
            posterWidth: layout.posterWidth
        )
    }

    private var sourceRails: some View {
        VStack(alignment: .leading, spacing: layout.rowSpacing) {
            if model.sourcesLoading && model.sourceRails.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
            ForEach(model.sourceRails) { rail in
                RemoteRail(
                    title: rail.series
                        ? "\(rail.source.name) · \(model.language.t("مسلسلات", "Series"))"
                        : rail.source.name,
                    titles: rail.titles,
                    posterWidth: layout.posterWidth
                )
            }
        }
    }

    private func hero(_ featured: [CatalogTitle]) -> some View {
        let index = min(featuredIndex, featured.count - 1)
        let title = featured[index]
        return ZStack(alignment: .bottomLeading) {
            CatalogImage(asset: title.backdropAsset)
                .frame(maxWidth: .infinity)
                .frame(height: heroHeight)
                .clipped()
                .id(title.id)
                .transition(.opacity)

            LinearGradient(
                colors: [.clear, .black.opacity(0.15), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 10) {
                Text(title.title.text(model.language))
                    .font(.system(size: layout.heroTitleSize, weight: .black))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .shadow(color: .black.opacity(0.6), radius: 8, y: 2)
                Text(title.genres.prefix(3).map { $0.title(model.language) }.joined(separator: " · "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                HStack(spacing: 10) {
                    PlayPill(title: playLabel(title)) {
                        model.play(title: title)
                    }
                    Button {
                        model.toggleSaved(title.id)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: model.isSaved(title.id) ? "checkmark" : "plus")
                            Text(model.language.t("قائمتي", "My List"))
                        }
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(Color.white.opacity(0.22), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    NavigationLink(value: title) {
                        Image(systemName: "info.circle")
                            .font(.title3.weight(.semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
                HStack(spacing: 6) {
                    ForEach(0..<featured.count, id: \.self) { dot in
                        Button {
                            withAnimation(.easeInOut(duration: 0.35)) { featuredIndex = dot }
                        } label: {
                            Capsule()
                                .fill(dot == index ? Color.white : Color.white.opacity(0.35))
                                .frame(width: dot == index ? 16 : 6, height: 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, sideInset)
            .padding(.bottom, 18)
        }
        .frame(height: heroHeight)
    }

    private var heroHeight: CGFloat { layout.heroHeight }

    private func playLabel(_ title: CatalogTitle) -> String {
        if model.resumeTarget(for: title) != nil {
            return model.language.t("استئناف", "Resume")
        }
        return model.language.t("تشغيل", "Play")
    }

    private var continueRail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.language.t("متابعة المشاهدة", "Continue watching"))
                .font(.title3.weight(.bold))
                .padding(.horizontal, sideInset)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(model.continueWatching()) { item in
                        Button {
                            model.play(title: item.title, episode: item.episode)
                        } label: {
                            ContinueCard(item: item, width: layout.continueCardWidth)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                model.clearProgress(episodeID: item.episode.id)
                            } label: {
                                Label(model.language.t("إزالة من المتابعة", "Remove from Continue"), systemImage: "minus.circle")
                            }
                        }
                    }
                }
                .padding(.horizontal, sideInset)
            }
        }
    }

    private var myListRail: some View {
        MediaRail(
            lane: Lane(
                id: "mylist-home",
                title: L10n(ar: "قائمتي", en: "My List"),
                titleIDs: model.myList().map(\.id),
                style: .poster
            ),
            posterWidth: layout.posterWidth
        )
    }
}

enum HomeChip {
    case home
    case series
    case movies
    case categories
}

extension AppModel {
    var featuredTitles: [CatalogTitle] {
        Catalog.featured(kidsOnly: kidsOnly)
    }
}
