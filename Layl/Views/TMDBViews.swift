import SwiftUI

struct TMDBPosterImage: View {
    let url: URL?
    var width: CGFloat

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                            .overlay {
                                if phase.error == nil { ProgressView().tint(.white) }
                            }
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: width, height: width * 1.5)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipped()
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [Color(red: 0.16, green: 0.18, blue: 0.23), Color(red: 0.07, green: 0.08, blue: 0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay { Image(systemName: "film").foregroundStyle(.white.opacity(0.55)) }
    }
}

struct TMDBTitleCard: View {
    let title: TMDBTitle
    let width: CGFloat

    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TMDBPosterImage(url: title.posterURL, width: width)
                .overlay(alignment: .bottomTrailing) {
                    Text(title.kind == "tv" ? model.language.t("مسلسل", "TV") : model.language.t("فيلم", "Movie"))
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.75), in: Capsule())
                        .padding(6)
                }
            Text(title.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(width: width, alignment: .leading)
            HStack(spacing: 6) {
                if let year = title.year { Text(year) }
                if let rating = title.voteAverage, rating > 0 {
                    if title.year != nil { Text("·") }
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .labelStyle(.titleAndIcon)
                }
            }
            .font(.caption2)
            .foregroundStyle(LaylTheme.muted)
        }
        .contentShape(Rectangle())
    }
}

struct TMDBRail: View {
    let title: String
    let items: [TMDBTitle]
    let posterWidth: CGFloat

    @Environment(AppModel.self) private var model
    @Environment(\.laylLayout) private var layout

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, layout.contentInset)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: layout.posterGap + 4) {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                TMDBTitleCard(title: item, width: posterWidth)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, layout.contentInset)
                    .padding(.bottom, 2)
                }
                .laylHugsWidth()
            }
            .laylHugsWidth()
        }
    }
}

struct TMDBAttributionFooter: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image("TMDBLogo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 210, maxHeight: 30, alignment: .leading)
                .accessibilityLabel("The Movie Database")
            Text(model.language.t(
                "هذا المنتج يستخدم TMDB API، لكنه غير معتمد أو موصى به من TMDB.",
                "This product uses the TMDB API but is not endorsed or certified by TMDB."
            ))
            .font(.caption2)
            Link("themoviedb.org", destination: URL(string: "https://www.themoviedb.org")!)
                .font(.caption)
        }
        .foregroundStyle(LaylTheme.muted)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct DiscoverView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.laylLayout) private var layout

    private var globalTitles: [TMDBTitle] {
        model.tmdb.trending.filter { !model.kidsOnly && $0.adult != true }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layout.rowSpacing) {
                header
                if model.kidsOnly {
                    EmptyState(
                        systemImage: "lock.shield",
                        title: model.language.t("الكتالوج العالمي مخفي", "Global catalog hidden"),
                        message: model.language.t("بيانات TMDB لا تتضمن تصنيفًا عمريًا موثوقًا لكل عمل، لذلك لا نظهرها في ملف الأطفال.", "TMDB does not provide a reliable age rating for every title, so the global catalog is hidden in a kids profile.")
                    )
                    .padding(.horizontal, layout.contentInset)
                } else if !model.tmdb.isConfigured {
                    setupCard
                } else if model.tmdb.isLoading && globalTitles.isEmpty {
                    ProgressView(model.language.t("نجلب الرائج عالميًا...", "Loading worldwide trends..."))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else if globalTitles.isEmpty {
                    EmptyState(
                        systemImage: "wifi.exclamationmark",
                        title: model.language.t("تعذر تحميل الكتالوج", "Could not load the catalog"),
                        message: model.tmdb.error ?? model.language.t("تحقق من الاتصال أو رمز TMDB.", "Check your connection or TMDB token.")
                    )
                    .padding(.horizontal, layout.contentInset)
                } else {
                    TMDBRail(
                        title: model.language.t("الرائج عالميًا", "Trending worldwide"),
                        items: globalTitles,
                        posterWidth: layout.posterWidth
                    )
                    TMDBRail(
                        title: model.language.t("أفلام رائجة عالميًا", "Trending movies worldwide"),
                        items: globalTitles.filter { $0.kind == "movie" },
                        posterWidth: layout.posterWidth
                    )
                    TMDBRail(
                        title: model.language.t("مسلسلات رائجة عالميًا", "Trending TV worldwide"),
                        items: globalTitles.filter { $0.kind == "tv" },
                        posterWidth: layout.posterWidth
                    )
                    TMDBAttributionFooter()
                        .padding(.horizontal, layout.contentInset)
                }
            }
            .padding(.vertical, 12)
            .padding(.bottom, 24)
        }
        .laylScreen()
        .navigationTitle(model.language.t("اكتشف عالميًا", "Worldwide"))
        .navigationBarTitleDisplayMode(.large)
        .laylNavigationChrome()
        .refreshable { await model.tmdb.refreshTrending(language: model.tmdbLanguage) }
        .onAppear { model.tmdb.loadTrending(language: model.tmdbLanguage) }
        .onChange(of: model.tmdbLanguage) { _, language in
            model.tmdb.loadTrending(language: language, forceRefresh: true)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.language.t("أفلام ومسلسلات من أنحاء العالم", "Movies and TV from around the world"))
                    .font(.headline)
                Text(model.language.t("بيانات وصور من TMDB · لا تشمل تشغيل الفيديو", "Metadata and artwork by TMDB · no video playback"))
                    .font(.caption)
                    .foregroundStyle(LaylTheme.muted)
            }
            Spacer(minLength: 8)
            NavigationLink { SettingsView() } label: {
                Image(systemName: "gearshape.fill")
                    .font(.body.weight(.semibold))
                    .padding(10)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.language.t("الإعدادات", "Settings"))
        }
        .padding(.horizontal, layout.contentInset)
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.language.t("فعّل الكتالوج العالمي المجاني", "Enable the free global catalog"))
                .font(.title3.weight(.bold))
            Text(model.language.t(
                "أنشئ رمز API Read Access Token مجانيًا من TMDB للحسابات غير التجارية، ثم أضفه في الإعدادات. هذا الرمز يجلب بيانات الأفلام والمسلسلات فقط.",
                "Create a free TMDB API Read Access Token for non-commercial use, then add it in Settings. The API provides title data only."
            ))
            .font(.subheadline)
            .foregroundStyle(LaylTheme.muted)
            NavigationLink { SettingsView() } label: {
                Text(model.language.t("إعداد TMDB", "Set up TMDB"))
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LaylTheme.red, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            TMDBAttributionFooter()
        }
        .padding(16)
        .background(LaylTheme.elevated, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, layout.contentInset)
    }
}

