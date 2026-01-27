//
//  CameraPreview.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI
import AVFoundation

/// NSViewRepresentable wrapper for AVCaptureVideoPreviewLayer
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    var zoomFactor: CGFloat = 1.0
    var onZoomChange: ((CGFloat) -> Void)?

    func makeNSView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.session = session
        view.zoomFactor = zoomFactor
        view.onZoomChange = onZoomChange
        return view
    }

    func updateNSView(_ nsView: CameraPreviewView, context: Context) {
        // Always refresh the session connection in case it changed state
        nsView.refreshSession(session)
        nsView.onZoomChange = onZoomChange
        nsView.setZoom(zoomFactor)
    }
}

/// Custom NSView containing the preview layer
final class CameraPreviewView: NSView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var sessionObserver: NSKeyValueObservation?
    var onZoomChange: ((CGFloat) -> Void)?
    var zoomFactor: CGFloat = 1.0

    var session: AVCaptureSession? {
        didSet {
            setupPreviewLayer()
            observeSession()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    deinit {
        sessionObserver?.invalidate()
    }

    /// Refresh session connection without full layer recreation
    func refreshSession(_ session: AVCaptureSession) {
        if self.session !== session {
            self.session = session
        } else if previewLayer == nil {
            // Recreate layer if it's missing
            setupPreviewLayer()
        } else {
            // Ensure frame is correct
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer?.frame = bounds
            CATransaction.commit()
        }
    }

    private func observeSession() {
        sessionObserver?.invalidate()

        guard let session = session else { return }

        // Observe session running state to ensure layer is properly connected
        sessionObserver = session.observe(\.isRunning, options: [.new]) { [weak self] session, change in
            DispatchQueue.main.async {
                if session.isRunning {
                    self?.ensurePreviewLayerConnected()
                }
            }
        }
    }

    private func ensurePreviewLayerConnected() {
        guard let session = session else { return }

        // If layer exists but isn't connected properly, refresh it
        if previewLayer?.session !== session {
            setupPreviewLayer()
        }

        // Ensure frame is correct
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer?.frame = bounds
        applyZoom()
        CATransaction.commit()
    }

    private func setupPreviewLayer() {
        previewLayer?.removeFromSuperlayer()

        guard let session = session else { return }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        // Fill the container - no black bars
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = bounds

        // Fix orientation - set connection orientation if available
        if let connection = previewLayer.connection {
            // For macOS, we typically want landscape orientation
            if connection.isVideoRotationAngleSupported(0) {
                connection.videoRotationAngle = 0
            }
        }

        layer?.addSublayer(previewLayer)
        self.previewLayer = previewLayer

        // Apply current zoom level
        applyZoom()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Re-setup when view is added to window to ensure proper sizing
        if window != nil && previewLayer == nil && session != nil {
            setupPreviewLayer()
        }
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer?.frame = bounds
        applyZoom()
        CATransaction.commit()
    }

    func setZoom(_ factor: CGFloat) {
        zoomFactor = factor
        applyZoom()
    }

    private func applyZoom() {
        guard let previewLayer = previewLayer else { return }

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.1)

        // Apply scale transform centered on the layer
        previewLayer.transform = CATransform3DMakeScale(zoomFactor, zoomFactor, 1.0)

        CATransaction.commit()
    }

    override func scrollWheel(with event: NSEvent) {
        // Delta Y is usually vertical scroll.
        // Positive deltaY (scrolling up) should zoom in.
        // Negative deltaY (scrolling down) should zoom out.
        // Using a multiplier to control sensitivity.
        let sensitivity: CGFloat = 0.05
        let delta = event.scrollingDeltaY * sensitivity

        // Pass the delta, not the absolute value, so the view model can apply it relative to current zoom
        onZoomChange?(delta)
    }
}
