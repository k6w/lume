import Foundation
import Observation

/// Polls GitHub Releases for a newer version of Lume than what's installed.
///
/// We hit the public, unauthenticated REST endpoint at
/// `api.github.com/repos/k6w/lume/releases/latest`. The endpoint is
/// rate-limited (60/hour for unauth requests) which is fine for a
/// per-user app — we throttle to once per launch + manual recheck.
///
/// "Don't show this again" is per-version, so dismissing 0.3.0 doesn't
/// hide 0.4.0 when it ships.
@MainActor
@Observable
final class UpdateChecker {
    static let dismissedVersionKey = "lume.update.dismissedVersion"
    static let lastCheckedAtKey    = "lume.update.lastCheckedAt"

    struct ReleaseInfo: Equatable {
        let tag: String                // "v0.3.0"
        let version: String            // "0.3.0"
        let title: String              // "Lume v0.3.0"
        let url: URL                   // GitHub release page
        let publishedAt: Date
        let notes: String              // Markdown body
    }

    /// Latest release from the API, even if older than installed.
    var latest: ReleaseInfo?
    /// Set true once `check()` has run at least once.
    var hasChecked: Bool = false
    var isChecking: Bool = false
    /// Tracked stored property so dismissing the banner triggers a
    /// re-render of any view reading `isUpdateAvailable`. Mirrored to
    /// UserDefaults so the choice survives restart.
    var dismissedVersion: String?

    /// True when the latest release is strictly newer than the installed
    /// build *and* the user hasn't dismissed that specific version.
    var isUpdateAvailable: Bool {
        guard let latest else { return false }
        if dismissedVersion == latest.version { return false }
        return Self.compareVersions(latest.version, installedVersion) > 0
    }

    var installedVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    var lastCheckedAt: Date? {
        UserDefaults.standard.object(forKey: Self.lastCheckedAtKey) as? Date
    }

    func dismissCurrent() {
        guard let latest else { return }
        dismissedVersion = latest.version
        UserDefaults.standard.set(latest.version, forKey: Self.dismissedVersionKey)
    }

    init() {
        // Hydrate the dismissed-version cache from UserDefaults so the
        // banner stays hidden across launches.
        self.dismissedVersion = UserDefaults.standard.string(forKey: Self.dismissedVersionKey)
    }

    /// Hit the GitHub API once. Failures are silent — no surfacing of
    /// network errors to the UI; offline runs are just "no update found".
    func check() async {
        guard !isChecking else { return }
        isChecking = true
        defer {
            isChecking = false
            hasChecked = true
            UserDefaults.standard.set(Date(), forKey: Self.lastCheckedAtKey)
        }
        do {
            let url = URL(string: "https://api.github.com/repos/k6w/lume/releases/latest")!
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Lume/\(installedVersion)", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            let payload = try JSONDecoder().decode(GitHubReleasePayload.self, from: data)
            let pubDate = payload.published_at.flatMap(Self.iso8601.date(from:)) ?? Date()
            self.latest = ReleaseInfo(
                tag: payload.tag_name,
                version: payload.tag_name.hasPrefix("v") ? String(payload.tag_name.dropFirst()) : payload.tag_name,
                title: payload.name ?? payload.tag_name,
                url: URL(string: payload.html_url) ?? URL(string: "https://github.com/k6w/lume/releases/latest")!,
                publishedAt: pubDate,
                notes: payload.body ?? ""
            )
        } catch {
            // Silent — keep `latest` whatever it was.
            NSLog("[Lume] update check failed: \(error)")
        }
    }

    // MARK: helpers

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Returns +1 / 0 / -1 like `<=>`. Compares dotted numeric components.
    static func compareVersions(_ a: String, _ b: String) -> Int {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        for (x, y) in zip(aParts, bParts) {
            if x != y { return x > y ? 1 : -1 }
        }
        if aParts.count != bParts.count {
            return aParts.count > bParts.count ? 1 : -1
        }
        return 0
    }
}

/// Minimal subset of the GitHub Releases response.
private struct GitHubReleasePayload: Decodable {
    let tag_name: String
    let name: String?
    let body: String?
    let html_url: String
    let published_at: String?
}
