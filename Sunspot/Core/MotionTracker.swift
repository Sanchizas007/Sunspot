import CoreMotion
import Observation
import SolarCore

/// Which way the phone is pointing, and how much that answer can be trusted.
///
/// The second half is the point. Sun Seeker is the biggest paid app in this category and its
/// reviews are full of people saying it is "way off axis" and "nowhere near accurate" — not
/// because a compass cannot do better, but because the app shows a confident arc while the
/// magnetometer is still lost. Here, a bad reading says so.
@MainActor
@Observable
final class MotionTracker {

    /// How far the compass can be trusted right now.
    enum Trust: Int, Comparable {
        case unavailable = 0
        case uncalibrated
        case low
        case medium
        case high

        static func < (lhs: Trust, rhs: Trust) -> Bool { lhs.rawValue < rhs.rawValue }

        /// True when the arc should be drawn as fact rather than as a guess.
        var isUsable: Bool { self >= .medium }

        var advice: String? {
            switch self {
            case .unavailable:
                String(localized: "This device cannot report which way it is pointing.")
            case .uncalibrated, .low:
                String(localized: "Wave the phone in a figure of eight to calibrate the compass. Keep away from speakers, magnets and car dashboards.")
            case .medium:
                String(localized: "The compass is roughly right. A figure of eight will sharpen it.")
            case .high:
                nil
            }
        }
    }

    private(set) var rotation: Rotation3?
    private(set) var trust: Trust = .unavailable

    private let motion = CMMotionManager()
    private let queue = OperationQueue()

    var isRunning: Bool { motion.isDeviceMotionActive }

    func start() {
        guard motion.isDeviceMotionAvailable else {
            trust = .unavailable
            startStandIn()
            return
        }
        guard !motion.isDeviceMotionActive else { return }

        // True north rather than magnetic: everything else in the app is worked out against
        // true north, and mixing the two would be a silent error of several degrees. It is
        // not always on offer, though — it needs a magnetometer and a location fix — so ask
        // what the device actually supports rather than assuming.
        let available = CMMotionManager.availableAttitudeReferenceFrames()
        let frame: CMAttitudeReferenceFrame
        if available.contains(.xTrueNorthZVertical) {
            frame = .xTrueNorthZVertical
        } else if available.contains(.xMagneticNorthZVertical) {
            frame = .xMagneticNorthZVertical
        } else {
            // Without a north reference the arc would point somewhere arbitrary, which is
            // worse than admitting the screen cannot work here.
            trust = .unavailable
            startStandIn()
            return
        }

        motion.deviceMotionUpdateInterval = 1.0 / 30

        // Spelled out as a `@Sendable` closure on purpose, and it is not a formality.
        //
        // A closure written inside a method of a main-actor class inherits that isolation.
        // Core Motion then calls it on a background queue, Swift checks the assumption at
        // runtime, finds it false, and stops the process — no message, no exception, just
        // signal 5. Marking it `@Sendable` keeps it off the actor, and the hop below puts
        // the result back where it belongs.
        let handler: @Sendable (CMDeviceMotion?, Error?) -> Void = { [weak self] deviceMotion, _ in
            guard let deviceMotion else { return }
            let matrix = deviceMotion.attitude.rotationMatrix
            let rotation = Rotation3(
                m11: matrix.m11, m12: matrix.m12, m13: matrix.m13,
                m21: matrix.m21, m22: matrix.m22, m23: matrix.m23,
                m31: matrix.m31, m32: matrix.m32, m33: matrix.m33
            )
            let accuracy = deviceMotion.magneticField.accuracy
            Task { @MainActor [weak self] in
                self?.rotation = rotation
                self?.trust = Trust(accuracy)
            }
        }
        motion.startDeviceMotionUpdates(using: frame, to: queue, withHandler: handler)
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        standIn?.invalidate()
        standIn = nil
    }

    // MARK: - Standing in for hardware that is not there

    private var standIn: Timer?

    /// Feeds a slowly panning attitude when the device has no motion hardware.
    ///
    /// This exists because of a crash. The Sky screen draws nothing at all without a compass,
    /// so in a simulator its overlay had never once run — and the first machine to execute
    /// that code was a customer's phone, where it went straight down. A stand-in costs a few
    /// lines and puts the screen under the same tests as everything else.
    ///
    /// `trust` deliberately stays at `.unavailable`, so the screen still says out loud that
    /// it does not know which way it is pointing.
    private func startStandIn() {
        #if targetEnvironment(simulator)
        guard standIn == nil else { return }
        let started = Date()
        standIn = Timer.scheduledTimer(withTimeInterval: 1.0 / 20, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                let elapsed = Date().timeIntervalSince(started)
                // Sweep right round the horizon in a minute, tipping up and down as it goes,
                // so every part of the sky passes through the frame.
                self?.rotation = Self.standInRotation(
                    azimuth: elapsed * 6,
                    elevation: 40 * sin(elapsed * 0.35)
                )
            }
        }
        #endif
    }

    /// An upright phone aimed at a given bearing and height.
    static func standInRotation(azimuth: Double, elevation: Double) -> Rotation3 {
        let a = azimuth * .pi / 180
        let e = elevation * .pi / 180
        let forward = (x: cos(e) * cos(a), y: -cos(e) * sin(a), z: sin(e))
        let outOfScreen = (x: -forward.x, y: -forward.y, z: -forward.z)
        let right = (x: -sin(a), y: -cos(a), z: 0.0)
        let top = (
            x: outOfScreen.y * right.z - outOfScreen.z * right.y,
            y: outOfScreen.z * right.x - outOfScreen.x * right.z,
            z: outOfScreen.x * right.y - outOfScreen.y * right.x
        )
        return Rotation3(
            m11: right.x, m12: right.y, m13: right.z,
            m21: top.x, m22: top.y, m23: top.z,
            m31: outOfScreen.x, m32: outOfScreen.y, m33: outOfScreen.z
        )
    }
}

private extension MotionTracker.Trust {
    init(_ accuracy: CMMagneticFieldCalibrationAccuracy) {
        switch accuracy {
        case .uncalibrated: self = .uncalibrated
        case .low: self = .low
        case .medium: self = .medium
        case .high: self = .high
        @unknown default: self = .uncalibrated
        }
    }
}
