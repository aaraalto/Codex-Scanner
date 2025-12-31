//
//  ScannerViewModel.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI
import SwiftData
import Combine
import CoreImage
import AppKit

/// Main view model coordinating camera, processing, and page management
@MainActor
final class ScannerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var scanningState: ScanningState = .paused  // Start paused - press record to scan
    @Published var isAutoScanEnabled = true
    @Published var currentBounds: ImageProcessor.DocumentBounds?
    @Published var smoothedBounds: ImageProcessor.DocumentBounds?  // Smoothed for display
    @Published var manualBoundsAdjustment: ImageProcessor.DocumentBounds?  // User adjustments
    @Published var capturedPages: [CapturedPage] = []
    @Published var selectedPreset: ImageProcessor.FilterPreset = .original
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var stabilityProgress: Double = 0  // 0 to 1 for visual feedback
    @Published var showCaptureSuccess = false  // Triggers success animation
    @Published var lastCapturedPageId: UUID?  // For highlighting newly added page
    @Published var isCameraReady = false  // Camera initialized but not scanning
    @Published var isOnCooldown = false  // Prevents rapid captures
    
    // MARK: - Services
    
    let cameraManager = CameraManager()
    let imageProcessor = ImageProcessor()
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var lastBoundsUpdate = Date()
    private var stableFrameCount = 0
    private let stabilityThreshold = 25  // Increased for more delay before auto-capture
    private let boundsMovementThreshold: CGFloat = 0.015  // Tighter threshold for stability
    private let cooldownDuration: TimeInterval = 3.0  // Seconds between captures
    private let smoothingFactor: CGFloat = 0.15  // Lower = smoother (more lag), Higher = more responsive
    
    // MARK: - Computed Properties
    
    /// The bounds to display - either manual adjustment or smoothed detection
    var displayBounds: ImageProcessor.DocumentBounds? {
        manualBoundsAdjustment ?? smoothedBounds
    }
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Initialize camera but don't start scanning
    func initializeCamera() async {
        await cameraManager.startSession()
        isCameraReady = true
        // Stay paused - user must press record to start
    }
    
    /// Start the scanning session (called when record is pressed)
    func startScanning() async {
        if !isCameraReady {
            await cameraManager.startSession()
            isCameraReady = true
        }
        scanningState = .scanning
    }
    
    /// Stop the scanning session completely
    func stopScanning() {
        cameraManager.stopSession()
        scanningState = .stopped
        isCameraReady = false
        stableFrameCount = 0
        stabilityProgress = 0
    }
    
    /// Pause scanning (keeps camera running but stops auto-capture)
    func pauseScanning() {
        scanningState = .paused
        stableFrameCount = 0
        stabilityProgress = 0
    }
    
    /// Resume scanning
    func resumeScanning() {
        scanningState = .scanning
    }
    
    /// Toggle between scanning and paused states
    func togglePlayPause() {
        if scanningState == .scanning {
            pauseScanning()
        } else if scanningState == .paused || scanningState == .stopped {
            Task { await startScanning() }
        }
    }
    
    /// Manually trigger a photo capture
    func capturePhoto() {
        guard scanningState != .stopped, !isOnCooldown else { return }
        cameraManager.capturePhoto()
    }
    
    /// Update a corner of the bounds manually
    func updateCorner(_ corner: Corner, to normalizedPoint: CGPoint) {
        var bounds = manualBoundsAdjustment ?? smoothedBounds ?? ImageProcessor.DocumentBounds(
            topLeft: CGPoint(x: 0.1, y: 0.9),
            topRight: CGPoint(x: 0.9, y: 0.9),
            bottomLeft: CGPoint(x: 0.1, y: 0.1),
            bottomRight: CGPoint(x: 0.9, y: 0.1)
        )
        
        // Clamp to valid range
        let clampedPoint = CGPoint(
            x: max(0.02, min(0.98, normalizedPoint.x)),
            y: max(0.02, min(0.98, normalizedPoint.y))
        )
        
        switch corner {
        case .topLeft: bounds.topLeft = clampedPoint
        case .topRight: bounds.topRight = clampedPoint
        case .bottomLeft: bounds.bottomLeft = clampedPoint
        case .bottomRight: bounds.bottomRight = clampedPoint
        }
        
        manualBoundsAdjustment = bounds
    }
    
    /// Clear manual bounds adjustment
    func resetManualBounds() {
        manualBoundsAdjustment = nil
    }
    
    enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    /// Remove a captured page
    func removePage(_ page: CapturedPage) {
        capturedPages.removeAll { $0.id == page.id }
    }
    
    /// Clear all captured pages
    func clearAllPages() {
        capturedPages.removeAll()
    }
    
    /// Reorder pages
    func movePage(from source: IndexSet, to destination: Int) {
        capturedPages.move(fromOffsets: source, toOffset: destination)
    }
    
    /// Update preset for a specific page
    func updatePreset(_ preset: ImageProcessor.FilterPreset, for page: CapturedPage) {
        guard let index = capturedPages.firstIndex(where: { $0.id == page.id }) else { return }
        
        var updatedPage = capturedPages[index]
        updatedPage.preset = preset
        updatedPage.processedImage = imageProcessor.process(
            image: updatedPage.originalImage,
            bounds: updatedPage.bounds,
            preset: preset,
            enhance: true
        )
        updatedPage.thumbnail = imageProcessor.nsImage(from: updatedPage.processedImage)?
            .resized(to: NSSize(width: 120, height: 160))
        
        capturedPages[index] = updatedPage
    }
    
    /// Save all captured pages to a book
    func saveToBook(_ book: Book, modelContext: ModelContext) async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let bookFolder = documentsURL.appendingPathComponent(book.id.uuidString, isDirectory: true)
        
        // Create folder if needed
        try FileManager.default.createDirectory(at: bookFolder, withIntermediateDirectories: true)
        
        for (index, capturedPage) in capturedPages.enumerated() {
            let filename = "\(UUID().uuidString).jpg"
            let fileURL = bookFolder.appendingPathComponent(filename)
            
            // Apply orientation correction before saving
            let correctedImage = correctOrientation(capturedPage.processedImage)
            try imageProcessor.save(image: correctedImage, to: fileURL)
            
            let relativePath = "\(book.id.uuidString)/\(filename)"
            let page = Page(imagePath: relativePath, order: book.pageCount + index)
            book.addPage(page)
        }
        
        try modelContext.save()
        capturedPages.removeAll()
    }
    
    /// Get images for export
    func getExportImages() -> [NSImage] {
        capturedPages.compactMap { imageProcessor.nsImage(from: $0.processedImage) }
    }
    
    // MARK: - Private Methods
    
    private func correctOrientation(_ image: CIImage) -> CIImage {
        // Apply orientation correction based on image properties
        guard let orientationValue = image.properties[kCGImagePropertyOrientation as String] as? UInt32,
              let orientation = CGImagePropertyOrientation(rawValue: orientationValue) else {
            return image
        }
        return image.oriented(orientation)
    }
    
    private func setupBindings() {
        // Handle camera errors
        cameraManager.$error
            .compactMap { $0?.localizedDescription }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.errorMessage = message
            }
            .store(in: &cancellables)
        
        // Process video frames for document detection
        cameraManager.framePublisher
            .throttle(for: .milliseconds(80), scheduler: DispatchQueue.global(qos: .userInteractive), latest: true)
            .sink { [weak self] pixelBuffer in
                guard let self = self else { return }
                let imageProcessor = self.imageProcessor
                // Detect synchronously on background queue, then update UI
                let bounds = imageProcessor.detectDocument(in: pixelBuffer)
                Task { @MainActor [weak self] in
                    self?.handleDetectedBounds(bounds)
                }
            }
            .store(in: &cancellables)
        
        // Handle captured photos
        cameraManager.photoPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ciImage in
                Task { @MainActor in
                    await self?.processPhoto(ciImage)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleDetectedBounds(_ bounds: ImageProcessor.DocumentBounds?) {
        // Update raw bounds
        currentBounds = bounds
        
        // Apply smoothing for display (interpolate towards new bounds)
        if let newBounds = bounds {
            if let current = smoothedBounds {
                smoothedBounds = ImageProcessor.DocumentBounds(
                    topLeft: interpolate(from: current.topLeft, to: newBounds.topLeft, factor: smoothingFactor),
                    topRight: interpolate(from: current.topRight, to: newBounds.topRight, factor: smoothingFactor),
                    bottomLeft: interpolate(from: current.bottomLeft, to: newBounds.bottomLeft, factor: smoothingFactor),
                    bottomRight: interpolate(from: current.bottomRight, to: newBounds.bottomRight, factor: smoothingFactor)
                )
            } else {
                smoothedBounds = newBounds
            }
        }
        
        // Only process stability if actively scanning and not on cooldown
        guard scanningState == .scanning, !isOnCooldown else {
            if scanningState != .scanning {
                stabilityProgress = 0
            }
            return
        }
        
        // Check stability for auto-scan
        if let newBounds = bounds, let oldBounds = currentBounds {
            let movement = maxMovement(from: oldBounds, to: newBounds)
            
            if movement < boundsMovementThreshold {
                stableFrameCount += 1
                stabilityProgress = min(1.0, Double(stableFrameCount) / Double(stabilityThreshold))
                
                if isAutoScanEnabled && stableFrameCount >= stabilityThreshold {
                    stableFrameCount = 0
                    stabilityProgress = 0
                    capturePhoto()
                }
            } else {
                stableFrameCount = max(0, stableFrameCount - 2)  // Decay more slowly
                stabilityProgress = min(1.0, Double(stableFrameCount) / Double(stabilityThreshold))
            }
        } else {
            stableFrameCount = 0
            stabilityProgress = 0
        }
    }
    
    private func interpolate(from: CGPoint, to: CGPoint, factor: CGFloat) -> CGPoint {
        CGPoint(
            x: from.x + (to.x - from.x) * factor,
            y: from.y + (to.y - from.y) * factor
        )
    }
    
    private func maxMovement(from old: ImageProcessor.DocumentBounds, to new: ImageProcessor.DocumentBounds) -> CGFloat {
        let movements = [
            distance(from: old.topLeft, to: new.topLeft),
            distance(from: old.topRight, to: new.topRight),
            distance(from: old.bottomLeft, to: new.bottomLeft),
            distance(from: old.bottomRight, to: new.bottomRight)
        ]
        return movements.max() ?? 0
    }
    
    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2))
    }
    
    private func processPhoto(_ ciImage: CIImage) async {
        isProcessing = true
        
        // Start cooldown
        isOnCooldown = true
        
        defer { isProcessing = false }
        
        // Apply orientation correction from EXIF
        let orientedImage = correctOrientation(ciImage)
        
        // Use manual bounds if available, otherwise detect
        let bounds: ImageProcessor.DocumentBounds?
        if let manual = manualBoundsAdjustment {
            bounds = manual
        } else {
            bounds = await imageProcessor.detectDocument(in: orientedImage)
        }
        
        // Process the image
        let processed = imageProcessor.process(
            image: orientedImage,
            bounds: bounds,
            preset: selectedPreset,
            enhance: true
        )
        
        // Create thumbnail
        let thumbnail = imageProcessor.nsImage(from: processed)?.resized(to: NSSize(width: 120, height: 160))
        
        let page = CapturedPage(
            originalImage: orientedImage,
            processedImage: processed,
            bounds: bounds,
            preset: selectedPreset,
            thumbnail: thumbnail
        )
        
        // Trigger success animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            capturedPages.append(page)
            lastCapturedPageId = page.id
        }
        
        // Clear manual bounds after capture
        manualBoundsAdjustment = nil
        
        // Show capture success overlay
        showCaptureSuccess = true
        
        // Play pleasant capture sound
        playSuccessSound()
        
        // Hide success message after delay
        try? await Task.sleep(for: .seconds(2.0))
        
        withAnimation(.easeOut(duration: 0.3)) {
            showCaptureSuccess = false
        }
        
        // End cooldown after delay
        try? await Task.sleep(for: .seconds(cooldownDuration - 2.0))
        isOnCooldown = false
        
        // Clear the highlight after a bit longer
        try? await Task.sleep(for: .seconds(0.5))
        lastCapturedPageId = nil
    }
    
    private func playSuccessSound() {
        // Try to play a pleasant system sound
        if let sound = NSSound(named: "Glass") ?? NSSound(named: "Pop") ?? NSSound(named: "Tink") {
            sound.play()
        } else {
            // Fallback to system beep
            NSSound.beep()
        }
    }
}
