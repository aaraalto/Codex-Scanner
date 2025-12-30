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

/// Scanning session state
enum ScanningState: String, CaseIterable {
    case stopped = "Stopped"
    case scanning = "Scanning"
    case paused = "Paused"
    
    var icon: String {
        switch self {
        case .stopped: return "stop.fill"
        case .scanning: return "play.fill"
        case .paused: return "pause.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .stopped: return .secondary
        case .scanning: return .green
        case .paused: return .orange
        }
    }
}

/// Main view model coordinating camera, processing, and page management
@MainActor
final class ScannerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var scanningState: ScanningState = .stopped
    @Published var isAutoScanEnabled = true
    @Published var currentBounds: ImageProcessor.DocumentBounds?
    @Published var capturedPages: [CapturedPage] = []
    @Published var selectedPreset: ImageProcessor.FilterPreset = .original
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var stabilityProgress: Double = 0  // 0 to 1 for visual feedback
    @Published var showCaptureSuccess = false  // Triggers success animation
    @Published var lastCapturedPageId: UUID?  // For highlighting newly added page
    
    // MARK: - Services
    
    let cameraManager = CameraManager()
    let imageProcessor = ImageProcessor()
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var lastBoundsUpdate = Date()
    private var stableFrameCount = 0
    private let stabilityThreshold = 15  // Number of stable frames before auto-capture
    private let boundsMovementThreshold: CGFloat = 0.02  // Max movement to consider stable
    
    // MARK: - Types
    
    struct CapturedPage: Identifiable {
        let id = UUID()
        let originalImage: CIImage
        var processedImage: CIImage
        var bounds: ImageProcessor.DocumentBounds?
        var preset: ImageProcessor.FilterPreset
        var thumbnail: NSImage?
        
        var displayImage: NSImage? {
            let context = CIContext()
            guard let cgImage = context.createCGImage(processedImage, from: processedImage.extent) else {
                return nil
            }
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
    }
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Start the scanning session
    func startScanning() async {
        await cameraManager.startSession()
        scanningState = .scanning
    }
    
    /// Stop the scanning session completely
    func stopScanning() {
        cameraManager.stopSession()
        scanningState = .stopped
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
        } else if scanningState == .paused {
            resumeScanning()
        }
    }
    
    /// Manually trigger a photo capture
    func capturePhoto() {
        guard scanningState != .stopped else { return }
        cameraManager.capturePhoto()
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
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.global(qos: .userInteractive), latest: true)
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
        // Only process if actively scanning
        guard scanningState == .scanning else {
            currentBounds = bounds
            stabilityProgress = 0
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
                stableFrameCount = 0
                stabilityProgress = 0
            }
        } else {
            stableFrameCount = 0
            stabilityProgress = 0
        }
        
        currentBounds = bounds
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
        defer { isProcessing = false }
        
        // Apply orientation correction from EXIF
        let orientedImage = correctOrientation(ciImage)
        
        // Detect bounds in high-res image
        let bounds = await imageProcessor.detectDocument(in: orientedImage)
        
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
        
        // Show capture success overlay
        showCaptureSuccess = true
        
        // Play pleasant capture sound
        playSuccessSound()
        
        // Hide success message after delay
        try? await Task.sleep(for: .seconds(2.5))
        
        withAnimation(.easeOut(duration: 0.3)) {
            showCaptureSuccess = false
        }
        
        // Clear the highlight after a bit longer
        try? await Task.sleep(for: .seconds(1))
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

// MARK: - NSImage Extension

extension NSImage {
    func resized(to targetSize: NSSize) -> NSImage {
        let aspectRatio = size.width / size.height
        var newSize = targetSize
        
        if aspectRatio > 1 {
            newSize.height = targetSize.width / aspectRatio
        } else {
            newSize.width = targetSize.height * aspectRatio
        }
        
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        draw(in: NSRect(origin: .zero, size: newSize),
             from: NSRect(origin: .zero, size: size),
             operation: .copy,
             fraction: 1.0)
        newImage.unlockFocus()
        
        return newImage
    }
}
