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
                "This device cannot report which way it is pointing."
            case .uncalibrated, .low:
                "Wave the phone in a figure of eight to calibrate the compass. Keep away from speakers, magnets and car dashboards."
            case .medium:
                "The compass is roughly right. A figure of eight will sharpen it."
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
            return
        }
        guard !motion.isDeviceMotionActive else { return }

        motion.deviceMotionUpdateInterval = 1.0 / 30
        // True north rather than magnetic: everything else in the app is worked out against
        // true north, and mixing the two would be a silent error of several degrees.
        motion.startDeviceMotionUpdates(using: .xTrueNorthZVertical, to: queue) {
            [weak self] deviceMotion, _ in
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
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
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
