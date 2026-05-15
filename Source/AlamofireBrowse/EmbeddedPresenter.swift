#if os(iOS)

import Foundation
import Combine
import WebKit

@MainActor
@available(iOS 16.0, *)
public final class EmbeddedPresenter: ObservableObject {

    public enum Stage: Sendable {
        case idle
        case primed
        case waitingForFirstLoad
        case ready
    }

    @Published public private(set) var phase: Stage = .idle
    @Published public private(set) var url: URL?

    public let store: EmbeddedSiteState
    public let configuration: EmbeddedConfig

    private var initialLoadCancellable: AnyCancellable?
    private var processTerminationCancellable: AnyCancellable?
    private var readySettlingTask: Task<Void, Never>?
    private var hasStartedLoading = false
    private var primeToken: UUID?
    private var prewarmToken: UUID?

    public init(
        configuration: EmbeddedConfig
    ) {
        self.configuration = configuration
        self.store = EmbeddedSiteState()
    }

    public func warmUp(url: URL) {
        let isSameRoute = self.url == url
        prewarmToken = nil
        self.url = url
        if store.homeURL == nil {
            store.setHomeURL(url)
        }

        if isSameRoute, phase == .ready {
            return
        }

        resetInitialLoadWatch()
        phase = .primed

        let token = UUID()
        primeToken = token

        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self,
                  self.primeToken == token,
                  self.url == url else {
                return
            }

            self.store.preparePresentation(
                configuration: self.configuration,
                initialURL: url
            )
        }
    }

    public func startPresentation() {
        guard let url else { return }

        observeWebContentProcessTermination()
        watchInitialLoad()

        if store.pageAppReady ||
            store.pageBecameInteractive ||
            isFallbackReady(for: url) {
            phase = .ready
            resetInitialLoadWatch()
            return
        }

        if phase != .ready {
            phase = .waitingForFirstLoad
        }
    }

    public func reset() {
        primeToken = nil
        prewarmToken = nil
        resetInitialLoadWatch()
        processTerminationCancellable = nil
        url = nil
        phase = .idle
        store.setHomeURL(nil)
    }

    private func watchInitialLoad() {
        guard initialLoadCancellable == nil else { return }

        hasStartedLoading = false

        initialLoadCancellable = Publishers.CombineLatest4(
            store.$isLoading,
            store.$pageBecameInteractive,
            store.$pageAppReady,
            store.$completedNavigationCount
        )
            .sink { [weak self] isLoading, pageBecameInteractive, pageAppReady, _ in
                guard let self else { return }
                guard let url = self.url else { return }

                if pageAppReady {
                    self.scheduleReadyTransition()
                    return
                }

                if pageBecameInteractive {
                    self.scheduleReadyTransition()
                    return
                }

                if isLoading {
                    self.hasStartedLoading = true

                    if self.phase != .ready {
                        self.phase = .waitingForFirstLoad
                    }
                    return
                }

                guard self.isFallbackReady(for: url) else {
                    return
                }

                self.scheduleReadyTransition()
            }
    }

    private func observeWebContentProcessTermination() {
        guard processTerminationCancellable == nil else { return }

        processTerminationCancellable = store.$contentProcessTerminationCount
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, self.url != nil else { return }
                self.readySettlingTask?.cancel()
                self.readySettlingTask = nil
                self.hasStartedLoading = false
                if self.phase != .idle {
                    self.phase = .waitingForFirstLoad
                }
            }
    }

    private func resetInitialLoadWatch() {
        initialLoadCancellable = nil
        readySettlingTask?.cancel()
        readySettlingTask = nil
        hasStartedLoading = false
    }

    private func scheduleReadyTransition() {
        guard phase != .ready, readySettlingTask == nil else { return }

        readySettlingTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, let self else { return }

            self.phase = .ready
            if let landing = self.store.currentURL {
                self.store.setHomeURL(landing)
            }
            self.resetInitialLoadWatch()
        }
    }

    private func isFallbackReady(for url: URL) -> Bool {
        !store.isLoading &&
        store.estimatedProgress >= 1.0 &&
        (store.didFinishLoad(for: url) || store.hasCompletedVisibleLoad())
    }
}

#endif
