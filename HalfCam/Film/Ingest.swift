import CoreImage
import CoreGraphics
import ImageIO
import UIKit

enum Ingest {
    struct LinearFrame {
        var width: Int
        var height: Int
        var rgb: [Float]
    }

    private static let linearProPhoto: CGColorSpace? = {
        let d50: [CGFloat] = [0.9642, 1.0000, 0.8249]
        let black: [CGFloat] = [0, 0, 0]
        let gamma: [CGFloat] = [1, 1, 1]
        let primaries: [CGFloat] = [
            0.7976749, 0.2880402, 0.0000000,
            0.1351917, 0.7118741, 0.0000000,
            0.0313534, 0.0000857, 0.8252100
        ]
        return d50.withUnsafeBufferPointer { wp in
            black.withUnsafeBufferPointer { bp in
                gamma.withUnsafeBufferPointer { gp in
                    primaries.withUnsafeBufferPointer { mp in
                        CGColorSpace(
                            calibratedRGBWhitePoint: wp.baseAddress!,
                            blackPoint: bp.baseAddress,
                            gamma: gp.baseAddress!,
                            matrix: mp.baseAddress
                        )
                    }
                }
            }
        }
    }()

    private static let context: CIContext = {
        let options: [CIContextOption: Any] = [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3) as Any,
            .outputColorSpace: linearProPhoto as Any,
            .cacheIntermediates: false
        ]
        if let device = SpektraEngine.shared.metalDevice {
            return CIContext(mtlDevice: device, options: options)
        }
        return CIContext(options: options)
    }()

    static func linearRGB(data: Data, longEdge: CGFloat) -> LinearFrame? {
        if isRAW(data), let raw = rawLinear(data: data, longEdge: longEdge) { return raw }
        return displayLinear(data: data, longEdge: longEdge)
    }

    private static func isRAW(_ data: Data) -> Bool {
        guard data.count >= 12 else { return false }
        if data[0] == 0xFF, data[1] == 0xD8 { return false }
        if data.dropFirst(4).prefix(4).elementsEqual("ftyp".utf8) { return false }
        if data[0] == 0x89, data[1] == 0x50, data[2] == 0x4E, data[3] == 0x47 { return false }
        return true
    }

    private static func rawLinear(data: Data, longEdge: CGFloat) -> LinearFrame? {
        guard let filter = CIRAWFilter(imageData: data, identifierHint: nil) else { return nil }
        filter.boostAmount = 0
        filter.boostShadowAmount = 0
        filter.isGamutMappingEnabled = false
        filter.localToneMapAmount = 0
        filter.extendedDynamicRangeAmount = 0
        if let native = nativeLongEdge(data), native > longEdge, native > 0 {
            filter.scaleFactor = Float(longEdge / native)
        }
        guard var image = filter.outputImage else { return nil }
        image = scaled(image, longEdge: longEdge)
        return raster(image)
    }

    private static func nativeLongEdge(_ data: Data) -> CGFloat? {
        guard let src = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else { return nil }
        let w = props[kCGImagePropertyPixelWidth] as? CGFloat ?? CGFloat((props[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0)
        let h = props[kCGImagePropertyPixelHeight] as? CGFloat ?? CGFloat((props[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0)
        let long = max(w, h)
        return long > 0 ? long : nil
    }

    private static func displayLinear(data: Data, longEdge: CGFloat) -> LinearFrame? {
        guard var image = CIImage(data: data, options: [.applyOrientationProperty: true]) else { return nil }
        image = scaled(image, longEdge: longEdge)
        return raster(image)
    }

    private static func scaled(_ image: CIImage, longEdge: CGFloat) -> CIImage {
        let long = max(image.extent.width, image.extent.height)
        guard long > longEdge, long > 0 else { return image }
        let s = longEdge / long
        return image.transformed(by: CGAffineTransform(scaleX: s, y: s))
    }

    private static func raster(_ image: CIImage) -> LinearFrame? {
        let rect = image.extent.integral
        let w = Int(rect.width)
        let h = Int(rect.height)
        let pixels = w * h
        guard w > 0, h > 0, pixels > 0, let space = linearProPhoto else { return nil }
        var rgb = [Float](repeating: 0, count: pixels * 4)
        let ok = rgb.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress else { return false }
            context.render(
                image,
                toBitmap: base,
                rowBytes: w * MemoryLayout<Float>.size * 4,
                bounds: rect,
                format: .RGBAf,
                colorSpace: space
            )
            return true
        }
        guard ok else { return nil }
        rgb.withUnsafeMutableBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            hc_pack_rgbaf_to_rgb(base, UInt32(pixels))
        }
        rgb.removeLast(pixels)
        return LinearFrame(width: w, height: h, rgb: rgb)
    }
}
