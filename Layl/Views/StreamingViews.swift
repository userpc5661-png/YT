import SwiftUI

struct RemotePosterImage: View {
    let urlString: String?
    var width: CGFloat = 114

    private var height: CGFloat { width * 1.48 }

    var body: some View {
        Color.clear
            .overlay { remoteImage }
            .frame(width: width, height: height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    @ViewBuilder
    private var remoteImage: some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    placeholder
                default:
                    placeholder.overlay { ProgressView().tint(.white) }
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [Color(red: 0.28, green: 0.05, blue: 0.07), Color(red: 0.08, green: 0.08, blue: 0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct RemoteBackdropImage: View {
    let urlString: String?
    var height: CGFloat = 320

    var body: some View {
        Color.clear
            .overlay {
                if let urlString, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [Color(red: 0.2, green: 0.04, blue: 0.06), LaylTheme.bg],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct StreamingShowCard: View {
    let show: StreamingShow
    var width: CGFloat = 114

    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemotePosterImage(urlString: show.posterURL, width: width)
            Text(show.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(width: width, alignment: .leading)
            if let year = show.releaseYear {
                Text("\(year)")
                    .font(.caption2)
                    .foregroundStyle(LaylTheme.muted)
            }
        }
    }
}

struct StreamingRail: View {
    let lane: DiscoverLane
    var posterWidth: CGFloat

    @Environment(AppModel.self) private var model
    @Environment(\.laylLayout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lane.title.text(model.language))
                .font(.title3.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, layout.contentInset)
                .laylHugsWidth()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(lane.shows) { show in
                        NavigationLink(value: show) {
                            StreamingShowCard(show: show, width: posterWidth)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, layout.contentInset)
            }
            .laylHugsWidth()
        }
        .laylHugsWidth()
    }
}

struct StreamingShowDetailView: View {
    let show: StreamingShow

    @Environment(AppModel.self) private var model
    @Environment(\.laylLayout) private var layout
    @Environment(\.openURL) private var openURL

    var body: some View {
        let language = model.language
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack(alignment: .bottomLeading) {
                    RemoteBackdropImage(urlString: show.backdropURL, height: layout.heroHeight * 0.72)
                    LinearGradient(colors: [.clear, LaylTheme.bg], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(show.title)
                            .font(.system(size: layout.detailTitleSize, weight: .heavy))
                            .lineLimit(2)
                        HStack(spacing: 10) {
                            if let year = show.releaseYear {
                                Text("\(year)")
                            }
                            Text(show.kind == .movie ? language.t("فيلم", "Movie") : language.t("مسلسل", "Series"))
                            if let rating = show.rating {
                                Text("\(rating)%")
                                    .foregroundStyle(LaylTheme.match)
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(LaylTheme.muted)
                    }
                    .padding(.horizontal, layout.contentInset)
                    .padding(.bottom, 14)
                }

                VStack(alignment: .leading, spacing: 14) {
                    if let local = model.catalogMatch(for: show) {
                        PlayPill(title: language.t("شغّل داخل ليل", "Play in Layl")) {
                            model.play(title: local)
                        }
                    }

                    Text(show.overview)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.9))

                    if !filteredOptions.isEmpty {
                        Text(language.t("أين يُعرض", "Where to stream"))
                            .font(.headline)
                        ForEach(filteredOptions) { option in
                            streamingRow(option)
                        }
                    } else {
                        Text(language.t("لا توجد روابط بث لهذه الدولة حاليًا.", "No streaming links for this country yet."))
                            .font(.footnote)
                            .foregroundStyle(LaylTheme.muted)
                    }

                    APIAttributionFooter()
                }
                .padding(.horizontal, layout.contentInset)
                .padding(.bottom, 28)
            }
        }
        .laylScreen()
        .navigationBarTitleDisplayMode(.inline)
        .laylNavigationChrome()
    }

    private var filteredOptions: [StreamingOption] {
        let preferred = model.preferredStreamingServices
        let options = show.streamingOptions
        if preferred.isEmpty { return options }
        return options.filter { preferred.contains($0.serviceID) || preferred.isEmpty }
    }

    private func streamingRow(_ option: StreamingOption) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(option.serviceName)
                    .font(.subheadline.weight(.semibold))
                Text(streamTypeLabel(option.type))
                    .font(.caption)
                    .foregroundStyle(LaylTheme.muted)
                if let quality = option.quality {
                    Text(quality.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(LaylTheme.match)
                }
            }
            Spacer()
            if let link = option.link {
                Button {
                    openURL(link)
                } label: {
                    Text(model.language.t("فتح", "Open"))
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(LaylTheme.red, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(LaylTheme.elevated, in: RoundedRectangle(cornerRadius: 12))
    }

    private func streamTypeLabel(_ raw: String) -> String {
        switch raw {
        case "subscription": return model.language.t("اشتراك", "Subscription")
        case "rent": return model.language.t("إيجار", "Rent")
        case "buy": return model.language.t("شراء", "Buy")
        case "free": return model.language.t("مجاني", "Free")
        case "addon": return model.language.t("إضافة", "Add-on")
        default: return raw
        }
    }
}

struct APIAttributionFooter: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.language.t("بيانات التوفر", "Availability data"))
                .font(.caption.weight(.semibold))
            Link(
                model.language.t("Streaming Availability API", "Streaming Availability API"),
                destination: URL(string: "https://github.com/movieofthenight/streaming-availability-api")!
            )
            .font(.caption)
            Text(model.language.t(
                "الصور والبيانات تخضع لشروط مزود الخدمة.",
                "Images and metadata are subject to the provider terms."
            ))
            .font(.caption2)
            .foregroundStyle(LaylTheme.muted)
        }
        .padding(.top, 8)
    }
}