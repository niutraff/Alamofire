#if os(iOS)

import Foundation

public enum EmbeddedNavDecision: Sendable {
    case allow

    case cancel

    case launchExternalEmbedded

    case launchInSafari

    case openInSystemBrowser
}


@MainActor
public protocol EmbeddedNavPolicy: AnyObject {

    // periphery:ignore:parameters isMainFrame,isNewWindow
    func decideEmbeddedPolicy(
        for url: URL,
        isMainFrame: Bool,
        isNewWindow: Bool
    ) -> EmbeddedNavDecision
}


@MainActor
public final class BasicNavRule: EmbeddedNavPolicy {

    public init() {}

    // periphery:ignore:parameters isMainFrame,isNewWindow
    public func decideEmbeddedPolicy(
        for url: URL,
        isMainFrame: Bool,
        isNewWindow: Bool
    ) -> EmbeddedNavDecision {
        guard let scheme = url.scheme?.lowercased() else {
            return .allow
        }

        if !["http", "https", "about", "blob"].contains(scheme) {
            return .openInSystemBrowser
        }

        return .allow
    }
}

#endif
