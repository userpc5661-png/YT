import SwiftUI

struct DiscoverView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.laylLayout) private var layout

  // Streaming Availability API — https://github.com/movieofthenight/streaming-availability-api
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if !model.hasStreamingAPI {
                    setupCard
                } else if model.discoverLoading {
                    ProgressView(model.language.t("نجلب القوائم...", "Loading lists..."))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if let error = model.discoverError, model.discoverLanes.isEmpty {
                    EmptyState(
                        systemImage: "wifi.exclamationmark",
                        title: model.language.t("تعذر التحميل", "Could not load"),
                        message: error
                    )
                } else if model.discoverLanes.isEmpty {
                    EmptyState(
                        systemImage: "sparkles.tv",
                        title: model.language.t("لا توجد قوائم", "No lists yet"),
                        message: model.language.t("جرّب خدمة أو دولة أخرى من الإعدادات.", "Try another service or country in Settings.")
                    )
                } else {
                    ForEach(model.discoverLanes) { lane in
                        StreamingRail(lane: lane, posterWidth: layout.posterWidth)
                    }
                    APIAttributionFooter()
                        .padding(.horizontal, layout.contentInset)
                }
            }
            .padding(.bottom, 32)
        }
        .laylScreen()
        .navigationTitle(model.language.t("اكتشف", "Discover"))
        .navigationBarTitleDisplayMode(.large)
        .laylNavigationChrome()
        .refreshable { model.loadDiscoverCatalog() }
        .onAppear {
            if model.discoverLanes.isEmpty, model.hasStreamingAPI {
                model.loadDiscoverCatalog()
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.language.t("أفضل العروض على البث", "Top streaming picks"))
                    .font(.headline)
                Text(StreamingCountry.supported.first { $0.code == model.streamCountry }?.name(model.language) ?? model.streamCountry.uppercased())
                    .font(.caption)
                    .foregroundStyle(LaylTheme.muted)
            }
            Spacer()
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, layout.contentInset)
        .padding(.top, 8)
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.language.t("فعّل اكتشاف البث", "Enable streaming discover"))
                .font(.title3.weight(.bold))
            Text(model.language.t(
                "أنشئ مفتاحًا مجانيًا من Movie of the Night ثم ألصقه في الإعدادات.",
                "Create a free Movie of the Night key and paste it in Settings."
            ))
            .font(.subheadline)
            .foregroundStyle(LaylTheme.muted)
            NavigationLink {
                SettingsView()
            } label: {
                Text(model.language.t("فتح الإعدادات", "Open Settings"))
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LaylTheme.red, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(LaylTheme.elevated, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, layout.contentInset)
    }
}