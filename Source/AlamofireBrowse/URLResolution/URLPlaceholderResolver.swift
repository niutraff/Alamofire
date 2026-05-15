#if os(iOS)

import Foundation

@MainActor
public protocol URLPlaceholderResolver {

    var name: String { get }

    func resolve(_ url: URL) -> URL?
}

#endif
