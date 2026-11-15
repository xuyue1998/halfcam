import Photos
import UIKit

enum PhotoExport {
    static let batchSize = 6

    static func composeJPEG(urls: [URL], rebates: [String] = [], filmBorder: Bool = false) -> Data? {
        if !filmBorder, urls.count == 1, let data = try? Data(contentsOf: urls[0]), !data.isEmpty {
            return data
        }
        let images = urls.compactMap { ImageStore.decodeExport($0, maxSide: 1600) }
        guard !images.isEmpty else { return nil }
        let composed = filmBorder
            ? strip(images, rebates: rebates)
            : stitch(images)
        guard let jpeg = composed.jpegData(compressionQuality: 0.92) else { return nil }
        guard let source = try? Data(contentsOf: urls[0]) else { return jpeg }
        return FilmRenderer.stampExport(jpeg, like: source)
    }

    private static func stitch(_ images: [UIImage]) -> UIImage {
        let h: CGFloat = 1600
        let w: CGFloat = h * 3 / 4
        let gap: CGFloat = images.count > 1 ? 10 : 0
        let canvas = CGSize(width: w * CGFloat(images.count) + gap * CGFloat(max(0, images.count - 1)), height: h)
        let renderer = UIGraphicsImageRenderer(size: canvas)
        return renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvas))
            for (i, img) in images.enumerated() {
                img.draw(in: CGRect(x: CGFloat(i) * (w + gap), y: 0, width: w, height: h))
            }
        }
    }

    private static func strip(_ images: [UIImage], rebates: [String]) -> UIImage {
        let photoH: CGFloat = 1600
        let photoW: CGFloat = photoH * 3 / 4
        let scale = photoH / 237
        let edge = 30 * scale
        let gap = 2 * scale
        let canvas = CGSize(
            width: photoW * CGFloat(images.count) + gap * CGFloat(max(0, images.count - 1)),
            height: photoH + edge * 2
        )
        let renderer = UIGraphicsImageRenderer(size: canvas)
        return renderer.image { ctx in
            let base = UIColor(red: 0.07, green: 0.055, blue: 0.04, alpha: 1)
            base.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvas))
            for (i, img) in images.enumerated() {
                img.draw(in: CGRect(x: CGFloat(i) * (photoW + gap), y: edge, width: photoW, height: photoH))
            }
            drawEdge(canvas: canvas, y: 0, height: edge, scale: scale, rebates: rebates, mark: nil)
            drawEdge(canvas: canvas, y: canvas.height - edge, height: edge, scale: scale, rebates: [], mark: "HALFCAM")
        }
    }

    private static func drawEdge(
        canvas: CGSize,
        y: CGFloat,
        height: CGFloat,
        scale: CGFloat,
        rebates: [String],
        mark: String?
    ) {
        let holeW = 13.5 * scale
        let holeH = 9.4 * scale
        let pitch = 23 * scale
        let top = mark == nil
        let holeY = y + (top ? (height - holeH) * 0.42 : (height - holeH) * 0.38)
        let fill = UIColor(red: 0.93, green: 0.90, blue: 0.82, alpha: 1)
        let rim = UIColor(red: 0.22, green: 0.18, blue: 0.12, alpha: 1)
        var x = -holeW * 0.45
        while x < canvas.width {
            let rect = CGRect(x: x, y: holeY, width: holeW, height: holeH)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 1.8 * scale)
            fill.setFill()
            path.fill()
            rim.setStroke()
            path.lineWidth = 0.7 * scale
            path.stroke()
            let inner = CGRect(x: rect.minX + 1.6 * scale, y: rect.minY + 0.6 * scale, width: rect.width - 3.2 * scale, height: 2.4 * scale)
            UIColor.white.withAlphaComponent(0.22).setFill()
            UIBezierPath(ovalIn: inner).fill()
            x += pitch
        }
        let ink = UIColor(red: 0.86, green: 0.62, blue: 0.18, alpha: 0.92)
        if top, !rebates.isEmpty {
            let font = UIFont.monospacedSystemFont(ofSize: 9 * scale, weight: .medium)
            for (i, code) in rebates.enumerated() {
                let cx = canvas.width * (CGFloat(i) + 0.5) / CGFloat(rebates.count)
                drawCentered(code, at: CGPoint(x: cx, y: y + height - font.lineHeight - 1.5 * scale), font: font, color: ink)
            }
        }
        if let mark {
            let font = UIFont.monospacedSystemFont(ofSize: 8.2 * scale, weight: .medium)
            drawCentered(mark, at: CGPoint(x: canvas.width / 2, y: y + (height - font.lineHeight) * 0.58), font: font, color: ink)
        }
    }

    private static func drawCentered(_ text: String, at origin: CGPoint, font: UIFont, color: UIColor) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .kern: font.pointSize * 0.12
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        (text as NSString).draw(at: CGPoint(x: origin.x - size.width / 2, y: origin.y), withAttributes: attrs)
    }

    enum Outcome {
        case saved(Int, [String])
        case noPrints
        case noPermission
        case failed
    }

    static func saveJPEGs(_ payloads: [Data]) async -> Outcome {
        guard payloads.contains(where: { !$0.isEmpty }) else { return .noPrints }
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else { return .noPermission }
        let box = IdentifierBox()
        do {
            try await PHPhotoLibrary.shared().performChanges {
                var ids: [String] = []
                ids.reserveCapacity(payloads.count)
                for data in payloads {
                    guard !data.isEmpty else {
                        ids.append("")
                        continue
                    }
                    let req = PHAssetCreationRequest.forAsset()
                    req.addResource(with: .photo, data: data, options: nil)
                    ids.append(req.placeholderForCreatedAsset?.localIdentifier ?? "")
                }
                box.ids = ids
            }
            let saved = payloads.filter { !$0.isEmpty }.count
            return .saved(saved, box.ids)
        } catch {
            return .failed
        }
    }

    static func liveAssetIds(_ ids: [String]) -> Set<String> {
        let unique = Array(Set(ids.filter { !$0.isEmpty }))
        guard !unique.isEmpty else { return [] }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: unique, options: nil)
        var live: Set<String> = []
        live.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            live.insert(asset.localIdentifier)
        }
        return live
    }

    @MainActor
    static func toast(_ outcome: Outcome) -> String {
        switch outcome {
        case .saved: L("已倒进系统相册")
        case .noPrints: L("没有成片")
        case .noPermission: L("没有相册权限")
        case .failed: L("倒出失败")
        }
    }
}

private final class IdentifierBox: @unchecked Sendable {
    var ids: [String] = []
}
