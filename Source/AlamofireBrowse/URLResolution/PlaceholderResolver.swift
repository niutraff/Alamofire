#if os(iOS)

import Foundation

@MainActor
@available(iOS 16.0, *)
public struct PlaceholderResolver: URLPlaceholderResolver {

    public typealias ValueProvider = @MainActor () -> String?

    public let name: String
    public let placeholders: [String]
    public let valueProvider: ValueProvider

    public init(
        name: String,
        placeholders: [String],
        valueProvider: @escaping ValueProvider
    ) {
        self.name = name
        self.placeholders = placeholders
        self.valueProvider = valueProvider
    }

    public func resolve(_ url: URL) -> URL? {
        guard containsPlaceholder(in: url),
              let value = valueProvider(), !value.isEmpty
        else { return nil }

        let raw = url.absoluteString
        var replaced = raw
        for placeholder in placeholders {
            replaced = replaced.replacingOccurrences(of: placeholder, with: value)
        }

        guard replaced != raw, let newURL = URL(string: replaced) else { return nil }
        return newURL
    }

    private func containsPlaceholder(in url: URL) -> Bool {
        let raw = url.absoluteString
        return placeholders.contains { raw.contains($0) }
    }
}

@available(iOS 16.0, *)
public extension PlaceholderResolver {

    static func subID(provider: @escaping ValueProvider) -> PlaceholderResolver {
        PlaceholderResolver(
            name: "subid",
            placeholders: ["{subid}", "{SUBID}", "%7Bsubid%7D", "%7BSUBID%7D"],
            valueProvider: provider
        )
    }

    static func sub6(provider: @escaping ValueProvider) -> PlaceholderResolver {
        PlaceholderResolver(
            name: "sub6",
            placeholders: ["{sub6}", "{SUB6}", "%7Bsub6%7D", "%7BSUB6%7D"],
            valueProvider: provider
        )
    }
}

#endif
