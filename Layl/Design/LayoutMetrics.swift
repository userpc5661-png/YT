import SwiftUI
import UIKit

/// Width buckets tuned for iPhone 13 mini through iPhone 17 Pro Max (logical points).
enum LaylPhoneClass: String, Codable {
    case mini
    case standard
    case pro
    case proMax
    case pad

    var labelAR: String {
        switch self {
        case .mini: return "آيفون صغير"
        case .standard: return "آيفون عادي"
        case .pro: return "آيفون برو"
        case .proMax: return "آيفون برو ماكس"
        case .pad: return "آيباد"
        }
    }

    var labelEN: String {
        switch self {
        case .mini: return "iPhone compact"
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
    let safeTop: CGFloat
    let safeBottom: CGFloat
    let contentInset: CGFloat
    let heroHeight: CGFloat
    let posterWidth: CGFloat
    let gridMinWidth: CGFloat
    let heroTitleSize: CGFloat
    let detailTitleSize: CGFloat
    let continueCardWidth: CGFloat
    let density: ContentDensity

    static func current(
        horizontalSizeClass: UserInterfaceSizeClass?,
        density: ContentDensity = .comfortable
    ) -> LaylLayoutMetrics {
        let bounds = UIScreen.main.bounds
        let width = min(bounds.width, bounds.height)
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        let safe = window?.safeAreaInsets ?? .zero

        let phoneClass: LaylPhoneClass
        if horizontalSizeClass == .regular {
            phoneClass = .pad
        } else if width >= 428 {
            phoneClass = .proMax
        } else if width >= 402 {
            phoneClass = .pro
        } else if width >= 390 {
            phoneClass = .standard
        } else {
            phoneClass = .mini
        }

        let baseInset: CGFloat = switch phoneClass {
        case .mini: 14
        case .standard: 16
        case .pro: 18
        case .proMax: 20
        case .pad: 28
        }

        let densityFactor: CGFloat = density == .compact ? 0.9 : 1.0

        let poster: CGFloat = switch phoneClass {
        case .mini: 104
        case .standard: 114
        case .pro: 118
        case .proMax: 124
        case .pad: 152
        }

        let hero: CGFloat = switch phoneClass {
        case .mini: 420
        case .standard: 460
        case .pro: 478
        case .proMax: 502
        case .pad: 560
        }

        let heroTitle: CGFloat = switch phoneClass {
        case .mini: 32
        case .standard: 36
        case .pro: 38
        case .proMax: 40
        case .pad: 56
        }

        let detailTitle: CGFloat = switch phoneClass {
        case .mini: 30
        case .standard: 34
        case .pro: 36
        case .proMax: 38
        case .pad: 48
        }

        let continueW: CGFloat = switch phoneClass {
        case .mini: 196
        case .standard: 214
        case .pro: 224
        case .proMax: 236
        case .pad: 260
        }

        return LaylLayoutMetrics(
            phoneClass: phoneClass,
            screenWidth: width,
            safeTop: safe.top,
            safeBottom: safe.bottom,
            contentInset: baseInset,
            heroHeight: hero,
            posterWidth: poster * densityFactor,
            gridMinWidth: (poster - 6) * densityFactor,
            heroTitleSize: heroTitle,
            detailTitleSize: detailTitle,
            continueCardWidth: continueW,
            density: density
        )
    }
}

private struct LaylLayoutKey: EnvironmentKey {
    static let defaultValue = LaylLayoutMetrics.current(horizontalSizeClass: .compact)
}

extension EnvironmentValues {
    var laylLayout: LaylLayoutMetrics {
        get { self[LaylLayoutKey.self] }
        set { self[LaylLayoutKey.self] = newValue }
    }
}