#if os(iOS)

import Foundation
import Combine
import WebKit

@MainActor
public final class EmbeddedSiteState: ObservableObject {

    @Published public private(set) var canGoBack: Bool = false

    @Published public private(set) var canGoForward: Bool = false

    @Published public private(set) var currentURL: URL?

    @Published public private(set) var isLoading: Bool = false

    @Published public private(set) var estimatedProgress: Double = 0

    public private(set) var isInitialized: Bool = false

    @Published public private(set) var pageBecameInteractive: Bool = false

    @Published public private(set) var pageAppReady: Bool = false

    @Published public private(set) var completedNavigationCount: Int = 0

    @Published public private(set) var contentProcessTerminationCount: Int = 0

    @Published public var safariURL: URL?

    @Published public var externalBrowseViewURL: URL?

    @Published public private(set) var homeURL: URL?

    private var webView: WKWebView?
    private var preparedWebView: WKWebView?
    private var activeConfiguration: EmbeddedConfig?
    private var preparedConfiguration: EmbeddedConfig?
    private var preparedInitialURL: URL?
    private var lastRequestedURL: URL?
    private var lastCompletedRequestURL: URL?
    private var lastReloadAt: Date?
    private var observations: [NSKeyValueObservation] = []

    public init() {}

    deinit {
        observations.removeAll()
    }

    public func preparePresentation(
        configuration: EmbeddedConfig,
        initialURL: URL? = nil
    ) {
        if let webView {
            if let initialURL {
                primeIfPending(initialURL, in: webView)
            }
            return
        }

        if let preparedConfiguration,
           preparedConfiguration != configuration {
            preparedWebView = nil
            self.preparedConfiguration = nil
            preparedInitialURL = nil
            lastRequestedURL = nil
            lastCompletedRequestURL = nil
        }

        if let preparedConfiguration,
           preparedConfiguration == configuration,
           preparedWebView != nil {
            if let initialURL,
               let preparedWebView {
                warmPreparedURLIfPending(initialURL, in: preparedWebView)
            }
            return
        }

        let webView = EmbeddedSurfaceMaker.assembleEmbeddedSurface(
            frame: EmbeddedSurfaceMaker.prewarmFrame,
            configuration: configuration,
            dataStore: EmbeddedSurfaceMaker.assembleDataStore(for: configuration),
            lifecycleHandler: PageLifecycleLogger(store: self)
        )
        preparedWebView = webView
        self.preparedConfiguration = configuration
        lastRequestedURL = nil
        lastCompletedRequestURL = nil

        if let initialURL {
            warmPreparedURLIfPending(initialURL, in: webView)
        }
    }

    public func stepBack() {
        webView?.goBack()
    }

    public func stepForward() {
        webView?.goForward()
    }

    public func reload() {
        guard let webView else { return }

        if webView.isLoading {
            return
        }

        let now = Date()
        if let lastReloadAt,
           now.timeIntervalSince(lastReloadAt) < 0.8 {
            return
        }

        lastReloadAt = now
        setPageBecameInteractive(false)
        setPageAppReady(false)
        webView.reload()
    }

    public func goHome() {
        guard let homeURL, let webView else { return }

        let backItem = webView.backForwardList.backList
            .reversed()
            .first { $0.url == homeURL }

        if let backItem {
            webView.go(to: backItem)
            return
        }

        primeIfPending(homeURL, in: webView)
    }

    public func setHomeURL(_ url: URL?) {
        guard homeURL != url else { return }
        homeURL = url
    }

    public func load(_ url: URL) {
        guard let webView else { return }
        primeIfPending(url, in: webView)
    }

