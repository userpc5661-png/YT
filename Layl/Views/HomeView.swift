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
        ScrollView {
            VStack(alignment: .leading, spacing: layout.rowSpacing) {
                Color.clear.frame(height: 118)
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
                } else if chip == .fresh {
                    newestRail
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
        .background { ambient }
        .overlay(alignment: .top) { topBar }
        .toolbar(.hidden, for: .navigationBar)
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

    private var ambient: some View {
        let asset = filteredFeatured.first?.backdropAsset ?? "backdrop_sintel"
        let tone = ArtworkTone.color(asset: asset)
        return ZStack {
            tone.ignoresSafeArea()
            CatalogImage(asset: asset)
                .blur(radius: 50)
                .scaleEffect(1.35)
                .opacity(0.55)
                .ignoresSafeArea()
            LinearGradient(colors: [tone.opacity(0.2), .black.opacity(0.82)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: 0.45), value: asset)
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                BrandLockup(mark: 26)
                Text(model.language.t("الرئيسية", "Home"))
                    .font(.title3.weight(.bold))
                Spacer(minLength: 8)
                headerIcon("airplayvideo", model.language.t("البث", "Cast")) { showCast = true }
                headerIcon("arrow.down.to.line", model.language.t("التنزيلات", "Downloads")) { showDownloads = true }
                headerIcon("bell", model.language.t("جديد", "New")) { showBell = true }
            }
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
                                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .laylGlassCapsule()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, sideInset)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    private func headerIcon(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
                .foregroundStyle(selected ? Color.black : Color.white)
                .background {
                    if selected {
                        Capsule().fill(Color.white)
                    }
                }
                .laylGlassCapsule(interactive: !selected)
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
        let index = min(featuredIndex, max(featured.count - 1, 0))
        let title = featured[index]
        return VStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                CatalogImage(asset: title.backdropAsset)
                    .frame(maxWidth: .infinity)
                    .frame(height: heroHeight * 0.78)
                    .clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.82)], startPoint: .center, endPoint: .bottom)
                VStack(spacing: 8) {
                    Text(title.title.text(model.language))
                        .font(.system(size: min(layout.heroTitleSize, 40), weight: .black))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .shadow(color: .black.opacity(0.7), radius: 6, y: 2)
                    Text(title.genres.prefix(3).map { $0.title(model.language) }.joined(separator: " · "))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Button {
                            model.play(title: title)
                        } label: {
                            Label(playLabel(title), systemImage: "play.fill")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        Button {
                            model.toggleSaved(title.id)
                        } label: {
                            Label(model.language.t("قائمتي", "My List"), systemImage: model.isSaved(title.id) ? "checkmark" : "plus")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        model.detailTitle = title
                    } label: {
                        Text(model.language.t("التفاصيل", "Details"))
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
            }
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
    case fresh
    case categories
}

extension AppModel {
    var featuredTitles: [CatalogTitle] {
        Catalog.featured(kidsOnly: kidsOnly)
    }
}
