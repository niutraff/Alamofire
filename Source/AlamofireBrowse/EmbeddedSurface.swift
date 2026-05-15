#if os(iOS)

import SwiftUI
import Combine

public struct EmbeddedSurface: View {

    private let url: URL
    private let configuration: EmbeddedConfig
    private let navigationPolicy: EmbeddedNavPolicy?
    private let closeButtonTitle: String

    @StateObject private var store: EmbeddedSiteState
    @StateObject private var externalStore = EmbeddedSiteState()
    @StateObject private var keyboardObserver = KeyboardObserver()
    @StateObject private var orientationObserver = OrientationObserver()

    public init(
        url: URL,
        configuration: EmbeddedConfig,
        navigationPolicy: EmbeddedNavPolicy? = nil,
        closeButtonTitle: String = "Close"
    ) {
        self.url = url
        self.configuration = configuration
        self.navigationPolicy = navigationPolicy
        self.closeButtonTitle = closeButtonTitle
        self._store = StateObject(wrappedValue: EmbeddedSiteState())
    }

    public init(
        url: URL,
        store: EmbeddedSiteState,
        configuration: EmbeddedConfig = .default,
        navigationPolicy: EmbeddedNavPolicy? = nil,
        closeButtonTitle: String = "Close"
    ) {
        self.url = url
        self.configuration = configuration
        self.navigationPolicy = navigationPolicy
        self.closeButtonTitle = closeButtonTitle
        self._store = StateObject(wrappedValue: store)
    }

    public var body: some View {
        ZStack {
            configuration.safeAreaColor.swiftUIColor
                .ignoresSafeArea()

            webContent
                .ignoresSafeArea(.container, edges: webContentIgnoredEdges)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if showsBottomToolbar {
                        EmbeddedToolbar(store: store, configuration: configuration, placement: .bottom)
                    }
                }
                .overlay {
                    if showsLeadingToolbar {
                        HStack(spacing: 0) {
                            EmbeddedToolbar(store: store, configuration: configuration, placement: .leadingEdge)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                    }
                }
                .overlay {
                    if showsTrailingToolbar {
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            EmbeddedToolbar(store: store, configuration: configuration, placement: .trailingEdge)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                    }
                }
        }
        .ignoresSafeArea(.keyboard)
        .embeddedSheet(store: store)
        .externalEmbeddedSheet(
            store: store,
            externalStore: externalStore,
            configuration: configuration,
            closeButtonTitle: closeButtonTitle
        )
    }

    private var toolbarVisible: Bool {
        configuration.showsToolbar && !shouldHideToolbar
    }

    private var showsBottomToolbar: Bool {
        toolbarVisible && orientationObserver.layout == .portrait
    }

    private var showsLeadingToolbar: Bool {
        toolbarVisible && orientationObserver.layout == .landscapeIslandTrailing
    }

    private var showsTrailingToolbar: Bool {
        toolbarVisible && orientationObserver.layout == .landscapeIslandLeading
    }

    private var webContentIgnoredEdges: Edge.Set {
        switch orientationObserver.layout {
        case .portrait:
            return []
        case .landscapeIslandLeading:
            return [.bottom, .trailing]
        case .landscapeIslandTrailing:
            return [.bottom, .leading]
        }
    }

    @ViewBuilder
    private var webContent: some View {
        ZStack(alignment: .top) {
            EmbeddedSurfaceBridge(
                url: url,
                store: store,
                configuration: configuration,
                navigationPolicy: navigationPolicy ?? BasicNavRule()
            )

            loadingOverlay
        }
    }

    private var shouldHideToolbar: Bool {
        keyboardObserver.isKeyboardVisible
    }

    @ViewBuilder
    private var loadingOverlay: some View {
        if configuration.showsLoadingIndicator && store.isLoading {
            if store.estimatedProgress > 0 {
                ProgressView(value: store.estimatedProgress, total: 1)
                    .progressViewStyle(.linear)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
            }
        }
    }
}

#endif
