#if os(iOS)

import Foundation

public extension EmbeddedConfig {

    static let `default` = EmbeddedConfig()

    static let minimal = EmbeddedConfig(
        showsToolbar: false,
        showsLoadingIndicator: false
    )

    static func mobileSafariUA(
        showsToolbar: Bool = true
    ) -> EmbeddedConfig {
        EmbeddedConfig(
            customUserAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1",
            isZoomDisabled: true,
            isBackgroundTransparent: false,
            showsToolbar: showsToolbar,
            showsLoadingIndicator: true,
            extendsSessionCookies: true
        )
    }
}

#endif
