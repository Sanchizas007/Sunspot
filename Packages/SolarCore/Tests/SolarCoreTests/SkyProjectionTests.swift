import Testing
import Foundation
@testable import SolarCore

/// The projection cannot be checked by running the app: a simulator has neither a camera nor
/// a compass, so the first time this code meets a real device it has to already be right.
/// These build the rotation matrices by hand from known orientations.
///
/// The rule used throughout: each row of the matrix is one of the device's own axes written
/// in reference coordinates, where x is north, y is west and z is up. Row one is the phone's
/// right edge, row two its top edge, row three the direction out of its screen.
struct SkyProjectionTests {

    static func rotation(right: (Double, Double, Double),
                         top: (Double, Double, Double),
                         outOfScreen: (Double, Double, Double)) -> Rotation3 {
        Rotation3(
            m11: right.0, m12: right.1, m13: right.2,
            m21: top.0, m22: top.1, m23: top.2,
            m31: outOfScreen.0, m32: outOfScreen.1, m33: outOfScreen.2
        )
    }

    static let north = (1.0, 0.0, 0.0)
    static let south = (-1.0, 0.0, 0.0)
    static let west = (0.0, 1.0, 0.0)
    static let east = (0.0, -1.0, 0.0)
    static let up = (0.0, 0.0, 1.0)
    static let down = (0.0, 0.0, -1.0)

    /// Held upright in portrait, back camera facing north.
    static let facingNorth = rotation(right: east, top: up, outOfScreen: south)
    /// Held upright in portrait, back camera facing east.
    static let facingEast = rotation(right: south, top: up, outOfScreen: west)
    /// Lying flat on a table, screen up, top edge pointing north.
    static let flatOnTable = rotation(right: east, top: north, outOfScreen: up)
    /// Lying flat, screen down, so the camera stares at the sky.
    static let facingStraightUp = rotation(right: east, top: south, outOfScreen: down)

    static func projection(_ rotation: Rotation3, fov: Double = 60) -> SkyProjection {
        SkyProjection(rotation: rotation, horizontalFieldOfView: fov, verticalFieldOfView: fov)
    }

    // MARK: - Which way the camera looks

    @Test("A phone held up facing north reports north and level")
    func aimFacingNorth() {
        let aim = Self.projection(Self.facingNorth).aim
        #expect(abs(aim.azimuth) < 0.001 || abs(aim.azimuth - 360) < 0.001, "azimuth \(aim.azimuth)")
        #expect(abs(aim.elevation) < 0.001, "elevation \(aim.elevation)")
    }

    @Test("Turning to face east reads ninety degrees")
    func aimFacingEast() {
        let aim = Self.projection(Self.facingEast).aim
        #expect(abs(aim.azimuth - 90) < 0.001, "azimuth \(aim.azimuth)")
        #expect(abs(aim.elevation) < 0.001, "elevation \(aim.elevation)")
    }

    @Test("Face down on a table, the camera is looking at the table")
    func aimFlatOnTable() {
        #expect(abs(Self.projection(Self.flatOnTable).aim.elevation + 90) < 0.001)
    }

    @Test("Screen down, the camera is looking at the sky")
    func aimStraightUp() {
        #expect(abs(Self.projection(Self.facingStraightUp).aim.elevation - 90) < 0.001)
    }

