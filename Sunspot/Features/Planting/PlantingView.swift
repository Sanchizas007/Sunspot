import SwiftUI
import SolarCore
import SpotKit

/// What will actually grow at this spot.
///
/// The number is the answer to the question people asked. This is the answer to the question
/// behind it: they were never really wondering how many hours the bed gets, they were
/// wondering whether the tomatoes would ripen in it.
struct PlantingView: View {
    let spot: Spot
    let minutes: Int

    private var hours: Double { Double(minutes) / 60 }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(Format.duration(minutes: minutes)) of direct sun")
                        .font(.headline)
                    Text("At \(spot.name), today. The year matters too — a bed that manages six hours in June may get two in September.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            group("Will do well here", Plant.thriving(atHours: hours), tint: .green)
            group("Will manage", Plant.managing(atHours: hours), tint: .orange)
            group("Too much sun here", Plant.scorching(atHours: hours), tint: .red)

            Section {
                Text("Sun is one thing of several. Soil, water and wind decide plenty too, and none of them are in this app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("What will grow")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func group(_ title: LocalizedStringKey, _ plants: [Plant], tint: Color) -> some View {
        if !plants.isEmpty {
            Section(title) {
                ForEach(plants) { plant in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(LocalizedStringKey(plant.name))
                            Spacer()
                            Text("\(Format.hours(plant.minimumHours))+")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(tint)
                        }
                        if let note = plant.note {
                            Text(LocalizedStringKey(note)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
