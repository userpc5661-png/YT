import SwiftUI
import UIKit

struct CatalogImage: View {
    let asset: String

    var body: some View {
        if let image = UIImage(named: asset) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [Color(red: 0.28, green: 0.05, blue: 0.07), Color(red: 0.08, green: 0.08, blue: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct ProfileAvatar: View {
    let profile: Profile
    var size: CGFloat = 112
    var selected: Bool = false
    var rounded: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: profile.colorHex))
            Text(String(profile.name.prefix(1)))
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
        }
        .frame(width: size, height: size)
        .clipShape(rounded ? AnyShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)) : AnyShape(Circle()))
        .overlay(alignment: .bottomTrailing) {
            if profile.isKids {
                Image(systemName: "star.fill")
                    .font(.system(size: size * 0.14))
                    .foregroundStyle(.white)
                    .padding(size * 0.06)
                    .background(Circle().fill(.black.opacity(0.45)))
                    .padding(size * 0.04)
            }
        }
        .overlay {
            Circle()
                .strokeBorder(selected ? Color.white : Color.clear, lineWidth: 3)
        }
        .shadow(color: Color(hex: profile.colorHex).opacity(0.35), radius: selected ? 16 : 0)
    }
}

struct PosterCard: View {
    let title: CatalogTitle
    var width: CGFloat = 116
    var rank: Int? = nil

    private var height: CGFloat { width * 1.5 }

    var body: some View {
        HStack(alignment: .bottom, spacing: rank == nil ? 0 : -18) {
            if let rank {
                RankNumeral(rank: rank)
                    .frame(width: width * 0.62, alignment: .leading)
                    .padding(.bottom, 4)
            }
            CatalogImage(asset: title.posterAsset)
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .bottomLeading) {
                    Text(title.title.text(language))
                        .font(.caption2.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(8)
                        .foregroundStyle(.white)
                }
        }
        .frame(width: rank == nil ? width : width * 1.48, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title.title.text(language))
    }

    @Environment(AppModel.self) private var model
    private var language: AppLanguage { model.language }
}

struct RankNumeral: View {
    let rank: Int

    var body: some View {
        ZStack {
            Text("\(rank)")
                .font(.system(size: 92, weight: .black, design: .default))
                .foregroundStyle(.white)
                .offset(x: 1.4, y: 1.4)
            Text("\(rank)")
                .font(.system(size: 92, weight: .black, design: .default))
                .foregroundStyle(LaylTheme.bg)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .environment(\.layoutDirection, .leftToRight)
    }
}

struct ContinueCard: View {
    let item: ContinueItem
    var width: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottom) {
                CatalogImage(asset: item.episode.stillAsset)
                    .frame(width: width, height: width * 0.56)
                    .clipped()
                ProgressView(value: item.progress.fraction)
                    .tint(LaylTheme.red)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(item.title.title.text(language))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(LaylTheme.muted)
                .lineLimit(1)
        }
        .frame(width: width, alignment: .leading)
    }

    @Environment(AppModel.self) private var model
    private var language: AppLanguage { model.language }

    private var subtitle: String {
        if item.title.kind == .series {
            return language.t(
                "ح\(item.episode.number) · \(item.episode.title.text(language))",
                "E\(item.episode.number) · \(item.episode.title.text(language))"
            )
        }
        let remaining = max(item.progress.duration - item.progress.position, 0)
        return language.t("متبقّي \(Clock.text(remaining))", "\(Clock.text(remaining)) left")
    }
}

struct MediaRail: View {
    let lane: Lane
    var posterWidth: CGFloat = 116

    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(lane.title.text(model.language))
                    .font(.title3.weight(.bold))
                Spacer()
                NavigationLink(value: lane) {
                    Text(model.language.t("عرض الكل", "See all"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LaylTheme.muted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, horizontalPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: layout.posterGap) {
                    let titles = Catalog.titles(ids: lane.titleIDs).filter(model.isVisible)
                    ForEach(Array(titles.enumerated()), id: \.element.id) { index, title in
                        Button {
                            model.detailTitle = title
                        } label: {
                            PosterCard(
                                title: title,
                                width: posterWidth,
                                rank: lane.style == .ranked ? index + 1 : nil
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu { titleMenu(title) }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 4)
            }
        }
    }

    @Environment(\.laylLayout) private var layout
    private var horizontalPadding: CGFloat { layout.contentInset }

    @ViewBuilder
    private func titleMenu(_ title: CatalogTitle) -> some View {
        Button {
            model.play(title: title)
        } label: {
            Label(model.language.t("تشغيل", "Play"), systemImage: "play.fill")
        }
        Button {
            model.toggleSaved(title.id)
        } label: {
            Label(
                model.isSaved(title.id) ? model.language.t("إزالة من قائمتي", "Remove from My List") : model.language.t("إضافة إلى قائمتي", "Add to My List"),
                systemImage: model.isSaved(title.id) ? "checkmark" : "plus"
            )
        }
    }
}

struct PlayPill: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .environment(\.layoutDirection, .leftToRight)
                Text(title)
            }
            .font(.headline.weight(.bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(.white, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct RoundIconButton: View {
    let systemName: String
    var filled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.bold))
                .frame(width: 44, height: 44)
                .background(filled ? Color.white.opacity(0.18) : Color.white.opacity(0.12), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}

struct MetaPills: View {
    let title: CatalogTitle

    @Environment(AppModel.self) private var model

    var body: some View {
        let language = model.language
        HStack(spacing: 8) {
            Text(String(title.year))
            Text(title.maturity.text(language))
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.white.opacity(0.7), lineWidth: 1))
            Text(length)
            Text("HD")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.white.opacity(0.55), lineWidth: 1))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.9))
    }

    private var length: String {
        let language = model.language
        if title.kind == .series {
            return language.t("موسم ١ · \(title.episodes.count) حلقات", "1 season · \(title.episodes.count) episodes")
        }
        return language.t("\(title.minutes) د", "\(title.minutes)m")
    }
}

struct EmptyState: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(LaylTheme.red)
            Text(title)
                .font(.title3.weight(.bold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(LaylTheme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

struct BrandLockup: View {
    var mark: CGFloat = 36

    var body: some View {
        HStack(spacing: 8) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: mark, height: mark)
                .clipShape(RoundedRectangle(cornerRadius: mark * 0.22, style: .continuous))
            Text("ليل")
                .font(.system(size: mark * 0.72, weight: .heavy))
                .foregroundStyle(LaylTheme.red)
                .tracking(0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Layl")
    }
}
