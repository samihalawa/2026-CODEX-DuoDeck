import Foundation

/// Where DuoDeck sends people outside the app: DuoDeck's addresses on the web, written once, and its App
/// Store page. The site is duodeck.megawebs.com (the maintainer's, confirmed 2026-09-25): change `site` and the
/// privacy link follows.
enum DuoDeckLinks {
    /// The site.
    static let site = URL(string: "https://duodeck.megawebs.com")!
    /// Where the free DuoDeck Host is downloaded (the connect screen's footer).
    static let download = URL(string: "https://duodeck.megawebs.com/#downloads")!
    /// Help, and how to reach the developer, which guideline 1.5 wants inside the app as well as
    /// behind App Store Connect's Support URL (the connect screen's footer).
    static let support = URL(string: "https://github.com/samihalawa/2026-CODEX-DuoDeck/issues")!
    /// The privacy policy, which guideline 5.1.1(i) wants linked inside the app as well as in
    /// App Store Connect (the connect screen's footer).
    static let privacy = site.appending(path: "privacy")

    /// DuoDeck's App Store page, https://apps.apple.com/app/id‹Apple ID›: the link under a Mac's update
    /// notice (a goodbye "update"). The Apple ID is the App Store Connect record's; the page
    /// opens once Apple approves the first version.
    static let appStoreText = "https://apps.apple.com/app/id6832548998"

    /// An https URL from `appStoreText`, else nil. DEBUG: `-DuoDeckAppStoreURL <url>` replaces it.
    static var appStore: URL? {
        #if DEBUG
        if let override = UserDefaults.standard.string(forKey: "DuoDeckAppStoreURL"), let url = https(override) { return url }
        #endif
        return https(appStoreText)
    }

    private static func https(_ text: String) -> URL? {
        guard let url = URL(string: text), url.scheme == "https", let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}
