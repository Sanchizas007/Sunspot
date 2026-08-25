import Testing
@testable import SpotKit

/// The spot tests themselves live in the app target, where they always have. This target
/// exists so the shared module is compiled and type-checked on its own, without the app
/// around it — which is exactly the situation the widget puts it in.
struct SpotKitBuilds {
    @Test("The shared module stands up without an app around it")
    func moduleLoads() {
        #expect(SpotArchive.appGroup == "group.app.sunspot")
    }
}
