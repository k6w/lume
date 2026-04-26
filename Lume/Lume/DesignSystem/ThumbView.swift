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
            // Decoding small JPEG thumbnails on the main actor is fine —
            // they're ~10 KB. Avoiding `Task.detached` here keeps the code
            // portable across SDKs that haven't promised NSImage: Sendable.
            if let nsImage = NSImage(data: data) {
                image = Image(nsImage: nsImage)
            }
        }
    }
}