    @Test("A level phone is not rolled; one turned on its side is")
    func rollIsReported() {
        #expect(abs(Self.projection(Self.facingNorth).roll) < 0.001)

        // Same direction, but the phone turned on its side so the right edge points at the
        // ground. The interface never follows it there — the app is portrait only — but the
        // physical device still rolls, and the arc has to stay where the sky is.
        let onItsSide = Self.rotation(right: Self.down, top: Self.east, outOfScreen: Self.south)
        #expect(abs(abs(Self.projection(onItsSide).roll) - 90) < 0.001,
                "roll was \(Self.projection(onItsSide).roll)")
    }

    // MARK: - Sky to screen

    @Test("Whatever the camera is aimed at lands in the middle of the frame")
    func aimPointLandsAtCentre() {
        for rotation in [Self.facingNorth, Self.facingEast, Self.facingStraightUp] {
            let projection = Self.projection(rotation)
            let aim = projection.aim
            let point = projection.project(azimuth: aim.azimuth, elevation: aim.elevation)
            let centre = try! #require(point)
            #expect(abs(centre.x) < 1e-9 && abs(centre.y) < 1e-9,
                    "landed at \(centre) instead of the centre")
        }
    }

    @Test("The edge of the field of view lands exactly at the edge of the frame")
    func fieldOfViewEdges() {
        let projection = Self.projection(Self.facingNorth, fov: 60)

        // Thirty degrees east of north is half a sixty-degree field away, so it belongs
        // at the right-hand edge.
        let right = try! #require(projection.project(azimuth: 30, elevation: 0))
        #expect(abs(right.x - 1) < 1e-9, "x was \(right.x)")
        #expect(abs(right.y) < 1e-9)

        let left = try! #require(projection.project(azimuth: 330, elevation: 0))
        #expect(abs(left.x + 1) < 1e-9, "x was \(left.x)")

        // Thirty degrees up belongs at the top, and screen y runs downwards.
        let top = try! #require(projection.project(azimuth: 0, elevation: 30))
        #expect(abs(top.y + 1) < 1e-9, "y was \(top.y)")
        #expect(abs(top.x) < 1e-9)
    }

    @Test("East is to the right and up is up when facing north")
    func screenAxesPointTheExpectedWay() {
        let projection = Self.projection(Self.facingNorth)
        let east = try! #require(projection.project(azimuth: 20, elevation: 0))
        let west = try! #require(projection.project(azimuth: 340, elevation: 0))
        let high = try! #require(projection.project(azimuth: 0, elevation: 20))
        let low = try! #require(projection.project(azimuth: 0, elevation: -20))

        #expect(east.x > 0, "east should be on the right, got \(east.x)")
        #expect(west.x < 0, "west should be on the left, got \(west.x)")
        #expect(high.y < 0, "higher in the sky should be higher up the screen, got \(high.y)")
        #expect(low.y > 0)
    }

    @Test("Anything behind the camera is refused rather than drawn in the wrong place")
    func behindTheCameraIsRefused() {
        let projection = Self.projection(Self.facingNorth)
        #expect(projection.project(azimuth: 180, elevation: 0) == nil, "due south is behind")
        #expect(projection.project(azimuth: 120, elevation: 0) == nil)
        #expect(projection.project(azimuth: 0, elevation: -90) == nil, "straight down is behind")
    }

    @Test("Points beyond the frame project outside it rather than being clipped silently")
    func outsideTheFrameStaysOutside() {
        let projection = Self.projection(Self.facingNorth, fov: 60)
        let justOutside = try! #require(projection.project(azimuth: 40, elevation: 0))
        #expect(!justOutside.isOnScreen)
        #expect(justOutside.x > 1)
    }

    // MARK: - Screen to sky, and back

    @Test("Tapping a point and projecting it back gives the same point")
    func projectionRoundTripsThroughTheScreen() {
        // The skyline is traced with a finger and drawn back as an outline; if these two
        // directions disagree the outline will not sit where it was drawn.
        for rotation in [Self.facingNorth, Self.facingEast, Self.facingStraightUp,
                         Self.rotation(right: Self.down, top: Self.east, outOfScreen: Self.south)] {
            let projection = SkyProjection(
                rotation: rotation, horizontalFieldOfView: 68, verticalFieldOfView: 50
            )
            for x in stride(from: -1.0, through: 1.0, by: 0.5) {
                for y in stride(from: -1.0, through: 1.0, by: 0.5) {
                    let start = ScreenPoint(x: x, y: y)
                    let sky = projection.direction(at: start)
                    let back = try! #require(
                        projection.project(azimuth: sky.azimuth, elevation: sky.elevation),
                        "\(start) came back from behind the camera"
                    )
                    #expect(abs(back.x - start.x) < 1e-9 && abs(back.y - start.y) < 1e-9,
                            "\(start) round-tripped to \(back)")
                }
            }
        }
    }

    @Test("The centre of the screen is whatever the camera is aimed at")
    func centreOfScreenIsTheAim() {
        for rotation in [Self.facingNorth, Self.facingEast] {
            let projection = Self.projection(rotation)
            let centre = projection.direction(at: ScreenPoint(x: 0, y: 0))
            #expect(abs(centre.azimuth - projection.aim.azimuth) < 1e-9)
            #expect(abs(centre.elevation - projection.aim.elevation) < 1e-9)
        }
    }

    @Test("Tracing across the screen sweeps across the sky in the same direction")
    func draggingRightSweepsClockwise() {
        let projection = Self.projection(Self.facingNorth)
        let left = projection.direction(at: ScreenPoint(x: -0.8, y: 0))
        let right = projection.direction(at: ScreenPoint(x: 0.8, y: 0))
        // Facing north, moving right goes towards the east, so the bearing increases.
        #expect(left.azimuth > 180, "left of north should wrap past 360, got \(left.azimuth)")
        #expect(right.azimuth < 180 && right.azimuth > 0, "got \(right.azimuth)")
    }

    @Test("Higher up the screen is higher in the sky")
    func draggingUpRaisesElevation() {
        let projection = Self.projection(Self.facingNorth)
        let low = projection.direction(at: ScreenPoint(x: 0, y: 0.8))
        let high = projection.direction(at: ScreenPoint(x: 0, y: -0.8))
        #expect(high.elevation > low.elevation)
        #expect(low.elevation < 0 && high.elevation > 0)
    }

    // MARK: - Field of view from the frame's shape

    @Test("A vertical field of view is derived from the frame's shape")
    func verticalFieldOfViewFollowsAspectRatio() {
        // A tall portrait frame sees less across than it does up and down.
        let portrait = SkyProjection(
            rotation: .identity, horizontalFieldOfView: 60, aspectRatio: 9.0 / 16.0
        )
        #expect(portrait.verticalFieldOfView > portrait.horizontalFieldOfView)

        let square = SkyProjection(rotation: .identity, horizontalFieldOfView: 60, aspectRatio: 1)
        #expect(abs(square.verticalFieldOfView - 60) < 1e-9)
    }
}

