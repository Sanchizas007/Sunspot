import AVFoundation
import SwiftUI

/// The live view from the back camera, with the angle it covers.
///
/// Reports its own field of view rather than assuming one: it differs between an iPhone's
/// wide, ultra-wide and telephoto lenses, and an assumed number would put the sun's arc
/// several degrees away from the sun.
@MainActor
@Observable
final class CameraFeed: NSObject {

    enum State: Equatable {
        case idle
        case running(fieldOfView: Double)
        case denied
        case unavailable(String)
    }

    private(set) var state: State = .idle
    /// The session itself lives inside a handle so it can cross to the session queue; see
    /// the note on `SessionHandle`.
    private nonisolated let handle = SessionHandle(session: AVCaptureSession())

    /// Every call that starts, stops or reconfigures the session goes through here.
    private nonisolated let sessionQueue = DispatchQueue(label: "app.sunspot.camera.session")

    /// For handing to the preview layer, which is a main-thread affair.
    var session: AVCaptureSession { handle.session }

    func start() {
        // Asking for the camera during a screenshot run puts a permission dialog across the
        // frame, and there is no lens behind it to grant access to. `simctl` can pre-grant
        // location and a dozen other things but not this one, so it is settled here.
        if Demo.isRunning {
            state = .running(fieldOfView: 68)
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            // `@Sendable` for the same reason as in MotionTracker: AVFoundation calls this
            // back on a queue of its own choosing, and a closure that quietly inherited main
            // actor isolation would take the process down when it did.
            let answered: @Sendable (Bool) -> Void = { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if granted { self.configureAndRun() } else { self.state = .denied }
                }
            }
            AVCaptureDevice.requestAccess(for: .video, completionHandler: answered)
        case .denied, .restricted:
            state = .denied
        @unknown default:
            state = .denied
        }
    }

    func stop() {
        let handle = handle
        sessionQueue.async {
            if handle.session.isRunning { handle.session.stopRunning() }
        }
    }

    private func configureAndRun() {
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back
        ) else {
            #if targetEnvironment(simulator)
            // No camera here, but the overlay still needs a field of view to draw against.
            // Leaving it dark meant the Sky screen was never exercised until it reached a
            // real phone, which is how a crash got that far. A typical wide lens stands in.
            state = .running(fieldOfView: 68)
            #else
            state = .unavailable(String(localized: "No camera on this device, so the live view is not available."))
            #endif
            return
        }

        if session.inputs.isEmpty {
            do {
                let input = try AVCaptureDeviceInput(device: device)
                session.beginConfiguration()
                session.sessionPreset = .high
                if session.canAddInput(input) { session.addInput(input) }
                session.commitConfiguration()
            } catch {
                state = .unavailable(String(localized: "The camera could not be started."))
                return
            }
        }

        let fieldOfView = Double(device.activeFormat.videoFieldOfView)
        let handle = handle
        sessionQueue.async {
            if !handle.session.isRunning { handle.session.startRunning() }
        }
        state = .running(fieldOfView: fieldOfView)
    }
}

/// AVFoundation predates Swift concurrency: `AVCaptureSession` is not `Sendable`, and yet
/// `startRunning()` blocks for long enough that it must never be called on the main thread.
/// Apple's own guidance is to confine the session to a single serial queue, which is what
/// `sessionQueue` above does. This wrapper records that promise to the compiler rather than
/// silencing it somewhere less visible.
private struct SessionHandle: @unchecked Sendable {
    let session: AVCaptureSession
}

/// Puts the camera's output on screen.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.previewLayer.session = session
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        /// Reached through its own name rather than by overriding `layer`. UIKit asks for
        /// `layer` at moments of its own choosing, including partway through initialisation,
        /// and a covariant override with a forced cast is a poor thing to have sitting in
        /// that path.
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
