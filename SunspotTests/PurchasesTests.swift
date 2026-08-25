import Testing
import StoreKit
@testable import Sunspot

/// What can honestly be checked without a store, and a plain note about what cannot.
///
/// Two things were tried and abandoned here, both worth recording so nobody spends the
/// afternoon again.
///
/// `SKTestSession` does not function under `xcodebuild test` in this project: it constructs
/// without complaint from either bundle and then reports an empty storefront and no
/// products, and will not accept a storefront when one is assigned. Five approaches were
/// tried.
///
/// Anything that reaches StoreKit without a test store — `Product.products`, `AppStore.sync`
/// — goes out to the real App Store and sits there, turning a two-second suite into a
/// two-minute one. So the tests below never touch the network.
///
/// **Still to be checked by hand, once, from Xcode:** run the app, open the Year tab, and
/// confirm the paywall shows a price rather than "Can't reach the App Store", then buy it.
/// That is precisely the failure a wrong path in the scheme produces, and it is silent.
/// `Tools/check.sh` guards everything short of the purchase: that the file the scheme names
/// exists, and that its product, type, price and storefront are right and its identifier
/// still matches the one in the code.
@MainActor
struct PurchasesTests {

    @Test("Nothing is unlocked before the store has said anything")
    func startsLocked() {
        let purchases = Purchases()
        #expect(!purchases.isUnlocked)
        #expect(purchases.state == .loading)
        #expect(purchases.lastError == nil)
        #expect(!purchases.isWorking)
    }

    @Test("Buying with nothing loaded does nothing rather than crashing")
    func buyingWithoutAProductIsSafe() async {
        let purchases = Purchases()
        await purchases.buy()

        #expect(!purchases.isUnlocked)
        #expect(!purchases.isWorking, "the working flag must not be left stuck on")
    }

    @Test("The identifier the app asks for is the one it is meant to sell")
    func productIdentifierIsStable() {
        // Guards a rename in one place and not the other; check.sh compares this against the
        // configuration file itself.
        #expect(Purchases.productID == "app.sunspot.full")
    }

    @Test("Only an actual purchase counts as unlocked")
    func onlyPurchaseUnlocks() {
        // The states are deliberately not interchangeable: a store that cannot be reached is
        // a bad connection, not a refusal, and neither is a sale.
        #expect(Purchases.State.loading != .unlocked)
        #expect(Purchases.State.unavailable != .unlocked)
        #expect(Purchases.State.locked(price: "$5.99") != .unlocked)
    }
}
