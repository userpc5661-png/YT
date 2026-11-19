import SwiftUI

enum DetailPane: String, CaseIterable, Identifiable {
    case episodes, collection, similar, trailers
    var id: String { rawValue }
}

struct TitleDetailView: View {
    let title: CatalogTitle

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.laylLayout) private var layout
    @Environment(\.openURL) private var openURL
    @State private var pane: DetailPane = .episodes
    @State private var expanded = false
    @State private var showRate = false
    @State private var season = 1

    var body: some View {
        let language = model.language
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                VStack(alignment: .leading, spacing: 14) {
                    Text("ليل")
                        .font(.caption.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(LaylTheme.red)
                    Text(title.title.text(language))
                        .font(.system(size: layout.detailTitleSize, weight: .bold))
                        .minimumScaleFactor(0.7)
                    metaRow
                    Text(title.credit.text(language))
                        .font(.subheadline.weight(.semibold))
                    Button { model.play(title: title) } label: {
                        Label(playLabel, systemImage: "play.fill")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    Button { model.toggleDownload(title.id) } label: {
                        Label(
                            model.isDownloaded(title.id) ? language.t("محفوظ على الجهاز", "Saved on this device") : language.t("تنزيل", "Download"),
                            systemImage: "arrow.down.to.line"
                        )
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .laylGlassButton()
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title.synopsis.text(language))
                            .font(.subheadline)
                            .lineLimit(expanded ? nil : 3)
                        Button(expanded ? language.t("أقل", "Less") : language.t("المزيد", "More")) {
                            expanded.toggle()
                        }
                        .font(.caption.weight(.bold))
                    }
                    actionRow
                    panePicker
                    paneBody
                    if model.hasStreamingAPI { streamingAvailability }
                    rights
                }
                .padding(.horizontal, layout.contentInset)
                .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            if #available(iOS 26, *) {
                Color.clear
            } else {
                Color.black.opacity(0.96)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear { model.loadStreamingInfo(for: title) }
        .popover(isPresented: $showRate) {
            ratePopover
                .presentationCompactAdaptation(.popover)
        }
    }

    private var metaRow: some View {
        let language = model.language
        let seasons = Set(title.episodes.map(\.season)).count
        return HStack(spacing: 8) {
            Text(String(title.year))
            Text(title.maturity.text(language))
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 4)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(.white.opacity(0.7)))
            if title.kind == .series {
                Text(language.t("\(seasons) مواسم", "\(seasons) seasons"))
            }
            Text(title.quality == .hd ? "HD" : "SD")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 4)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(.white.opacity(0.7)))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.85))
    }

    private var actionRow: some View {
        let language = model.language
        return HStack {
            actionButton(language.t("قائمتي", "My List"), model.isSaved(title.id) ? "checkmark" : "plus") {
                model.toggleSaved(title.id)
            }
            actionButton(language.t("تقييم", "Rate"), "hand.thumbsup") { showRate = true }
            ShareLink(item: title.title.text(language)) {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                    Text(language.t("مشاركة", "Share")).font(.caption2)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            actionButton(language.t("تنزيل الموسم", "Download season"), "arrow.down.to.line") {
                model.toggleDownload(title.id)
            }
        }
        .foregroundStyle(.white)
    }

    private func actionButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                Text(title).font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var ratePopover: some View {
        let language = model.language
        return HStack(spacing: 16) {
            rateChoice("hand.thumbsdown", language.t("ليس لي", "Not for me"), "skip")
            rateChoice("hand.thumbsup", language.t("أعجبني", "I like this"), "like")
            rateChoice("heart.fill", language.t("أحببته", "Love this!"), "love")
        }
        .padding(16)
        .laylGlass(in: Capsule(), interactive: true)
        .presentationBackground(.clear)
    }

    private func rateChoice(_ symbol: String, _ label: String, _ value: String) -> some View {
        Button {
            model.setTaste(value, for: title.id)
            showRate = false
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.title3)
                Text(label).font(.caption2).multilineTextAlignment(.center)
            }
            .frame(width: 72)
            .foregroundStyle(model.taste(for: title.id) == value ? LaylTheme.red : .white)
        }
        .buttonStyle(.plain)
    }

    private var panePicker: some View {
        let language = model.language
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(DetailPane.allCases) { item in
                    Button(paneTitle(item, language)) { pane = item }
                        .font(.subheadline.weight(pane == item ? .bold : .regular))
                        .foregroundStyle(pane == item ? .white : .white.opacity(0.55))
                        .padding(.bottom, 6)
                        .overlay(alignment: .bottom) {
                            if pane == item { Rectangle().fill(LaylTheme.red).frame(height: 2) }
                        }
                }
            }
        }
        .laylHugsWidth()
    }

    private func paneTitle(_ pane: DetailPane, _ language: AppLanguage) -> String {
        switch pane {
        case .episodes: return language.t("الحلقات", "Episodes")
        case .collection: return language.t("المجموعة", "Collection")
        case .similar: return language.t("عناوين مشابهة", "More like this")
        case .trailers: return language.t("مقتطفات", "Trailers")
        }
    }

    @ViewBuilder
    private var paneBody: some View {
        switch pane {
        case .episodes:
            seasonMenu
            ForEach(title.episodes.filter { $0.season == season }) { episode in
                episodeRow(episode)
            }
        case .collection, .similar:
            let related = Catalog.related(to: title, kidsOnly: model.kidsOnly)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: layout.gridMinWidth), spacing: 10)], spacing: 12) {
                ForEach(related) { item in
                    Button { model.detailTitle = item } label: {
                        PosterCard(title: item, width: layout.gridMinWidth)
                    }
                    .buttonStyle(.plain)
                }
            }
        case .trailers:
            ForEach(title.episodes) { episode in
                Button { model.play(title: title, episode: episode) } label: {
                    ZStack {
                        CatalogImage(asset: episode.stillAsset)
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .clipped()
                        Image(systemName: "play.fill").font(.title).padding(16).background(.black.opacity(0.45), in: Circle())
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var seasonMenu: some View {
        let seasons = Array(Set(title.episodes.map(\.season))).sorted()
        return Menu {
            ForEach(seasons, id: \.self) { item in
                Button(model.language.t("الموسم \(item)", "Season \(item)")) { season = item }
            }
        } label: {
            HStack {
                Text(model.language.t("الموسم \(season)", "Season \(season)"))
                Image(systemName: "chevron.down")
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .laylGlassCapsule()
        }
    }

    private var header: some View {
        ZStack(alignment: .top) {
            CatalogImage(asset: title.backdropAsset)
                .frame(maxWidth: .infinity)
                .frame(height: min(layout.heroHeight * 0.55, 240))
                .clipped()
            HStack {
                Button { model.play(title: title) } label: {
                    Image(systemName: "airplayvideo")
                        .frame(width: 36, height: 36)
                        .laylGlassCircle()
                }
                .buttonStyle(.plain)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.bold))
                        .frame(width: 36, height: 36)
                        .laylGlassCircle()
                }
                .buttonStyle(.plain)
            }
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
