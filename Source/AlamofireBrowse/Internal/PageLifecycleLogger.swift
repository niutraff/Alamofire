#if os(iOS)

import Foundation
import WebKit

@MainActor
@available(iOS 16.0, *)
final class PageLifecycleLogger: NSObject, WKScriptMessageHandler {

    private weak var store: EmbeddedSiteState?

    init(store: EmbeddedSiteState?) {
        self.store = store
    }

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == PageLifecycleScript.messageHandlerName,
              let body = message.body as? [String: Any] else {
            return
        }

        let event = body["event"] as? String ?? ""
        let readyState = body["readyState"] as? String ?? ""
        let urlString = body["url"] as? String ?? ""

        guard let url = URL(string: urlString) else {
            return
        }

        Task { @MainActor [weak self] in
            if event == "app-ready" {
                self?.store?.markPageAppReady(url: url)
            } else if Self.isInteractiveEvent(event: event, readyState: readyState) {
                self?.store?.markPageInteractive(url: url)
            }
        }
    }

    private nonisolated static func isInteractiveEvent(
        event: String,
        readyState: String
    ) -> Bool {
        switch event {
        case "DOMContentLoaded", "window-load":
            return true
        default:
            return readyState == "interactive" || readyState == "complete"
        }
    }
}

#endif
