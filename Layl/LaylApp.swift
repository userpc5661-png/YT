import SwiftUI

@main
struct LaylApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(LaylTheme.red)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        GeometryReader { proxy in
            Group {
                if model.activeProfile == nil {
                    ProfilePickerView()
                } else {
                    MainShell()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .environment(\.layoutDirection, model.language == .arabic ? .rightToLeft : .leftToRight)
            .environment(\.locale, Locale(identifier: model.language == .arabic ? "ar_SA" : "en_US"))
            .environment(
                \.laylLayout,
                LaylLayoutMetrics.current(
                    width: proxy.size.width,
                    height: proxy.size.height,
                    safeTop: proxy.safeAreaInsets.top,
                    safeBottom: proxy.safeAreaInsets.bottom,
                    horizontalSizeClass: sizeClass,
                    density: model.contentDensity,
                    dynamicTypeSize: dynamicType
                )
            )
        }
    }
}
