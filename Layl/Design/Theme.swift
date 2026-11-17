import SwiftUI

enum LaylTheme {
    static let bg = Color(red: 0.071, green: 0.071, blue: 0.071)
    static let elevated = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let red = Color(red: 0.898, green: 0.035, blue: 0.078)
    static let match = Color(red: 0.275, green: 0.827, blue: 0.412)
    static let muted = Color.white.opacity(0.68)
}

extension Color {
    init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.replacingOccurrences(of: "#", with: "")
        var parsed: UInt64 = 0
        Scanner(string: value).scanHexInt64(&parsed)
        let red = Double((parsed >> 16) & 0xFF) / 255
        let green = Double((parsed >> 8) & 0xFF) / 255
        let blue = Double(parsed & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

extension View {
    func laylScreen() -> some View {
        background(LaylTheme.bg.ignoresSafeArea())
    }

    func laylNavigationChrome() -> some View {
        self
            .toolbarBackground(LaylTheme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar(.visible, for: .navigationBar)
    }

    func laylDestinations() -> some View {
        navigationDestination(for: CatalogTitle.self) { title in
            TitleDetailView(title: title)
        }
        .navigationDestination(for: Lane.self) { lane in
            LaneGridView(lane: lane)
        }
    }
}
