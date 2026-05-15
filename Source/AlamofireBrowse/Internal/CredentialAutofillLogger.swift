#if os(iOS)

import Foundation
import WebKit

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
