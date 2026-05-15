#if os(iOS)

import Combine
import UIKit

@MainActor
@available(iOS 16.0, *)
final class KeyboardObserver: ObservableObject {

    @Published private(set) var isKeyboardVisible: Bool = false

    private var cancellables: Set<AnyCancellable> = []

    init() {
        let center = NotificationCenter.default

        center.publisher(for: UIResponder.keyboardWillShowNotification)
            .merge(with: center.publisher(for: UIResponder.keyboardDidShowNotification))
            .sink { [weak self] _ in self?.isKeyboardVisible = true }
            .store(in: &cancellables)

        center.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in self?.isKeyboardVisible = false }
            .store(in: &cancellables)
    }
}

#endif
