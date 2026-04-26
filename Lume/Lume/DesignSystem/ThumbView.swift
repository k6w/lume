import SwiftUI

/// Decodes a `Data` blob into an SwiftUI `Image` exactly once, off-main,
/// and caches it. List rows can use this for clip thumbnails without
/// re-decoding on every body re-render — which is what made scrolling
/// laggy when there were lots of image clips.
struct ThumbView: View {
    let data: Data
    var contentMode: ContentMode = .fill
    var maxWidth: CGFloat? = nil
    var maxHeight: CGFloat? = nil
    var radius: CGFloat = Tokens.Radius.s

    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.quaternary)
            }
        }
        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .task(id: data) {
            // Decode off-main; keep the result.
            let decoded: NSImage? = await Task.detached { NSImage(data: data) }.value
            if let decoded {
                await MainActor.run { image = Image(nsImage: decoded) }
            }
        }
    }
}
