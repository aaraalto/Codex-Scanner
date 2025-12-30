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
        
        await configureSession(with: device)
        
        // Start session on background thread
        let captureSession = session
        Task.detached {
            captureSession.startRunning()
            await MainActor.run { [weak self] in
                self?.isRunning = true
            }
        }
    }
    
    /// Stop the capture session
    func stopSession() {
        let captureSession = session
        Task.detached {
            captureSession.stopRunning()
            await MainActor.run { [weak self] in
                self?.isRunning = false
            }
        }
    }
    
    /// Switch to a different camera device
    func switchDevice(to device: AVCaptureDevice) async {
        await configureSession(with: device)
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
    
    private func configureSession(with device: AVCaptureDevice) async {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        // Remove existing inputs
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        
        // Add device input
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            error = .configurationFailed
            return
        }
        
        guard session.canAddInput(input) else {
            error = .configurationFailed
            return
        }
        session.addInput(input)
        currentDevice = device
        
        // Configure video output for frame processing
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        guard session.canAddOutput(videoOutput) else {
            error = .configurationFailed
            return
        }
        session.addOutput(videoOutput)
        self.videoOutput = videoOutput
        
        // Configure photo output for high-res capture
        let photoOutput = AVCapturePhotoOutput()
        
        guard session.canAddOutput(photoOutput) else {
            error = .configurationFailed
            return
        }
        session.addOutput(photoOutput)
        self.photoOutput = photoOutput
        
        // Set session preset for high quality
        if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        }
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
