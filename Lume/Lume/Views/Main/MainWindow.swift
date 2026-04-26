import SwiftUI

@MainActor
struct MainWindowRoot: View {
    let environment: AppEnvironment
    @State private var selection: SidebarItem = .all
    @State private var query: String = ""
    @State private var focusedClipID: String?
    @State private var tagFilter: TagFilter = .all
    @State private var allTags: [Tag] = []
    @State private var tagObservationTask: Task<Void, Never>?

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
        } detail: {
            VStack(spacing: 0) {
                if environment.updateChecker.isUpdateAvailable,
                   let release = environment.updateChecker.latest {
                    UpdateBanner(
                        release: release,
                        installedVersion: environment.updateChecker.installedVersion,
                        onOpen: {},
                        onDismiss: { environment.updateChecker.dismissCurrent() }
                    )
                }
                content
            }
            .navigationSplitViewColumnWidth(min: 600, ideal: 760)
        }
        .navigationSplitViewStyle(.balanced)
        // Hoisted toolbar: same shape on every tab so the title bar
        // height never changes. Placed at .navigation (leading on macOS).
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    if let id = focusedClipID,
                       let clip = try? environment.clipRepository.clip(id: id) {
                        environment.pasteInjector.copy(clip)
                    }
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(focusedClipID == nil || isMetaTab)
                .help("Copy the focused clip back to the pasteboard")
            }
            ToolbarItem(placement: .navigation) {
                ToolbarSearchField(text: $query)
                    .frame(width: 220)
                    .disabled(isMetaTab)
            }
            ToolbarItem(placement: .navigation) {
                tagFilterMenu
                    .disabled(isMetaTab)
            }
        }
        .onAppear { startTagObservation() }
        .onDisappear { tagObservationTask?.cancel() }
    }

    private var tagFilterMenu: some View {
        Menu {
            Button {
                tagFilter = .all
            } label: {
                Label("All Tags", systemImage: tagFilter == .all ? "checkmark" : "tag")
            }
            Button {
                tagFilter = .untagged
            } label: {
                Label("Untagged", systemImage: tagFilter == .untagged ? "checkmark" : "tag.slash")
            }
            if !allTags.isEmpty {
                Divider()
                ForEach(allTags, id: \.id) { tag in
                    Button {
                        tagFilter = .tagID(tag.id)
                    } label: {
                        Label(tag.name, systemImage: isSelected(tag) ? "checkmark" : (tag.icon ?? "tag"))
                    }
                }
            }
        } label: {
            Label(currentFilterLabel, systemImage: currentFilterSymbol)
        }
        .help("Filter by tag")
    }

    private func isSelected(_ tag: Tag) -> Bool {
        if case .tagID(let id) = tagFilter, id == tag.id { return true }
        return false
    }

    private var currentFilterLabel: String {
        switch tagFilter {
        case .all: return "All Tags"
        case .untagged: return "Untagged"
        case .tagID(let id):
            return allTags.first(where: { $0.id == id })?.name ?? "Tag"
        }
    }

    private var currentFilterSymbol: String {
        switch tagFilter {
        case .all: return "tag"
        case .untagged: return "tag.slash"
        case .tagID(let id):
            return allTags.first(where: { $0.id == id })?.icon ?? "tag.fill"
        }
    }

    private func startTagObservation() {
        tagObservationTask?.cancel()
        tagObservationTask = Task { @MainActor in
            do {
                let observation = environment.tagRepository.observeAll()
                for try await fresh in observation.values(in: environment.tagRepository.pool) {
                    self.allTags = fresh
                    // Drop the active filter if its tag was deleted.
                    if case .tagID(let id) = tagFilter,
                       !fresh.contains(where: { $0.id == id }) {
                        tagFilter = .all
                    }
                }
            } catch {
                NSLog("[Lume] tag observe failed: \(error)")
            }
        }
    }

    /// True when the current sidebar selection isn't a clip list (i.e.
    /// Snippets / Stats / Settings). Toolbar controls are still rendered
    /// — keeping the bar height consistent — but disabled.
    private var isMetaTab: Bool {
        switch selection {
        case .snippets, .stats, .settings: return true
        default: return false
        }
    }

    @ViewBuilder private var content: some View {
        switch selection {
        case .settings: SettingsView(environment: environment)
        case .snippets: SnippetsView(environment: environment)
        case .stats:    StatsView(environment: environment)
        default:
            HistoryBrowser(environment: environment,
                           scope: selection,
                           query: $query,
                           focusedClipID: $focusedClipID,
                           tagFilter: $tagFilter)
        }
    }
}

/// A SwiftUI wrapper around `NSSearchField`. macOS-native look + size,
/// no toolbar height changes, no `.searchable` placement quirks.
struct ToolbarSearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Search clips"

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.controlSize = .regular
        field.bezelStyle = .roundedBezel
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: ToolbarSearchField
        init(_ parent: ToolbarSearchField) { self.parent = parent }
        func controlTextDidChange(_ note: Notification) {
            if let f = note.object as? NSSearchField { parent.text = f.stringValue }
        }
    }
}
