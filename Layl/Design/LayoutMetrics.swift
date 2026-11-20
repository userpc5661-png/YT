import SwiftUI

/// Portrait width classes from iPhone SE (320) through 17 Pro Max (440) and iPad.
enum LaylPhoneClass: String, Codable {
    case se
    case compact
    case standard
    case pro
    case proMax
    case pad

    var labelAR: String {
        switch self {
        case .se: return "آيفون SE"
        case .compact: return "آيفون صغير"
        case .standard: return "آيفون عادي"
        case .pro: return "آيفون برو"
        case .proMax: return "آيفون برو ماكس"
        case .pad: return "آيباد"
        }
    }

    var labelEN: String {
        switch self {
        case .se: return "iPhone SE"
        case .compact: return "iPhone mini"
        case .standard: return "iPhone"
        case .pro: return "iPhone Pro"
        case .proMax: return "iPhone Pro Max"
        case .pad: return "iPad"
        }
    }
}

struct LaylLayoutMetrics: Equatable {
    let phoneClass: LaylPhoneClass
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let safeTop: CGFloat
    let safeBottom: CGFloat
    let contentInset: CGFloat
    let heroHeight: CGFloat
    let posterWidth: CGFloat
    let posterHeight: CGFloat
    let gridMinWidth: CGFloat
    let heroTitleSize: CGFloat
    let detailTitleSize: CGFloat
    let continueCardWidth: CGFloat
    let rowSpacing: CGFloat
    let posterGap: CGFloat
    let tabBarHeight: CGFloat
    let avatarSize: CGFloat
    let density: ContentDensity
    let typeScale: CGFloat

    /// 2:3 posters. Sizes are derived from the shorter screen side so rotation does not jump classes.
    static func current(
        width: CGFloat,
        height: CGFloat,
        safeTop: CGFloat,
        safeBottom: CGFloat,
        horizontalSizeClass: UserInterfaceSizeClass?,
        density: ContentDensity = .comfortable,
        dynamicTypeSize: DynamicTypeSize = .large
    ) -> LaylLayoutMetrics {
        let shortSide = min(max(width, 1), max(height, 1))
        let phoneClass = classify(shortSide: shortSide, regular: horizontalSizeClass == .regular)
        let typeScale = typeScale(for: dynamicTypeSize)
        let densityFactor: CGFloat = density == .compact ? 0.9 : 1

        // Share of the short side used by one poster. Clamped so SE still shows two posters
        // and iPad does not grow posters without a limit.
        let posterShare: CGFloat = switch phoneClass {
        case .se: 0.30
        case .compact: 0.30
        case .standard: 0.29
        case .pro: 0.28
        case .proMax: 0.27
        case .pad: 0.16
        }
        let posterWidth = (shortSide * posterShare).clamped(to: 92...176) * densityFactor * min(typeScale, 1.12)
        let posterHeight = posterWidth * 1.5
        let gridMinWidth = phoneClass == .pad ? max(posterWidth, 144) : max(posterWidth, 104)

        let heroRatio: CGFloat = switch phoneClass {
        case .se: 0.92
        case .compact: 0.90
        case .standard: 0.86
        case .pro: 0.84
        case .proMax: 0.80
        case .pad: 0.42
        }
        let heroHeight = (shortSide * heroRatio).clamped(to: 260...460)

        let inset: CGFloat = phoneClass == .pad ? 28 : 16
        let rowSpacing = (shortSide * 0.04).clamped(to: 14...32)
        let posterGap: CGFloat = phoneClass == .pad ? 10 : 8
        let titleSize = (shortSide * 0.092).clamped(to: 28...64) * min(typeScale, 1.2)
        let detailSize = (shortSide * 0.078).clamped(to: 26...52) * min(typeScale, 1.2)
        let continueWidth = (shortSide * (phoneClass == .pad ? 0.28 : 0.56)).clamped(to: 168...320)
        let avatar = (shortSide * (phoneClass == .se ? 0.28 : 0.30)).clamped(to: 88...140)

        return LaylLayoutMetrics(
            phoneClass: phoneClass,
            screenWidth: width,
            screenHeight: height,
            safeTop: safeTop,
            safeBottom: safeBottom,
            contentInset: inset,
            heroHeight: heroHeight,
            posterWidth: posterWidth,
            posterHeight: posterHeight,
            gridMinWidth: gridMinWidth,
            heroTitleSize: titleSize,
            detailTitleSize: detailSize,
            continueCardWidth: continueWidth,
            rowSpacing: rowSpacing,
            posterGap: posterGap,
            tabBarHeight: 54,
            avatarSize: avatar,
            density: density,
            typeScale: typeScale
        )
    }

    static func classify(shortSide: CGFloat, regular: Bool) -> LaylPhoneClass {
        if regular && shortSide >= 700 { return .pad }
        if shortSide < 350 { return .se }          // 320: SE (1st)
        if shortSide < 388 { return .compact }     // 375: SE 2/3, mini
        if shortSide < 400 { return .standard }    // 390–393: 14/15/16
        if shortSide < 420 { return .pro }         // 402: 16/17 Pro
        if shortSide < 700 { return .proMax }      // 428–440: Plus / Pro Max
        return .pad
    }

    static func typeScale(for size: DynamicTypeSize) -> CGFloat {
        switch size {
        case .xSmall: return 0.88
        case .small: return 0.94
        case .medium, .large: return 1
        case .xLarge: return 1.06
        case .xxLarge: return 1.12
        case .xxxLarge: return 1.18
        case .accessibility1: return 1.24
        case .accessibility2: return 1.30
        case .accessibility3: return 1.36
        case .accessibility4: return 1.42
        case .accessibility5: return 1.48
        @unknown default: return 1
        }
    }

    static let fallback = LaylLayoutMetrics.current(
        width: 393,
        height: 852,
        safeTop: 59,
        safeBottom: 34,
        horizontalSizeClass: .compact
    )
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private struct LaylLayoutKey: EnvironmentKey {
    static let defaultValue = LaylLayoutMetrics.fallback
}

extension EnvironmentValues {
    var laylLayout: LaylLayoutMetrics {
        get { self[LaylLayoutKey.self] }
        set { self[LaylLayoutKey.self] = newValue }
    }
}

struct Viewport: Equatable {
    var width: CGFloat
    var height: CGFloat
    var top: CGFloat
    var bottom: CGFloat
}

struct ViewportKey: PreferenceKey {
    static var defaultValue = Viewport(width: 393, height: 852, top: 59, bottom: 34)
    static func reduce(value: inout Viewport, nextValue: () -> Viewport) {
        value = nextValue()
    }
}
