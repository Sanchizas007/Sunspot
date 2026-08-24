import Foundation

/// Where the sun is, for any spot on Earth at any moment.
///
/// The maths follows the standard low-precision solar equations from Jean Meeus,
/// *Astronomical Algorithms* (chapters 25 and 13) — the same set NOAA publishes in
/// its solar calculator. Accuracy is well under a tenth of a degree for dates within
/// a few centuries of today, which is far finer than a phone's compass can resolve.
///
/// Everything here is pure arithmetic: no network, no data files, no clock beyond the
/// `Date` you hand it.
public enum Solar {

    // MARK: - Time

    /// Julian Day for an instant. Day 2451545.0 is 2000-01-01 12:00 UTC.
    public static func julianDay(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86400 + 2440587.5
    }

    /// Julian centuries since J2000.0.
    static func julianCentury(_ julianDay: Double) -> Double {
        (julianDay - 2451545.0) / 36525
    }

    // MARK: - The sun in the sky

    /// The geometric position of the sun's centre, ignoring atmospheric refraction.
    ///
    /// Geometric rather than apparent is deliberate: shade calculations compare the sun
    /// against physical obstructions, and refraction only matters within about half a
    /// degree of the horizon. Use ``apparentElevation(forGeometric:)`` when you need the
    /// elevation a person would actually see.
    public static func position(at date: Date, coordinate: GeoCoordinate) -> SolarPosition {
        let jd = julianDay(date)
        let t = julianCentury(jd)
        let s = sunEclipticState(t)

        // Hour angle: how far the sun is from the local meridian, in degrees.
        // Negative before local solar noon, positive after.
        let minutesIntoUTCDay = ((jd + 0.5) - (jd + 0.5).rounded(.down)) * 1440
        let trueSolarMinutes = minutesIntoUTCDay + s.equationOfTimeMinutes + 4 * coordinate.longitude
        var hourAngle = trueSolarMinutes / 4 - 180
        hourAngle = hourAngle.truncatingRemainder(dividingBy: 360)
        if hourAngle < -180 { hourAngle += 360 }
        if hourAngle > 180 { hourAngle -= 360 }

        let ha = radians(hourAngle)
        let lat = radians(coordinate.latitude)
        let dec = s.declination

        let sinElevation = sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(ha)
        let elevation = asin(min(1, max(-1, sinElevation)))

        // Meeus 13.5 gives the azimuth measured from south, westward. Adding 180 turns it
        // into the compass convention: clockwise from true north.
        let azimuthFromSouth = atan2(sin(ha), cos(ha) * sin(lat) - tan(dec) * cos(lat))
        let azimuth = wrap360(degrees(azimuthFromSouth) + 180)

        return SolarPosition(azimuth: azimuth, elevation: degrees(elevation))
    }

    /// The sun's declination in degrees — how far north or south of the celestial equator
    /// it sits. Swings between about ±23.44° over the year.
    public static func declination(at date: Date) -> Double {
        degrees(sunEclipticState(julianCentury(julianDay(date))).declination)
    }

    /// The equation of time in minutes: how far a sundial runs ahead of or behind the clock.
    public static func equationOfTimeMinutes(at date: Date) -> Double {
        sunEclipticState(julianCentury(julianDay(date))).equationOfTimeMinutes
    }

    /// Elevation as the eye sees it, with the atmosphere's bending added back in.
    ///
    /// Uses Sæmundsson's formula. The correction is about 34 arcminutes at the horizon
    /// and falls away to nothing overhead.
    public static func apparentElevation(forGeometric elevation: Double) -> Double {
        guard elevation > -5 else { return elevation }
        let refractionArcminutes = 1.02 / tan(radians(elevation + 10.3 / (elevation + 5.11)))
        return elevation + refractionArcminutes / 60
    }

    // MARK: - Shared intermediate terms

    struct EclipticState {
        var declination: Double          // radians
        var equationOfTimeMinutes: Double
    }

    static func sunEclipticState(_ t: Double) -> EclipticState {
        // Geometric mean longitude and mean anomaly of the sun.
        let l0 = wrap360(280.46646 + t * (36000.76983 + t * 0.0003032))
        let m = 357.52911 + t * (35999.05029 - t * 0.0001537)
        let e = 0.016708634 - t * (0.000042037 + t * 0.0000001267)

        let mRad = radians(m)
        let centre = sin(mRad) * (1.914602 - t * (0.004817 + t * 0.000014))
                   + sin(2 * mRad) * (0.019993 - t * 0.000101)
                   + sin(3 * mRad) * 0.000289
        let trueLongitude = l0 + centre

        // Nutation and aberration, folded into an apparent longitude.
        let omega = radians(125.04 - 1934.136 * t)
        let apparentLongitude = trueLongitude - 0.00569 - 0.00478 * sin(omega)

        // Obliquity of the ecliptic — the tilt of the Earth's axis.
        let seconds = 21.448 - t * (46.8150 + t * (0.00059 - t * 0.001813))
        let meanObliquity = 23 + (26 + seconds / 60) / 60
        let obliquity = radians(meanObliquity + 0.00256 * cos(omega))

        let lambda = radians(apparentLongitude)
        let declination = asin(min(1, max(-1, sin(obliquity) * sin(lambda))))

        let y = pow(tan(obliquity / 2), 2)
        let l0Rad = radians(l0)
        let eot = 4 * degrees(
            y * sin(2 * l0Rad)
            - 2 * e * sin(mRad)
            + 4 * e * y * sin(mRad) * cos(2 * l0Rad)
            - 0.5 * y * y * sin(4 * l0Rad)
            - 1.25 * e * e * sin(2 * mRad)
        )

        return EclipticState(declination: declination, equationOfTimeMinutes: eot)
    }
}