    func setEmbeddedView(
        _ webView: WKWebView,
        configuration: EmbeddedConfig
    ) {
        self.webView = webView
        activeConfiguration = configuration
        preparedWebView = nil
        preparedConfiguration = nil
        lastRequestedURL = preparedInitialURL
        if preparedInitialURL != nil,
           !webView.isLoading,
           webView.url != nil {
            lastCompletedRequestURL = preparedInitialURL
        }
        preparedInitialURL = nil
        isInitialized = true
        wireObservations(for: webView)
        syncNavigationStateWhenSwiftUIUpdateCompletes(from: webView)
    }

    func applyLoadingFlag(_ value: Bool) {
        updateLoadingFlag(value)
    }

    func launchInSafari(_ url: URL) {
        safariURL = url
    }

    func launchExternalEmbedded(_ url: URL) {
        externalBrowseViewURL = url
    }

    func takePreparedEmbedded(
        matching configuration: EmbeddedConfig
    ) -> WKWebView? {
        guard let preparedConfiguration,
              preparedConfiguration == configuration else {
            preparedWebView = nil
            self.preparedConfiguration = nil
            preparedInitialURL = nil
            lastRequestedURL = nil
            lastCompletedRequestURL = nil
            return nil
        }

        let webView = preparedWebView
        preparedWebView = nil
        self.preparedConfiguration = nil
        return webView
    }

    func didPrepareInitialLoad(
        for url: URL
    ) -> Bool {
        preparedInitialURL == url
    }

    func didFinishLoad(
        for url: URL
    ) -> Bool {
        currentURL == url || lastCompletedRequestURL == url
    }

    func hasCompletedVisibleLoad() -> Bool {
        guard let currentURL else { return false }
        return lastCompletedRequestURL == currentURL
    }

    func logRouteRequest(_ url: URL) {
        if lastRequestedURL != url {
            setPageBecameInteractive(false)
            setPageAppReady(false)
        } else if !isLoading {
            setPageBecameInteractive(false)
            setPageAppReady(false)
        }

        guard lastRequestedURL != url || isLoading else { return }
        lastRequestedURL = url
    }

    func concludeNavigation(visibleURL: URL?) {
        let completedURL = visibleURL ?? lastRequestedURL
        guard let completedURL else { return }

        lastCompletedRequestURL = completedURL
        updateCurrentURL(completedURL)
        setEstimatedProgress(1)
        setPageBecameInteractive(true)
        completedNavigationCount += 1
    }

    func releaseEmbedded(_ webView: WKWebView) {
        guard self.webView === webView else { return }

        observations.removeAll()

        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.scrollView.delegate = nil

        preparedWebView = webView
        preparedConfiguration = activeConfiguration
        preparedInitialURL = webView.url
        lastRequestedURL = webView.url
        lastCompletedRequestURL = webView.url

        self.webView = nil
        activeConfiguration = nil
        isInitialized = false
        resetReleasedStateWhenSwiftUIUpdateCompletes()
    }

    func markPageInteractive(url: URL) {
        guard isRelevantLifecycleURL(url) else { return }
        setPageBecameInteractive(true)
        if activeConfiguration?.extendsSessionCookies == true {
            EmbeddedSurfaceMaker.persistentCookieKeeper.scheduleUpgradeAfterPageSettles()
        }
    }

    func markPageAppReady(url: URL) {
        guard isRelevantLifecycleURL(url) else { return }
        setPageBecameInteractive(true)
        setPageAppReady(true)
    }

    func markWebContentProcessTerminated() {
        contentProcessTerminationCount += 1
        setPageBecameInteractive(false)
        setPageAppReady(false)
        updateLoadingFlag(false)
        setEstimatedProgress(0)
    }

    private func wireObservations(for webView: WKWebView) {
        observations.removeAll()

        observations.append(
            webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
                if Thread.isMainThread {
                    self?.updateCanStepBack(webView.canGoBack)
                } else {
                    Task { @MainActor [weak self] in
                        self?.updateCanStepBack(webView.canGoBack)
                    }
                }
            }
        )

