import Testing
import Foundation
@testable import Sunspot

/// The list turns a number into a decision, so a wrong verdict is not a cosmetic slip: it is
/// somebody planting tomatoes where they will never ripen.
struct PlantTests {

    @Test("A full-sun bed grows the things full sun is for")
    func fullSunGrowsFruitingCrops() {
        let names = Set(Plant.thriving(atHours: 9).map(\.name))
        #expect(names.contains("Tomatoes"))
        #expect(names.contains("Lavender"))
        #expect(names.contains("Rosemary"))
    }

    @Test("A dark corner does not promise tomatoes")
    func deepShadeGrowsAlmostNothing() {
        let thriving = Plant.thriving(atHours: 1)
        #expect(!thriving.contains { $0.name == "Tomatoes" },
                "a spot with an hour of sun was offered tomatoes")

        // A dark corner must still be given something rather than a blank screen — even if
        // it is only "will manage", which for a fern at one hour is the honest word.
        let offered = Set(
            (thriving + Plant.managing(atHours: 1)).map(\.name)
        )
        #expect(offered.contains("Ferns") || offered.contains("Hostas"),
                "nothing at all was offered for a shady corner: \(offered)")
    }

    @Test("Every spot, however dark, is offered something")
    func nothingIsEverABlankScreen() {
        for hours in stride(from: 0.0, through: 14.0, by: 0.5) {
            let offered = Plant.thriving(atHours: hours).count
                + Plant.managing(atHours: hours).count
            #expect(offered > 0, "\(hours)h produced an empty list")
        }
    }

    @Test("Every plant lands in exactly one group")
    func verdictsDoNotOverlap() {
        for hours in stride(from: 0.0, through: 14.0, by: 0.5) {
            let thriving = Set(Plant.thriving(atHours: hours).map(\.name))
            let managing = Set(Plant.managing(atHours: hours).map(\.name))
            let scorching = Set(Plant.scorching(atHours: hours).map(\.name))

            #expect(thriving.isDisjoint(with: managing), "overlap at \(hours)h")
            #expect(thriving.isDisjoint(with: scorching), "overlap at \(hours)h")
            #expect(managing.isDisjoint(with: scorching), "overlap at \(hours)h")
        }
    }

    @Test("More sun never takes a plant off the list it was already on")
    func moreSunIsNeverWorseForSunLovers() {
        // Ignoring the shade lovers, which genuinely do get worse with more sun.
        for plant in Plant.all where plant.maximumHours == nil {
            var wasSuitable = false
            for hours in stride(from: 0.0, through: 14.0, by: 0.5) {
                let suitable = plant.verdict(forHours: hours) != .tooDark
                if wasSuitable {
                    #expect(suitable, "\(plant.name) stopped being suitable at \(hours)h")
                }
                wasSuitable = suitable
            }
        }
    }

    @Test("Shade lovers are warned about too much sun, not too little")
    func shadeLoversHaveACeiling() {
        let hosta = Plant.all.first { $0.name == "Hostas" }!
        #expect(hosta.verdict(forHours: 2) == .thrives)
        #expect(hosta.verdict(forHours: 9) == .tooBright, "scorched leaves are a real thing")
    }

    @Test("Nothing is offered a spot below what it needs")
    func minimumsAreRespected() {
        for plant in Plant.all {
            let justUnder = plant.minimumHours - 0.1
            if justUnder >= 0 {
                #expect(plant.verdict(forHours: justUnder) == .tooDark,
                        "\(plant.name) was offered \(justUnder)h when it needs \(plant.minimumHours)h")
            }
        }
    }

    @Test("Every plant is described well enough to be useful")
    func entriesAreSane() {
        #expect(Plant.all.count > 30, "too short a list to be worth opening")
        #expect(Set(Plant.all.map(\.name)).count == Plant.all.count, "a plant is listed twice")

        for plant in Plant.all {
            #expect(!plant.name.isEmpty)
            #expect(plant.minimumHours >= 0 && plant.minimumHours <= 12)
            #expect(plant.idealHours >= plant.minimumHours,
                    "\(plant.name) wants less sun ideally than it needs at minimum")
            if let note = plant.note {
                #expect(note.hasSuffix("."), "\(plant.name): \(note)")
            }
        }
    }

    @Test("Every kind of plant is represented")
    func everyKindHasEntries() {
        for kind in Plant.Kind.allCases {
            #expect(Plant.all.contains { $0.kind == kind }, "nothing listed under \(kind.title)")
        }
    }
}
