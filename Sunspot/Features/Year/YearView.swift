import SwiftUI
import SpotKit
import Charts
import SolarCore

/// The whole year at this spot, answered in words before it is drawn.
struct YearView: View {
    @Environment(SpotStore.self) private var store
    @Environment(Purchases.self) private var purchases

    @State private var year: SunYear?
    @State private var computedFor: Spot?

    private var thisYear: Int { Calendar.current.component(.year, from: .now) }

    var body: some View {
        NavigationStack {
            Group {
                if !purchases.isUnlocked {
                    Paywall()
                } else if let spot = store.spot {
                    if let year, computedFor == spot {
                        Content(spot: spot, year: year)
                    } else {
                        ProgressView("Working out the year")
                            .task(id: spot) { await compute(for: spot) }
                    }
                } else {
                    ContentUnavailableView(
                        "No spot yet",
                        systemImage: "calendar",
                        description: Text("Once there is a spot, this shows how its sun changes across the year.")
                    )
                }
            }
            .navigationTitle("Year")
        }
    }

    /// Off the main actor: a year is a few hundred thousand sun positions and would hold
    /// the screen still if it ran where the screen is drawn.
    private func compute(for spot: Spot) async {
        let wanted = thisYear
        let computed = await Task.detached(priority: .userInitiated) {
            SunYear(spot: spot, year: wanted)
        }.value
        guard !Task.isCancelled else { return }
        year = computed
        computedFor = spot
    }
}

private struct Content: View {
    let spot: Spot
    let year: SunYear

    var body: some View {
        List {
            Section {
                Verdict(spot: spot, year: year)
                    .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
            }

            Section("Across the year") {
                YearChart(year: year, timeZone: spot.timeZone)
                    .frame(height: 220)
                    .listRowInsets(EdgeInsets(top: 16, leading: 12, bottom: 8, trailing: 16))
            }

            if !spot.hasMeasuredSkyline {
                Section {
                    Label(
                        "This is open sky. Trace the roofs and trees on the Sky screen and the shape of this year will change — often dramatically in winter.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.orange)
                }
            }
        }
    }
}

/// The part somebody would repeat to a neighbour.
private struct Verdict: View {
    let spot: Spot
    let year: SunYear

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let season = year.season(atLeast: .fullSun) {
                Line(
                    icon: "sun.max.fill", tint: .orange,
                    title: "Full sun \(Format.dateRange(season, in: spot.timeZone))",
                    detail: "Six hours or more. Tomatoes, peppers and most vegetables want this window."
                )
            } else if let season = year.season(atLeast: .partSun) {
                Line(
                    icon: "sun.min.fill", tint: .yellow,
                    title: "Best it gets: part sun \(Format.dateRange(season, in: spot.timeZone))",
                    detail: "Never six hours in a day. Beans, carrots and herbs will manage; fruiting crops will not."
                )
            } else {
                Line(
                    icon: "cloud.fill", tint: .gray,
                    title: "Never more than four hours",
                    detail: "A shade bed. Ferns and hostas rather than anything that has to ripen."
                )
            }

            if let blackout = year.blackout {
                Line(
                    icon: "moon.fill", tint: .indigo,
                    title: "No direct sun at all \(Format.dateRange(blackout, in: spot.timeZone))",
                    detail: "The sun never clears the skyline here on those days."
                )
            }

            if let best = year.sunniest {
                Line(
                    icon: "chart.line.uptrend.xyaxis", tint: .green,
                    title: "Most sun: \(Format.duration(minutes: best.minutes)) on \(Format.day(best.date, in: spot.timeZone))",
                    detail: nil
                )
            }
        }
    }

    private struct Line: View {
        let icon: String
        let tint: Color
        let title: String
        let detail: String?

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .font(.title3)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    if let detail {
                        Text(detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct YearChart: View {
    let year: SunYear
    let timeZone: TimeZone

    var body: some View {
        Chart {
            ForEach(year.days) { day in
                AreaMark(
                    x: .value("Date", day.date),
                    y: .value("Hours", Double(day.minutes) / 60)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [.orange.opacity(0.65), .orange.opacity(0.08)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)
            }

            // The line growers actually care about.
            RuleMark(y: .value("Full sun", 6))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(.secondary)
                .annotation(position: .top, alignment: .leading) {
                    Text("full sun").font(.caption2).foregroundStyle(.secondary)
                }
        }
        .chartYAxisLabel("hours of sun")
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 2)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
        // Fit the data rather than reserving room for a polar summer nobody here will see.
        .chartYScale(domain: 0...max(4, ceil(Double(year.sunniest?.minutes ?? 0) / 60) + 1))
    }
}
