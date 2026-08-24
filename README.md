# Sunspot

**How much sun does this spot actually get?**

Every seed packet, plant label and solar-panel spec is written in hours of direct sun.
Almost nobody knows what their own garden, balcony or roof actually gets — so the tomatoes
go in the shady corner and never ripen, and the panels go on the side of the roof the
neighbour's lime tree shades from October.

Sunspot answers the question with a number.

Other sun apps show you where the sun is. That is the easy half. The half that decides the
answer is what stands in the way: the fence, the garage, the tree next door. Sunspot lets
you trace that skyline with the camera, then walks the day a minute at a time and counts
only the light that actually reaches the spot.

---

## Status

Early. The calculation engine is built and tested; the app around it is not yet written.

| Piece | State |
| --- | --- |
| `SolarCore` — sun position, skyline, sun-hours | ✅ built, 31 tests passing |
| iOS app — map, AR, skyline capture, paywall | ⬜ not started |
| Widget | ⬜ not started |

## The engine

`Packages/SolarCore` is a standalone Swift package with no dependencies. It runs anywhere
Swift runs, which means the maths can be tested from the command line without a simulator.

```bash
cd Packages/SolarCore
swift test
```

What it does:

- **`Solar.position(at:coordinate:)`** — the sun's azimuth and elevation for any place and
  moment, using the standard low-precision equations from Meeus's *Astronomical Algorithms*.
- **`HorizonProfile`** — the skyline around a spot, as a ring of measured heights that
  interpolates between samples and wraps across north.
- **`Solar.sunDay(containing:coordinate:timeZone:horizon:)`** — stretches of direct sun,
  the total, the first and last sun, and the longest unbroken run.
- **`Solar.sunYear(year:coordinate:timeZone:horizon:)`** — the same figure for every day of
  the year, for showing a bed that bakes in July sitting in shadow from October.
- **`SunExposure`** — grades a spot the way plant labels are worded: full sun, part sun,
  part shade, full shade.

### On accuracy

The engine is checked two ways, because self-consistency is not correctness.

**Against physics.** Quantities fixed by the geometry of the solar system, not by any
implementation of it: declination peaking at the axial tilt on the solstices and crossing
zero at the equinoxes, noon elevation equal to 90° minus the angle between your latitude and
the sun's, the noon sun due south in the northern hemisphere and due north in the southern,
midnight sun above the Arctic Circle and polar night below the Antarctic, the equation of
time staying inside its known envelope.

**Against the world.** Sunrise and sunset were compared with two independent providers on
2026-08-24. Where those two disagreed with each other, this engine matched Open-Meteo to
within a fraction of a minute; a separate check showed the other provider places sunrise
with the sun's centre near −1.08°, rather than the −0.833° its own documentation specifies.
Those reference times are pinned in `SunriseReferenceTests` so the agreement cannot quietly
rot.

Sunrise is taken at the moment the sun's apparent upper limb clears the skyline — 34
arcminutes of atmospheric refraction plus the disc's own 16-arcminute radius. Comparing the
bare geometric centre against a flat horizon instead costs a spot five to twelve minutes at
each end of the day, depending on latitude. Transitions are refined by bisection rather than
left on a one-minute grid, because a grid error always falls the same way and shortens the
day.

## Layout

```
Packages/SolarCore/        the maths, dependency-free and testable from a terminal
  Sources/SolarCore/
    Geometry.swift             coordinates, angles
    SolarPositionCalculator.swift  where the sun is
    HorizonProfile.swift       what stands in the way
    SunHours.swift             what that adds up to
  Tests/SolarCoreTests/
```

---

## Copyright and rights

Copyright © 2026 Sanchizas007. All rights reserved.

This repository is **public to read, not open source.** The source is published so the work
can be inspected, linked to and discussed. No licence is granted to use, copy, modify,
merge, publish, distribute, sublicense or sell any part of it, and no right is granted to
publish a derived or substantially similar application to any app store.

Reading the code, learning from it and quoting short excerpts with attribution is welcome.
Shipping it, in whole or in part, is not.

For any other use, ask first. See `LICENSE` for the full terms.
