import SwiftUI
import UIKit

enum ArtworkTone {
    static func color(asset: String) -> Color {
        guard let image = UIImage(named: asset), let cgImage = image.cgImage else {
            return Color(red: 0.28, green: 0.08, blue: 0.1)
        }
        let width = 6
        let height = 6
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return Color(red: 0.28, green: 0.08, blue: 0.1)
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        var red = 0
        var green = 0
        var blue = 0
        let count = width * height
        for index in 0..<count {
            red += Int(pixels[index * 4])
            green += Int(pixels[index * 4 + 1])
            blue += Int(pixels[index * 4 + 2])
        }
        return Color(
            red: Double(red) / Double(count) / 255,
            green: Double(green) / Double(count) / 255,
            blue: Double(blue) / Double(count) / 255
        )
    }
}

extension View {
    /// Liquid Glass on iOS 26, frosted material on earlier systems.
    @ViewBuilder
    func laylGlass(in shape: some Shape, interactive: Bool = false) -> some View {
        if #available(iOS 26, *) {
            if interactive {
                self.glassEffect(.regular.interactive(), in: shape)
            } else {
                self.glassEffect(.regular, in: shape)
            }
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    @ViewBuilder
    func laylGlassCircle(interactive: Bool = true) -> some View {
        laylGlass(in: Circle(), interactive: interactive)
    }

    @ViewBuilder
    func laylGlassCapsule(interactive: Bool = true) -> some View {
        laylGlass(in: Capsule(), interactive: interactive)
    }

    @ViewBuilder
    func laylProminentButton() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    func laylGlassButton() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func laylNavigationChrome() -> some View {
        if #available(iOS 26, *) {
            // The system NavigationStack toolbar is already Liquid Glass. A custom
            // toolbar background would replace it with a flat material.
            self.toolbarColorScheme(.dark, for: .navigationBar)
        } else {
            self
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    @ViewBuilder
    func laylGlassSheet() -> some View {
        if #available(iOS 26, *) {
            self.presentationDragIndicator(.visible)
        } else {
            self
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
    }

    /// Keeps a horizontal rail or page from adopting a child's ideal width.
    func laylHugsWidth() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LaylChipGlass: ViewModifier {
    var active: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *), active {
            content.glassEffect(.regular.interactive(), in: Capsule())
        } else if active {
            content.background(.ultraThinMaterial, in: Capsule())
        } else {
            content
        }
    }
}

struct LaylGlassGroup<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

struct LaylTabChrome: ViewModifier {
    var regular: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if regular {
                content
                    .tabViewStyle(.sidebarAdaptable)
                    .tabBarMinimizeBehavior(.onScrollDown)
            } else {
                content.tabBarMinimizeBehavior(.onScrollDown)
            }
        } else if #available(iOS 18, *), regular {
            content.tabViewStyle(.sidebarAdaptable)
        } else {
            content
        }
    }
}