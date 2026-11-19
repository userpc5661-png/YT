import SwiftUI

enum BrowseMode: Hashable {
    case movies
    case series
    case all
}

struct BrowseView: View {
    var mode: BrowseMode

    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var genre: Genre?

    var body: some View {
        let titles = results
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                genreChips
                if titles.isEmpty {
                    EmptyState(
                        systemImage: "film",
                        title: model.language.t("لا توجد عناوين", "No titles"),
                        message: model.language.t("جرّب تصنيفًا آخر.", "Try another genre.")
                    )
                } else {
                    posterGrid(titles)
                }
            }
            .padding(.bottom, 24)
        }
        .laylScreen()
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .laylNavigationChrome()
    }

    private var navigationTitle: String {
        switch mode {
        case .movies: return model.language.t("أفلام", "Movies")
        case .series: return model.language.t("مسلسلات", "Series")
        case .all: return model.language.t("تصفح", "Browse")
        }
    }

    private var results: [CatalogTitle] {
        let kind: TitleKind? = switch mode {
        case .movies: .movie
        case .series: .series
        case .all: nil
        }
        return Catalog.results(query: "", genre: genre, kind: kind, kidsOnly: model.kidsOnly)
    }

    private var genreChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(nil, model.language.t("الكل", "All"))
                ForEach(usedGenres) { item in
                    chip(item, item.title(model.language))
                }
            }
            .padding(.horizontal, sideInset)
        }
    }

    private var usedGenres: [Genre] {
        let pool = Catalog.all.filter { title in
            if model.kidsOnly && !title.kids { return false }
            switch mode {
            case .movies: return title.kind == .movie
            case .series: return title.kind == .series
            case .all: return true
            }
        }
        let present = Set(pool.flatMap(\.genres))
        return Genre.allCases.filter { present.contains($0) }
    }

    private func chip(_ value: Genre?, _ label: String) -> some View {
        let selected = genre == value
        return Button {
            genre = value
        } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Color.white : Color.white.opacity(0.08), in: Capsule())
                .foregroundStyle(selected ? Color.black : Color.white)
        }
        .buttonStyle(.plain)
    }

    private func posterGrid(_ titles: [CatalogTitle]) -> some View {
        let minWidth: CGFloat = sizeClass == .regular ? 150 : 108
        let columns = [GridItem(.adaptive(minimum: minWidth), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(titles) { title in
                NavigationLink(value: title) {
                    PosterCard(title: title, width: minWidth)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, sideInset)
    }

    private var sideInset: CGFloat { sizeClass == .regular ? 28 : 16 }
}

struct LaneGridView: View {
    let lane: Lane

    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let titles = Catalog.titles(ids: lane.titleIDs).filter(model.isVisible)
        ScrollView {
            posterGrid(titles)
                .padding(.vertical, 16)
        }
        .laylScreen()
        .navigationTitle(lane.title.text(model.language))
        .navigationBarTitleDisplayMode(.inline)
        .laylNavigationChrome()
    }

    private func posterGrid(_ titles: [CatalogTitle]) -> some View {
        let minWidth: CGFloat = sizeClass == .regular ? 150 : 108
        let columns = [GridItem(.adaptive(minimum: minWidth), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Array(titles.enumerated()), id: \.element.id) { index, title in
                NavigationLink(value: title) {
                    PosterCard(title: title, width: minWidth, rank: lane.style == .ranked ? index + 1 : nil)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, sizeClass == .regular ? 28 : 16)
    }
}

struct SearchView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var query = ""
    @State private var genre: Genre?

    var body: some View {
        let titles = Catalog.results(query: query, genre: genre, kind: nil, kidsOnly: model.kidsOnly)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(LaylTheme.muted)
                    TextField(model.language.t("ابحث عن فيلم أو مسلسل", "Search movies and series"), text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(LaylTheme.muted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, sideInset)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        genreChip(nil, model.language.t("كل التصنيفات", "All genres"))
                        ForEach(Genre.allCases) { item in
                            genreChip(item, item.title(model.language))
                        }
                    }
                    .padding(.horizontal, sideInset)
                }

                if titles.isEmpty {
                    EmptyState(
                        systemImage: "magnifyingglass",
                        title: model.language.t("لا توجد نتائج", "No results"),
                        message: model.language.t("جرّب اسمًا آخر أو تصنيفًا مختلفًا.", "Try another title or genre.")
                    )
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: sizeClass == .regular ? 150 : 108), spacing: 12)], spacing: 16) {
                        ForEach(titles) { title in
                            NavigationLink(value: title) {
                                PosterCard(title: title, width: sizeClass == .regular ? 150 : 108)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, sideInset)
                }
            }
            .padding(.vertical, 12)
        }
        .laylScreen()
        .navigationTitle(model.language.t("بحث", "Search"))
        .navigationBarTitleDisplayMode(.inline)
        .laylNavigationChrome()
    }

    private var sideInset: CGFloat { sizeClass == .regular ? 28 : 16 }

    private func genreChip(_ value: Genre?, _ label: String) -> some View {
        let selected = genre == value
        return Button {
            genre = value
        } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Color.white : Color.white.opacity(0.08), in: Capsule())
                .foregroundStyle(selected ? Color.black : Color.white)
        }
        .buttonStyle(.plain)
    }
}

