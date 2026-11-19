import SwiftUI

struct ClipsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.laylLayout) private var layout

    private var clips: [CatalogTitle] {
        Catalog.all.filter { title in
            model.isVisible(title) && (title.genres.contains(.shortFilm) || title.minutes <= 15)
        }
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(clips) { title in
                        clipPage(title, height: geo.size.height)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
        }
        .background(Color.black)
        .toolbar(.hidden, for: .navigationBar)
        .overlay {
            if clips.isEmpty {
                Text(model.language.t("لا توجد مقاطع قصيرة.", "No short clips yet."))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func clipPage(_ title: CatalogTitle, height: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            CatalogImage(asset: title.backdropAsset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 10) {
                Text(title.title.text(model.language))
                    .font(.title.weight(.bold))
                    .lineLimit(2)
                Text(title.genres.prefix(3).map { $0.title(model.language) }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                HStack(spacing: 12) {
                    Button {
                        model.play(title: title)
                    } label: {
                        Label(model.language.t("تشغيل", "Play"), systemImage: "play.fill")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Button {
                        model.detailTitle = title
                    } label: {
                        Text(model.language.t("التفاصيل", "Details"))
                            .font(.headline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .laylGlassCapsule()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .frame(height: max(height, 480))
        .containerRelativeFrame(.vertical)
    }
}