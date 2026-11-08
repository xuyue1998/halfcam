import Photos

enum PhotoExport {
    static let batchSize = 6

    enum Outcome {
        case saved(Int)
        case noPrints
        case noPermission
        case failed
    }

    static func saveJPEGs(_ payloads: [Data]) async -> Outcome {
        let jpegs = payloads.filter { !$0.isEmpty }
        guard !jpegs.isEmpty else { return .noPrints }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return .noPermission }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                for data in jpegs {
                    let req = PHAssetCreationRequest.forAsset()
                    req.addResource(with: .photo, data: data, options: nil)
                }
            }
            return .saved(jpegs.count)
        } catch {
            return .failed
        }
    }

    @MainActor
    static func toast(_ outcome: Outcome) -> String {
        switch outcome {
        case .saved: L("已存入相册")
        case .noPrints: L("没有成片")
        case .noPermission: L("没有相册权限")
        case .failed: L("导出失败")
        }
    }
}
