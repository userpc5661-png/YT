import Combine
import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.laylLayout) private var layout
    @State private var featuredIndex = 0
    @State private var showLicenses = false
    @State private var showSettings = false
    @State private var showGenres = false
    @State private var showCast = false
    @State private var showSavedForLater = false
    @State private var showBell = false
    @State private var homeGenre: Genre?
    @State private var chip: HomeChip = .home

    var body: some View {
        let featured = filteredFeatured
        VStack(spacing: 4) {
            chipRow
            ScrollView {
                VStack(alignment: .leading, spacing: layout.rowSpacing) {
                    if chip == .anime && !model.kidsOnly {
                        if let anime = model.anilist.trending.first {
                            animeHero(anime)
                        } else if model.anilist.isLoading {
                            ProgressView(model.language.t("نجلب الأنمي الرائج...", "Loading trending anime..."))
                                .frame(maxWidth: .infinity)
                                .frame(height: heroHeight)
                        }
                    } else if let title = tmdbHeroTitle {
                        tmdbHero(title)
                    } else if !featured.isEmpty {
                        hero(featured)
                    }
                    if chip != .anime && !model.continueWatching().isEmpty {
                        continueRail
                    }
                    if chip != .anime && !model.myList().isEmpty {
                        myListRail
                    }
                    if !model.kidsOnly && chip == .anime {
                        animeCatalogSection
                    }
                    if !model.kidsOnly && chip != .categories && chip != .anime {
                        tmdbCatalogSection
                    }
                    if chip == .series {
                        seriesRail
                    } else if chip == .movies {
                        moviesRail
                    } else if chip == .fresh {
                        newestRail
                    } else if chip == .anime {
                        EmptyView()
                    } else if let homeGenre {
                        genreRail(homeGenre)
                    } else {
                        onlyOnRail
                        newestRail
                        ForEach(Catalog.homeLanes(kidsOnly: model.kidsOnly)) { lane in
                            MediaRail(lane: lane, posterWidth: layout.posterWidth)
                        }
                    }
                    if !model.kidsOnly && chip != .anime { sourceRails }
                }
                .laylHugsWidth()
                .padding(.bottom, 28)
            }
            .refreshable {
                if !model.kidsOnly {
                    async let refreshTMDB: Void = model.tmdb.refreshHomeCatalog(language: model.tmdbLanguage)
                    async let refreshAnime: Void = model.anilist.refreshTrending()
                    _ = await (refreshTMDB, refreshAnime)
                    model.reloadSourceRails()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .background(LaylTheme.bg.ignoresSafeArea())
        .toolbar { homeToolbar }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .laylNavigationChrome()
        .onAppear {
            if !model.kidsOnly {
                model.reloadSourceRails()
                model.tmdb.loadHomeCatalog(language: model.tmdbLanguage)
                model.anilist.loadTrending()
            }
        }
        .onChange(of: model.tmdbLanguage) { _, language in
            guard !model.kidsOnly else { return }
            model.tmdb.loadHomeCatalog(language: language, forceRefresh: true)
        }
        .sheet(isPresented: $showGenres) { genreSheet }
        .sheet(isPresented: $showCast) { castSheet }
        .sheet(isPresented: $showSavedForLater) { savedForLaterSheet }
        .sheet(isPresented: $showBell) { bellSheet }
        .onReceive(Timer.publish(every: 8, on: .main, in: .common).autoconnect()) { _ in
            guard model.heroCarouselEnabled, featured.count > 1 else { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                featuredIndex = (featuredIndex + 1) % featured.count
            }
        }
        .onChange(of: model.activeProfileID) { _, _ in
            featuredIndex = 0
            chip = .home
            homeGenre = nil
            if !model.kidsOnly {
                model.reloadSourceRails()
                model.tmdb.loadHomeCatalog(language: model.tmdbLanguage)
                model.anilist.loadTrending()
            } else {
                model.sourceRails = []
            }
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
        case .anime:
            return []
        case .fresh:
            return Catalog.all.filter(model.isVisible).sorted { $0.year > $1.year }
        case .home, .categories:
            return base
        }
    }

    private var tmdbHeroTitle: TMDBTitle? {
        guard model.tmdb.isConfigured else { return nil }
        let candidates: [TMDBTitle] = switch chip {
        case .home, .fresh: model.tmdb.trending
        case .movies: model.tmdb.movies
        case .series: model.tmdb.series
        case .anime, .categories: []
        }
        return candidates.first(where: { $0.backdropURL != nil }) ?? candidates.first
    }

    @ToolbarContentBuilder
    private var homeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            BrandLockup(mark: 27)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Layl")
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { showCast = true } label: { Image(systemName: "airplayvideo") }
                .accessibilityLabel(model.language.t("البث", "Cast"))
            Button { showSavedForLater = true } label: { Image(systemName: "bookmark") }
                .accessibilityLabel(model.language.t("محفوظ للمشاهدة لاحقًا", "Saved for later"))
            Button { showBell = true } label: { Image(systemName: "bell") }
                .accessibilityLabel(model.language.t("جديد", "New"))
        }
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipButton(.home, model.language.t("الرئيسية", "Home"))
                chipButton(.series, model.language.t("مسلسلات", "Series"))
                chipButton(.movies, model.language.t("أفلام", "Films"))
                if !model.kidsOnly {
                    chipButton(.anime, model.language.t("أنمي", "Anime"))
                }
                chipButton(.fresh, model.language.t("جديد ورائج", "New & hot"))
                Button {
                    showGenres = true
                } label: {
                    HStack(spacing: 4) {
                        Text(homeGenre?.title(model.language) ?? model.language.t("التصنيفات", "Categories"))
                            .lineLimit(1)
                        Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .foregroundStyle(.white)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, sideInset)
        }
        .laylHugsWidth()
    }

    private func chipButton(_ value: HomeChip, _ title: String) -> some View {
        let selected = chip == value
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                chip = selected ? .home : value
                featuredIndex = 0
                if value != .categories { homeGenre = nil }
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(.white)
                .background {
                    if selected {
                        Capsule().fill(LaylTheme.red)
                    } else {
                        Capsule().fill(Color.white.opacity(0.08))
                    }
                }
                .overlay(Capsule().stroke(Color.white.opacity(selected ? 0 : 0.16), lineWidth: 1))
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

    private var animeCatalogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.language.t("أنمي رائج", "Trending anime"))
                    .font(.title3.weight(.bold))
                Text(model.language.t("كتالوج متخصص من AniList · معلومات فقط", "Specialist AniList catalog · metadata only"))
                    .font(.caption2)
                    .foregroundStyle(LaylTheme.muted)
            }
            .padding(.horizontal, sideInset)

            if model.anilist.isLoading && model.anilist.trending.isEmpty {
                ProgressView(model.language.t("نجلب الأنمي...", "Loading anime..."))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if model.anilist.trending.isEmpty {
                VStack(spacing: 12) {
                    EmptyState(
                        systemImage: "sparkles",
                        title: model.language.t("لا توجد نتائج أنمي الآن", "No anime results right now"),
                        message: model.anilist.error ?? model.language.t("تحقق من الاتصال أو جرّب لاحقًا.", "Check your connection or try again later.")
                    )
                    Button {
                        model.anilist.loadTrending(forceRefresh: true)
                    } label: {
                        Label(model.language.t("إعادة المحاولة", "Retry"), systemImage: "arrow.clockwise")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.bordered)
                    .tint(LaylTheme.red)
                }
                .padding(.horizontal, sideInset)
            } else {
                AniListRail(
                    title: model.language.t("الأكثر رواجًا", "Trending now"),
                    items: model.anilist.trending,
                    posterWidth: layout.posterWidth
                )
            }
            AniListAttributionFooter()
                .padding(.horizontal, sideInset)
        }
        .laylHugsWidth()
    }

    private var tmdbCatalogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.language.t("اكتشف أفلامًا ومسلسلات وأنمي", "Discover films, series & anime"))
                        .font(.title3.weight(.bold))
                    Text(model.language.t("بيانات وصور من TMDB · لا تشمل تشغيل الفيديو", "TMDB metadata and artwork · not video playback"))
                        .font(.caption2)
                        .foregroundStyle(LaylTheme.muted)
                }
                Spacer(minLength: 8)
                NavigationLink { DiscoverView() } label: {
                    Text(model.language.t("الكل", "Explore"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, sideInset)

            if !model.tmdb.isConfigured {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.language.t("الكتالوج العالمي يحتاج رمز TMDB مجانيًا", "The global catalog needs a free TMDB token"))
                        .font(.subheadline.weight(.semibold))
                    NavigationLink { SettingsView() } label: {
                        Label(model.language.t("إعداد TMDB", "Set up TMDB"), systemImage: "key.fill")
                            .font(.caption.weight(.bold))
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LaylTheme.elevated, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, sideInset)
            } else if model.tmdb.isLoadingHome && model.tmdb.trending.isEmpty && model.tmdb.movies.isEmpty && model.tmdb.series.isEmpty {
                ProgressView(model.language.t("نجلب الرائج عالميًا...", "Loading worldwide trends..."))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                if model.tmdb.homeWarning {
                    HStack(spacing: 10) {
                        Label(
                            model.language.t("بعض الأقسام لم تُحمّل", "Some catalog sections did not load"),
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.caption)
                        .foregroundStyle(LaylTheme.muted)
                        Spacer(minLength: 4)
                        retryCatalogButton
                    }
                    .padding(.horizontal, sideInset)
                }
                if chip == .movies {
                    tmdbCategoryContent(
                        title: model.language.t("أفلام رائجة", "Popular films"),
                        emptyTitle: model.language.t("لا توجد أفلام الآن", "No films available right now"),
                        items: model.tmdb.movies
                    )
                } else if chip == .series {
                    tmdbCategoryContent(
                        title: model.language.t("مسلسلات رائجة", "Popular series"),
                        emptyTitle: model.language.t("لا توجد مسلسلات الآن", "No series available right now"),
                        items: model.tmdb.series
                    )
                } else if chip == .fresh {
                    tmdbCategoryContent(
                        title: model.language.t("الرائج عالميًا", "Trending worldwide"),
                        emptyTitle: model.language.t("لا توجد أعمال رائجة الآن", "No trending titles right now"),
                        items: model.tmdb.trending
                    )
                } else if chip == .home {
                    tmdbCategoryContent(
                        title: model.language.t("الرائج عالميًا", "Trending worldwide"),
                        emptyTitle: model.language.t("لا توجد أعمال رائجة الآن", "No trending titles right now"),
                        items: model.tmdb.trending
                    )
                } else {
                    TMDBRail(
                        title: model.language.t("الرائج عالميًا", "Trending worldwide"),
                        items: model.tmdb.trending,
                        posterWidth: layout.posterWidth
                    )
                }
                TMDBAttributionFooter()
                    .padding(.horizontal, sideInset)
            }
        }
        .laylHugsWidth()
    }

    private var moviesRail: some View {
        let ids = Catalog.all.filter { $0.kind == .movie && model.isVisible($0) }.map(\.id)
        return MediaRail(
            lane: Lane(id: "movies-home", title: L10n(ar: "أفلام", en: "Films"), titleIDs: ids, style: .poster),
            posterWidth: layout.posterWidth
        )
    }

    @ViewBuilder
    private func tmdbCategoryContent(title: String, emptyTitle: String, items: [TMDBTitle]) -> some View {
        if items.isEmpty {
            if model.tmdb.isLoadingHome {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 12) {
                    EmptyState(
                        systemImage: "film",
                        title: emptyTitle,
                        message: model.tmdb.homeError ?? model.language.t("لا تتوفر نتائج لهذه الفئة الآن. تحقق من الاتصال أو جرّب لاحقًا.", "No results are available for this category. Check your connection or try again later.")
                    )
                    retryCatalogButton
                }
                .padding(.horizontal, sideInset)
            }
        } else {
            TMDBRail(title: title, items: items, posterWidth: layout.posterWidth)
        }
    }

    private var retryCatalogButton: some View {
        Button {
            model.tmdb.loadHomeCatalog(language: model.tmdbLanguage, forceRefresh: true)
        } label: {
            Label(model.language.t("إعادة المحاولة", "Retry"), systemImage: "arrow.clockwise")
                .font(.caption.weight(.bold))
        }
        .buttonStyle(.bordered)
        .tint(LaylTheme.red)
    }

    private var onlyOnRail: some View {
        let ids = Catalog.all.filter(model.isVisible).prefix(14).map(\.id)
        return MediaRail(
            lane: Lane(id: "only-on-layl", title: L10n(ar: "حصريًا على ليل", en: "Only on Layl"), titleIDs: Array(ids), style: .poster),
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
        .laylHugsWidth()
    }

    private func hero(_ featured: [CatalogTitle]) -> some View {
        let index = min(featuredIndex, max(featured.count - 1, 0))
        let title = featured[index]
        let imageHeight = min(max(heroHeight * 0.94, 300), 410)
        return VStack(spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                CatalogImage(asset: title.backdropAsset)
                    .frame(maxWidth: .infinity)
                    .frame(height: imageHeight)
                    .clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.92)], startPoint: .center, endPoint: .bottom)
                    .allowsHitTesting(false)
                LinearGradient(colors: [.black.opacity(0.2), .clear], startPoint: .top, endPoint: .center)
                    .allowsHitTesting(false)
                VStack(alignment: .leading, spacing: 10) {
                    Text(model.language.t("اختيار الليلة", "Tonight's pick"))
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(title.title.text(model.language))
                        .font(.system(size: min(layout.heroTitleSize * 0.9, 42), weight: .black))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    MetaPills(title: title)
                    Text(title.genres.prefix(3).map { $0.title(model.language) }.joined(separator: " · "))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 8) {
                        Button {
                            model.play(title: title)
                        } label: {
                            Label(playLabel(title), systemImage: "play.fill")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        myListButton(title)
                        Button { model.detailTitle = title } label: {
                            Image(systemName: "info.circle")
                                .font(.headline.weight(.bold))
                                .frame(width: 46, height: 44)
                                .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(model.language.t("التفاصيل", "Details"))
                    }
                }
                .padding(.horizontal, sideInset)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 6) {
                ForEach(0..<featured.count, id: \.self) { dot in
                    Capsule()
                        .fill(dot == index ? Color.white : Color.white.opacity(0.35))
                        .frame(width: dot == index ? 16 : 6, height: 6)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.35)) { featuredIndex = dot }
                        }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .laylHugsWidth()
    }

    private func tmdbHero(_ title: TMDBTitle) -> some View {
        let imageHeight = min(max(heroHeight * 0.94, 300), 410)
        return ZStack(alignment: .bottomLeading) {
            RemoteBackdropImage(urlString: title.backdropURL?.absoluteString, height: imageHeight)
            LinearGradient(colors: [.clear, .black.opacity(0.96)], startPoint: .center, endPoint: .bottom)
            LinearGradient(colors: [.black.opacity(0.25), .clear], startPoint: .top, endPoint: .center)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 1).fill(LaylTheme.red).frame(width: 3, height: 14)
                    Text(model.language.t("رائج الآن", "Trending now"))
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .tracking(1.1)
                }
                .foregroundStyle(.white.opacity(0.88))
                Text(title.title)
                    .font(.system(size: min(layout.heroTitleSize * 0.9, 42), weight: .black))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 8) {
                    if let year = title.year { Text(year) }
                    Text(title.kind == "tv" ? model.language.t("مسلسل", "Series") : model.language.t("فيلم", "Movie"))
                    if let rating = title.voteAverage, rating > 0 {
                        Label(String(format: "%.1f", rating), systemImage: "star.fill")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))
                if !title.overview.isEmpty {
                    Text(title.overview)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                        .frame(maxWidth: 500, alignment: .leading)
                }
                HStack(spacing: 10) {
                    NavigationLink(value: title) {
                        Label(model.language.t("التفاصيل", "Details"), systemImage: "info.circle.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    Link(destination: title.tmdbURL) {
                        Image(systemName: "arrow.up.right")
                            .font(.subheadline.weight(.bold))
                            .frame(width: 42, height: 42)
                            .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .accessibilityLabel(model.language.t("عرض في TMDB", "Open in TMDB"))
                }
            }
            .padding(.horizontal, sideInset)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: imageHeight)
        .clipped()
    }

    private func animeHero(_ title: AniListTitle) -> some View {
        let imageHeight = min(max(heroHeight * 0.94, 280), 390)
        return ZStack(alignment: .bottomLeading) {
            RemoteBackdropImage(urlString: title.bannerURL?.absoluteString, height: imageHeight)
            LinearGradient(colors: [.clear, .black.opacity(0.94)], startPoint: .center, endPoint: .bottom)
            LinearGradient(colors: [.black.opacity(0.2), .clear], startPoint: .top, endPoint: .center)
            VStack(alignment: .leading, spacing: 10) {
                Text(model.language.t("أنمي يستحق الاكتشاف", "Anime to discover"))
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.8))
                Text(title.displayTitle)
                    .font(.system(size: min(layout.heroTitleSize * 0.9, 40), weight: .black))
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                HStack(spacing: 8) {
                    if let year = title.seasonYear { Text(String(year)) }
                    if let rating = title.ratingText { Label(rating, systemImage: "star.fill") }
                    if let episodes = title.episodes { Text(model.language.t("\(episodes) حلقة", "\(episodes) ep")) }
                    Text(model.language.t("أنمي · معلومات فقط", "Anime · details only"))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))
                NavigationLink(value: title) {
                    Label(model.language.t("التفاصيل", "Details"), systemImage: "info.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, sideInset)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: imageHeight)
        .clipped()
    }

    @ViewBuilder
    private func myListButton(_ title: CatalogTitle) -> some View {
        let label = Label(
            model.language.t("قائمتي", "My List"),
            systemImage: model.isSaved(title.id) ? "checkmark" : "plus"
        )
        .font(.headline.weight(.bold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        Button { model.toggleSaved(title.id) } label: {
            label.background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var newestRail: some View {
        let ids = Catalog.all.filter(model.isVisible).sorted { $0.year > $1.year }.prefix(12).map(\.id)
        return MediaRail(
            lane: Lane(id: "new-home", title: L10n(ar: "جديد على ليل", en: "New on Layl"), titleIDs: Array(ids), style: .poster),
            posterWidth: layout.posterWidth
        )
    }

    private var castSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(model.language.t("أرسل الصورة إلى تلفاز أو سمّاعة عبر AirPlay من شاشة التشغيل.", "Send the picture to a TV or speaker with AirPlay from the player."))
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationTitle(model.language.t("البث", "Cast"))
            .laylNavigationChrome()
        }
        .presentationDetents([.medium])
        .laylGlassSheet()
    }

    private var savedForLaterSheet: some View {
        NavigationStack {
            List(model.savedForLater, id: \.self) { id in
                if let title = Catalog.title(id: id) {
                    Button(title.title.text(model.language)) { model.detailTitle = title }
                        .foregroundStyle(.white)
                }
            }
            .overlay {
                if model.savedForLater.isEmpty {
                    Text(model.language.t("لا توجد أعمال محفوظة بعد.", "Nothing saved for later yet."))
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle(model.language.t("للمشاهدة لاحقًا", "Saved for later"))
            .laylNavigationChrome()
        }
        .presentationDetents([.medium, .large])
        .laylGlassSheet()
    }

    private var bellSheet: some View {
        let newest = Catalog.all.filter(model.isVisible).sorted { $0.year > $1.year }.prefix(8)
        return NavigationStack {
            List(Array(newest)) { title in
                Button(title.title.text(model.language)) { model.detailTitle = title }
                    .foregroundStyle(.white)
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle(model.language.t("وصل حديثًا", "Just added"))
            .laylNavigationChrome()
        }
        .presentationDetents([.medium, .large])
        .laylGlassSheet()
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
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, sideInset)
                .laylHugsWidth()
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
            .laylHugsWidth()
        }
        .laylHugsWidth()
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
    case anime
    case fresh
    case categories
}

extension AppModel {
    var featuredTitles: [CatalogTitle] {
        Catalog.featured(kidsOnly: kidsOnly)
    }
}
