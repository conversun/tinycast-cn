import AVFoundation

/// The capture session behind the join preview. `AVCaptureSession` is not `Sendable`, so it stays
/// main-actor isolated; only `startRunning` and `stopRunning` — which block — go off.
@MainActor
final class CameraPreviewSession {
    /// What the preview has to show, settled before the panel opens so it never renders a stage it
    /// would have to swap out from under the user.
    enum Feed {
        case live(AVCaptureSession)
        case denied
        case noCamera
    }

    private var capture: AVCaptureSession?

    /// Asks the first time and configures once; the grant is process-wide after that. Blocking on
    /// `startRunning` is the point: the caller's first frame is video rather than black.
    func start() async -> Feed {
        var access = Permissions.cameraAccess()
        if access == .notDetermined {
            _ = await Permissions.requestCameraAccess()
            access = Permissions.cameraAccess()
        }
        guard access == .granted else { return .denied }
        guard let capture = capture ?? configure() else { return .noCamera }
        self.capture = capture
        guard !capture.isRunning else { return .live(capture) }
        let box = CaptureBox(session: capture)
        await Task.detached { box.session.startRunning() }.value
        return .live(capture)
    }

    func stop() {
        guard let capture, capture.isRunning else { return }
        // The camera light must go out with the panel, so this is never left to deallocation.
        let box = CaptureBox(session: capture)
        Task.detached { box.session.stopRunning() }
    }

    private func configure() -> AVCaptureSession? {
        guard let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device)
        else { return nil }
        let capture = AVCaptureSession()
        capture.sessionPreset = .medium
        guard capture.canAddInput(input) else { return nil }
        capture.addInput(input)
        return capture
    }
}

/// `startRunning` and `stopRunning` block, and Apple's own samples drive both off the main queue —
/// but `AVCaptureSession` carries no `Sendable` annotation. This box is confined to this file, and
/// those two calls are the only things that ever touch the session off the main actor.
private struct CaptureBox: @unchecked Sendable {
    let session: AVCaptureSession
}
