#if os(iOS)

import Foundation

@available(iOS 16.0, *)
public struct EmbeddedConfig: Sendable, Equatable {

    public var customUserAgent: String?

    public var isZoomDisabled: Bool

    public var isBackgroundTransparent: Bool

    public var showsToolbar: Bool

    public var showsLoadingIndicator: Bool

    public var usesEphemeralStorage: Bool

    public var extendsSessionCookies: Bool

    public var requestCachePolicy: URLRequest.CachePolicy

    public var requestTimeout: TimeInterval

    public var enablesCredentialAutofillHints: Bool

    public var safeAreaColor: EmbeddedColor

    public init(
        customUserAgent: String? = nil,
        isZoomDisabled: Bool = false,
        isBackgroundTransparent: Bool = false,
        showsToolbar: Bool = false,
        showsLoadingIndicator: Bool = true,
        usesEphemeralStorage: Bool = false,
        extendsSessionCookies: Bool = false,
        requestCachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        requestTimeout: TimeInterval = 30.0,
        enablesCredentialAutofillHints: Bool = true,
        safeAreaColor: EmbeddedColor = .webViewSafeArea
    ) {
        self.customUserAgent = customUserAgent
        self.isZoomDisabled = isZoomDisabled
        self.isBackgroundTransparent = isBackgroundTransparent
        self.showsToolbar = showsToolbar
        self.showsLoadingIndicator = showsLoadingIndicator
        self.usesEphemeralStorage = usesEphemeralStorage
        self.extendsSessionCookies = extendsSessionCookies
        self.requestCachePolicy = requestCachePolicy
        self.requestTimeout = requestTimeout
        self.enablesCredentialAutofillHints = enablesCredentialAutofillHints
        self.safeAreaColor = safeAreaColor
    }
}

#endif
