import Foundation

/// A 3×3 rotation matrix, row-major.
///
/// This is the shape Core Motion hands over in `CMAttitude.rotationMatrix`, kept here as a
/// plain value so the projection maths can be tested without a device — which matters,
/// because neither the camera nor the compass exists in a simulator.
public struct Rotation3: Sendable, Equatable {
    public var m11, m12, m13: Double
    public var m21, m22, m23: Double
    public var m31, m32, m33: Double

    public init(
        m11: Double, m12: Double, m13: Double,
        m21: Double, m22: Double, m23: Double,
        m31: Double, m32: Double, m33: Double
    ) {
        self.m11 = m11; self.m12 = m12; self.m13 = m13
        self.m21 = m21; self.m22 = m22; self.m23 = m23
        self.m31 = m31; self.m32 = m32; self.m33 = m33
    }

    public static let identity = Rotation3(
        m11: 1, m12: 0, m13: 0,
        m21: 0, m22: 1, m23: 0,
        m31: 0, m32: 0, m33: 1
    )

    /// Rotates a vector given in the reference frame into the device's own frame.
    func apply(_ v: (x: Double, y: Double, z: Double)) -> (x: Double, y: Double, z: Double) {
        (
            x: m11 * v.x + m12 * v.y + m13 * v.z,
            y: m21 * v.x + m22 * v.y + m23 * v.z,
            z: m31 * v.x + m32 * v.y + m33 * v.z
        )
    }
}

/// A point on the screen in normalised coordinates: −1…1 across and down, origin at centre.
public struct ScreenPoint: Sendable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    /// True when the point falls inside the visible frame.
    public var isOnScreen: Bool { abs(x) <= 1 && abs(y) <= 1 }
}

/// Where the back camera is pointing.
public struct CameraAim: Sendable, Equatable {
    /// Degrees clockwise from true north.
    public var azimuth: Double
    /// Degrees above the horizon.
    public var elevation: Double

    public init(azimuth: Double, elevation: Double) {
        self.azimuth = azimuth
        self.elevation = elevation
    }
}

/// Maps between directions in the sky and points on the camera image.
///
/// Both ways matter. Drawing the sun's arc over the live view needs sky → screen; letting
/// someone trace the roofline with a finger needs screen → sky, and the two have to be exact
/// inverses or the traced skyline will not sit where the person drew it.
///
/// The reference frame is Core Motion's true-north-and-vertical one: x points to true north,
/// y to west, z straight up. The device frame is Apple's usual one: x out of the right edge,
/// y out of the top edge, z out of the screen towards the viewer — so the back camera looks
/// along −z.
public struct SkyProjection: Sendable {

    public let rotation: Rotation3
    /// Full horizontal angle the camera sees, in degrees.
    public let horizontalFieldOfView: Double
    /// Full vertical angle the camera sees, in degrees.
    public let verticalFieldOfView: Double

    public init(rotation: Rotation3, horizontalFieldOfView: Double, verticalFieldOfView: Double) {
        self.rotation = rotation
        self.horizontalFieldOfView = horizontalFieldOfView
        self.verticalFieldOfView = verticalFieldOfView
    }

    /// Builds a projection from the horizontal field of view and the frame's shape.
    public init(rotation: Rotation3, horizontalFieldOfView: Double, aspectRatio: Double) {
        let halfHorizontal = radians(horizontalFieldOfView / 2)
        let halfVertical = atan(tan(halfHorizontal) / aspectRatio)
        self.init(
            rotation: rotation,
            horizontalFieldOfView: horizontalFieldOfView,
            verticalFieldOfView: degrees(halfVertical) * 2
        )
    }

    // MARK: - Which way the camera looks

    /// The direction the back camera is facing.
    ///
    /// The third row of the rotation matrix is the device's own z axis written in reference
    /// coordinates, and the camera looks the opposite way along it.
    public var aim: CameraAim {
        let forward = (x: -rotation.m31, y: -rotation.m32, z: -rotation.m33)
        return CameraAim(
            azimuth: wrap360(degrees(atan2(-forward.y, forward.x))),
            elevation: degrees(asin(min(1, max(-1, forward.z))))
        )
    }

    /// How far the camera is rolled from level, in degrees. Positive is clockwise.
    ///
    /// Shown to the person rather than silently corrected: a skyline traced with the phone
    /// tipped over is a skyline in the wrong place.
    public var roll: Double {
        // The device's x axis in reference coordinates is the first row of the matrix.
        let right = (x: rotation.m11, y: rotation.m12, z: rotation.m13)
        return degrees(asin(min(1, max(-1, right.z))))
    }

    // MARK: - Sky to screen

    /// How far outside the frame a point may land before it is refused.
    ///
    /// Twenty frame-widths is far past anything a person could see, and well inside what a
    /// drawing surface will accept. Without a ceiling the numbers here get genuinely wild:
    /// a phone held upright facing north puts a patch of sky near the zenith at 4,867 —
    /// close to a million points once scaled to a screen — and handing a path like that to
    /// Core Graphics takes the app down with it.
    public static let maximumOffscreenExtent: Double = 20

