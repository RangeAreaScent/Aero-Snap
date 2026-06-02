import Foundation
import Observation
import StoreKit

/// StoreKit purchase manager for Aero Snap Supporter (one-time IAP).
/// The product is **not yet registered** in App Store Connect at this
/// dev stage; `product` resolves to `nil` and the UI shows a clear
/// "purchases not available in this build" message. Once registration
/// lands the product loads automatically.
@MainActor
@Observable
final class PurchaseManager {
    static let shared = PurchaseManager()

    /// Locked at scaffold per playbook §4 scaffold-time gate.
    static let supporterProductID = "com.ryan.aerosnap.supporter"

    private(set) var product: Product?
    private(set) var isUnlocked = false
    private(set) var isWorking = false
    private(set) var lastError: String?

    private var transactionListener: Task<Void, Never>?

    private init() {
        // Persisted unlock cache so the UI doesn't flash "locked → unlocked"
        // on every cold start while the receipt verification runs.
        isUnlocked = UserDefaults.standard.bool(forKey: Self.cacheKey)
    }

    private static let cacheKey = "aerosnap.isSupporter"

    var priceDisplay: String { product?.displayPrice ?? "$2.99" }

    func start() async {
        transactionListener?.cancel()
        transactionListener = Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        await loadProduct()
        await refreshEntitlement()
    }

    func purchase() async -> Bool {
        guard let product else {
            lastError = "Purchases are not yet available in this build."
            return false
        }
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verification.payloadValue
                await transaction.finish()
                isUnlocked = true
                UserDefaults.standard.set(true, forKey: Self.cacheKey)
                lastError = nil
                return true
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async -> Bool {
        isWorking = true
        defer { isWorking = false }
        try? await AppStore.sync()
        await refreshEntitlement()
        return isUnlocked
    }

    private func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.supporterProductID])
            self.product = products.first
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func refreshEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result,
               t.productID == Self.supporterProductID,
               t.revocationDate == nil {
                isUnlocked = true
                UserDefaults.standard.set(true, forKey: Self.cacheKey)
                return
            }
        }
        // No active entitlement — leave the cached value as-is if the user
        // had previously purchased and is offline; clear only on explicit revoke.
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        if case .verified(let transaction) = result,
           transaction.productID == Self.supporterProductID {
            isUnlocked = transaction.revocationDate == nil
            UserDefaults.standard.set(isUnlocked, forKey: Self.cacheKey)
            await transaction.finish()
        }
    }

    // MARK: - Debug / TestFlight unlock

    /// Toggle the supporter unlock without going through StoreKit. Wired
    /// to the SecretTapDetector on the AboutView version row so beta
    /// testers and App Store reviewers can audit premium content without
    /// a sandbox purchase. Mirrors the cache key so the toggle survives
    /// a relaunch.
    ///
    /// Returns the new `isUnlocked` value for the caller to surface a
    /// confirmation (toast, haptic).
    @discardableResult
    func debugToggleUnlock() -> Bool {
        isUnlocked.toggle()
        UserDefaults.standard.set(isUnlocked, forKey: Self.cacheKey)
        return isUnlocked
    }
}
