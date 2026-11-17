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

    var body: some View {
        Group {
            if model.activeProfile == nil {
                ProfilePickerView()
            } else {
                MainShell()
            }
        }
        .environment(\.layoutDirection, model.language == .arabic ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: model.language == .arabic ? "ar_SA" : "en_US"))
    }
}