struct TMDBDetailView: View {
    let title: TMDBTitle

    @Environment(AppModel.self) private var model
    @Environment(\.laylLayout) private var layout

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack(alignment: .bottomLeading) {
                    backdrop
                    LinearGradient(colors: [.clear, LaylTheme.bg], startPoint: .center, endPoint: .bottom)
                    Text(title.title)
                        .font(.system(size: min(layout.detailTitleSize, 40), weight: .heavy))
                        .lineLimit(3)
                        .padding(.horizontal, layout.contentInset)
                        .padding(.bottom, 14)
                }
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        if let year = title.year { Text(year) }
                        Text(title.kind == "tv" ? model.language.t("مسلسل", "TV series") : model.language.t("فيلم", "Movie"))
                        if let rating = title.voteAverage, rating > 0 {
                            Label(String(format: "%.1f / 10", rating), systemImage: "star.fill")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LaylTheme.muted)

                    if let original = title.originalTitle {
                        labeled(model.language.t("العنوان الأصلي", "Original title"), original)
                    }
                    if let languageCode = title.originalLanguage {
                        labeled(model.language.t("لغة العمل", "Original language"), languageCode.uppercased())
                    }
                    if !title.overview.isEmpty {
                        labeled(model.language.t("النبذة", "Overview"), title.overview)
                    }
                    Text(model.language.t(
                        "هذا سجل معلومات وصور فقط؛ TMDB لا يقدّم ملف الفيديو أو حق تشغيل العمل.",
                        "This is a metadata and artwork listing; TMDB does not provide the video file or streaming rights."
                    ))
                    .font(.footnote)
                    .foregroundStyle(LaylTheme.muted)
                    Link(destination: title.tmdbURL) {
                        Label(model.language.t("عرض صفحة العمل في TMDB", "View title on TMDB"), systemImage: "arrow.up.right.square")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(LaylTheme.red)
                    TMDBAttributionFooter()
                }
                .padding(.horizontal, layout.contentInset)
                .padding(.bottom, 28)
            }
        }
        .laylScreen()
        .navigationBarTitleDisplayMode(.inline)
        .laylNavigationChrome()
    }

    private var backdrop: some View {
        Group {
            if let url = title.backdropURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { Color(red: 0.12, green: 0.13, blue: 0.17) }
                }
            } else {
                Color(red: 0.12, green: 0.13, blue: 0.17)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: min(layout.heroHeight * 0.68, 310))
        .clipped()
    }

    private func labeled(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(LaylTheme.muted)
            Text(value)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
