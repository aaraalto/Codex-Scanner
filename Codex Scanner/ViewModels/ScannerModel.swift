//
//  ScannerModel.swift
//  Codex Scanner
//
//  Enum-driven scanner state machine. Replaces the many-boolean
//  ScannerViewModel with a single ScannerPhase.
//

import SwiftUI
import SwiftData
import Combine
import CoreImage
import AppKit

/// The scanner's current operational phase.
enum ScannerPhase: Equatable {
    case idle        // camera off / not scanning
    case scanning    // looking for documents
    case capturing   // a photo is being taken
    case processing  // a captured photo is being processed
}

@MainActor
final class ScannerModel: ObservableObject {

    // MARK: - Published state
    @Published var phase: ScannerPhase = .idle
    @Published var isAutoCaptureEnabled = true
    @Published var detectedBounds: ImageProcessor.DocumentBounds?
    @Published var capturedPages: [CapturedPage] = []
    @Published var processingMode: ImageProcessor.ProcessingMode = .mixed
    @Published var exportQuality: ImageProcessor.ExportQuality = .high
    @Published var errorMessage: String?

    // MARK: - Services
    let cameraManager = CameraManager()
    let imageProcessor = ImageProcessor()

    // MARK: - Private
    private var cancellables = Set<AnyCancellable>()
    private var previousBounds: ImageProcessor.DocumentBounds?
    private var stableFrameCount = 0
    private let stabilityThreshold = 25
    private let movementThreshold: CGFloat = 0.015

    init() {
        setupBindings()
    }

    // MARK: - Lifecycle
    func initializeCamera() async {
        await cameraManager.startSession()
        phase = .scanning
    }

    func stop() {
        cameraManager.stopSession()
        phase = .idle
        resetStability()
    }

    func capturePhoto() {
        guard phase == .scanning else { return }
        phase = .capturing
        cameraManager.capturePhoto()
    }

    // MARK: - Page management
    func removePage(_ page: CapturedPage) {
        capturedPages.removeAll { $0.id == page.id }
    }

    func clearAllPages() {
        capturedPages.removeAll()
    }

    func movePage(from source: IndexSet, to destination: Int) {
        capturedPages.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Save
    func saveToBook(_ book: Book, modelContext: ModelContext) async throws {
        let previous = phase
        phase = .processing
        defer { phase = previous }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let bookFolder = documentsURL.appendingPathComponent(book.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: bookFolder, withIntermediateDirectories: true)

        let ext = exportQuality == .maximum ? "png" : "jpg"
        for (index, captured) in capturedPages.enumerated() {
            let filename = "\(UUID().uuidString).\(ext)"
            let fileURL = bookFolder.appendingPathComponent(filename)
            let corrected = correctOrientation(captured.processedImage)
            try imageProcessor.save(image: corrected, to: fileURL, quality: exportQuality)
            let relativePath = "\(book.id.uuidString)/\(filename)"
            let page = Page(imagePath: relativePath, order: book.pageCount + index)
            book.addPage(page)
        }

        try modelContext.save()
        capturedPages.removeAll()
    }

    // MARK: - Private helpers
    private func correctOrientation(_ image: CIImage) -> CIImage {
        guard let value = image.properties[kCGImagePropertyOrientation as String] as? UInt32,
              let orientation = CGImagePropertyOrientation(rawValue: value) else {
            return image
        }
        return image.oriented(orientation)
    }

    private func resetStability() {
        stableFrameCount = 0
        previousBounds = nil
        detectedBounds = nil
    }

    private func setupBindings() {
        cameraManager.$error
            .compactMap { $0?.localizedDescription }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in self?.errorMessage = message }
            .store(in: &cancellables)

        cameraManager.framePublisher
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.global(qos: .userInteractive), latest: true)
            .sink { [weak self] pixelBuffer in
                Task { @MainActor [weak self] in
                    guard let self, self.phase == .scanning else { return }
                    let processor = self.imageProcessor
                    let bounds = await Task.detached { processor.detectDocument(in: pixelBuffer) }.value
                    self.handleDetectedBounds(bounds)
                }
            }
            .store(in: &cancellables)

        cameraManager.photoPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ciImage in
                Task { @MainActor in await self?.processPhoto(ciImage) }
            }
            .store(in: &cancellables)
    }

    private func handleDetectedBounds(_ bounds: ImageProcessor.DocumentBounds?) {
        guard phase == .scanning else { return }
        detectedBounds = bounds

        guard let newBounds = bounds else {
            previousBounds = nil
            stableFrameCount = 0
            return
        }

        if let old = previousBounds {
            let movement = maxCornerMovement(from: old, to: newBounds)
            if movement < movementThreshold {
                stableFrameCount += 1
                if isAutoCaptureEnabled && stableFrameCount >= stabilityThreshold {
                    stableFrameCount = 0
                    capturePhoto()
                }
            } else {
                stableFrameCount = max(0, stableFrameCount - 2)
            }
        }
        previousBounds = newBounds
    }

    private func maxCornerMovement(from old: ImageProcessor.DocumentBounds,
                                   to new: ImageProcessor.DocumentBounds) -> CGFloat {
        max(
            distance(old.topLeft, new.topLeft),
            distance(old.topRight, new.topRight),
            distance(old.bottomLeft, new.bottomLeft),
            distance(old.bottomRight, new.bottomRight)
        )
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt(pow(b.x - a.x, 2) + pow(b.y - a.y, 2))
    }

    private func processPhoto(_ ciImage: CIImage) async {
        phase = .processing
        defer {
            phase = .scanning
            resetStability()
        }

        let oriented = correctOrientation(ciImage)
        let bounds: ImageProcessor.DocumentBounds?
        if let detected = detectedBounds {
            bounds = detected
        } else {
            bounds = await imageProcessor.detectDocument(in: oriented)
        }
        let processed = imageProcessor.process(
            image: oriented,
            bounds: bounds,
            preset: .original,
            mode: processingMode,
            enhance: true
        )
        let thumbnail = imageProcessor.createHighResThumbnail(
            from: processed,
            size: NSSize(width: 150, height: 200)
        )
        let page = CapturedPage(
            originalImage: oriented,
            processedImage: processed,
            bounds: bounds,
            preset: .original,
            processingMode: processingMode,
            thumbnail: thumbnail
        )
        capturedPages.append(page)

        if let sound = NSSound(named: "Glass") ?? NSSound(named: "Pop") {
            sound.play()
        }
    }
}