        observations.append(
            webView.observe(\.canGoForward, options: [.new]) { [weak self] webView, _ in
                if Thread.isMainThread {
                    self?.updateCanStepForward(webView.canGoForward)
                } else {
                    Task { @MainActor [weak self] in
                        self?.updateCanStepForward(webView.canGoForward)
                    }
                }
            }
        )

        observations.append(
            webView.observe(\.isLoading, options: [.new]) { [weak self] webView, _ in
                if Thread.isMainThread {
                    self?.updateLoadingFlag(webView.isLoading)
                } else {
                    Task { @MainActor [weak self] in
                        self?.updateLoadingFlag(webView.isLoading)
                    }
                }
            }
        )

        observations.append(
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                if Thread.isMainThread {
                    self?.setEstimatedProgress(webView.estimatedProgress)
                } else {
                    Task { @MainActor [weak self] in
                        self?.setEstimatedProgress(webView.estimatedProgress)
                    }
                }
            }
        )

        observations.append(
            webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                if Thread.isMainThread {
                    self?.updateCurrentURL(webView.url)
                } else {
                    Task { @MainActor [weak self] in
                        self?.updateCurrentURL(webView.url)
                    }
                }
            }
        )
    }

    private func warmPreparedURLIfPending(
        _ url: URL,
        in webView: WKWebView
    ) {
        preparedInitialURL = url
        primeIfPending(url, in: webView)
    }

    private func primeIfPending(
        _ url: URL,
        in webView: WKWebView
    ) {
        if webView.url == url {
            return
        }
        if webView.isLoading, lastRequestedURL == url {
            return
        }
        logRouteRequest(url)
        let configuration = activeConfiguration ?? preparedConfiguration ?? .default
        let request = URLRequest(
            url: url,
            cachePolicy: configuration.requestCachePolicy,
            timeoutInterval: configuration.requestTimeout
        )
        webView.load(request)
    }

    private func syncRouteState(from webView: WKWebView) {
        updateCanStepBack(webView.canGoBack)
        updateCanStepForward(webView.canGoForward)
        updateLoadingFlag(webView.isLoading)
        setEstimatedProgress(webView.estimatedProgress)
        updateCurrentURL(webView.url)
    }

    private func syncNavigationStateWhenSwiftUIUpdateCompletes(
        from webView: WKWebView
    ) {
        Task { @MainActor [weak self, weak webView] in
            guard let self,
                  let webView,
                  self.webView === webView else {
                return
            }

            self.syncRouteState(from: webView)
        }
    }

    private func resetReleasedStateWhenSwiftUIUpdateCompletes() {
        Task { @MainActor [weak self] in
            guard let self,
                  self.webView == nil else {
                return
            }

            self.updateLoadingFlag(false)
            self.setEstimatedProgress(0)
        }
    }

    private func isRelevantLifecycleURL(_ url: URL) -> Bool {
        if currentURL == nil {
            return true
        }
        if currentURL == url || lastRequestedURL == url {
            return true
        }
        return currentURL?.host == url.host
    }

    private func updateCanStepBack(_ value: Bool) {
        guard canGoBack != value else { return }
        canGoBack = value
    }

    private func updateCanStepForward(_ value: Bool) {
        guard canGoForward != value else { return }
        canGoForward = value
    }

    private func updateLoadingFlag(_ value: Bool) {
        guard isLoading != value else { return }
        isLoading = value
    }

    private func setEstimatedProgress(_ value: Double) {
        let progress = min(max(value, 0), 1)
        guard estimatedProgress != progress else { return }
        estimatedProgress = progress
    }

    private func updateCurrentURL(_ value: URL?) {
        guard currentURL != value else { return }
        currentURL = value
    }

    private func setPageBecameInteractive(_ value: Bool) {
        guard pageBecameInteractive != value else { return }
        pageBecameInteractive = value
    }

    private func setPageAppReady(_ value: Bool) {
        guard pageAppReady != value else { return }
        pageAppReady = value
    }
}

#endif
