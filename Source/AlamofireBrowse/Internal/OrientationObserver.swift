#if os(iOS)

import SwiftUI
import Combine
import UIKit

@MainActor
final class OrientationObserver: ObservableObject {

    enum Layout {
        case portrait
        case landscapeIslandLeading
        case landscapeIslandTrailing
    }

    @Published private(set) var layout: Layout = .portrait

    private var observer: NSObjectProtocol?

    init() {
        update()
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        observer = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.update()
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    private func update() {
        let interfaceOrientation = Self.currentInterfaceOrientation()
        switch interfaceOrientation {
        case .landscapeLeft:
            // Device rotated so its top edge points right → Dynamic Island on the right.
            layout = .landscapeIslandTrailing
        case .landscapeRight:
            // Device rotated so its top edge points left → Dynamic Island on the left.
            layout = .landscapeIslandLeading
        default:
            layout = .portrait
        }
    }

    private static func currentInterfaceOrientation() -> UIInterfaceOrientation {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.interfaceOrientation ?? .portrait
    }
}

#endif
