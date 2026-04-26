import SwiftUI
import AppKit

/// Liquid-glass-friendly search field. Wraps NSSearchField so we can
/// command it to focus the moment the popover appears.
struct LumeSearchField: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: (() -> Void)?
    var onArrow: ((Direction) -> Void)?
    var placeholder: String = "Search clips"

    enum Direction { case up, down, returnKey, escape }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.bezelStyle = .roundedBezel
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 14)
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }
        DispatchQueue.main.async {
            if nsView.window?.firstResponder !== nsView.currentEditor() {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: LumeSearchField
        init(_ parent: LumeSearchField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            if let field = notification.object as? NSSearchField {
                parent.text = field.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView,
                     doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.moveDown(_:)):
                parent.onArrow?(.down); return true
            case #selector(NSResponder.moveUp(_:)):
                parent.onArrow?(.up); return true
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit?(); return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onArrow?(.escape); return true
            default:
                return false
            }
        }
    }
}
