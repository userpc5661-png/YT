import SwiftUI

struct AniListPosterImage: View {
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
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .clipped()
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [Color(hex: "36131C"), Color(hex: "101014")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay { Image(systemName: "sparkles").foregroundStyle(.white.opacity(0.55)) }
    }
}

struct AniListTitleCard: View {
    let title: AniListTitle
    let width: CGFloat

    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AniListPosterImage(url: title.coverURL, width: width)
                .overlay(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.68)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    if let rating = title.ratingText {
                        Label(rating, systemImage: "star.fill")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.72), in: Capsule())
                            .padding(7)
                    }
                }
            Text(title.displayTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(width: width, alignment: .leading)
            HStack(spacing: 6) {
                if let year = title.seasonYear { Text(String(year)) }
                if let episodes = title.episodes {
                    if title.seasonYear != nil { Text("·") }
                    Text(model.language.t("\(episodes) حلقة", "\(episodes) ep"))
                }
            }
            .font(.caption2)
            .foregroundStyle(LaylTheme.muted)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct AniListRail: View {
    let title: String
    let items: [AniListTitle]
    let posterWidth: CGFloat

    @Environment(AppModel.self) private var model
    @Environment(\.laylLayout) private var layout

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 8)
                    NavigationLink {
                        AniListBrowseView(title: title, items: items)
                    } label: {
                        Text(model.language.t("عرض الكل", "See all"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LaylTheme.muted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, layout.contentInset)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: layout.posterGap + 4) {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                AniListTitleCard(title: item, width: posterWidth)
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

struct AniListBrowseView: View {
    let title: String
    let items: [AniListTitle]

    @Environment(AppModel.self) private var model
    @Environment(\.laylLayout) private var layout

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: layout.gridMinWidth), spacing: 12)], spacing: 16) {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        AniListTitleCard(title: item, width: layout.gridMinWidth)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, layout.contentInset)
            .padding(.vertical, 16)
        }
        .laylScreen()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .laylNavigationChrome()
    }
}

struct AniListAttributionFooter: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(model.language.t(
                "بيانات الأنمي وصوره من AniList. تُستبعد الوسوم الصريحة قدر الإمكان، لكن التصنيف العمري غير مضمون.",
                "Anime metadata and artwork are from AniList. Explicit tags are filtered where possible, but age ratings are not guaranteed."
            ))
            .font(.caption2)
            .foregroundStyle(LaylTheme.muted)
            Link("AniList", destination: URL(string: "https://anilist.co")!)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct AniListDetailView: View {
    let title: AniListTitle

    @Environment(AppModel.self) private var model
    @Environment(\.laylLayout) private var layout

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .bottomLeading) {
                    banner
                    LinearGradient(colors: [.clear, LaylTheme.bg], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 9) {
                        Text(title.displayTitle)
                            .font(.system(size: min(layout.detailTitleSize, 40), weight: .heavy))
                            .lineLimit(3)
                            .minimumScaleFactor(0.7)
                        if let native = title.originalTitle {
                            Text(native)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.82))
                                .lineLimit(2)
                        }
                    }
                    .padding(.horizontal, layout.contentInset)
                    .padding(.bottom, 18)
                }
                .frame(height: min(layout.heroHeight * 0.68, 320))
                .clipped()

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 9) {
                        if let year = title.seasonYear { Text(String(year)) }
                        if let format = title.format { Text(formatLabel(format)) }
                        if let episodes = title.episodes { Text(model.language.t("\(episodes) حلقة", "\(episodes) ep")) }
                        if let rating = title.ratingText {
                            Label("\(rating) / 10", systemImage: "star.fill")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LaylTheme.muted)

                    if !title.genres.isEmpty {
                        detailField(model.language.t("التصنيفات", "Genres"), title.genres.joined(separator: " · "))
                    }
                    if let overview = title.overview?.trimmingCharacters(in: .whitespacesAndNewlines), !overview.isEmpty {
                        detailField(model.language.t("النبذة", "Overview"), overview)
                    }
                    Text(model.language.t(
                        "معلومات الأنمي من AniList؛ لا يوفر هذا التطبيق تشغيلًا من AniList.",
                        "Anime information is from AniList; this app does not stream from AniList."
                    ))
                    .font(.footnote)
                    .foregroundStyle(LaylTheme.muted)
                    Link(destination: title.aniListURL) {
                        Label(model.language.t("عرض صفحة الأنمي في AniList", "View anime on AniList"), systemImage: "arrow.up.right.square")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(LaylTheme.red)
                    AniListAttributionFooter()
                }
                .padding(.horizontal, layout.contentInset)
                .padding(.bottom, 28)
            }
        }
        .laylScreen()
        .navigationBarTitleDisplayMode(.inline)
        .laylNavigationChrome()
    }

    private var banner: some View {
        Group {
            if let url = title.bannerURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: min(layout.heroHeight * 0.68, 320))
        .clipped()
    }

    private var placeholder: some View {
        LinearGradient(colors: [Color(hex: "36131C"), LaylTheme.bg], startPoint: .top, endPoint: .bottom)
    }

    private func detailField(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(LaylTheme.muted)
            Text(value)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func formatLabel(_ format: String) -> String {
        guard model.language == .arabic else { return format.replacingOccurrences(of: "_", with: " ") }
        switch format {
        case "TV": return "مسلسل"
        case "TV_SHORT": return "مسلسل قصير"
        case "MOVIE": return "فيلم"
        case "SPECIAL": return "حلقة خاصة"
        case "MUSIC": return "موسيقى"
        default: return format
        }
    }
}