struct MyListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let titles = model.myList()
        ScrollView {
            if titles.isEmpty {
                EmptyState(
                    systemImage: "plus.rectangle.on.rectangle",
                    title: model.language.t("قائمتك فارغة", "Your list is empty"),
                    message: model.language.t("أضف فيلمًا من الصفحة الرئيسية أو من صفحة العمل.", "Add a title from Home or from its details page.")
                )
                .padding(.top, 48)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: sizeClass == .regular ? 150 : 108), spacing: 12)], spacing: 16) {
                    ForEach(titles) { title in
                        NavigationLink(value: title) {
                            PosterCard(title: title, width: sizeClass == .regular ? 150 : 108)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                model.toggleSaved(title.id)
                            } label: {
                                Label(model.language.t("إزالة", "Remove"), systemImage: "minus.circle")
                            }
                        }
                    }
                }
                .padding(sizeClass == .regular ? 28 : 16)
            }
        }
        .laylScreen()
        .navigationTitle(model.language.t("قائمتي", "My List"))
        .navigationBarTitleDisplayMode(.large)
        .laylNavigationChrome()
    }
}

struct LicensesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            SwiftUI.Section {
                Text(model.language.t(
                    "ليل يعرض أفلامًا مفتوحة من مؤسسة بلندر وأفلامًا كلاسيكية في الملك العام. لا نملك هذه الأعمال، ونعرضها مع ذكر المصدر والترخيص. التشغيل يتم مباشرة من أرشيف الإنترنت.",
                    "Layl plays Blender Foundation open movies and public-domain classics. We do not own these films. Each title is shown with its source and license, and streams directly from the Internet Archive."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .listRowBackground(LaylTheme.elevated)
            }
            SwiftUI.Section(model.language.t("الأعمال", "Titles")) {
                ForEach(Catalog.all) { title in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title.title.text(model.language))
                            .font(.headline)
                        Text(title.credit.text(model.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(title.rights)
                            .font(.caption.weight(.semibold))
                        if let rightsURL = URL(string: title.rightsURL) {
                            Link(model.language.t("نص الترخيص", "License text"), destination: rightsURL)
                                .font(.caption)
                        }
                        if let archive = URL(string: title.archivePage) {
                            Link(model.language.t("المصدر على أرشيف الإنترنت", "Internet Archive source"), destination: archive)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(LaylTheme.elevated)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(LaylTheme.bg)
        .navigationTitle(model.language.t("الحقوق والمصادر", "Rights and sources"))
        .navigationBarTitleDisplayMode(.inline)
        .laylNavigationChrome()
    }
}
