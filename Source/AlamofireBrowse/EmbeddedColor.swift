#if os(iOS)

import SwiftUI

@available(iOS 16.0, *)
public struct EmbeddedColor: Sendable, Equatable {

    public var red: Double
    public var green: Double
    public var blue: Double
    public var opacity: Double

    public init(
        red: Double,
        green: Double,
        blue: Double,
        opacity: Double = 1.0
    ) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    public init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }

    public static let webViewSafeArea = EmbeddedColor(hex: 0x1C211D)

    var swiftUIColor: Color {
        Color(
            .sRGB,
            red: red,
            green: green,
            blue: blue,
            opacity: opacity
        )
    }
}

#endif
