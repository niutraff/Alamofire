#if os(iOS)

import SwiftUI
import Combine

@available(iOS 16.0, *)
struct EmbeddedToolbar: View {

    enum Placement {
        case bottom
        case leadingEdge
        case trailingEdge
    }

    @ObservedObject var store: EmbeddedSiteState
    let configuration: EmbeddedConfig
    var placement: Placement = .bottom

    private let iconSize: CGFloat = 20
    private let iconOffsetMagnitude: CGFloat = 8

    private var iconOffset: CGSize {
        switch placement {
        case .bottom:
            return CGSize(width: 0, height: iconOffsetMagnitude)
        case .leadingEdge:
            return CGSize(width: 0, height: 0)
        case .trailingEdge:
            return CGSize(width: 0, height: 0)
        }
    }

    private var isVertical: Bool {
        switch placement {
        case .bottom: return false
        case .leadingEdge, .trailingEdge: return true
        }
    }

    private var iconBarThickness:CGFloat {
        switch placement {
        case .bottom:
            return 14
        case .leadingEdge:
            return 40
        case .trailingEdge:
            return 40
        }
    }

    private let iconSpacing: CGFloat = 40

    var body: some View {
        Group {
            if isVertical {
                VStack(spacing: iconSpacing) { buttons }
                    .frame(maxHeight: .infinity)
                    .frame(width: iconBarThickness)
                    .background(configuration.safeAreaColor.swiftUIColor)
            } else {
                HStack(spacing: iconSpacing) { buttons }
                    .frame(maxWidth: .infinity)
                    .frame(height: iconBarThickness)
                    .background(configuration.safeAreaColor.swiftUIColor)
            }
        }
        .font(.system(size: iconSize, weight: .semibold))
    }

    @ViewBuilder
    private var buttons: some View {
        Button {
            store.stepBack()
        } label: {
            Image(systemName: "chevron.left")
                .offset(x: iconOffset.width, y: iconOffset.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!store.canGoBack)

        Button {
            store.stepForward()
        } label: {
            Image(systemName: "chevron.right")
                .offset(x: iconOffset.width, y: iconOffset.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!store.canGoForward)

        Button {
            store.goHome()
        } label: {
            Image(systemName: "house")
                .offset(x: iconOffset.width, y: iconOffset.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.homeURL == nil || store.currentURL == store.homeURL)

        Button {
            store.reload()
        } label: {
            Image(systemName: "arrow.clockwise")
                .offset(x: iconOffset.width, y: iconOffset.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#endif
