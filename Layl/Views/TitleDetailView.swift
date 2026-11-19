import SwiftUI

struct TitleDetailView: View {
    let title: CatalogTitle

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.laylLayout) private var layout
    @Environment(\.openURL) private var openURL

    var body: some View {
        let language = model.language
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Text("\(title.match)%")
                            .foregroundStyle(LaylTheme.match)
                            .fontWeight(.bold)
                        Text(language.t("مناسب لك", "Match"))
                            .foregroundStyle(LaylTheme.match)
                        Text(String(format: "%.1f", title.score))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .font(.subheadline)

                    HStack(spacing: 12) {
                        PlayPill(title: playLabel) { model.play(title: title) }
                        RoundIconButton(systemName: model.isSaved(title.id) ? "checkmark" : "plus", filled: model.isSaved(title.id)) {
                            model.toggleSaved(title.id)
                        }
                        .accessibilityLabel(language.t("قائمتي", "My List"))
                    }

                    Text(title.synopsis.text(language))
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(title.genres.map { $0.title(language) }.joined(separator: language.t(" · ", " · ")))
                        .font(.subheadline)
                        .foregroundStyle(LaylTheme.muted)

                    labeled(language.t("بطولة وإنتاج", "Credits"), title.credit.text(language))
                    if !title.cast.isEmpty {
                        labeled(
                            language.t("التمثيل", "Cast"),
                            title.cast.map { $0.text(language) }.joined(separator: language.t("، ", ", "))
                        )
                    }
                    if let quality = qualityNote {
                        Text(quality)
                            .font(.footnote)
                            .foregroundStyle(LaylTheme.muted)
                    }

                    if title.kind == .series {
                        episodes
                    }

                    let related = Catalog.related(to: title, kidsOnly: model.kidsOnly)
                    if !related.isEmpty {
                        MediaRail(
                            lane: Lane(
                                id: "related-\(title.id)",
                                title: L10n(ar: "عناوين مشابهة", en: "More like this"),
                                titleIDs: related.map(\.id),
                                style: .poster
                            ),
                            posterWidth: layout.posterWidth
                        )
                        .padding(.horizontal, -layout.contentInset)
                    }

                    if model.hasStreamingAPI {
                        streamingAvailability
                    }

                    rights
                }
                .padding(.horizontal, layout.contentInset)
                .padding(.bottom, 32)
            }
        }
        .laylScreen()
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear { model.loadStreamingInfo(for: title) }
    }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            CatalogImage(asset: title.backdropAsset)
                .frame(height: layout.heroHeight * 0.72)
                .frame(maxWidth: .infinity)
                .clipped()
            LinearGradient(colors: [.clear, LaylTheme.bg], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 8) {
                Text(title.title.text(model.language))
                    .font(.system(size: layout.detailTitleSize, weight: .heavy))
                    .lineLimit(3)
                MetaPills(title: title)
            }
            .padding(.horizontal, layout.contentInset)
            .padding(.bottom, 12)
        }
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: model.language == .arabic ? "chevron.right" : "chevron.left")
                    .font(.body.weight(.bold))
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, layout.contentInset)
            .padding(.top, 12)
        }
    }

    private var streamingAvailability: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.language.t("أين يُعرض (API)", "Where to stream (API)"))
                .font(.title3.weight(.bold))
            if let show = model.titleStreamingInfo[title.id] {
                if show.streamingOptions.isEmpty {
                    Text(model.language.t("لا توجد روابط في دولتك المختارة.", "No links in your selected country."))
                        .font(.footnote)
                        .foregroundStyle(LaylTheme.muted)
                } else {
                    ForEach(show.streamingOptions.prefix(6)) { option in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.serviceName).font(.subheadline.weight(.semibold))
                                Text(option.type).font(.caption).foregroundStyle(LaylTheme.muted)
                            }
                            Spacer()
                            if let link = option.link {
                                Button(model.language.t("فتح", "Open")) { openURL(link) }
                                    .font(.caption.weight(.bold))
                            }
                        }
                        .padding(10)
                        .background(LaylTheme.elevated, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                APIAttributionFooter()
            } else {
                ProgressView()
            }
        }
    }

    private var playLabel: String {
        model.resumeTarget(for: title) == nil
            ? model.language.t("تشغيل", "Play")
            : model.language.t("استئناف", "Resume")
    }

    private var qualityNote: String? {
        switch title.quality {
        case .hd:
            return nil
        case .compact:
            return model.language.t(
                "نسخة مضغوطة للبث. الفيلم الأصلي أوضح على موقع بلندر.",
                "Compact streaming copy. The original master is sharper on the Blender project page."
            )
        case .archival:
            return model.language.t(
                "نسخة أرشيفية بدقة قياسية من الملك العام أو رخصة حرة. جودة الصورة تتبع النقل المتاح.",
                "Standard-definition archival transfer under a public-domain or free license."
            )
        }
    }

    private var episodes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.language.t("الحلقات", "Episodes"))
                .font(.title3.weight(.bold))
            Text(model.language.t("الموسم ١", "Season 1"))
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1), in: Capsule())
            ForEach(title.episodes) { episode in
                episodeRow(episode)
            }
        }
    }

    private func episodeRow(_ episode: Episode) -> some View {
        Button {
            model.play(title: title, episode: episode)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack(alignment: .bottom) {
                    CatalogImage(asset: episode.stillAsset)
                        .frame(width: 128, height: 72)
                        .clipped()
                    if let progress = model.progress(for: episode.id), progress.duration > 1 {
                        ProgressView(value: progress.fraction)
                            .tint(LaylTheme.red)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.language.t("الحلقة \(episode.number)", "Episode \(episode.number)"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(LaylTheme.muted)
                        Spacer()
                        Text(model.language.t("\(episode.minutes) د", "\(episode.minutes)m"))
                            .font(.caption2)
                            .foregroundStyle(LaylTheme.muted)
                    }
                    Text(episode.title.text(model.language))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(episode.synopsis.text(model.language))
                        .font(.caption)
                        .foregroundStyle(LaylTheme.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(10)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private var rights: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.language.t("الترخيص", "License"))
                .font(.caption.weight(.bold))
                .foregroundStyle(LaylTheme.muted)
            Text(title.rights)
                .font(.footnote.weight(.semibold))
            Link(title.rightsURL, destination: URL(string: title.rightsURL)!)
                .font(.caption)
            Link(destination: URL(string: title.archivePage)!) {
                Text(model.language.t("صفحة الأرشيف", "Archive page"))
                    .font(.caption.weight(.semibold))
            }
            Text(model.language.t(
                "يُبث هذا العمل كما نُشر، دون تعديل على الفيلم. ذكر النسبة مطلوب لتراخيص المشاع الإبداعي.",
                "This copy streams the published film without changes. Creative Commons titles require attribution."
            ))
            .font(.caption2)
            .foregroundStyle(LaylTheme.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(LaylTheme.muted)
            Text(value)
                .font(.subheadline)
        }
    }
}
