import Foundation
import AppKit
import ImageIO

/// Produces a 200×200 JPEG thumbnail at write-time so list rows never
/// decode the original image. Heavy lifting is `CGImageSource`'s
/// thumbnail path, which decodes only what it needs.
enum ImageThumbnailer {
    static func thumbnail(from data: Data, maxPixel: Int = 400) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform:   true,
            kCGImageSourceShouldCacheImmediately:         true,
            kCGImageSourceThumbnailMaxPixelSize:          maxPixel
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary) else { return nil }
        let mutable = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            mutable, "public.jpeg" as CFString, 1, nil
        ) else { return nil }
        let destOpts: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.7]
        CGImageDestinationAddImage(dest, thumb, destOpts as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return mutable as Data
    }
}
