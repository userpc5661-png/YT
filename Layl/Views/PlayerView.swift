import AVFoundation
import AVKit
import Combine
import SwiftUI
import UIKit

struct PlayerScreen: View {
    let title: CatalogTitle
    @State private var episode: Episode
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = PlayerEngine()
    @State private var started = false
    @State private var showControls = true
    @State private var hideTask: Task<Void, Never>?
    @State private var showEpisodes = false
    @State private var countdown: Int?

    init(title: CatalogTitle, episode: Episode) {
        self.title = title
        _episode = State(initialValue: episode)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                PlayerSurface(player: engine.player)
                    .ignoresSafeArea()

                if engine.errorText != nil {
                    errorPane
                } else if showControls || !engine.isPlaying || engine.ended {
                    controls
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }

                if engine.ended {
                    endCard
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard engine.errorText == nil, !engine.ended else { return }
                showControls.toggle()
                if showControls { scheduleHide() }
            }
            .gesture(skipGesture(width: geo.size.width))
        }
        .background(Color.black)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            guard !started else { return }
            started = true
            activateAudio()
            load(episode, keepPosition: true)
            scheduleHide()
        }
        .onDisappear {
            save(force: true)
            engine.teardown()
            hideTask?.cancel()
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
        .onChange(of: engine.isPlaying) { _, playing in
            if playing { scheduleHide() }
        }
        .onChange(of: engine.ended) { _, ended in
            if ended {
                save(force: true)
                countdown = nextEpisode == nil ? nil : 8
            }
        }
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
            if engine.isPlaying { save(force: true) }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard engine.ended, let countdown else { return }
            if countdown <= 1 {
                self.countdown = nil
                if let next = nextEpisode { play(next) }
            } else {
                self.countdown = countdown - 1
            }
        }
        .sheet(isPresented: $showEpisodes) {
            episodeSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .environment(\.layoutDirection, model.language == .arabic ? .rightToLeft : .leftToRight)
        .preferredColorScheme(.dark)
    }

    private var nextEpisode: Episode? {
        guard let index = title.episodes.firstIndex(where: { $0.id == episode.id }) else { return nil }
        let next = title.episodes.index(after: index)
        guard next < title.episodes.endIndex else { return nil }
        return title.episodes[next]
    }

    private var controls: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    save(force: true)
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.bold))
                        .frame(width: 40, height: 40)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.title.text(model.language))
                        .font(.headline)
                        .lineLimit(1)
                    if title.kind == .series {
                        Text(model.language.t(
                            "الحلقة \(episode.number) · \(episode.title.text(model.language))",
                            "Episode \(episode.number) · \(episode.title.text(model.language))"
                        ))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                    }
                }
                Spacer()
                AirPlayRouteButton()
                    .frame(width: 36, height: 36)
                if title.kind == .series {
                    Button {
                        showEpisodes = true
                        showControls = true
                    } label: {
                        Image(systemName: "rectangle.stack")
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            HStack(spacing: 36) {
                transportButton("gobackward.10") { engine.seek(by: -10) }
                Button {
                    engine.toggle()
                    scheduleHide()
                } label: {
                    ZStack {
                        if engine.waiting && !engine.isPlaying {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 34))
                                .environment(\.layoutDirection, .leftToRight)
                        }
                    }
                    .frame(width: 68, height: 68)
                    .background(.white.opacity(0.16), in: Circle())
                }
                .buttonStyle(.plain)
                transportButton("goforward.10") { engine.seek(by: 10) }
            }
            .environment(\.layoutDirection, .leftToRight)
            .opacity(engine.ended ? 0 : 1)

            Spacer()

            VStack(spacing: 6) {
                Slider(
                    value: Binding(
                        get: { engine.current },
                        set: { engine.current = $0; engine.scrubbing = true }
                    ),
                    in: 0...max(engine.duration, 1),
                    onEditingChanged: { editing in
                        if editing {
                            engine.scrubbing = true
                            hideTask?.cancel()
                        } else {
                            engine.seek(to: engine.current, resume: engine.isPlaying)
                            scheduleHide()
                        }
                    }
                )
                .tint(LaylTheme.red)
                HStack {
                    Text(Clock.text(engine.current))
                    Spacer()
                    Text(engine.duration > 1 ? "-\(Clock.text(max(engine.duration - engine.current, 0)))" : Clock.text(0))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
            }
            .environment(\.layoutDirection, .leftToRight)
            .padding(.bottom, 8)
        }
        .foregroundStyle(.white)
        .background(
            LinearGradient(colors: [.black.opacity(0.72), .clear, .black.opacity(0.78)], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
        )
    }

    private func transportButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            scheduleHide()
        }) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
    }

    private var errorPane: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
            Text(model.language.t("تعذّر تشغيل الفيديو", "The video could not play"))
                .font(.headline)
            Text(model.language.t(
                "تحقق من الاتصال بالإنترنت ثم أعد المحاولة. المصدر على أرشيف الإنترنت.",
                "Check your internet connection and try again. The file streams from the Internet Archive."
            ))
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.75))
            .multilineTextAlignment(.center)
            if let detail = engine.errorText {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(3)
            }
            Button(model.language.t("إعادة المحاولة", "Try again")) {
                load(episode, keepPosition: true)
            }
            .buttonStyle(.borderedProminent)
            .tint(LaylTheme.red)
            Button(model.language.t("إغلاق", "Close")) { dismiss() }
                .foregroundStyle(.white)
        }
        .padding(28)
    }

    private var endCard: some View {
        VStack(spacing: 14) {
            Text(model.language.t("انتهت الحلقة", "Finished"))
                .font(.headline)
            if let next = nextEpisode {
                if let countdown {
                    Text(model.language.t(
                        "الحلقة التالية خلال \(countdown) ث",
                        "Next episode in \(countdown)s"
                    ))
                    .foregroundStyle(.white.opacity(0.75))
                }
                Button(model.language.t("تشغيل \(next.title.text(model.language))", "Play \(next.title.text(model.language))")) {
                    play(next)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                if countdown != nil {
                    Button(model.language.t("إلغاء", "Cancel")) { countdown = nil }
                        .foregroundStyle(.white)
                }
            }
            Button(model.language.t("إعادة", "Replay")) {
                countdown = nil
                engine.replay()
            }
            .foregroundStyle(.white)
        }
        .padding(24)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
    }

    private var episodeSheet: some View {
        NavigationStack {
            List(title.episodes) { item in
                Button {
                    showEpisodes = false
                    play(item)
                } label: {
                    HStack(spacing: 12) {
                        CatalogImage(asset: item.stillAsset)
                            .frame(width: 96, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.language.t("الحلقة \(item.number)", "Episode \(item.number)"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(LaylTheme.muted)
                            Text(item.title.text(model.language))
                                .foregroundStyle(.white)
                            if item.id == episode.id {
                                Text(model.language.t("تُشغَّل الآن", "Now playing"))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(LaylTheme.red)
                            }
                        }
                    }
                }
                .listRowBackground(LaylTheme.elevated)
            }
            .scrollContentBackground(.hidden)
            .background(LaylTheme.bg)
            .navigationTitle(model.language.t("الحلقات", "Episodes"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }

    private func skipGesture(width: CGFloat) -> some Gesture {
        SpatialTapGesture(count: 2).onEnded { value in
            if value.location.x < width / 2 {
                engine.seek(by: -10)
            } else {
                engine.seek(by: 10)
            }
            showControls = true
            scheduleHide()
        }
    }

    private func load(_ episode: Episode, keepPosition: Bool) {
        guard let url = URL(string: episode.videoURL) else {
            engine.fail(model.language.t("رابط غير صالح", "Invalid video address"))
            return
        }
        let saved = model.progress(for: episode.id)
        let start = (keepPosition && saved?.isResumable == true) ? (saved?.position ?? 0) : 0
        countdown = nil
        engine.load(url: url, start: start)
    }

    private func play(_ next: Episode) {
        save(force: true)
        episode = next
        load(next, keepPosition: true)
        showControls = true
        scheduleHide()
    }

    private func save(force: Bool) {
        model.noteProgress(
            titleID: title.id,
            episodeID: episode.id,
            position: engine.current,
            duration: engine.duration,
            force: force
        )
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            if engine.isPlaying && !engine.scrubbing && !engine.ended {
                showControls = false
            }
        }
    }

    private func activateAudio() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }
}

struct PlayerSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerHostView {
        let view = PlayerHostView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PlayerHostView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
}

final class PlayerHostView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct AirPlayRouteButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = .white
        view.activeTintColor = UIColor(red: 0.898, green: 0.035, blue: 0.078, alpha: 1)
        view.prioritizesVideoDevices = true
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

@MainActor
final class PlayerEngine: ObservableObject {
    let player = AVPlayer()
    @Published var isPlaying = false
    @Published var current: Double = 0
    @Published var duration: Double = 0
    @Published var waiting = false
    @Published var ended = false
    @Published var scrubbing = false
    @Published var errorText: String?

    private var observations: [NSKeyValueObservation] = []
    private var timeToken: Any?
    private var endObserver: NSObjectProtocol?
    private var pendingStart: Double = 0
    private var appliedStart = false

    func fail(_ message: String) {
        errorText = message
    }

    func load(url: URL, start: Double) {
        clearObservers()
        pendingStart = start
        appliedStart = false
        ended = false
        errorText = nil
        current = start
        duration = 0
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 8
        player.replaceCurrentItem(with: item)
        player.actionAtItemEnd = .pause
        player.automaticallyWaitsToMinimizeStalling = true
        player.preventsDisplaySleepDuringVideoPlayback = true
        observe(item)
    }

    func toggle() {
        if ended {
            replay()
            return
        }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    func seek(by delta: Double) {
        let upper = duration > 1 ? duration : max(current + max(delta, 0), 0)
        seek(to: min(max(0, current + delta), upper), resume: true)
    }

    func seek(to value: Double, resume: Bool) {
        ended = false
        scrubbing = false
        let clamped = max(0, value)
        current = clamped
        let tolerance = CMTime(seconds: 0.35, preferredTimescale: 600)
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: tolerance, toleranceAfter: tolerance)
        if resume { player.play() }
    }

    func replay() {
        seek(to: 0, resume: true)
    }

    func teardown() {
        clearObservers()
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    private func observe(_ item: AVPlayerItem) {
        observations.append(item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let status = item.status
            let message = item.error?.localizedDescription
            let seconds = item.duration.seconds
            Task { @MainActor in
                self?.handle(status: status, message: message, itemDuration: seconds)
            }
        })
        observations.append(player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            let waiting = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
            let playing = player.timeControlStatus == .playing
            Task { @MainActor in
                self?.waiting = waiting
                self?.isPlaying = playing
            }
        })
        timeToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            let seconds = time.seconds
            Task { @MainActor in
                guard let self, !self.scrubbing, !self.ended, seconds.isFinite else { return }
                self.current = seconds
                if let duration = self.player.currentItem?.duration.seconds, duration.isFinite, duration > 0 {
                    self.duration = duration
                }
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.ended = true
                self.isPlaying = false
                if self.duration > 0 { self.current = self.duration }
            }
        }
    }

    private func handle(status: AVPlayerItem.Status, message: String?, itemDuration: Double) {
        switch status {
        case .readyToPlay:
            errorText = nil
            if itemDuration.isFinite, itemDuration > 0 { duration = itemDuration }
            guard !appliedStart else { return }
            appliedStart = true
            let start = pendingStart
            let tooLate = itemDuration.isFinite && itemDuration > 1 && start >= itemDuration - 1
            if start > 1, !tooLate {
                let tolerance = CMTime(seconds: 0.5, preferredTimescale: 600)
                player.seek(to: CMTime(seconds: start, preferredTimescale: 600), toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] _ in
                    Task { @MainActor in self?.player.play() }
                }
            } else {
                player.play()
            }
        case .failed:
            errorText = message ?? "Playback failed"
            isPlaying = false
        default:
            break
        }
    }

    private func clearObservers() {
        if let timeToken {
            player.removeTimeObserver(timeToken)
            self.timeToken = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        observations.removeAll()
    }
}
