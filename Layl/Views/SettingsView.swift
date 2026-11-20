import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.laylLayout) private var layout
    @Environment(\.dismiss) private var dismiss

    @State private var tmdbToken = ""
    @State private var density: ContentDensity = .comfortable
    @State private var heroCarousel = true

    var body: some View {
        Form {
            SwiftUI.Section {
                Text(model.language.t(
                    "أضف رمز TMDB المجاني لاستكشاف الأفلام والمسلسلات والأنمي. البيانات والصور فقط؛ الرمز لا يفتح بث الفيديو.",
                    "Add a free TMDB token to explore films, series, and anime. It provides data and artwork only, not video streams."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
                Link(
                    model.language.t("إنشاء الرمز المجاني من TMDB", "Get a free TMDB token"),
                    destination: URL(string: "https://www.themoviedb.org/settings/api")!
                )
                SecureField(model.language.t("API Read Access Token", "API Read Access Token"), text: $tmdbToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Text(model.language.t(
                    "يُحفظ الرمز في Keychain على هذا الجهاز. الاستخدام المجاني مخصص للمشاريع غير التجارية.",
                    "The token is stored in this device's Keychain. Free use is for non-commercial projects."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            } header: {
                Text("TMDB · API")
            }

            SwiftUI.Section {
                Picker(model.language.t("كثافة الشاشة", "Screen density"), selection: $density) {
                    ForEach(ContentDensity.allCases) { item in
                        Text(item.title(model.language)).tag(item)
                    }
                }
                Toggle(model.language.t("بانر متحرك في الرئيسية", "Animated home hero"), isOn: $heroCarousel)
                Text(model.language.t("فئة الجهاز: ", "Device size: ") + layout.phoneClass.label(model.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(model.language.t("المظهر والمقاس", "Appearance and layout"))
            }

            SwiftUI.Section(model.language.t("مصادر إضافية", "Additional sources")) {
                NavigationLink(model.language.t("مصادر الأفلام والمسلسلات", "Movie and series sources")) {
                    SourceListView()
                }
            }

            SwiftUI.Section(model.language.t("نسبة المصدر", "Attribution")) {
                TMDBAttributionFooter()
                    .listRowBackground(Color.clear)
            }

            SwiftUI.Section {
                Button(model.language.t("حفظ", "Save")) {
                    model.tmdb.updateAccessToken(tmdbToken)
                    model.updatePreferences(density: density, heroCarousel: heroCarousel)
                    if model.tmdb.isConfigured {
                        model.tmdb.loadHomeCatalog(language: model.tmdbLanguage, forceRefresh: true)
                    }
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
            tmdbToken = model.tmdb.accessToken
            density = model.contentDensity
            heroCarousel = model.heroCarouselEnabled
        }
    }
}

extension LaylPhoneClass {
    func label(_ language: AppLanguage) -> String {
        language == .arabic ? labelAR : labelEN
    }
}