/// Turning the one number a camera reports into the two the screen really covers.
struct DisplayedFieldOfViewTests {

    @Test("The sensor's wide angle runs down the screen, not across it")
    func theWideAngleRunsDownTheScreen() {
        // A tall view, so the image fills the width and is cropped top and bottom.
        let shown = SkyProjection.displayedFieldOfView(
            cameraFieldOfView: 68, viewAspectRatio: 9.0 / 19.5
        )
        #expect(shown.vertical > shown.horizontal,
                "an upright phone should see further up and down: \(shown)")
    }

    @Test("Filling the view never claims to show more sky than the sensor captured")
    func fillingNeverInvents() {
        // Aspect ratios well past anything a portrait-locked phone produces, because the
        // guarantee is about the arithmetic and not about which handset is in the shops.
        for viewAspect in [0.4, 0.46, 0.75, 1.0, 1.5, 2.2] {
            let shown = SkyProjection.displayedFieldOfView(
                cameraFieldOfView: 68, viewAspectRatio: viewAspect
            )
            #expect(shown.horizontal <= 68.001 && shown.vertical <= 68.001,
                    "aspect \(viewAspect) claimed \(shown)")
            #expect(shown.horizontal > 0 && shown.vertical > 0)
        }
    }

    @Test("The narrow side of a four-by-three sensor is the angle it should be")
    func narrowSideMatchesTheSensorShape() {
        // A square view crops to the narrow dimension, which for a 4∶3 sensor with a 68°
        // wide angle works out near 54°.
        let shown = SkyProjection.displayedFieldOfView(
            cameraFieldOfView: 68, viewAspectRatio: 1
        )
        #expect(abs(shown.horizontal - shown.vertical) < 0.001, "a square view sees a square")
        #expect(abs(shown.vertical - 53.7) < 1.0, "got \(shown.vertical)")
    }

    @Test("A wider lens shows more sky")
    func widerLensShowsMore() {
        let narrow = SkyProjection.displayedFieldOfView(
            cameraFieldOfView: 50, viewAspectRatio: 9.0 / 19.5
        )
        let wide = SkyProjection.displayedFieldOfView(
            cameraFieldOfView: 100, viewAspectRatio: 9.0 / 19.5
        )
        #expect(wide.vertical > narrow.vertical)
        #expect(wide.horizontal > narrow.horizontal)
    }
}

