#if os(iOS)

import UIKit
import WebKit

@available(iOS 16.0, *)
final class EdgeToEdgeWebView: WKWebView {
    override var safeAreaInsets: UIEdgeInsets { .zero }
}

@available(iOS 16.0, *)
enum EmbeddedSurfaceMaker {

    static let sharedProcessPool = WKProcessPool()
    static let sharedEphemeralDataStore: WKWebsiteDataStore = .nonPersistent()

    @MainActor
    static let persistentCookieKeeper = CookiePersistenceKeeper()

    private static var credentialAutofillLoggerKey: UInt8 = 0

    @MainActor
    static var prewarmFrame: CGRect {
        let screenSize = UIScreen.main.bounds.size
        guard screenSize != .zero else {
            return CGRect(x: 0, y: 0, width: 390, height: 844)
        }
        return CGRect(origin: .zero, size: screenSize)
    }

    static func assembleDataStore(
        for configuration: EmbeddedConfig
    ) -> WKWebsiteDataStore {
        if configuration.usesEphemeralStorage {
            return sharedEphemeralDataStore
        }

        let store = WKWebsiteDataStore.default()
        if configuration.extendsSessionCookies {
            MainActor.assumeIsolated {
                persistentCookieKeeper.attach(to: store.httpCookieStore)
            }
        }
        return store
    }

    @MainActor
    static func assembleEmbeddedSurface(
        frame: CGRect,
        configuration: EmbeddedConfig,
        dataStore: WKWebsiteDataStore,
        lifecycleHandler: WKScriptMessageHandler? = nil
    ) -> WKWebView {
        let wkConfig = WKWebViewConfiguration()
        wkConfig.processPool = Self.sharedProcessPool
        wkConfig.websiteDataStore = dataStore
        wkConfig.preferences.javaScriptCanOpenWindowsAutomatically = true
        wkConfig.allowsInlineMediaPlayback = true
        wkConfig.mediaTypesRequiringUserActionForPlayback = []

        if configuration.isZoomDisabled {
            let script = WKUserScript(
                source: ZoomBlockerScript.source,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            wkConfig.userContentController.addUserScript(script)
        }

        if configuration.enablesCredentialAutofillHints {
            let logger = CredentialAutofillLogger()
            let script = WKUserScript(
                source: CredentialAutofillScript.source,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )
            wkConfig.userContentController.addUserScript(script)
            wkConfig.userContentController.add(
                logger,
                name: CredentialAutofillScript.messageHandlerName
            )
            objc_setAssociatedObject(
                wkConfig.userContentController,
                &credentialAutofillLoggerKey,
                logger,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }

        if let lifecycleHandler {
            let script = WKUserScript(
                source: PageLifecycleScript.source,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            wkConfig.userContentController.addUserScript(script)
            wkConfig.userContentController.add(
                lifecycleHandler,
                name: PageLifecycleScript.messageHandlerName
            )
        }

        let webView = EdgeToEdgeWebView(frame: frame, configuration: wkConfig)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.keyboardDismissMode = .interactive
        webView.disableInputAccessoryView()

        if let userAgent = configuration.customUserAgent {
            webView.customUserAgent = userAgent
        }

        if configuration.isBackgroundTransparent {
            webView.isOpaque = false
            webView.backgroundColor = .clear
            webView.scrollView.backgroundColor = .clear
        }

        return webView
    }
}

#endif
