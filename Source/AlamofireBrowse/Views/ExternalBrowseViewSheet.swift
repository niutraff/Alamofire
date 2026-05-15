#if os(iOS)

import SwiftUI
import Combine

@available(iOS 16.0, *)
struct ExternalEmbeddedSheetModifier: ViewModifier {

    @ObservedObject var store: EmbeddedSiteState
    @ObservedObject var externalStore: EmbeddedSiteState
    let configuration: EmbeddedConfig
    let closeButtonTitle: String

    func body(content: Content) -> some View {
        content.sheet(
            isPresented: Binding(
                get: { store.externalBrowseViewURL != nil },
                set: { if !$0 { store.externalBrowseViewURL = nil } }
            )
        ) {
            if let url = store.externalBrowseViewURL {
                NavigationStack {
                    EmbeddedSurfaceBridge(
                        url: url,
                        store: externalStore,
                        configuration: externalConfiguration,
                        navigationPolicy: BasicNavRule()
                    )
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(closeButtonTitle) {
                                store.externalBrowseViewURL = nil
                            }
                        }
                    }
                }
            }
        }
    }

    private var externalConfiguration: EmbeddedConfig {
        EmbeddedConfig(
            customUserAgent: configuration.customUserAgent,
            isZoomDisabled: configuration.isZoomDisabled,
            isBackgroundTransparent: configuration.isBackgroundTransparent,
            showsToolbar: false,
            showsLoadingIndicator: false,
            usesEphemeralStorage: configuration.usesEphemeralStorage,
            extendsSessionCookies: configuration.extendsSessionCookies,
            requestCachePolicy: configuration.requestCachePolicy,
            requestTimeout: configuration.requestTimeout,
            enablesCredentialAutofillHints: configuration.enablesCredentialAutofillHints,
            safeAreaColor: configuration.safeAreaColor
        )
    }
}


@available(iOS 16.0, *)
extension View {
    func externalEmbeddedSheet(
        store: EmbeddedSiteState,
        externalStore: EmbeddedSiteState,
        configuration: EmbeddedConfig,
        closeButtonTitle: String = "Close"
    ) -> some View {
        modifier(ExternalEmbeddedSheetModifier(
            store: store,
            externalStore: externalStore,
            configuration: configuration,
            closeButtonTitle: closeButtonTitle
        ))
    }
}

#endif
