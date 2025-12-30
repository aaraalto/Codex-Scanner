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
    
    func makeNSView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.session = session
        return view
    }
    
    func updateNSView(_ nsView: CameraPreviewView, context: Context) {
        nsView.session = session
    }
}

/// Custom NSView containing the preview layer
final class CameraPreviewView: NSView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    var session: AVCaptureSession? {
        didSet {
            setupPreviewLayer()
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.cornerRadius = 12
        layer?.masksToBounds = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.cornerRadius = 12
        layer?.masksToBounds = true
    }
    
    private func setupPreviewLayer() {
        previewLayer?.removeFromSuperlayer()
        
        guard let session = session else { return }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspect
        previewLayer.frame = bounds
        previewLayer.cornerRadius = 12
        
        // Fix orientation - set connection orientation if available
        if let connection = previewLayer.connection {
            // For macOS, we typically want landscape orientation
            if connection.isVideoRotationAngleSupported(0) {
                connection.videoRotationAngle = 0
            }
        }
        
        layer?.addSublayer(previewLayer)
        self.previewLayer = previewLayer
    }
    
    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer?.frame = bounds
        CATransaction.commit()
    }
}
