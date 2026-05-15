#if os(iOS)

import Foundation
import WebKit

@available(iOS 16.0, *)
final class CredentialAutofillLogger: NSObject, WKScriptMessageHandler {

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == CredentialAutofillScript.messageHandlerName else {
            return
        }
    }
}

#endif
