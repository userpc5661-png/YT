import SwiftUI

/// Layout checks for SE through Pro Max and iPad. These previews do not run in CI; they document the math.
struct LayoutSpecGallery: View {
    private let samples: [(String, CGFloat, CGFloat, UserInterfaceSizeClass)] = [
        ("SE 320", 320, 568, .compact),
        ("SE 375", 375, 667, .compact),
        ("15 393", 393, 852, .compact),
        ("Pro 402", 402, 874, .compact),
        ("Max 430", 430, 932, .compact),
        ("17 Max 440", 440, 956, .compact),
        ("iPad 768", 768, 1024, .regular)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(samples, id: \.0) { sample in
                    let metrics = LaylLayoutMetrics.current(
                        width: sample.1,
                        height: sample.2,
                        safeTop: sample.1 < 360 ? 20 : 59,
                        safeBottom: sample.1 < 360 ? 0 : 34,
                        horizontalSizeClass: sample.3
                    )
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(sample.0) · \(metrics.phoneClass.rawValue)")
                            .font(.headline)
                        Text(String(format: "inset %.0f  hero %.0f  poster %.0f×%.0f  gap %.0f  title %.0f",
                                    metrics.contentInset,
                                    metrics.heroHeight,
                                    metrics.posterWidth,
                                    metrics.posterHeight,
                                    metrics.posterGap,
                                    metrics.heroTitleSize))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        HStack(spacing: metrics.posterGap) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.16))
                                    .frame(width: metrics.posterWidth, height: metrics.posterHeight)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.black)
    }
}

#Preview("SE") {
    LayoutSpecGallery()
        .environment(AppModel())
        .preferredColorScheme(.dark)
}

#Preview("Widths") {
    LayoutSpecGallery()
}