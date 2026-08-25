import StoreKit
import Observation

/// One thing to buy, once, for good.
///
/// No RevenueCat: a single non-consumable is a hundred lines of StoreKit, and a service that
/// takes a percentage of every sale for the rest of the app's life is a strange price to pay
/// for that.
@MainActor
@Observable
final class Purchases {

    /// Outside the actor: it is a constant, and both the paywall and the tests that guard the
    /// configuration file need to name it from wherever they happen to be.
    nonisolated static let productID = "app.sunspot.full"

    enum State: Equatable {
        /// Still asking the store.
        case loading
        /// Not bought, and here is what it costs.
        case locked(price: String)
        /// Bought. Everything is open.
        case unlocked
        /// The store could not be reached. Treated as locked, but said differently — this is
        /// a bad aeroplane connection, not a refusal.
        case unavailable
    }

    private(set) var state: State = .loading
    private(set) var isWorking = false
    private(set) var lastError: String?

    var isUnlocked: Bool { state == .unlocked }

    private var product: Product?
    /// Kept out of observation and off the actor. Nothing watches it, and `deinit` belongs to
    /// no actor yet still has to cancel it; a `Task` is `Sendable`, so nothing is being
    /// smuggled past the compiler here.
    @ObservationIgnored
    private nonisolated(unsafe) var updates: Task<Void, Never>?

    /// Begins listening for purchases that arrive without a button being pressed: one
    /// finished on another device, or an interrupted one the system resumes later.
    ///
    /// Deliberately not done in `init`. `Transaction.updates` never ends, and an object that
    /// starts an endless task the moment it is created cannot be built in a test without
    /// leaving that task running behind it — which is exactly how a two-second suite turned
    /// into one that never finished.
    func startListening() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                guard case let .verified(transaction) = update else { continue }
                await transaction.finish()
                await self?.refreshEntitlement()
            }
        }
    }

    func stopListening() {
        updates?.cancel()
        updates = nil
    }

    deinit { updates?.cancel() }

    /// Asks the store what is on sale and whether it has already been bought.
    func load() async {
        await refreshEntitlement()
        guard state != .unlocked else { return }

        do {
            let products = try await Product.products(for: [Self.productID])
            guard let found = products.first else {
                state = .unavailable
                return
            }
            product = found
            state = .locked(price: found.displayPrice)
        } catch {
            state = .unavailable
        }
    }

    func buy() async {
        guard let product, !isWorking else { return }
        isWorking = true
        lastError = nil
        defer { isWorking = false }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case let .verified(transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlement()
                } else {
                    lastError = "That purchase could not be verified. Nothing has been charged."
                }
            case .userCancelled:
                break
            case .pending:
                // Ask-to-buy and similar: the answer arrives later through Transaction.updates.
                lastError = "Waiting for approval. It will unlock as soon as that comes through."
            @unknown default:
                break
            }
        } catch {
            lastError = "The purchase did not go through. Nothing has been charged."
        }
    }

    func restore() async {
        guard !isWorking else { return }
        isWorking = true
        lastError = nil
        defer { isWorking = false }

        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if state != .unlocked {
                lastError = "No earlier purchase found on this Apple Account."
            }
        } catch {
            lastError = "Could not reach the store to check. Try again in a moment."
        }
    }

    /// The single source of truth about whether this is paid for.
    private func refreshEntitlement() async {
        for await entitlement in Transaction.currentEntitlements {
            guard case let .verified(transaction) = entitlement,
                  transaction.productID == Self.productID,
                  transaction.revocationDate == nil
            else { continue }
            state = .unlocked
            return
        }
        // Not entitled. Leave a known price in place rather than dropping back to loading.
        if case .unlocked = state { state = .loading }
    }
}
