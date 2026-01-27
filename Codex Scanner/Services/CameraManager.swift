//
//  CameraManager.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import AVFoundation
import CoreImage
import Combine

/// Manages camera capture session, including Continuity Camera discovery
@MainActor
final class CameraManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isRunning = false
    @Published private(set) var currentDevice: AVCaptureDevice?
    @Published private(set) var availableDevices: [AVCaptureDevice] = []
    @Published private(set) var error: CameraError?
    @Published var zoomFactor: CGFloat = 1.0
    @Published private(set) var maxZoomFactor: CGFloat = 5.0  // Digital zoom limit
    
    // MARK: - Public Properties
    
    let session = AVCaptureSession()
    
    /// Publisher for video frame buffers (for document detection)
    var framePublisher: AnyPublisher<CVPixelBuffer, Never> {
        frameSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for captured high-resolution photos
    var photoPublisher: AnyPublisher<CIImage, Never> {
        photoSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    
    // Use nonisolated(unsafe) for subjects accessed from delegate callbacks
    private nonisolated(unsafe) let frameSubject = PassthroughSubject<CVPixelBuffer, Never>()
    private nonisolated(unsafe) let photoSubject = PassthroughSubject<CIImage, Never>()
    
    private var videoOutput: AVCaptureVideoDataOutput?
    private var photoOutput: AVCapturePhotoOutput?
    private let videoQueue = DispatchQueue(label: "com.codexscanner.videoQueue", qos: .userInteractive)
    private let sessionQueue = DispatchQueue(label: "com.codexscanner.sessionQueue")
    
    private var deviceDiscoverySession: AVCaptureDevice.DiscoverySession?
    private var deviceObserver: NSKeyValueObservation?
    
    // MARK: - Errors
    
    enum CameraError: LocalizedError {
        case notAuthorized
        case configurationFailed
        case noDeviceAvailable
        case captureError(String)
        
        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Camera access not authorized. Please enable in System Settings."
            case .configurationFailed:
                return "Failed to configure camera session."
            case .noDeviceAvailable:
                return "No camera device available. Connect an iPhone via Continuity Camera."
            case .captureError(let message):
                return "Capture error: \(message)"
            }
        }
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        // Load saved zoom factor
        let savedZoom = UserDefaults.standard.double(forKey: "CameraZoomFactor")
        if savedZoom > 0 {
            self.zoomFactor = CGFloat(savedZoom)
        }
        setupDeviceDiscovery()
    }
    
    // MARK: - Public Methods
    
    /// Request camera authorization and setup
    func requestAuthorization() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            error = .notAuthorized
            return false
        }
    }
    
    /// Configure and start the capture session
    func startSession() async {
        guard await requestAuthorization() else { return }
        
        // Find best available device (prefer external/iPhone for Continuity Camera)
        guard let device = selectBestDevice() else {
            error = .noDeviceAvailable
            return
        }
        
        // Configure and start on the session queue to avoid threading issues
        let captureSession = session
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            captureSession.beginConfiguration()
            
            // Remove existing inputs/outputs
            for input in captureSession.inputs {
                captureSession.removeInput(input)
            }
            for output in captureSession.outputs {
                captureSession.removeOutput(output)
            }
            
            // Add device input
            guard let input = try? AVCaptureDeviceInput(device: device) else {
                Task { @MainActor in self.error = .configurationFailed }
                captureSession.commitConfiguration()
                return
            }
            
            guard captureSession.canAddInput(input) else {
                Task { @MainActor in self.error = .configurationFailed }
                captureSession.commitConfiguration()
                return
            }
            captureSession.addInput(input)
            
            Task { @MainActor in
                self.currentDevice = device
            }
            
            // Configure video output
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            
            guard captureSession.canAddOutput(videoOutput) else {
                Task { @MainActor in self.error = .configurationFailed }
                captureSession.commitConfiguration()
                return
            }
            captureSession.addOutput(videoOutput)
            
            Task { @MainActor in
                self.videoOutput = videoOutput
            }
            
            // Configure photo output
            let photoOutput = AVCapturePhotoOutput()
            
            guard captureSession.canAddOutput(photoOutput) else {
                Task { @MainActor in self.error = .configurationFailed }
                captureSession.commitConfiguration()
                return
            }
            captureSession.addOutput(photoOutput)
            
            Task { @MainActor in
                self.photoOutput = photoOutput
            }
            
            // Set session preset
            if captureSession.canSetSessionPreset(.photo) {
                captureSession.sessionPreset = .photo
            }
            
            captureSession.commitConfiguration()
            
            // Now start running
            captureSession.startRunning()
            
            Task { @MainActor in
                self.isRunning = true
            }
        }
    }
    
    /// Stop the capture session
    func stopSession() {
        let captureSession = session
        sessionQueue.async { [weak self] in
            captureSession.stopRunning()
            Task { @MainActor in
                self?.isRunning = false
            }
        }
    }
    
    /// Switch to a different camera device
    func switchDevice(to device: AVCaptureDevice) async {
        let captureSession = session
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            captureSession.beginConfiguration()
            
            // Remove existing inputs
            for input in captureSession.inputs {
                captureSession.removeInput(input)
            }
            
            // Add new device input
            guard let input = try? AVCaptureDeviceInput(device: device) else {
                Task { @MainActor in self.error = .configurationFailed }
                captureSession.commitConfiguration()
                return
            }
            
            guard captureSession.canAddInput(input) else {
                Task { @MainActor in self.error = .configurationFailed }
                captureSession.commitConfiguration()
                return
            }
            captureSession.addInput(input)
            
            captureSession.commitConfiguration()
            
            Task { @MainActor in
                self.currentDevice = device
            }
        }
    }
    
    /// Capture a high-resolution photo
    func capturePhoto() {
        guard let photoOutput = photoOutput else {
            error = .captureError("Photo output not configured")
            return
        }
        
        let settings = AVCapturePhotoSettings()
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    /// Set the camera zoom factor (digital zoom for macOS)
    func setZoom(_ factor: CGFloat) {
        // macOS doesn't support hardware zoom - we use digital zoom
        // Clamp to safe range
        let clampedZoom = max(1.0, min(factor, maxZoomFactor))
        self.zoomFactor = clampedZoom
        
        // Persist
        UserDefaults.standard.set(Double(clampedZoom), forKey: "CameraZoomFactor")
    }
    
    // MARK: - Private Methods
    
    private func setupDeviceDiscovery() {
        // Discover all video devices including external (iPhone via Continuity Camera)
        deviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        
        updateAvailableDevices()
        
        // Observe device changes
        deviceObserver = deviceDiscoverySession?.observe(\.devices, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.updateAvailableDevices()
            }
        }
    }
    
    private func updateAvailableDevices() {
        availableDevices = deviceDiscoverySession?.devices ?? []
    }
    
    private func selectBestDevice() -> AVCaptureDevice? {
        // Prefer external device (iPhone via Continuity Camera)
        if let external = availableDevices.first(where: { $0.deviceType == .external }) {
            return external
        }
        // Fallback to built-in camera
        return availableDevices.first
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frameSubject.send(pixelBuffer)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            Task { @MainActor [weak self] in
                self?.error = .captureError(error.localizedDescription)
            }
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let ciImage = CIImage(data: data) else {
            Task { @MainActor [weak self] in
                self?.error = .captureError("Failed to process photo data")
            }
            return
        }
        
        photoSubject.send(ciImage)
    }
}
