#if os(iOS)

import Foundation
import WebKit

@MainActor
@available(iOS 16.0, *)
final class CookiePersistenceKeeper: NSObject, WKHTTPCookieStoreObserver {

    private static let extendedExpiration: TimeInterval = 60 * 60 * 24 * 365 * 10
    private static let renewalThreshold: TimeInterval = 60 * 60 * 24 * 30
    private static let debounceInterval: TimeInterval = 5.0
    private static let postInteractiveDelay: TimeInterval = 2.0
    private static let upgradeCooldown: TimeInterval = 60.0
    private static let selfChangeSuppression: TimeInterval = 1.0

    private weak var cookieStore: WKHTTPCookieStore?
    private var debounceTask: Task<Void, Never>?
    private var postInteractiveTask: Task<Void, Never>?
    private var isUpgrading = false
    private var pendingChange = false
    private var loadingClients = 0
    private var isApplyingUpgrades = false
    private var hasInteractivePage = false
    private var ignoreChangesUntil: Date?
    private var lastUpgradeAt: Date?

    func attach(to cookieStore: WKHTTPCookieStore) {
        guard self.cookieStore !== cookieStore else { return }
        self.cookieStore?.remove(self)
        self.cookieStore = cookieStore
        cookieStore.add(self)
        pendingChange = true
    }

    func applyLoadingFlag(_ isLoading: Bool) {
        if isLoading {
            loadingClients += 1
            debounceTask?.cancel()
            debounceTask = nil
            postInteractiveTask?.cancel()
            postInteractiveTask = nil
            hasInteractivePage = false
        } else {
            loadingClients = max(0, loadingClients - 1)
            if loadingClients == 0, hasInteractivePage, pendingChange {
                scheduleUpgradeAfterPageSettles()
            }
        }
    }

    func scheduleUpgradeAfterPageSettles() {
        hasInteractivePage = true
        guard loadingClients == 0, pendingChange else { return }
        guard shouldAllowUpgrade() else { return }

        postInteractiveTask?.cancel()
        postInteractiveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.postInteractiveDelay))
            guard !Task.isCancelled, let self else { return }
            guard self.loadingClients == 0 else { return }
            self.scheduleDebouncedUpgrade()
        }
    }

    nonisolated func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        Task { @MainActor [weak self] in
            self?.handleCookieChange()
        }
    }

    private func handleCookieChange() {
        if isApplyingUpgrades {
            return
        }
        if let ignoreChangesUntil, Date() < ignoreChangesUntil {
            return
        }

        pendingChange = true
        guard loadingClients == 0 else { return }
        scheduleUpgradeAfterPageSettles()
    }

    private func scheduleDebouncedUpgrade() {
        guard !isUpgrading else { return }
        guard shouldAllowUpgrade() else { return }

        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.debounceInterval))
            guard !Task.isCancelled, let self else { return }
            guard self.loadingClients == 0 else {
                return
            }
            await self.runUpgrade()
        }
    }

    private func runUpgrade() async {
        guard let cookieStore, !isUpgrading else { return }
        guard shouldAllowUpgrade() else { return }
        isUpgrading = true
        pendingChange = false
        isApplyingUpgrades = true
        defer {
            isApplyingUpgrades = false
            ignoreChangesUntil = Date().addingTimeInterval(Self.selfChangeSuppression)
            isUpgrading = false
        }

        let cookies = await cookieStore.allCookies()
        let renewalCutoff = Date().addingTimeInterval(Self.renewalThreshold)
        let target = Date().addingTimeInterval(Self.extendedExpiration)

        for cookie in cookies {
            if loadingClients > 0 {
                pendingChange = true
                return
            }
            if let expires = cookie.expiresDate, expires > renewalCutoff {
                continue
            }
            guard let renewed = makePersistent(cookie, expires: target) else { continue }
            await cookieStore.setCookie(renewed)
            await Task.yield()
        }

        lastUpgradeAt = Date()
    }

    private func shouldAllowUpgrade() -> Bool {
        guard let lastUpgradeAt else { return true }
        return Date().timeIntervalSince(lastUpgradeAt) >= Self.upgradeCooldown
    }

    private func makePersistent(_ cookie: HTTPCookie, expires: Date) -> HTTPCookie? {
        var props = cookie.properties ?? [:]
        props[.name] = cookie.name
        props[.value] = cookie.value
        props[.domain] = cookie.domain
        props[.path] = cookie.path
        props[.expires] = expires
        props[.discard] = "FALSE"
        if cookie.isSecure {
            props[.secure] = "TRUE"
        }
        if cookie.isHTTPOnly {
            props[.init("HttpOnly")] = "TRUE"
        }
        if let sameSite = cookie.sameSitePolicy {
            props[.sameSitePolicy] = sameSite.rawValue
        }
        return HTTPCookie(properties: props)
    }
}

#endif
