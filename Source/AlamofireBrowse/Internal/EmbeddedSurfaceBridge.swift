#if os(iOS)

import SwiftUI
import WebKit

@available(iOS 16.0, *)
struct EmbeddedSurfaceBridge: UIViewRepresentable {

    let url: URL
    let store: EmbeddedSiteState
    let configuration: EmbeddedConfig
    let navigationPolicy: EmbeddedNavPolicy

    func makeUIView(context: Context) -> WKWebView {
        let webView = store.takePreparedEmbedded(matching: configuration)
            ?? EmbeddedSurfaceMaker.assembleEmbeddedSurface(
                frame: .zero,
                configuration: configuration,
                dataStore: EmbeddedSurfaceMaker.assembleDataStore(for: configuration),
                lifecycleHandler: PageLifecycleLogger(store: store)
            )
        let didPrepareInitialLoad = store.didPrepareInitialLoad(for: url)
        let shouldSkipInitialLoad = didPrepareInitialLoad && (webView.isLoading || webView.url != nil)
        let needsInitialLoad = webView.url != url && !shouldSkipInitialLoad

        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        if configuration.isZoomDisabled {
            webView.scrollView.delegate = context.coordinator
        }

        context.coordinator.webView = webView
        context.coordinator.loadedURL = url
        store.setEmbeddedView(webView, configuration: configuration)

        guard needsInitialLoad else {
            return webView
        }

        Task { @MainActor [weak webView, weak coordinator = context.coordinator] in
            guard let webView,
                  let coordinator,
                  coordinator.webView === webView,
                  coordinator.loadedURL == url else {
                return
            }

            store.load(url)
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard store.isInitialized,
              context.coordinator.loadedURL != url else {
            return
        }

        context.coordinator.loadedURL = url
        Task { @MainActor [weak webView, weak coordinator = context.coordinator] in
            guard let webView,
                  let coordinator,
                  coordinator.webView === webView,
                  coordinator.loadedURL == url else {
                return
            }

            store.load(url)
        }
    }

    func makeCoordinator() -> EmbeddedSurfaceFlow {
        EmbeddedSurfaceFlow(
            store: store,
            navigationPolicy: navigationPolicy,
            configuration: configuration
        )
    }

    static func dismantleUIView(
        _ webView: WKWebView,
        coordinator: EmbeddedSurfaceFlow
    ) {
        coordinator.releaseManagedEmbedded(webView)
    }
}

#endif
