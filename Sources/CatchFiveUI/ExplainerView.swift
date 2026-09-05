import Foundation
import SwiftUI

/// The engineering explainer: ten self-contained HTML pages exported from Claude Design,
/// bundled under `Explainer/` and read offline. Links between pages are relative, so they
/// keep working as long as the pages sit in one folder.
public enum ExplainerLibrary {
    public static let folder = "Explainer"
    public static let indexPage = "Index"
    /// Every page, in the reading order the Index uses.
    public static let pages = ["Index", "Build-and-Run", "Architecture", "Game-Flow", "Types-and-Functions",
                               "Testing", "Decisions", "Code-Map", "Tutorial", "Tutorial-Spec"]

    public static func url(for page: String, in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: page, withExtension: "dc.html", subdirectory: folder)
    }

    /// True when a navigation stays inside the bundled folder.
    public static func isBundled(_ url: URL, in bundle: Bundle = .main) -> Bool {
        guard url.isFileURL, let root = bundle.url(forResource: folder, withExtension: nil) else { return false }
        return url.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path)
    }
}

#if canImport(UIKit)
import WebKit

/// Sheet that shows the explainer pages with a Back button for the links between them.
struct ExplainerView: View {
    let onDismiss: () -> Void
    @StateObject private var browser = ExplainerBrowser()

    var body: some View {
        NavigationStack {
            Group {
                if let url = ExplainerLibrary.url(for: ExplainerLibrary.indexPage) {
                    ExplainerWebView(browser: browser, url: url)
                } else {
                    Text("The explainer pages are not in this build.").foregroundStyle(.secondary)
                }
            }
            .navigationTitle(browser.title.isEmpty ? "How it's built" : browser.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { browser.goBack() } label: { Label("Back", systemImage: "chevron.left") }.disabled(!browser.canGoBack)
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done", action: onDismiss) }
            }
        }
    }
}

@MainActor
final class ExplainerBrowser: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var canGoBack = false
    @Published var title = ""
    weak var webView: WKWebView?

    func goBack() { webView?.goBack() }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = action.request.url else { return .cancel }
        if ExplainerLibrary.isBundled(url) || url.scheme == "blob" || url.scheme == "about" { return .allow }
        // Anything outside the bundle opens in Safari rather than inside the sheet.
        if let scheme = url.scheme, scheme.hasPrefix("http") { await UIApplication.shared.open(url) }
        return .cancel
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        canGoBack = webView.canGoBack
        title = (webView.title ?? "").replacingOccurrences(of: "Bundled Page", with: "")
    }
}

struct ExplainerWebView: UIViewRepresentable {
    let browser: ExplainerBrowser
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = browser
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.035, green: 0.16, blue: 0.13, alpha: 1)
        browser.webView = webView
        // Read access to the whole folder is what lets relative links reach the other pages.
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#endif
