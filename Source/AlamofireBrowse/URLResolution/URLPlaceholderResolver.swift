#if os(iOS)

import Foundation

@MainActor
@available(iOS 16.0, *)
public protocol URLPlaceholderResolver {

    var name: String { get }

    func resolve(_ url: URL) -> URL?
}

#endif
