#if os(iOS)

import UIKit
import WebKit

@MainActor
final class EmbeddedSurfaceFlow: NSObject {

    private let store: EmbeddedSiteState
    private let navigationPolicy: EmbeddedNavPolicy
    private let configuration: EmbeddedConfig
    var loadedURL: URL?
    var webView: WKWebView?
    var navigationStartedAt: Date?
    var cookieKeeperPaused = false

    init(
        store: EmbeddedSiteState,
        navigationPolicy: EmbeddedNavPolicy,
        configuration: EmbeddedConfig
    ) {
        self.store = store
        self.navigationPolicy = navigationPolicy
        self.configuration = configuration
    }

    func releaseManagedEmbedded(_ webView: WKWebView) {
        resumeCookieKeeperIfNeeded()
        store.releaseEmbedded(webView)
        self.webView = nil
        loadedURL = nil
    }
}

extension EmbeddedSurfaceFlow: WKNavigationDelegate {

    func webView(
        _ webView: WKWebView,
        didStartProvisionalNavigation navigation: WKNavigation!
    ) {
        navigationStartedAt = Date()
        if configuration.extendsSessionCookies {
            EmbeddedSurfaceMaker.persistentCookieKeeper.applyLoadingFlag(true)
            cookieKeeperPaused = true
        }
        store.applyLoadingFlag(true)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        navigationStartedAt = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationStartedAt = nil
        resumeCookieKeeperIfNeeded()
        store.concludeNavigation(visibleURL: webView.url)
        store.applyLoadingFlag(false)
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        navigationStartedAt = nil
        resumeCookieKeeperIfNeeded()
        store.applyLoadingFlag(false)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        navigationStartedAt = nil
        resumeCookieKeeperIfNeeded()
        store.applyLoadingFlag(false)
    }

    private func resumeCookieKeeperIfNeeded() {
        guard cookieKeeperPaused else { return }
        cookieKeeperPaused = false
        EmbeddedSurfaceMaker.persistentCookieKeeper.applyLoadingFlag(false)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true

        if isMainFrame, let resolved = EmbeddedURLRegistry.shared.resolve(url) {
            decisionHandler(.cancel)
            webView.load(URLRequest(url: resolved))
            return
        }

        let decision = navigationPolicy.decideEmbeddedPolicy(
            for: url,
            isMainFrame: isMainFrame,
            isNewWindow: false
        )

        switch decision {
        case .allow:
            if isMainFrame {
                store.logRouteRequest(url)
            }
            decisionHandler(.allow)

        case .cancel:
            decisionHandler(.cancel)

        case .launchExternalEmbedded:
            store.launchExternalEmbedded(url)
            decisionHandler(.cancel)

        case .launchInSafari:
            store.launchInSafari(url)
            decisionHandler(.cancel)

        case .openInSystemBrowser:
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!
    ) {
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        store.markWebContentProcessTerminated()
        webView.reload()
    }
}

extension EmbeddedSurfaceFlow: WKUIDelegate {

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil,
              let url = navigationAction.request.url else {
            return nil
        }

        let decision = navigationPolicy.decideEmbeddedPolicy(
            for: url,
            isMainFrame: true,
            isNewWindow: true
        )

        switch decision {
        case .allow:
            store.logRouteRequest(url)
            webView.load(navigationAction.request)

        case .launchInSafari:
            UIApplication.shared.open(
                url,
                options: [.universalLinksOnly: true]
            ) { [weak self] success in
                if !success {
                    Task { @MainActor in
                        self?.store.launchInSafari(url)
                    }
                }
            }

        case .launchExternalEmbedded:
            store.launchExternalEmbedded(url)

        case .openInSystemBrowser:
            UIApplication.shared.open(url)

        case .cancel:
            break
        }

        return nil
    }
}

extension EmbeddedSurfaceFlow: UIScrollViewDelegate {

    func scrollViewWillBeginZooming(
        _ scrollView: UIScrollView,
        with view: UIView?
    ) {
        scrollView.pinchGestureRecognizer?.isEnabled = false
    }
}

#endif
