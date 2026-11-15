import SwiftUI
import UIKit

enum FilmSamples {
    static func urls(for filmId: String) -> [URL] {
        let resolved = FilmCatalog.recipe(id: filmId).id
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("samples", isDirectory: true) else {
            return []
        }
        let folder = root.appendingPathComponent(resolved, isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return files
            .filter { ["jpg", "jpeg", "png", "heic"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

struct FilmSampleStrip: View {
    var filmId: String
    var onOpen: (Int) -> Void

    private var urls: [URL] { FilmSamples.urls(for: filmId) }

    var body: some View {
        if urls.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("样片"))
                    .font(.system(size: 14))
                    .foregroundStyle(Color(white: 0.78))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(urls.enumerated()), id: \.offset) { i, url in
                            Button {
                                onOpen(i)
                                Haptics.shared.chrome()
                            } label: {
                                FilmSampleStill(url: url)
                                    .frame(width: 72, height: 96)
                                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .stroke(Color.white.opacity(0.22), lineWidth: 0.6)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

struct FilmSampleStill: View {
    var url: URL
    var fill: Bool = true

    var body: some View {
        if let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: fill ? .fill : .fit)
        } else {
            Color(white: 0.12)
        }
    }
}

struct FilmSampleLightbox: View {
    var urls: [URL]
    @Binding var index: Int?

    var body: some View {
        if let i = index, urls.indices.contains(i) {
            ZStack {
                Color.black.opacity(0.88)
                    .ignoresSafeArea()
                TabView(selection: lightboxIndex) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { n, url in
                        FilmSampleStill(url: url, fill: false)
                            .padding(24)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .tag(n)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .automatic : .never))
            }
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded { close() })
            .ignoresSafeArea()
            .statusBarHidden()
        }
    }

    private var lightboxIndex: Binding<Int> {
        Binding(
            get: { index ?? 0 },
            set: { index = $0 }
        )
    }

    private func close() {
        Haptics.shared.latch()
        index = nil
    }
}
