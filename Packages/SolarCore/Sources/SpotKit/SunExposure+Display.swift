import Foundation
import SolarCore

public extension SunExposure {

    /// The wording used on seed packets and plant labels, which is where most people meet
    /// these terms in the first place — and where they meet them in their own language.
    var name: String {
        let key: String.LocalizationValue = switch self {
        case .fullSun: "exposure.fullSun"
        case .partSun: "exposure.partSun"
        case .partShade: "exposure.partShade"
        case .fullShade: "exposure.fullShade"
        }
        return String(localized: key, bundle: .module)
    }

    /// What that grade means in practice, in one line.
    var meaning: String {
        let key: String.LocalizationValue = switch self {
        case .fullSun: "exposure.fullSun.meaning"
        case .partSun: "exposure.partSun.meaning"
        case .partShade: "exposure.partShade.meaning"
        case .fullShade: "exposure.fullShade.meaning"
        }
        return String(localized: key, bundle: .module)
    }
}
