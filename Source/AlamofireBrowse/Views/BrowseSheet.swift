#if os(iOS)

import SwiftUI
import Combine
import SafariServices

@available(iOS 16.0, *)
struct EmbeddedSheetModifier: ViewModifier {

    @ObservedObject var store: EmbeddedSiteState

    func body(content: Content) -> some View {
        content.sheet(
            isPresented: Binding(
                get: { store.safariURL != nil },
                set: { if !$0 { store.safariURL = nil } }
            )
        ) {
            if let url = store.safariURL {
                ExternalSafariBridge(url: url) {
                    store.safariURL = nil
                }
                .ignoresSafeArea()
            }
        }
    }
}


@available(iOS 16.0, *)
struct ExternalSafariBridge: UIViewControllerRepresentable {

    let url: URL
    var onDismiss: (() -> Void)?

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(
        _ uiViewController: SFSafariViewController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        var onDismiss: (() -> Void)?

        init(onDismiss: (() -> Void)?) {
            self.onDismiss = onDismiss
        }

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onDismiss?()
        }
    }
}


@available(iOS 16.0, *)
extension View {
    func embeddedSheet(store: EmbeddedSiteState) -> some View {
        modifier(EmbeddedSheetModifier(store: store))
    }
}

#endif
