import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.laylLayout) private var layout
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey: String = ""
    @State private var provider: StreamingAPIProvider = .movieOfTheNight
    @State private var country: String = "sa"
    @State private var density: ContentDensity = .comfortable
    @State private var heroCarousel = true
    @State private var services: Set<String> = []

    var body: some View {
        Form {
            SwiftUI.Section {
                Text(model.language.t(
                    "اربط التطبيق بـ Streaming Availability API لاكتشاف الأفلام والمسلسلات ومعرفة أين تُعرض على نتفليكس وديزني+ وغيرها.",
                    "Connect to the Streaming Availability API to discover titles and see where they stream on Netflix, Disney+, and more."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
                Link(
                    model.language.t("التسجيل المجاني للمفتاح", "Get a free API key"),
                    destination: URL(string: "https://developers.movieofthenight.com/")!
                )
            } header: {
                Text(model.language.t("واجهة البث", "Streaming API"))
            }

            SwiftUI.Section {
                SecureField(model.language.t("مفتاح API", "API key"), text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Picker(model.language.t("المزود", "Provider"), selection: $provider) {
                    ForEach(StreamingAPIProvider.allCases) { item in
                        Text(item.title(model.language)).tag(item)
                    }
                }
                Picker(model.language.t("الدولة", "Country"), selection: $country) {
                    ForEach(StreamingCountry.supported) { item in
                        Text(item.name(model.language)).tag(item.code)
                    }
                }
            }

            SwiftUI.Section {
                Picker(model.language.t("كثافة الشاشة", "Screen density"), selection: $density) {
                    ForEach(ContentDensity.allCases) { item in
                        Text(item.title(model.language)).tag(item)
                    }
                }
                Toggle(model.language.t("بانر متحرك في الرئيسية", "Animated home hero"), isOn: $heroCarousel)

                Text(model.language.t("الجهاز: ", "Device: ") + layout.phoneClass.label(model.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(model.language.t("المظهر والمقاس", "Layout"))
            }

            SwiftUI.Section {
                ForEach(StreamingServiceChip.featured) { service in
                    Toggle(isOn: Binding(
                        get: { services.contains(service.id) },
                        set: { on in
                            if on { services.insert(service.id) } else { services.remove(service.id) }
                        }
                    )) {
                        Text(service.title(model.language))
                    }
                }
            } header: {
                Text(model.language.t("خدمات البث المفضلة", "Preferred services"))
            }

            SwiftUI.Section {
                Button(model.language.t("حفظ", "Save")) {
                    model.updatePreferences(
                        apiKey: apiKey,
                        provider: provider,
                        country: country,
                        density: density,
                        heroCarousel: heroCarousel,
                        services: services
                    )
                    dismiss()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .scrollContentBackground(.hidden)
        .background(LaylTheme.bg)
        .navigationTitle(model.language.t("الإعدادات", "Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .laylNavigationChrome()
        .onAppear {
            apiKey = model.apiKey
            provider = model.apiProvider
            country = model.streamCountry
            density = model.contentDensity
            heroCarousel = model.heroCarouselEnabled
            services = model.preferredStreamingServices.isEmpty
                ? Set(StreamingServiceChip.featured.map(\.id))
                : model.preferredStreamingServices
        }
    }
}

extension LaylPhoneClass {
    func label(_ language: AppLanguage) -> String {
        language == .arabic ? labelAR : labelEN
    }
}