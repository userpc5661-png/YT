import SwiftUI

struct AccountView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.laylLayout) private var layout

    var body: some View {
        List {
            if let profile = model.activeProfile {
                SwiftUI.Section {
                    HStack(spacing: 14) {
                        ProfileAvatar(profile: profile, size: 64, rounded: true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name).font(.title3.weight(.bold))
                            Text(layout.phoneClass.label(model.language))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button(model.language.t("تبديل الملف", "Switch profile")) {
                        model.leaveProfile()
                    }
                }
            }
            SwiftUI.Section {
                NavigationLink(model.language.t("مصادر الأفلام والمسلسلات", "Movie and series sources")) {
                    SourceListView()
                }
                NavigationLink(model.language.t("الإعدادات", "Settings")) {
                    SettingsView()
                }
                NavigationLink(model.language.t("أفلام", "Movies")) {
                    BrowseView(mode: .movies)
                }
                NavigationLink(model.language.t("مسلسلات", "Series")) {
                    BrowseView(mode: .series)
                }
            }
            SwiftUI.Section {
                Button(model.language == .arabic ? "English" : "العربية") {
                    model.toggleLanguage()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle(model.language.t("حسابي", "Account"))
        .laylNavigationChrome()
    }
}

struct SourceListView: View {
    @Environment(AppModel.self) private var model
    @State private var editor: ContentSource?

    var body: some View {
        List {
            SwiftUI.Section {
                Text(model.language.t(
                    "أضف واجهة عامة: العنوان، المسارات، والمفتاح يُحفظ في سلسلة المفاتيح. القوالب الجاهزة لبيانات TMDB وStreaming Availability فقط.",
                    "Add a generic API: base URL, paths, and a key kept in the Keychain. Built-in presets are TMDB metadata and Streaming Availability only."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            SwiftUI.Section {
                Button(model.language.t("قالب TMDB", "TMDB preset")) {
                    editor = SourcePresets.tmdb()
                }
                Button(model.language.t("قالب توفر البث", "Streaming Availability preset")) {
                    editor = SourcePresets.streamingAvailability()
                }
                Button(model.language.t("مصدر فارغ", "Blank source")) {
                    editor = ContentSource(
                        id: UUID(),
                        name: "",
                        enabled: true,
                        baseURL: "https://",
                        moviesPath: "/movies",
                        seriesPath: "/series",
                        searchPath: "/search?q={query}",
                        episodesPath: "",
                        authKind: .none,
                        authName: "X-API-Key",
                        pageStyle: .none,
                        pageParameter: "page",
                        pageStart: 1,
                        map: .empty
                    )
                }
            }
            SwiftUI.Section {
                ForEach(model.sources) { source in
                    Button(source.name) { editor = source }
                        .foregroundStyle(.white)
                }
                .onDelete { indexSet in
                    indexSet.map { model.sources[$0] }.forEach(model.deleteSource)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle(model.language.t("المصادر", "Sources"))
        .laylNavigationChrome()
        .sheet(item: $editor) { source in
            SourceEditorView(source: source)
        }
    }
}

struct SourceEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State var source: ContentSource
    @State private var secret = ""
    @State private var testing = false
    @State private var preview: [RemoteTitle] = []
    @State private var testMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section(model.language.t("الأساس", "Basics")) {
                    TextField(model.language.t("الاسم", "Name"), text: $source.name)
                    TextField(model.language.t("رابط الأساس", "Base URL"), text: $source.baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle(model.language.t("مفعّل", "Enabled"), isOn: $source.enabled)
                }
                SwiftUI.Section(model.language.t("المسارات", "Endpoints")) {
                    TextField(model.language.t("أفلام", "Movies"), text: $source.moviesPath)
                    TextField(model.language.t("مسلسلات", "Series"), text: $source.seriesPath)
                    TextField(model.language.t("بحث {query}", "Search {query}"), text: $source.searchPath)
                    TextField(model.language.t("حلقات {id}", "Episodes {id}"), text: $source.episodesPath)
                }
                SwiftUI.Section(model.language.t("الدخول", "Auth")) {
                    Picker(model.language.t("النوع", "Type"), selection: $source.authKind) {
                        ForEach(SourceAuthKind.allCases) { kind in
                            Text(kind.title(model.language)).tag(kind)
                        }
                    }
                    if source.authKind == .header || source.authKind == .query {
                        TextField(model.language.t("اسم الحقل", "Field name"), text: $source.authName)
                    }
                    SecureField(model.language.t("المفتاح", "Secret"), text: $secret)
                }
                SwiftUI.Section(model.language.t("الصفحات", "Paging")) {
                    Picker(model.language.t("الأسلوب", "Style"), selection: $source.pageStyle) {
                        ForEach(SourcePageStyle.allCases) { style in
                            Text(style.title(model.language)).tag(style)
                        }
                    }
                    TextField(model.language.t("اسم المعامل", "Parameter"), text: $source.pageParameter)
                }
                SwiftUI.Section(model.language.t("مسارات JSON", "JSON paths")) {
                    mapField(model.language.t("العناصر", "Items"), $source.map.items)
                    mapField(model.language.t("المعرّف", "ID"), $source.map.id)
                    mapField(model.language.t("العنوان", "Title"), $source.map.title)
                    mapField(model.language.t("القصة", "Overview"), $source.map.overview)
                    mapField(model.language.t("الملصق", "Poster"), $source.map.poster)
                    mapField(model.language.t("الخلفية", "Backdrop"), $source.map.backdrop)
                    mapField(model.language.t("السنة", "Year"), $source.map.year)
                    mapField(model.language.t("التصنيفات", "Genres"), $source.map.genres)
                    mapField(model.language.t("التقييم", "Rating"), $source.map.rating)
                    mapField(model.language.t("رابط الفيديو", "Stream URL"), $source.map.stream)
                    mapField(model.language.t("الحلقات", "Episodes"), $source.map.episodes)
                    mapField(model.language.t("عنوان الحلقة", "Episode title"), $source.map.episodeTitle)
                    mapField(model.language.t("فيديو الحلقة", "Episode stream"), $source.map.episodeStream)
                    mapField(model.language.t("بادئة الصور", "Image prefix"), $source.map.imagePrefix)
                }
                SwiftUI.Section {
                    Button(testing ? model.language.t("جارٍ الاختبار…", "Testing…") : model.language.t("اختبار الاتصال", "Test connection")) {
                        test()
                    }
                    .disabled(testing)
                    if !testMessage.isEmpty {
                        Text(testMessage).font(.footnote)
                    }
                    ForEach(preview.prefix(8)) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.subheadline.weight(.semibold))
                            Text(item.overview).font(.caption).lineLimit(2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle(model.language.t("مصدر", "Source"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.language.t("إلغاء", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.language.t("حفظ", "Save")) {
                        model.upsert(source, secret: secret)
                        model.reloadSourceRails()
                        dismiss()
                    }
                    .disabled(source.name.trimmingCharacters(in: .whitespaces).isEmpty || source.baseURL.isEmpty)
                }
            }
            .onAppear {
                secret = KeychainStore.get(account: source.id.uuidString) ?? ""
            }
        }
        .preferredColorScheme(.dark)
    }

    private func mapField(_ label: String, _ text: Binding<String>) -> some View {
        TextField(label, text: text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }

    private func test() {
        testing = true
        testMessage = ""
        preview = []
        let draft = source
        let typed = secret
        Task {
            if !typed.isEmpty {
                KeychainStore.set(typed, account: draft.id.uuidString)
            }
            do {
                let items = try await SourceClient.load(draft, feed: .movies)
                await MainActor.run {
                    preview = items
                    testing = false
                    testMessage = model.language.t("تم قراءة \(items.count) عنصرًا.", "Parsed \(items.count) items.")
                }
            } catch {
                await MainActor.run {
                    testing = false
                    testMessage = error.localizedDescription
                }
            }
        }
    }
}