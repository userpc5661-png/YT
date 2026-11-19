import AVFoundation
import SwiftUI

struct RemotePlayerScreen: View {
    let title: String
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = PlayerEngine()
    @State private var started = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PlayerSurface(player: engine.player)
                .ignoresSafeArea()
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.bold))
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.55), in: Circle())
                    }
                    .buttonStyle(.plain)
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Button(action: { engine.toggle() }) {
                        Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                Spacer()
                if let error = engine.errorText {
                    Text(error)
                        .font(.footnote)
                        .padding()
                }
            }
        }
        .onAppear {
            guard !started else { return }
            started = true
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try? AVAudioSession.sharedInstance().setActive(true)
            engine.load(url: url, start: 0)
            engine.player.play()
        }
        .onDisappear {
            engine.teardown()
        }
    }
}

struct RemoteRail: View {
    let title: String
    let titles: [RemoteTitle]
    var posterWidth: CGFloat

    @Environment(\.laylLayout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.weight(.bold))
                .padding(.horizontal, layout.contentInset)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: layout.posterGap) {
                    ForEach(titles) { item in
                        NavigationLink(value: item) {
                            RemotePoster(title: item, width: posterWidth)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, layout.contentInset)
            }
        }
    }
}

struct RemotePoster: View {
    let title: RemoteTitle
    var width: CGFloat

    var body: some View {
        RemotePosterImage(urlString: title.posterURL?.absoluteString, width: width)
            .overlay(alignment: .bottomLeading) {
                Text(title.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(2)
                    .padding(6)
            }
            .accessibilityLabel(title.title)
    }
}

struct RemoteDetailView: View {
    let title: RemoteTitle

    @Environment(AppModel.self) private var model
    @Environment(\.laylLayout) private var layout
    @Environment(\.openURL) private var openURL
    @State private var episodes: [RemoteEpisode] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RemoteBackdropImage(urlString: title.backdropURL?.absoluteString ?? title.posterURL?.absoluteString, height: layout.heroHeight * 0.62)
                VStack(alignment: .leading, spacing: 12) {
                    Text(title.title)
                        .font(.system(size: layout.detailTitleSize, weight: .black))
                        .minimumScaleFactor(0.6)
                    HStack(spacing: 8) {
                        if let year = title.year { Text(year) }
                        if let rating = title.rating { Text(rating).foregroundStyle(LaylTheme.match) }
                        Text(title.kind == .series ? model.language.t("مسلسل", "Series") : model.language.t("فيلم", "Movie"))
                    }
                    .font(.subheadline)
                    .foregroundStyle(LaylTheme.muted)
                    if title.directVideo {
                        PlayPill(title: model.language.t("تشغيل", "Play")) {
                            model.play(remote: title)
                        }
                    } else if let link = title.streamURL {
                        Button(model.language.t("فتح صفحة العرض", "Open the watch page")) {
                            openURL(link)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(LaylTheme.red)
                    }
                    Text(title.overview)
                        .font(.body)
                    if !episodes.isEmpty {
                        Text(model.language.t("الحلقات", "Episodes"))
                            .font(.title3.weight(.bold))
                        ForEach(episodes) { episode in
                            HStack {
                                Text(episode.title)
                                Spacer()
                                if let url = episode.streamURL, RemoteTitle(sourceID: title.sourceID, id: episode.id, title: episode.title, overview: "", posterURL: nil, backdropURL: nil, year: nil, genres: [], rating: nil, streamURL: url, episodes: [], kind: .movie).directVideo {
                                    Button(model.language.t("تشغيل", "Play")) {
                                        model.remotePlay = RemotePlayback(url: url, title: episode.title)
                                    }
                                }
                            }
                            .font(.subheadline)
                        }
                    }
                    Text(model.language.t("مصدر مخصص على هذا الجهاز.", "Custom source stored on this device."))
                        .font(.caption)
                        .foregroundStyle(LaylTheme.muted)
                }
                .padding(.horizontal, layout.contentInset)
                .padding(.bottom, 28)
            }
        }
        .laylScreen()
        .navigationBarTitleDisplayMode(.inline)
        .laylNavigationChrome()
        .task {
            guard let source = model.sources.first(where: { $0.id == title.sourceID }) else { return }
            episodes = await SourceClient.episodes(for: title, source: source)
        }
    }
}