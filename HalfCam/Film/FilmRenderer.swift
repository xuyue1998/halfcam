import ImageIO
import UIKit

enum FilmRenderer {
    struct Output {
        var positive: Data
        var thumb: Data
    }

    static func stampExport(_ jpeg: Data, like source: Data) -> Data {
        stamp(jpeg, original: source, frame: nil, recipe: nil)
    }

    static func stampExport(_ jpeg: Data, likeURL sourceURL: URL) -> Data {
        let captured = metadata(at: sourceURL)
        return writeMetadata(jpeg, captured: captured, frame: nil, recipe: nil)
    }

    static func metadata(at url: URL) -> [CFString: Any] {
        guard let source = CGImageSourceCreateWithURL(
            url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary
        ) else { return [:] }
        return (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
    }

    static func stamp(_ jpeg: Data, original: Data, frame: Frame?, recipe: FilmRecipe?) -> Data {
        let captured = CGImageSourceCreateWithData(original as CFData, nil).flatMap {
            CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any]
        } ?? [:]
        return writeMetadata(jpeg, captured: captured, frame: frame, recipe: recipe)
    }

    private static func writeMetadata(
        _ jpeg: Data, captured: [CFString: Any], frame: Frame?, recipe: FilmRecipe?
    ) -> Data {
        guard let src = CGImageSourceCreateWithData(jpeg as CFData, nil),
              let uti = CGImageSourceGetType(src) else { return jpeg }
        var all = (CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]) ?? [:]
        merge(&all, captured, kCGImagePropertyGPSDictionary)
        merge(&all, captured, kCGImagePropertyMakerAppleDictionary)
        merge(&all, captured, kCGImagePropertyIPTCDictionary)
        merge(&all, captured, kCGImagePropertyExifAuxDictionary)
        var exif = dict(all, kCGImagePropertyExifDictionary)
        merge(&exif, dict(captured, kCGImagePropertyExifDictionary))
        if exif[kCGImagePropertyExifISOSpeedRatings] == nil, let iso = frame?.iso,
           iso.isFinite, iso > 0, iso < Float(Int32.max) {
            exif[kCGImagePropertyExifISOSpeedRatings] = [Int(iso.rounded())]
        }
        if exif[kCGImagePropertyExifExposureTime] == nil, let shutter = frame?.shutter,
           shutter.isFinite, shutter > 0 {
            exif[kCGImagePropertyExifExposureTime] = shutter
        }
        // Frame.lens is normalized focus position, not an f-number. Preserve the
        // captured aperture metadata; do not invent an aperture when it is absent.
        if let shotAt = frame?.shotAt {
            let shot = stampDate.string(from: shotAt)
            if exif[kCGImagePropertyExifDateTimeOriginal] == nil {
                exif[kCGImagePropertyExifDateTimeOriginal] = shot
            }
            if exif[kCGImagePropertyExifDateTimeDigitized] == nil {
                exif[kCGImagePropertyExifDateTimeDigitized] = shot
            }
        }
        if let recipe {
            exif[kCGImagePropertyExifUserComment] = recipe.name
        }
        all[kCGImagePropertyExifDictionary] = exif
        var tiff = dict(all, kCGImagePropertyTIFFDictionary)
        merge(&tiff, dict(captured, kCGImagePropertyTIFFDictionary))
        tiff[kCGImagePropertyTIFFSoftware] = "HALF CAM"
        if let recipe {
            tiff[kCGImagePropertyTIFFImageDescription] = recipe.name
        }
        if tiff[kCGImagePropertyTIFFDateTime] == nil, let shotAt = frame?.shotAt {
            tiff[kCGImagePropertyTIFFDateTime] = stampDate.string(from: shotAt)
        }
        all[kCGImagePropertyTIFFDictionary] = tiff
        all[kCGImagePropertyOrientation] = 1
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, uti, 1, nil) else { return jpeg }
        CGImageDestinationAddImageFromSource(dest, src, 0, all as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return jpeg }
        return out as Data
    }

    private static let stampDate: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy:MM:dd HH:mm:ss"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt
    }()

    private static func dict(_ props: [CFString: Any], _ key: CFString) -> [CFString: Any] {
        props[key] as? [CFString: Any] ?? [:]
    }

    private static func merge(_ dest: inout [CFString: Any], _ src: [CFString: Any]) {
        for (key, value) in src where dest[key] == nil {
            dest[key] = value
        }
    }

    private static func merge(_ dest: inout [CFString: Any], _ src: [CFString: Any], _ key: CFString) {
        let extra = dict(src, key)
        guard !extra.isEmpty else { return }
        var current = dict(dest, key)
        merge(&current, extra)
        dest[key] = current
    }
}
