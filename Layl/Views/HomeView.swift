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
    @State private var showDownloads = false
    @State private var showBell = false
    @State private var homeGenre: Genre?
    @State private var chip: HomeChip = .home

    var body: some View {
        let featured = filteredFeatured
        VStack(spacing: 8) {
            chipRow
            ScrollView {
                VStack(alignment: .leading, spacing: layout.rowSpacing) {
                    if !featured.isEmpty {
                        hero(featured)
                    }
                    if !model.continueWatching().isEmpty {
                        continueRail
                    }
                    if !model.myList().isEmpty {
                        myListRail
                    }
                    if chip == .series {
                        seriesRail
                    } else if chip == .movies {
                        moviesRail
                    } else if chip == .fresh {
                        newestRail
                    } else if let homeGenre {
                        genreRail(homeGenre)
                    } else {
                        onlyOnRail
                        newestRail
                        ForEach(Catalog.homeLanes(kidsOnly: model.kidsOnly)) { lane in
                            MediaRail(lane: lane, posterWidth: layout.posterWidth)
                        }
                    }
                    sourceRails
                }
                .laylHugsWidth()
                .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .background { ambient }
        .toolbar { homeToolbar }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .laylNavigationChrome()
        .onAppear { model.reloadSourceRails() }
        .sheet(isPresented: $showGenres) { genreSheet }
        .sheet(isPresented: $showCast) { castSheet }
        .sheet(isPresented: $showDownloads) { downloadSheet }
        .sheet(isPresented: $showBell) { bellSheet }
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
        case .fresh:
            return Catalog.all.filter(model.isVisible).sorted { $0.year > $1.year }
        case .home, .categories:
            return base
        }
    }

    private var ambientAsset: String {
        let featured = filteredFeatured
        guard !featured.isEmpty else { return "backdrop_sintel" }
        let index = min(max(featuredIndex, 0), featured.count - 1)
        return featured[index].backdropAsset
    }

    private var ambient: some View {
        let asset = ambientAsset
        let tone = ArtworkTone.color(asset: asset)
        return ZStack {
            tone
            CatalogImage(asset: asset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blur(radius: 28)
                .opacity(0.45)
            LinearGradient(colors: [tone.opacity(0.15), .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.45), value: asset)
    }

    @ToolbarContentBuilder
    private var homeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 8) {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text(model.language.t("الرئيسية", "Home"))
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Layl")
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { showCast = true } label: { Image(systemName: "airplayvideo") }
                .accessibilityLabel(model.language.t("البث", "Cast"))
            Button { showDownloads = true } label: { Image(systemName: "arrow.down.to.line") }
                .accessibilityLabel(model.language.t("التنزيلات", "Downloads"))
            Button { showBell = true } label: { Image(systemName: "bell") }
                .accessibilityLabel(model.language.t("جديد", "New"))
        }
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LaylGlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    chipButton(.series, model.language.t("مسلسلات", "Series"))
                    chipButton(.movies, model.language.t("أفلام", "Films"))
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
                        .modifier(LaylChipGlass(active: true))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, sideInset)
            }
        }
        .laylHugsWidth()
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
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? Color.black : Color.white)
                .background {
                    if selected {
                        Capsule().fill(Color.white)
                    }
                }
                .modifier(LaylChipGlass(active: !selected))
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

    private var moviesRail: some View {
        let ids = Catalog.all.filter { $0.kind == .movie && model.isVisible($0) }.map(\.id)
        return MediaRail(
            lane: Lane(id: "movies-home", title: L10n(ar: "أفلام", en: "Films"), titleIDs: ids, style: .poster),
            posterWidth: layout.posterWidth
        )
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
        let imageHeight = min(heroHeight * 0.72, 340)
        return VStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                CatalogImage(asset: title.backdropAsset)
                    .frame(maxWidth: .infinity)
                    .frame(height: imageHeight)
                    .overlay(alignment: .bottom) {
                        LinearGradient(colors: [.clear, .black.opacity(0.88)], startPoint: .center, endPoint: .bottom)
                            .frame(height: imageHeight * 0.72)
                            .allowsHitTesting(false)
                    }
                    .clipped()
                VStack(spacing: 10) {
                    Text(title.title.text(model.language))
                        .font(.system(size: min(layout.heroTitleSize, 34), weight: .black))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                    Text(title.genres.prefix(3).map { $0.title(model.language) }.joined(separator: " · "))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
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
                    }
                    Button {
                        model.detailTitle = title
                    } label: {
                        Text(model.language.t("التفاصيل", "Details"))
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, sideInset)
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
        if #available(iOS 26, *) {
            Button { model.toggleSaved(title.id) } label: { label }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity)
        } else {
            Button { model.toggleSaved(title.id) } label: {
                label.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
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

    private var downloadSheet: some View {
        NavigationStack {
            List(model.downloads, id: \.self) { id in
                if let title = Catalog.title(id: id) {
                    Button(title.title.text(model.language)) { model.detailTitle = title }
                        .foregroundStyle(.white)
                }
            }
            .overlay {
                if model.downloads.isEmpty {
                    Text(model.language.t("لا توجد تنزيلات بعد.", "Nothing saved for later yet."))
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle(model.language.t("التنزيلات", "Downloads"))
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
    case fresh
    case categories
}

extension AppModel {
    var featuredTitles: [CatalogTitle] {
        Catalog.featured(kidsOnly: kidsOnly)
    }
}
