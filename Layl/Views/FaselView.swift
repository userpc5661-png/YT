import SwiftUI

enum FaselKind: String, CaseIterable, Identifiable {
    case all = ""
    case movie
    case series
    case anime
    case asian

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .all: return language.t("الكل", "All")
        case .movie: return language.t("أفلام", "Movies")
        case .series: return language.t("مسلسلات", "Series")
        case .anime: return language.t("أنمي", "Anime")
        case .asian: return language.t("آسيوي", "Asian")
        }
    }
}

struct FaselView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.laylLayout) private var layout
    @StateObject private var client = FaselClient.shared

    @State private var query = ""
    @State private var kind: FaselKind = .all
    @State private var hostDraft = FaselConfig.host
    @State private var editingHost = false
    @State private var resolving: FaselItem?
    @State private var alertMessage: String?
    @State private var searchTask: Task<Void, Never>?

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: layout.gridMinWidth), spacing: layout.posterGap)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layout.rowSpacing) {
                kindChips
                content
            }
            .padding(.horizontal, layout.contentInset)
            .padding(.bottom, layout.tabBarHeight + 24)
        }
        .scrollIndicators(.hidden)
        .laylScreen()
        .navigationTitle("FaselHD")
        .navigationBarTitleDisplayMode(.inline)
        .laylNavigationChrome()
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(model.language.t("ابحث في FaselHD", "Search FaselHD"))
        )
        .onSubmit(of: .search) { reload() }
        .onChange(of: query) { _, _ in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                await load(append: false)
            }
        }
        .onChange(of: kind) { _, _ in reload() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    hostDraft = FaselConfig.host
                    editingHost = true
                } label: {
                    Image(systemName: "server.rack")
                }
                .accessibilityLabel(model.language.t("عنوان السيرفر", "Server address"))
            }
        }
        .sheet(isPresented: $editingHost) { hostSheet }
        .overlay { resolvingOverlay }
        .alert(
            "FaselHD",
            isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })
        ) {
            Button("OK") { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
        .task {
            if client.items.isEmpty { await load(append: false) }
        }
    }

    private var kindChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FaselKind.allCases) { option in
                    let selected = option == kind
                    Button {
                        kind = option
                    } label: {
                        Text(option.title(model.language))
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                selected ? LaylTheme.red : Color.white.opacity(0.12),
                                in: Capsule()
                            )
                            .foregroundStyle(selected ? Color.white : LaylTheme.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if client.items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if client.loading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else if let error = client.error {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(LaylTheme.muted)
                    HStack(spacing: 12) {
                        Button(model.language.t("إعادة المحاولة", "Retry")) {
                            reload()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(LaylTheme.red)
                        Button(model.language.t("عنوان السيرفر", "Server address")) {
                            hostDraft = FaselConfig.host
                            editingHost = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }
                } else {
                    Text(model.language.t("لا توجد عناصر.", "No items."))
                        .font(.subheadline)
                        .foregroundStyle(LaylTheme.muted)
                        .padding(.vertical, 40)
                }
            }
            .padding(.vertical, 8)
        } else {
            LazyVGrid(columns: columns, spacing: layout.posterGap + 12) {
                ForEach(client.items) { item in
                    Button {
                        play(item)
                    } label: {
                        FaselCard(item: item, width: layout.posterWidth)
                    }
                    .buttonStyle(.plain)
                    .onAppear { loadMoreIfNeeded(after: item) }
                }
            }
            if client.loading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
            } else if client.currentPage >= client.totalPages, client.total > 0 {
                Text(model.language.t("\(client.total) عنصرًا", "\(client.total) items"))
                    .font(.caption)
                    .foregroundStyle(LaylTheme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
        }
    }

    @ViewBuilder
    private var resolvingOverlay: some View {
        if let item = resolving {
            ZStack {
                Color.black.opacity(0.65).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.3)
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(model.language.t("جارٍ تجهيز البث…", "Preparing the stream…"))
                        .font(.caption)
                        .foregroundStyle(LaylTheme.muted)
                }
                .padding(22)
                .frame(maxWidth: 260)
                .background(LaylTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var hostSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("192.168.1.5", text: $hostDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.numbersAndPunctuation)
                } header: {
                    Text(model.language.t("عنوان جهاز السيرفر", "Server host"))
                } footer: {
                    Text(model.language.t(
                        "العنوان الذي يطبعه faselhd_server_v2.py عند التشغيل، والجهاز على نفس الشبكة.",
                        "The address faselhd_server_v2.py prints at startup, on the same network."
                    ))
                }
            }
            .navigationTitle("FaselHD")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.language.t("إلغاء", "Cancel")) { editingHost = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.language.t("حفظ", "Save")) {
                        let trimmed = hostDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { FaselConfig.host = trimmed }
                        editingHost = false
                        reload()
                    }
                    .disabled(hostDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    private func reload() {
        Task { await load(append: false) }
    }

    private func load(append: Bool) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        await client.load(
            type: kind.rawValue,
            query: trimmed,
            page: append ? client.currentPage + 1 : 1,
            appending: append
        )
    }

    private func loadMoreIfNeeded(after item: FaselItem) {
        guard !client.loading,
              client.currentPage < client.totalPages,
              client.items.last?.id == item.id
        else { return }
        Task { await load(append: true) }
    }

    private func play(_ item: FaselItem) {
        guard resolving == nil else { return }
        resolving = item
        client.prefetch(item)
        Task {
            let url = await client.resolveStream(item)
            resolving = nil
            if let url {
                model.remotePlay = RemotePlayback(url: url, title: item.title)
            } else {
                alertMessage = model.language.t(
                    "تعذّر تجهيز رابط البث لهذا العنصر.",
                    "Could not resolve the stream for this item."
                )
            }
        }
    }
}

struct FaselCard: View {
    let item: FaselItem
    var width: CGFloat

    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemotePosterImage(urlString: item.imageURL?.absoluteString, width: width)
                .overlay(alignment: .bottomLeading) {
                    Text(item.title)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(2)
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .overlay(alignment: .topTrailing) {
                    Text(kindLabel)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.6), in: Capsule())
                        .padding(5)
                }
            HStack(spacing: 4) {
                if !item.year.isEmpty {
                    Text(item.year)
                }
                Text(kindLabel)
                Spacer(minLength: 0)
            }
            .font(.caption2)
            .foregroundStyle(LaylTheme.muted)
            .lineLimit(1)
        }
        .frame(width: width)
        .accessibilityLabel(item.title)
    }

    private var kindLabel: String {
        switch item.type {
        case "movie": return model.language.t("فيلم", "Movie")
        case "series": return model.language.t("مسلسل", "Series")
        case "anime": return model.language.t("أنمي", "Anime")
        case "asian": return model.language.t("آسيوي", "Asian")
        default: return item.type
        }
    }
}
