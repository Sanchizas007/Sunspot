import Foundation

/// What a plant wants, in the only unit this app deals in: hours of direct sun.
///
/// The figures are the ordinary horticultural ones — the same numbers printed on seed packets
/// and plant labels, which is where most people meet them. They are a guide and not a promise:
/// soil, water and wind decide plenty too, and nothing here knows about those.
struct Plant: Identifiable, Hashable {

    enum Kind: String, CaseIterable {
        case vegetable, herb, fruit, flower, shrub

        var title: String {
            switch self {
            case .vegetable: "Vegetables"
            case .herb: "Herbs"
            case .fruit: "Fruit"
            case .flower: "Flowers"
            case .shrub: "Shrubs and climbers"
            }
        }
    }

    let name: String
    /// Below this it will not really work.
    let minimumHours: Double
    /// At or above this it is in its element.
    let idealHours: Double
    let kind: Kind
    let note: String?

    var id: String { name }

    /// How a spot suits this plant.
    enum Verdict {
        case thrives
        case manages
        case tooDark
        /// More sun than it wants — worth saying for the shade lovers.
        case tooBright
    }

    func verdict(forHours hours: Double) -> Verdict {
        if hours < minimumHours { return .tooDark }
        // A handful of plants genuinely suffer in full sun; scorched hostas are a real thing.
        if let ceiling = maximumHours, hours > ceiling { return .tooBright }
        return hours >= idealHours ? .thrives : .manages
    }

    /// Only the shade lovers have one.
    var maximumHours: Double? {
        idealHours < 3 ? 5 : nil
    }
}

extension Plant {

    /// A short, ordinary list. Enough to turn a number into a decision, and no attempt at
    /// being an encyclopaedia — a long list nobody trusts is worse than a short one they do.
    static let all: [Plant] = [
        // Vegetables
        Plant(name: "Tomatoes", minimumHours: 6, idealHours: 8, kind: .vegetable,
              note: "Fruit will not ripen properly under six hours."),
        Plant(name: "Peppers and chillies", minimumHours: 6, idealHours: 8, kind: .vegetable, note: nil),
        Plant(name: "Aubergine", minimumHours: 6, idealHours: 8, kind: .vegetable, note: nil),
        Plant(name: "Courgettes", minimumHours: 6, idealHours: 7, kind: .vegetable, note: nil),
        Plant(name: "Cucumbers", minimumHours: 6, idealHours: 7, kind: .vegetable, note: nil),
        Plant(name: "Sweetcorn", minimumHours: 6, idealHours: 8, kind: .vegetable, note: nil),
        Plant(name: "Beans", minimumHours: 4, idealHours: 6, kind: .vegetable, note: nil),
        Plant(name: "Peas", minimumHours: 4, idealHours: 6, kind: .vegetable, note: nil),
        Plant(name: "Onions and garlic", minimumHours: 5, idealHours: 6, kind: .vegetable, note: nil),
        Plant(name: "Carrots", minimumHours: 4, idealHours: 6, kind: .vegetable, note: nil),
        Plant(name: "Beetroot", minimumHours: 4, idealHours: 6, kind: .vegetable, note: nil),
        Plant(name: "Potatoes", minimumHours: 5, idealHours: 6, kind: .vegetable, note: nil),
        Plant(name: "Radishes", minimumHours: 3, idealHours: 4, kind: .vegetable,
              note: "Quick enough to fit into a gap between other crops."),
        Plant(name: "Lettuce", minimumHours: 3, idealHours: 4, kind: .vegetable,
              note: "Bolts in a hot, wide-open spot. Afternoon shade suits it."),
        Plant(name: "Spinach", minimumHours: 3, idealHours: 4, kind: .vegetable, note: nil),
        Plant(name: "Kale and chard", minimumHours: 3, idealHours: 5, kind: .vegetable, note: nil),
        Plant(name: "Rocket", minimumHours: 2, idealHours: 4, kind: .vegetable, note: nil),

        // Herbs
        Plant(name: "Basil", minimumHours: 6, idealHours: 7, kind: .herb, note: nil),
        Plant(name: "Rosemary", minimumHours: 6, idealHours: 8, kind: .herb, note: nil),
        Plant(name: "Thyme", minimumHours: 6, idealHours: 8, kind: .herb, note: nil),
        Plant(name: "Oregano", minimumHours: 5, idealHours: 7, kind: .herb, note: nil),
        Plant(name: "Sage", minimumHours: 5, idealHours: 7, kind: .herb, note: nil),
        Plant(name: "Coriander", minimumHours: 3, idealHours: 5, kind: .herb,
              note: "Runs to seed fast in strong sun."),
        Plant(name: "Parsley", minimumHours: 3, idealHours: 5, kind: .herb, note: nil),
        Plant(name: "Chives", minimumHours: 3, idealHours: 5, kind: .herb, note: nil),
        Plant(name: "Mint", minimumHours: 2, idealHours: 4, kind: .herb,
              note: "Happy in shade, and will take over a bed given the chance."),

        // Fruit
        Plant(name: "Strawberries", minimumHours: 5, idealHours: 7, kind: .fruit, note: nil),
        Plant(name: "Raspberries", minimumHours: 4, idealHours: 6, kind: .fruit, note: nil),
        Plant(name: "Blackcurrants", minimumHours: 3, idealHours: 5, kind: .fruit, note: nil),
        Plant(name: "Apple and pear trees", minimumHours: 6, idealHours: 8, kind: .fruit, note: nil),
        Plant(name: "Grapes", minimumHours: 7, idealHours: 9, kind: .fruit, note: nil),

        // Flowers
        Plant(name: "Sunflowers", minimumHours: 6, idealHours: 8, kind: .flower, note: nil),
        Plant(name: "Lavender", minimumHours: 6, idealHours: 8, kind: .flower, note: nil),
        Plant(name: "Roses", minimumHours: 5, idealHours: 6, kind: .flower, note: nil),
        Plant(name: "Geraniums", minimumHours: 4, idealHours: 6, kind: .flower, note: nil),
        Plant(name: "Foxgloves", minimumHours: 2, idealHours: 4, kind: .flower, note: nil),
        Plant(name: "Impatiens", minimumHours: 1, idealHours: 2, kind: .flower,
              note: "One of the few that flowers properly in real shade."),

        // Shrubs and climbers
        Plant(name: "Hydrangea", minimumHours: 3, idealHours: 4, kind: .shrub,
              note: "Wilts in an exposed spot through the afternoon."),
        Plant(name: "Clematis", minimumHours: 4, idealHours: 6, kind: .shrub, note: nil),
        Plant(name: "Ivy", minimumHours: 1, idealHours: 2, kind: .shrub, note: nil),
        Plant(name: "Hostas", minimumHours: 1, idealHours: 2, kind: .shrub,
              note: "Leaves scorch where the sun is strong."),
        Plant(name: "Ferns", minimumHours: 0, idealHours: 2, kind: .shrub, note: nil)
    ]

    /// Everything that will do well at a spot, best fit first.
    static func thriving(atHours hours: Double) -> [Plant] {
        all.filter { $0.verdict(forHours: hours) == .thrives }
            .sorted { $0.idealHours > $1.idealHours }
    }

    static func managing(atHours hours: Double) -> [Plant] {
        all.filter { $0.verdict(forHours: hours) == .manages }
            .sorted { $0.minimumHours > $1.minimumHours }
    }

    /// What wants less sun than this spot gets.
    static func scorching(atHours hours: Double) -> [Plant] {
        all.filter { $0.verdict(forHours: hours) == .tooBright }
    }
}
