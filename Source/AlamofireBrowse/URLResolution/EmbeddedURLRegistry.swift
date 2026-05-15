#if os(iOS)

import Foundation

@MainActor
@available(iOS 16.0, *)
public final class EmbeddedURLRegistry {

    public static let shared = EmbeddedURLRegistry()

    public private(set) var resolvers: [URLPlaceholderResolver] = []

    public init() {}

    public func register(_ resolver: URLPlaceholderResolver) {
        unregister(named: resolver.name)
        resolvers.append(resolver)
    }

    public func unregister(named name: String) {
        resolvers.removeAll { $0.name == name }
    }

    public func resolve(_ url: URL) -> URL? {
        guard !resolvers.isEmpty else { return nil }

        var current = url
        var changed = false

        for resolver in resolvers {
            guard let next = resolver.resolve(current) else { continue }
            current = next
            changed = true
        }

        return changed ? current : nil
    }
}

#endif