    /// Where a direction in the sky lands on the camera image.
    ///
    /// Returns `nil` when the direction is behind the camera, which is the case for most of
    /// the sun's arc most of the time, and when it is so far outside the frame that drawing
    /// it would be both pointless and dangerous.
    public func project(azimuth: Double, elevation: Double) -> ScreenPoint? {
        let device = rotation.apply(Self.unitVector(azimuth: azimuth, elevation: elevation))

        // The camera looks along −z, so anything with a non-negative z is behind it.
        //
        // The margin is not fussiness. A direction at exactly ninety degrees to the camera
        // axis lands on z = 0, and floating point delivers that as a value a hair either
        // side of zero. Take the negative one and the division below returns a coordinate
        // in the tens of quadrillions, which is not off-screen so much as poison for
        // whatever tries to draw it.
        let depth = -device.z
        guard depth > 1e-9 else { return nil }
        let x = (device.x / depth) / tan(radians(horizontalFieldOfView / 2))
        // Screen y runs downwards; the device's y axis runs up the screen.
        let y = (-device.y / depth) / tan(radians(verticalFieldOfView / 2))

        guard x.isFinite, y.isFinite,
              abs(x) <= Self.maximumOffscreenExtent,
              abs(y) <= Self.maximumOffscreenExtent
        else { return nil }

        return ScreenPoint(x: x, y: y)
    }

    // MARK: - Screen to sky

    /// Which direction in the sky sits under a point on the camera image.
    public func direction(at point: ScreenPoint) -> CameraAim {
        // Rebuild the ray in the device frame, then rotate it back into the world.
        let deviceRay = (
            x: point.x * tan(radians(horizontalFieldOfView / 2)),
            y: -point.y * tan(radians(verticalFieldOfView / 2)),
            z: -1.0
        )
        let world = Self.applyTransposed(rotation, deviceRay)
        let length = (world.x * world.x + world.y * world.y + world.z * world.z).squareRoot()
        guard length > 0 else { return aim }

        let unit = (x: world.x / length, y: world.y / length, z: world.z / length)
        return CameraAim(
            azimuth: wrap360(degrees(atan2(-unit.y, unit.x))),
            elevation: degrees(asin(min(1, max(-1, unit.z))))
        )
    }

    // MARK: - Vector helpers

    /// A unit vector in the reference frame for a direction in the sky.
    static func unitVector(azimuth: Double, elevation: Double) -> (x: Double, y: Double, z: Double) {
        let az = radians(azimuth)
        let el = radians(elevation)
        return (
            x: cos(el) * cos(az),   // north
            y: -cos(el) * sin(az),  // west, so east is negative
            z: sin(el)              // up
        )
    }

    /// Rotates a device-frame vector back into the reference frame.
    static func applyTransposed(
        _ r: Rotation3, _ v: (x: Double, y: Double, z: Double)
    ) -> (x: Double, y: Double, z: Double) {
        (
            x: r.m11 * v.x + r.m21 * v.y + r.m31 * v.z,
            y: r.m12 * v.x + r.m22 * v.y + r.m32 * v.z,
            z: r.m13 * v.x + r.m23 * v.y + r.m33 * v.z
        )
    }
}

extension SkyProjection {

    /// Works out how much sky the preview actually shows.
    ///
    /// The camera reports one number: the angle across its widest dimension. Turning that
    /// into the two angles the screen really covers takes two steps, and skipping either
    /// puts the sun's arc in the wrong place by several degrees.
    ///
    /// First, the sensor is landscape while the phone is held portrait, so its wide angle
    /// ends up running down the screen, not across it. Second, a preview that fills the view
    /// crops whichever dimension does not fit.
    ///
    /// - Parameters:
    ///   - cameraFieldOfView: the angle across the sensor's wide side, in degrees.
    ///   - sensorAspectRatio: the sensor's own width over height, usually 4∶3.
    ///   - viewAspectRatio: the preview's width over height on screen.
    ///   - isPortrait: whether the phone is held upright, turning the sensor on its side.
    public static func displayedFieldOfView(
        cameraFieldOfView: Double,
        sensorAspectRatio: Double = 4.0 / 3.0,
        viewAspectRatio: Double,
        isPortrait: Bool
    ) -> (horizontal: Double, vertical: Double) {

        let halfWide = tan(radians(cameraFieldOfView / 2))
        let halfNarrow = halfWide / sensorAspectRatio

        // Held portrait, the sensor's wide side runs top to bottom.
        let imageHalfHorizontal = isPortrait ? halfNarrow : halfWide
        let imageHalfVertical = isPortrait ? halfWide : halfNarrow
        let imageAspect = imageHalfHorizontal / imageHalfVertical

        let halfHorizontal: Double
        let halfVertical: Double
        if viewAspectRatio > imageAspect {
            // The view is wider than the image, so the image is scaled until its width fits
            // and its top and bottom are cropped away.
            halfHorizontal = imageHalfHorizontal
            halfVertical = imageHalfHorizontal / viewAspectRatio
        } else {
            halfVertical = imageHalfVertical
            halfHorizontal = imageHalfVertical * viewAspectRatio
        }

        return (
            horizontal: degrees(atan(halfHorizontal)) * 2,
            vertical: degrees(atan(halfVertical)) * 2
        )
    }
}
