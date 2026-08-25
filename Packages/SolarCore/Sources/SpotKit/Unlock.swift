import Foundation

/// Whether the full picture has been paid for, written where the widget can see it.
///
/// The widget deliberately does not ask StoreKit itself. Its timeline is built in a
/// completion handler that predates Swift concurrency, so reaching for an asynchronous
/// entitlement there means smuggling a closure across an isolation boundary — the same
/// arrangement that took the Sky screen down with a runtime trap. The app already knows the
/// answer; it writes it down, and the widget reads it synchronously.
public enum Unlock {

    private static let key = "isUnlocked"

    private static var store: UserDefaults? {
        UserDefaults(suiteName: SpotArchive.appGroup)
    }

    /// True when the app last reported a valid purchase.
    ///
    /// A cached answer, so it is only as fresh as the last time the app ran. That is the
    /// right trade for a widget: the alternative is asking the App Store from an extension
    /// that has seconds to live, and being wrong when the network is slow.
    public static var isUnlocked: Bool {
        store?.bool(forKey: key) ?? false
    }

    /// Called by the app whenever it learns something new about the purchase.
    public static func record(isUnlocked: Bool) {
        store?.set(isUnlocked, forKey: key)
    }
}
