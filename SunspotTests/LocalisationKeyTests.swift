import Testing
import SwiftUI
@testable import Sunspot

/// What key an interpolated string actually asks the catalogue for.
///
/// This is here because five strings shipped in English to German and French readers while
/// every check in the project said the translations were complete. The catalogue held them
/// under `%1$lld … %2$@`, on the reasonable-sounding assumption that more than one
/// interpolation means positional specifiers. It does not. Both interpolation types below
/// emit plain `%lld` and `%@` however many arguments there are, so the catalogue was answering
/// a question nobody asked and the app fell back to the key — which reads as English.
///
/// Nothing warned about it: it builds, it runs, and it only shows up by looking at a German
/// screen. So the rule is pinned here rather than remembered, and `check-localisation.py`
/// computes keys the same way.
struct LocalisationKeyTests {

    private func swiftUIKey(_ value: LocalizedStringKey) -> String? {
        Mirror(reflecting: value).children.first { $0.label == "key" }?.value as? String
    }

    private func foundationKey(_ value: String.LocalizationValue) -> String? {
        Mirror(reflecting: value).children.first { $0.label == "key" }?.value as? String
    }

    @Test func swiftUIUsesPlainSpecifiersEvenWithSeveralArguments() {
        let minutes = 20
        let time = "08:10"
        #expect(swiftUIKey("around \(time) tomorrow") == "around %@ tomorrow")
        #expect(swiftUIKey("\(minutes) minutes before — around \(time) tomorrow.")
                == "%lld minutes before — around %@ tomorrow.")
        #expect(swiftUIKey("\(minutes)° of the \(minutes)° the sun crosses here")
                == "%lld° of the %lld° the sun crosses here")
    }

    @Test func foundationUsesTheSameSpecifiers() {
        let minutes = 20
        let time = "08:10"
        #expect(foundationKey("The sun reaches this spot in \(minutes) minutes, at \(time).")
                == "The sun reaches this spot in %lld minutes, at %@.")
    }
}
