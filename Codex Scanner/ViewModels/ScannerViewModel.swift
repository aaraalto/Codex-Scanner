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

/// Orientation preset for scanning
enum ScanOrientation: String, CaseIterable {
    case auto = "Auto"
    case landscape = "Landscape"
    case portrait = "Portrait"
    
    var icon: String {
        switch self {
        case .auto: return "rectangle.on.rectangle.angled"
        case .landscape: return "rectangle.landscape.rotate"
        case .portrait: return "rectangle.portrait.rotate"
        }
    }
}

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
    @Published var selectedProcessingMode: ImageProcessor.ProcessingMode = .mixed  // ML processing mode
    @Published var exportQuality: ImageProcessor.ExportQuality = .high  // Apple Books export quality
    @Published var autoDetectContentMode = true  // Auto-detect best processing mode per page
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var stabilityProgress: Double = 0  // 0 to 1 for visual feedback
    @Published var showCaptureSuccess = false  // Triggers success animation
    @Published var lastCapturedPageId: UUID?  // For highlighting newly added page
    @Published var isCameraReady = false  // Camera initialized but not scanning
    @Published var isOnCooldown = false  // Prevents rapid captures
    @Published var zoomFactor: CGFloat = 1.0
    
    // Book scanning features
    @Published var isBoundsLocked = false  // Lock the scanning area
    @Published var lockedBounds: ImageProcessor.DocumentBounds?  // The locked bounds
    @Published var scanOrientation: ScanOrientation = .landscape  // Default to landscape for books
    
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
    
    /// The bounds to display - prioritizes locked > manual > smoothed
    var displayBounds: ImageProcessor.DocumentBounds? {
        if isBoundsLocked, let locked = lockedBounds {
            return locked
        }
        return manualBoundsAdjustment ?? smoothedBounds
    }
    
    /// The bounds to use for capture - prioritizes locked > manual > detected
    var captureBounds: ImageProcessor.DocumentBounds? {
        if isBoundsLocked, let locked = lockedBounds {
            return locked
        }
        return manualBoundsAdjustment ?? currentBounds
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
    
    /// Lock the current bounds
    func lockBounds() {
        // Use current display bounds or create default landscape bounds
        if let bounds = displayBounds {
            lockedBounds = bounds
        } else {
            // Default landscape bounds (wider than tall)
            lockedBounds = createDefaultBounds(for: scanOrientation)
        }
        isBoundsLocked = true
    }
    
    /// Unlock bounds and resume detection
    func unlockBounds() {
        isBoundsLocked = false
        // Keep lockedBounds for potential re-lock
    }
    
    /// Toggle bounds lock
    func toggleBoundsLock() {
        if isBoundsLocked {
            unlockBounds()
        } else {
            lockBounds()
        }
    }
    
    /// Set absolute zoom level
    func setZoom(_ factor: CGFloat) {
        cameraManager.setZoom(factor)
    }
    
    /// Adjust zoom by a delta (for scroll wheel)
    func adjustZoom(delta: CGFloat) {
        let current = zoomFactor
        let newZoom = current + delta
        cameraManager.setZoom(newZoom)
    }
    
    /// Set scan orientation and optionally apply default bounds
    func setScanOrientation(_ orientation: ScanOrientation) {
        scanOrientation = orientation
        
        // If bounds are locked, update them to match new orientation
        if isBoundsLocked {
            lockedBounds = createDefaultBounds(for: orientation)
        }
    }
    
    /// Create default bounds for the given orientation
    func createDefaultBounds(for orientation: ScanOrientation) -> ImageProcessor.DocumentBounds {
        switch orientation {
        case .landscape:
            // Landscape: wider than tall (good for open books)
            return ImageProcessor.DocumentBounds(
                topLeft: CGPoint(x: 0.05, y: 0.85),
                topRight: CGPoint(x: 0.95, y: 0.85),
                bottomLeft: CGPoint(x: 0.05, y: 0.15),
                bottomRight: CGPoint(x: 0.95, y: 0.15),
                confidence: 1.0
            )
        case .portrait:
            // Portrait: taller than wide (single page)
            return ImageProcessor.DocumentBounds(
                topLeft: CGPoint(x: 0.15, y: 0.95),
                topRight: CGPoint(x: 0.85, y: 0.95),
                bottomLeft: CGPoint(x: 0.15, y: 0.05),
                bottomRight: CGPoint(x: 0.85, y: 0.05),
                confidence: 1.0
            )
        case .auto:
            // Auto: slightly larger area, let detection handle it
            return ImageProcessor.DocumentBounds(
                topLeft: CGPoint(x: 0.08, y: 0.92),
                topRight: CGPoint(x: 0.92, y: 0.92),
                bottomLeft: CGPoint(x: 0.08, y: 0.08),
                bottomRight: CGPoint(x: 0.92, y: 0.08),
                confidence: 1.0
            )
        }
    }
    
    /// Update a corner of the bounds manually
    func updateCorner(_ corner: Corner, to normalizedPoint: CGPoint) {
        // If bounds are locked, update the locked bounds
        let currentBounds = lockedBounds ?? manualBoundsAdjustment ?? smoothedBounds ?? createDefaultBounds(for: scanOrientation)
        
        // Clamp to valid range
        let clampedPoint = CGPoint(
            x: max(0.02, min(0.98, normalizedPoint.x)),
            y: max(0.02, min(0.98, normalizedPoint.y))
        )
        
        // Create new bounds with the updated corner
        let newBounds: ImageProcessor.DocumentBounds
        switch corner {
        case .topLeft:
            newBounds = ImageProcessor.DocumentBounds(
                topLeft: clampedPoint,
                topRight: currentBounds.topRight,
                bottomLeft: currentBounds.bottomLeft,
                bottomRight: currentBounds.bottomRight,
                confidence: currentBounds.confidence
            )
        case .topRight:
            newBounds = ImageProcessor.DocumentBounds(
                topLeft: currentBounds.topLeft,
                topRight: clampedPoint,
                bottomLeft: currentBounds.bottomLeft,
                bottomRight: currentBounds.bottomRight,
                confidence: currentBounds.confidence
            )
        case .bottomLeft:
            newBounds = ImageProcessor.DocumentBounds(
                topLeft: currentBounds.topLeft,
                topRight: currentBounds.topRight,
                bottomLeft: clampedPoint,
                bottomRight: currentBounds.bottomRight,
                confidence: currentBounds.confidence
            )
        case .bottomRight:
            newBounds = ImageProcessor.DocumentBounds(
                topLeft: currentBounds.topLeft,
                topRight: currentBounds.topRight,
                bottomLeft: currentBounds.bottomLeft,
                bottomRight: clampedPoint,
                confidence: currentBounds.confidence
            )
        }
        
        // Apply to the appropriate bounds
        if isBoundsLocked {
            lockedBounds = newBounds
        } else {
            manualBoundsAdjustment = newBounds
        }
    }
    
    /// Clear manual bounds adjustment
    func resetManualBounds() {
        manualBoundsAdjustment = nil
        if isBoundsLocked {
            // Reset locked bounds to default for current orientation
            lockedBounds = createDefaultBounds(for: scanOrientation)
        }
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
            mode: updatedPage.processingMode,
            enhance: true
        )
        // Higher resolution thumbnails for better quality display
        updatedPage.thumbnail = imageProcessor.createHighResThumbnail(
            from: updatedPage.processedImage,
            size: NSSize(width: 150, height: 200)
        )
        
        capturedPages[index] = updatedPage
    }
    
    /// Update processing mode for a specific page
    func updateProcessingMode(_ mode: ImageProcessor.ProcessingMode, for page: CapturedPage) {
        guard let index = capturedPages.firstIndex(where: { $0.id == page.id }) else { return }
        
        var updatedPage = capturedPages[index]
        updatedPage.processingMode = mode
        updatedPage.processedImage = imageProcessor.process(
            image: updatedPage.originalImage,
            bounds: updatedPage.bounds,
            preset: updatedPage.preset,
            mode: mode,
            enhance: true
        )
        updatedPage.thumbnail = imageProcessor.createHighResThumbnail(
            from: updatedPage.processedImage,
            size: NSSize(width: 150, height: 200)
        )
        
        capturedPages[index] = updatedPage
    }
    
    /// Reprocess all pages with current settings
    func reprocessAllPages() async {
        isProcessing = true
        defer { isProcessing = false }
        
        for index in capturedPages.indices {
            var page = capturedPages[index]
            page.processedImage = imageProcessor.process(
                image: page.originalImage,
                bounds: page.bounds,
                preset: page.preset,
                mode: page.processingMode,
                enhance: true
            )
            page.thumbnail = imageProcessor.createHighResThumbnail(
                from: page.processedImage,
                size: NSSize(width: 150, height: 200)
            )
            capturedPages[index] = page
        }
    }
    
    /// Save all captured pages to a book with high-quality export for Apple Books
    func saveToBook(_ book: Book, modelContext: ModelContext) async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let bookFolder = documentsURL.appendingPathComponent(book.id.uuidString, isDirectory: true)
        
        // Create folder if needed
        try FileManager.default.createDirectory(at: bookFolder, withIntermediateDirectories: true)
        
        // Determine file extension based on quality
        let fileExtension = exportQuality == .maximum ? "png" : "jpg"
        
        for (index, capturedPage) in capturedPages.enumerated() {
            let filename = "\(UUID().uuidString).\(fileExtension)"
            let fileURL = bookFolder.appendingPathComponent(filename)
            
            // Apply orientation correction before saving
            let correctedImage = correctOrientation(capturedPage.processedImage)
            
            // Save with Apple Books optimized quality settings
            try imageProcessor.save(image: correctedImage, to: fileURL, quality: exportQuality)
            
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
            
        // Sync zoom factor
        cameraManager.$zoomFactor
            .receive(on: DispatchQueue.main)
            .assign(to: &$zoomFactor)
        
        // Process video frames for document detection
        cameraManager.framePublisher
            .throttle(for: .milliseconds(80), scheduler: DispatchQueue.global(qos: .userInteractive), latest: true)
            .sink { [weak self] pixelBuffer in
                guard let self = self else { return }
                
                // Skip detection if bounds are locked
                Task { @MainActor [weak self] in
                    guard let self = self, !self.isBoundsLocked else { return }
                    
                    let imageProcessor = self.imageProcessor
                    
                    // Run detection on background
                    let bounds = await Task.detached {
                        imageProcessor.detectDocument(in: pixelBuffer)
                    }.value
                    
                    self.handleDetectedBounds(bounds)
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
        // Skip if bounds are locked
        guard !isBoundsLocked else { return }
        
        // Update raw bounds
        currentBounds = bounds
        
        // Apply orientation filtering if not auto
        let filteredBounds = filterBoundsByOrientation(bounds)
        
        // Apply smoothing for display (interpolate towards new bounds)
        if let newBounds = filteredBounds {
            if let current = smoothedBounds {
                smoothedBounds = ImageProcessor.DocumentBounds(
                    topLeft: interpolate(from: current.topLeft, to: newBounds.topLeft, factor: smoothingFactor),
                    topRight: interpolate(from: current.topRight, to: newBounds.topRight, factor: smoothingFactor),
                    bottomLeft: interpolate(from: current.bottomLeft, to: newBounds.bottomLeft, factor: smoothingFactor),
                    bottomRight: interpolate(from: current.bottomRight, to: newBounds.bottomRight, factor: smoothingFactor),
                    confidence: newBounds.confidence
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
        
        // Check stability for auto-scan (use filtered bounds)
        if let newBounds = filteredBounds, let oldBounds = smoothedBounds {
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
    
    /// Filter detected bounds based on orientation preference
    private func filterBoundsByOrientation(_ bounds: ImageProcessor.DocumentBounds?) -> ImageProcessor.DocumentBounds? {
        guard let bounds = bounds else { return nil }
        
        switch scanOrientation {
        case .auto:
            return bounds
            
        case .landscape:
            // Only accept if width > height
            let width = abs(bounds.topRight.x - bounds.topLeft.x)
            let height = abs(bounds.topLeft.y - bounds.bottomLeft.y)
            if width > height * 0.9 {  // Allow some tolerance
                return bounds
            }
            // Return existing smoothed bounds or default landscape
            return smoothedBounds ?? createDefaultBounds(for: .landscape)
            
        case .portrait:
            // Only accept if height > width
            let width = abs(bounds.topRight.x - bounds.topLeft.x)
            let height = abs(bounds.topLeft.y - bounds.bottomLeft.y)
            if height > width * 0.9 {  // Allow some tolerance
                return bounds
            }
            // Return existing smoothed bounds or default portrait
            return smoothedBounds ?? createDefaultBounds(for: .portrait)
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
        
        // Reset stability progress immediately (progress bar starts at 0%)
        stableFrameCount = 0
        stabilityProgress = 0
        
        defer { isProcessing = false }
        
        // Apply orientation correction from EXIF
        let orientedImage = correctOrientation(ciImage)
        
        // Use capture bounds (locked > manual > detected)
        let bounds: ImageProcessor.DocumentBounds?
        if let captureBounds = captureBounds {
            bounds = captureBounds
        } else {
            bounds = await imageProcessor.detectDocument(in: orientedImage)
        }
        
        // Determine processing mode - auto-detect or use selected
        let processingMode: ImageProcessor.ProcessingMode
        if autoDetectContentMode {
            // Use ML to analyze content and pick best mode
            processingMode = await imageProcessor.analyzeContent(in: orientedImage)
        } else {
            processingMode = selectedProcessingMode
        }
        
        // Process the image with ML-enhanced pipeline
        let processed = imageProcessor.process(
            image: orientedImage,
            bounds: bounds,
            preset: selectedPreset,
            mode: processingMode,
            enhance: true
        )
        
        // Create high-resolution thumbnail for better quality display
        let thumbnail = imageProcessor.createHighResThumbnail(
            from: processed,
            size: NSSize(width: 150, height: 200)
        )
        
        let page = CapturedPage(
            originalImage: orientedImage,
            processedImage: processed,
            bounds: bounds,
            preset: selectedPreset,
            processingMode: processingMode,
            thumbnail: thumbnail
        )
        
        // Trigger success animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            capturedPages.append(page)
            lastCapturedPageId = page.id
        }
        
        // DON'T clear manual/locked bounds after capture - keep them for next scan
        // This allows consistent scanning of multiple pages
        
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