/// A projected point is handed straight to a drawing surface, and drawing surfaces do not
/// survive coordinates in the hundreds of thousands. This is the guard that keeps them sane.
struct ProjectionBoundsTests {

    /// Every orientation a phone can be held in, coarsely.
    static func orientations() -> [Rotation3] {
        var all: [Rotation3] = []
        for yaw in stride(from: 0.0, to: 360.0, by: 30) {
            for pitch in stride(from: -80.0, through: 80.0, by: 20) {
                let y = yaw * .pi / 180
                let p = pitch * .pi / 180
                // Camera pointing along `yaw` at `pitch`, phone upright.
                let forward = (x: cos(p) * cos(y), y: -cos(p) * sin(y), z: sin(p))
                let outOfScreen = (x: -forward.x, y: -forward.y, z: -forward.z)
                // Right edge stays horizontal.
                let right = (x: -sin(y), y: -cos(y), z: 0.0)
                // Top = outOfScreen × right, completing a right-handed set.
                let top = (
                    x: outOfScreen.y * right.z - outOfScreen.z * right.y,
                    y: outOfScreen.z * right.x - outOfScreen.x * right.z,
                    z: outOfScreen.x * right.y - outOfScreen.y * right.x
                )
                all.append(Rotation3(
                    m11: right.x, m12: right.y, m13: right.z,
                    m21: top.x, m22: top.y, m23: top.z,
                    m31: outOfScreen.x, m32: outOfScreen.y, m33: outOfScreen.z
                ))
            }
        }
        return all
    }

    @Test("No orientation can produce a coordinate a drawing surface would choke on")
    func everyProjectedPointIsSafeToDraw() {
        // This is a regression: an upright phone facing north put sky near the zenith at
        // 4,867 — around a million points once scaled — and the Sky screen crashed the
        // moment it first had a real compass to work with.
        for rotation in Self.orientations() {
            let projection = SkyProjection(
                rotation: rotation, horizontalFieldOfView: 54, verticalFieldOfView: 68
            )
            for azimuth in stride(from: 0.0, to: 360.0, by: 3) {
                for elevation in stride(from: -2.0, through: 90.0, by: 3) {
                    guard let point = projection.project(azimuth: azimuth, elevation: elevation)
                    else { continue }
                    #expect(point.x.isFinite && point.y.isFinite,
                            "not a number at azimuth \(azimuth), elevation \(elevation)")
                    #expect(abs(point.x) <= SkyProjection.maximumOffscreenExtent
                            && abs(point.y) <= SkyProjection.maximumOffscreenExtent,
                            "\(point) at azimuth \(azimuth), elevation \(elevation)")
                }
            }
        }
    }

    @Test("Refusing the wild ones does not start refusing the visible ones")
    func everythingOnScreenStillProjects() {
        for rotation in Self.orientations() {
            let projection = SkyProjection(
                rotation: rotation, horizontalFieldOfView: 54, verticalFieldOfView: 68
            )
            let aim = projection.aim
            // Whatever the camera is aimed at, and a ring close around it, must survive.
            for offset in [0.0, 5.0, 15.0] {
                for bearing in stride(from: 0.0, to: 360.0, by: 45) {
                    let azimuth = aim.azimuth + offset * cos(bearing * .pi / 180)
                    let elevation = max(-89, min(89, aim.elevation + offset * sin(bearing * .pi / 180)))
                    if let point = projection.project(azimuth: azimuth, elevation: elevation) {
                        #expect(point.x.isFinite && point.y.isFinite)
                    }
                }
            }
            #expect(projection.project(azimuth: aim.azimuth, elevation: aim.elevation) != nil,
                    "the camera's own aim must always project")
        }
    }
}
