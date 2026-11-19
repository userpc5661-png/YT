import Combine
import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.laylLayout) private var layout
    @State private var featuredIndex = 0
    @State private var showLicenses = false
    @State private var showSettings = false

    var body: some View {
        let featured = model.featuredTitles
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                topBar
                if !featured.isEmpty {
                    hero(featured)
                }
                if !model.continueWatching().isEmpty {
                    continueRail
                }
                if !model.myList().isEmpty {
                    myListRail
                }
                ForEach(Catalog.homeLanes(kidsOnly: model.kidsOnly)) { lane in
                    MediaRail(lane: lane, posterWidth: layout.posterWidth)
                }
            }
            .padding(.bottom, 36)
        }
        .laylScreen()
        .toolbar(.hidden, for: .navigationBar)
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

    private var topBar: some View {
        HStack(spacing: 14) {
            BrandLockup(mark: 32)
            Spacer()
            NavigationLink {
                SearchView()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            Button(action: model.toggleLanguage) {
                Text(model.language == .arabic ? "EN" : "ع")
                    .font(.caption.weight(.heavy))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
            if let profile = model.activeProfile {
                Menu {
                    Button(model.language.t("تبديل الملف", "Switch profile"), systemImage: "person.2") {
                        model.leaveProfile()
                    }
                    Button {
                        showSettings = true
                    } label: {
                        Label(model.language.t("الإعدادات", "Settings"), systemImage: "gearshape")
                    }
                    Button(model.language.t("الحقوق والمصادر", "Rights and sources"), systemImage: "doc.text") {
                        showLicenses = true
                    }
                } label: {
                    ProfileAvatar(profile: profile, size: 34)
                }
            }
        }
        .padding(.horizontal, sideInset)
        .padding(.top, 6)
    }

    private func hero(_ featured: [CatalogTitle]) -> some View {
        let index = min(featuredIndex, featured.count - 1)
        let title = featured[index]
        return ZStack(alignment: .bottomLeading) {
            CatalogImage(asset: title.backdropAsset)
                .frame(maxWidth: .infinity)
                .frame(height: heroHeight)
                .clipped()
                .id(title.id)
                .transition(.opacity)

            LinearGradient(
                colors: [.black.opacity(0.15), .black.opacity(0.15), LaylTheme.bg],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 10) {
                Text(model.language.t("اختيار ليل", "Layl pick"))
                    .font(.caption.weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(LaylTheme.red)
                Text(title.title.text(model.language))
                    .font(.system(size: layout.heroTitleSize, weight: .heavy))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                MetaPills(title: title)
                Text(title.synopsis.text(model.language))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(3)
                    .frame(maxWidth: 620, alignment: .leading)
                HStack(spacing: 12) {
                    PlayPill(title: playLabel(title)) {
                        model.play(title: title)
                    }
                    RoundIconButton(
                        systemName: model.isSaved(title.id) ? "checkmark" : "plus",
                        filled: model.isSaved(title.id)
                    ) {
                        model.toggleSaved(title.id)
                    }
                    .accessibilityLabel(model.language.t("قائمتي", "My List"))
                    NavigationLink(value: title) {
                        Image(systemName: "info.circle")
                            .font(.body.weight(.bold))
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.12), in: Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.28), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
                HStack(spacing: 6) {
                    ForEach(0..<featured.count, id: \.self) { dot in
                        Button {
                            withAnimation(.easeInOut(duration: 0.35)) { featuredIndex = dot }
                        } label: {
                            Capsule()
                                .fill(dot == index ? Color.white : Color.white.opacity(0.35))
                                .frame(width: dot == index ? 16 : 6, height: 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, sideInset)
            .padding(.bottom, 18)
        }
        .frame(height: heroHeight)
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

extension AppModel {
    var featuredTitles: [CatalogTitle] {
        Catalog.featured(kidsOnly: kidsOnly)
    }
}
