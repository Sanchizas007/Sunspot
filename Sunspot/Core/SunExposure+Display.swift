import SolarCore

extension SunExposure {

    /// The wording used on seed packets and plant labels, which is where most people meet
    /// these terms in the first place.
    var name: String {
        switch self {
        case .fullSun: "full sun"
        case .partSun: "part sun"
        case .partShade: "part shade"
        case .fullShade: "full shade"
        }
    }

    /// What that grade means in practice, in one line.
    var meaning: String {
        switch self {
        case .fullSun: "Tomatoes, peppers, lavender, most vegetables."
        case .partSun: "Enough for beans, carrots and most herbs."
        case .partShade: "Leafy greens and shade-tolerant shrubs."
        case .fullShade: "Ferns and hostas. Fruit will not ripen here."
        }
    }
}
