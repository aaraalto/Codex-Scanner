//
//  ImageProcessor.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit
import Accelerate

/// Handles ML-powered document detection, perspective correction, and advanced image enhancement
/// Optimized for producing high-quality page scans suitable for Apple Books
// Image processing is CPU-bound work meant to run off the main actor. The project
// builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor, so this type is marked
// `nonisolated` to opt its methods out of implicit main-actor isolation.
nonisolated final class ImageProcessor: @unchecked Sendable {
    
    // MARK: - Types
    
    /// Processing quality mode for different content types
    enum ProcessingMode: String, CaseIterable, Identifiable, Sendable {
        case text = "Text"           // Optimized for printed text - high contrast, sharp edges
        case photo = "Photo"         // Preserves colors and gradients in photographs
        case mixed = "Mixed"         // Balanced for pages with text and images
        case handwritten = "Handwritten" // Optimized for handwriting clarity
        
        var id: String { rawValue }
        
        var description: String {
            switch self {
            case .text: return "Best for printed books and documents"
            case .photo: return "Preserves photo quality and colors"
            case .mixed: return "Balanced for text with images"
            case .handwritten: return "Enhanced for handwritten notes"
            }
        }
        
        var icon: String {
            switch self {
            case .text: return "text.alignleft"
            case .photo: return "photo"
            case .mixed: return "doc.richtext"
            case .handwritten: return "pencil.and.scribble"
            }
        }
    }
    
    /// Filter presets for visual appearance
    enum FilterPreset: String, CaseIterable, Identifiable {
        case original = "Original"
        case grayscale = "Grayscale"
        case highContrastBW = "High Contrast B&W"
        case warmPaper = "Warm Paper"       // Simulates aged paper look
        case coolWhite = "Cool White"       // Clean, modern white
        case sepia = "Sepia"               // Classic book aesthetic
        
        var id: String { rawValue }
    }
    
    /// Export quality settings for Apple Books
    enum ExportQuality: String, CaseIterable, Identifiable {
        case standard = "Standard"      // 150 DPI - smaller files
        case high = "High"              // 300 DPI - recommended for books
        case maximum = "Maximum"        // 600 DPI - archival quality
        
        var id: String { rawValue }
        
        var dpi: CGFloat {
            switch self {
            case .standard: return 150
            case .high: return 300
            case .maximum: return 600
            }
        }
        
        var compressionQuality: CGFloat {
            switch self {
            case .standard: return 0.85
            case .high: return 0.95
            case .maximum: return 1.0
            }
        }
    }
    
    nonisolated struct DocumentBounds: Sendable {
        let topLeft: CGPoint
        let topRight: CGPoint
        let bottomLeft: CGPoint
        let bottomRight: CGPoint
        let confidence: Float
        
        init(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint, confidence: Float) {
            self.topLeft = topLeft
            self.topRight = topRight
            self.bottomLeft = bottomLeft
            self.bottomRight = bottomRight
            self.confidence = confidence
        }
        
        init(from observation: VNRectangleObservation) {
            self.topLeft = observation.topLeft
            self.topRight = observation.topRight
            self.bottomLeft = observation.bottomLeft
            self.bottomRight = observation.bottomRight
            self.confidence = observation.confidence
        }
        
        /// Calculate the aspect ratio of the document (width / height)
        var aspectRatio: CGFloat {
            let width = hypot(topRight.x - topLeft.x, topRight.y - topLeft.y)
            let height = hypot(topLeft.x - bottomLeft.x, topLeft.y - bottomLeft.y)
            return width / max(height, 0.001)
        }
    }
    
    /// Result of text region detection
    struct TextRegions: Sendable {
        let regions: [CGRect]  // Normalized coordinates
        let confidence: Float
        let hasSignificantText: Bool
    }
    
    // MARK: - Private Properties
    
    private let context = CIContext(options: [
        .useSoftwareRenderer: false,
        .highQualityDownsample: true,
        .priorityRequestLow: false,
        .workingColorSpace: CGColorSpace(name: CGColorSpace.displayP3)!
    ])
    
    private let processingQueue = DispatchQueue(label: "com.codexscanner.imageProcessing", qos: .userInitiated, attributes: .concurrent)
    
    // MARK: - Document Detection (ML-Powered)
    
    /// Detect document bounds in a pixel buffer (for live preview)
    /// Uses Vision's ML-based VNDetectDocumentSegmentationRequest
    nonisolated func detectDocument(in pixelBuffer: CVPixelBuffer) -> DocumentBounds? {
        let request = VNDetectDocumentSegmentationRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try handler.perform([request])
            
            if let result = request.results?.first {
                return DocumentBounds(
                    topLeft: result.topLeft,
                    topRight: result.topRight,
                    bottomLeft: result.bottomLeft,
                    bottomRight: result.bottomRight,
                    confidence: result.confidence
                )
            }
            return nil
        } catch {
            return nil
        }
    }
    
    /// Detect document bounds in a CIImage using ML
    func detectDocument(in image: CIImage) async -> DocumentBounds? {
        await withCheckedContinuation { continuation in
            processingQueue.async {
                let request = VNDetectDocumentSegmentationRequest()
                let handler = VNImageRequestHandler(ciImage: image, options: [:])
                
                do {
                    try handler.perform([request])
                    
                    if let result = request.results?.first {
                        let bounds = DocumentBounds(from: result)
                        continuation.resume(returning: bounds)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// Detect text regions in an image for targeted enhancement
    func detectTextRegions(in image: CIImage) async -> TextRegions {
        await withCheckedContinuation { continuation in
            processingQueue.async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .fast  // Fast for region detection
                request.usesLanguageCorrection = false
                
                let handler = VNImageRequestHandler(ciImage: image, options: [:])
                
                do {
                    try handler.perform([request])
                    
                    guard let observations = request.results else {
                        let result = TextRegions(regions: [], confidence: 0, hasSignificantText: false)
                        continuation.resume(returning: result)
                        return
                    }
                    
                    var regions: [CGRect] = []
                    var totalConfidence: Float = 0
                    
                    for observation in observations {
                        if observation.confidence > 0.3 {
                            regions.append(observation.boundingBox)
                        }
                        totalConfidence += observation.confidence
                    }
                    
                    let avgConfidence = observations.isEmpty ? Float(0) : totalConfidence / Float(observations.count)
                    let result = TextRegions(
                        regions: regions,
                        confidence: avgConfidence,
                        hasSignificantText: regions.count > 3
                    )
                    continuation.resume(returning: result)
                } catch {
                    let result = TextRegions(regions: [], confidence: 0, hasSignificantText: false)
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    /// Analyze image content to automatically determine the best processing mode
    func analyzeContent(in image: CIImage) async -> ProcessingMode {
        let textRegions = await detectTextRegions(in: image)
        
        // Calculate text coverage
        let totalTextArea = textRegions.regions.reduce(0.0) { $0 + $1.width * $1.height }
        
        if totalTextArea > 0.6 {
            // Mostly text
            return .text
        } else if totalTextArea < 0.1 {
            // Very little text, probably photos
            return .photo
        } else {
            // Mixed content
            return .mixed
        }
    }
    
    // MARK: - Perspective Correction (ML-Guided)
    
    /// Apply perspective correction to straighten and flatten document
    /// Uses precise corner detection for accurate geometry correction
    func correctPerspective(image: CIImage, bounds: DocumentBounds) -> CIImage {
        let imageSize = image.extent.size
        
        // Convert normalized coordinates to image coordinates
        let topLeft = CGPoint(
            x: bounds.topLeft.x * imageSize.width,
            y: bounds.topLeft.y * imageSize.height
        )
        let topRight = CGPoint(
            x: bounds.topRight.x * imageSize.width,
            y: bounds.topRight.y * imageSize.height
        )
        let bottomLeft = CGPoint(
            x: bounds.bottomLeft.x * imageSize.width,
            y: bounds.bottomLeft.y * imageSize.height
        )
        let bottomRight = CGPoint(
            x: bounds.bottomRight.x * imageSize.width,
            y: bounds.bottomRight.y * imageSize.height
        )
        
        // Apply perspective correction
        let perspectiveFilter = CIFilter.perspectiveCorrection()
        perspectiveFilter.inputImage = image
        perspectiveFilter.topLeft = topLeft
        perspectiveFilter.topRight = topRight
        perspectiveFilter.bottomLeft = bottomLeft
        perspectiveFilter.bottomRight = bottomRight
        
        return perspectiveFilter.outputImage ?? image
    }
    
    /// Crop to detected bounds without full perspective correction (for preview)
    func cropToDocument(image: CIImage, bounds: DocumentBounds) -> CIImage {
        let imageSize = image.extent.size
        
        // Calculate bounding box
        let minX = min(bounds.topLeft.x, bounds.bottomLeft.x) * imageSize.width
        let maxX = max(bounds.topRight.x, bounds.bottomRight.x) * imageSize.width
        let minY = min(bounds.bottomLeft.y, bounds.bottomRight.y) * imageSize.height
        let maxY = max(bounds.topLeft.y, bounds.topRight.y) * imageSize.height
        
        let cropRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        return image.cropped(to: cropRect)
    }
    
    // MARK: - Advanced Image Enhancement
    
    /// Apply mode-specific enhancement optimized for the content type
    func enhance(image: CIImage, mode: ProcessingMode) -> CIImage {
        switch mode {
        case .text:
            return enhanceForText(image: image)
        case .photo:
            return enhanceForPhoto(image: image)
        case .mixed:
            return enhanceForMixed(image: image)
        case .handwritten:
            return enhanceForHandwritten(image: image)
        }
    }
    
    /// Enhance image for printed text - maximizes readability
    private func enhanceForText(image: CIImage) -> CIImage {
        var output = image
        
        // Step 1: Normalize paper color (white balance)
        output = normalizePaperColor(image: output)
        
        // Step 2: Remove shadows (important for book spines)
        output = removeShadows(image: output, intensity: 0.7)
        
        // Step 3: Increase contrast for text clarity
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = output
        colorControls.contrast = 1.25
        colorControls.saturation = 0.0  // Remove color for text
        colorControls.brightness = 0.03
        if let result = colorControls.outputImage {
            output = result
        }
        
        // Step 4: Apply unsharp mask for crisp text edges
        let unsharpMask = CIFilter.unsharpMask()
        unsharpMask.inputImage = output
        unsharpMask.radius = 1.5
        unsharpMask.intensity = 0.8
        if let result = unsharpMask.outputImage {
            output = result
        }
        
        // Step 5: Apply adaptive threshold-like effect for clean text
        output = applyTextEnhancementCurve(image: output)
        
        return output
    }
    
    /// Enhance image for photographs - preserves color and detail
    private func enhanceForPhoto(image: CIImage) -> CIImage {
        var output = image
        
        // Step 1: Light shadow removal
        output = removeShadows(image: output, intensity: 0.3)
        
        // Step 2: Auto-enhance colors
        let vibrance = CIFilter.vibrance()
        vibrance.inputImage = output
        vibrance.amount = 0.15
        if let result = vibrance.outputImage {
            output = result
        }
        
        // Step 3: Subtle contrast boost
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = output
        colorControls.contrast = 1.08
        colorControls.saturation = 1.05
        colorControls.brightness = 0.01
        if let result = colorControls.outputImage {
            output = result
        }
        
        // Step 4: Light noise reduction
        let noiseReduction = CIFilter.noiseReduction()
        noiseReduction.inputImage = output
        noiseReduction.noiseLevel = 0.01
        noiseReduction.sharpness = 0.3
        if let result = noiseReduction.outputImage {
            output = result
        }
        
        return output
    }
    
    /// Enhance image for mixed content (text + photos)
    private func enhanceForMixed(image: CIImage) -> CIImage {
        var output = image
        
        // Step 1: Moderate paper normalization
        output = normalizePaperColor(image: output)
        
        // Step 2: Moderate shadow removal
        output = removeShadows(image: output, intensity: 0.5)
        
        // Step 3: Balanced contrast
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = output
        colorControls.contrast = 1.15
        colorControls.saturation = 0.9
        colorControls.brightness = 0.02
        if let result = colorControls.outputImage {
            output = result
        }
        
        // Step 4: Moderate sharpening
        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = output
        sharpen.sharpness = 0.5
        if let result = sharpen.outputImage {
            output = result
        }
        
        return output
    }
    
    /// Enhance image for handwritten content
    private func enhanceForHandwritten(image: CIImage) -> CIImage {
        var output = image
        
        // Step 1: Strong paper normalization
        output = normalizePaperColor(image: output)
        
        // Step 2: Shadow removal
        output = removeShadows(image: output, intensity: 0.6)
        
        // Step 3: Reduce to grayscale but keep some warmth
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = output
        colorControls.contrast = 1.3
        colorControls.saturation = 0.2  // Keep slight color for ink
        colorControls.brightness = 0.02
        if let result = colorControls.outputImage {
            output = result
        }
        
        // Step 4: Edge enhancement for strokes
        let edges = CIFilter.unsharpMask()
        edges.inputImage = output
        edges.radius = 2.0
        edges.intensity = 0.6
        if let result = edges.outputImage {
            output = result
        }
        
        return output
    }
    
    // MARK: - Shadow Removal
    
    /// Remove shadows from document scan (especially book spine shadows)
    /// Uses morphological operations and tone mapping
    private func removeShadows(image: CIImage, intensity: Float) -> CIImage {
        var output = image
        
        // Method 1: Tone curve adjustment to lift shadows
        let toneCurve = CIFilter.toneCurve()
        toneCurve.inputImage = output
        // Lift shadows while preserving highlights
        toneCurve.point0 = CGPoint(x: 0.0, y: CGFloat(0.0 + intensity * 0.1))
        toneCurve.point1 = CGPoint(x: 0.15, y: CGFloat(0.15 + intensity * 0.08))
        toneCurve.point2 = CGPoint(x: 0.5, y: 0.5)
        toneCurve.point3 = CGPoint(x: 0.85, y: 0.85)
        toneCurve.point4 = CGPoint(x: 1.0, y: 1.0)
        if let result = toneCurve.outputImage {
            output = result
        }
        
        // Method 2: Highlight & Shadow adjustment
        let highlightShadow = CIFilter.highlightShadowAdjust()
        highlightShadow.inputImage = output
        highlightShadow.shadowAmount = Float(intensity * 0.8)  // Lift shadows
        highlightShadow.highlightAmount = 1.0
        if let result = highlightShadow.outputImage {
            output = result
        }
        
        return output
    }
    
    // MARK: - Paper Color Normalization
    
    /// Normalize paper color to clean white for text documents
    /// Analyzes the background color and adjusts white balance
    private func normalizePaperColor(image: CIImage) -> CIImage {
        var output = image
        
        // Apply automatic white balance
        let whitePoint = CIFilter.whitePointAdjust()
        whitePoint.inputImage = output
        // Use a slightly warm white to avoid harsh blue tint
        whitePoint.color = CIColor(red: 1.0, green: 0.98, blue: 0.96)
        if let result = whitePoint.outputImage {
            output = result
        }
        
        // Apply exposure adjustment to brighten paper
        let exposure = CIFilter.exposureAdjust()
        exposure.inputImage = output
        exposure.ev = 0.15  // Slight exposure boost
        if let result = exposure.outputImage {
            output = result
        }
        
        return output
    }
    
    /// Apply tone curve that enhances text contrast (pseudo-adaptive threshold)
    private func applyTextEnhancementCurve(image: CIImage) -> CIImage {
        let toneCurve = CIFilter.toneCurve()
        toneCurve.inputImage = image
        // S-curve for increased contrast between text and paper
        toneCurve.point0 = CGPoint(x: 0.0, y: 0.0)
        toneCurve.point1 = CGPoint(x: 0.2, y: 0.1)   // Darken darks (text)
        toneCurve.point2 = CGPoint(x: 0.5, y: 0.5)
        toneCurve.point3 = CGPoint(x: 0.7, y: 0.85)  // Brighten lights (paper)
        toneCurve.point4 = CGPoint(x: 1.0, y: 1.0)
        
        return toneCurve.outputImage ?? image
    }
    
    // MARK: - Legacy Enhancement (for compatibility)
    
    /// Basic enhancement for document scanning (legacy method)
    func enhance(image: CIImage) -> CIImage {
        enhance(image: image, mode: .mixed)
    }
    
    // MARK: - Filter Presets
    
    /// Apply a filter preset to an image
    func applyPreset(_ preset: FilterPreset, to image: CIImage) -> CIImage {
        switch preset {
        case .original:
            return image
            
        case .grayscale:
            let mono = CIFilter.photoEffectMono()
            mono.inputImage = image
            return mono.outputImage ?? image
            
        case .highContrastBW:
            // Convert to grayscale
            let mono = CIFilter.photoEffectMono()
            mono.inputImage = image
            guard let grayImage = mono.outputImage else { return image }
            
            // Apply high contrast
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = grayImage
            colorControls.contrast = 1.5
            colorControls.brightness = 0.05
            
            return colorControls.outputImage ?? grayImage
            
        case .warmPaper:
            // Simulate aged paper with warm tones
            let sepia = CIFilter.sepiaTone()
            sepia.inputImage = image
            sepia.intensity = 0.15
            guard let sepiaImage = sepia.outputImage else { return image }
            
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = sepiaImage
            colorControls.contrast = 1.1
            colorControls.saturation = 0.8
            
            return colorControls.outputImage ?? sepiaImage
            
        case .coolWhite:
            // Clean modern white look
            let whitePoint = CIFilter.whitePointAdjust()
            whitePoint.inputImage = image
            whitePoint.color = CIColor(red: 0.96, green: 0.98, blue: 1.0)
            guard let whiteImage = whitePoint.outputImage else { return image }
            
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = whiteImage
            colorControls.contrast = 1.15
            colorControls.saturation = 0.85
            colorControls.brightness = 0.03
            
            return colorControls.outputImage ?? whiteImage
            
        case .sepia:
            let sepia = CIFilter.sepiaTone()
            sepia.inputImage = image
            sepia.intensity = 0.4
            return sepia.outputImage ?? image
        }
    }
    
    // MARK: - Full Processing Pipeline
    
    /// Process a captured image through the full ML-enhanced pipeline
    /// This is the main entry point for processing captured pages
    func process(
        image: CIImage,
        bounds: DocumentBounds?,
        preset: FilterPreset = .original,
        mode: ProcessingMode = .mixed,
        enhance shouldEnhance: Bool = true
    ) -> CIImage {
        var output = image
        
        // Step 1: Apply perspective correction if bounds provided
        if let bounds = bounds {
            output = correctPerspective(image: output, bounds: bounds)
        }
        
        // Step 2: Apply mode-specific enhancement
        if shouldEnhance {
            output = self.enhance(image: output, mode: mode)
        }
        
        // Step 3: Apply filter preset
        output = applyPreset(preset, to: output)
        
        return output
    }
    
    /// Legacy process method for compatibility
    func process(image: CIImage, bounds: DocumentBounds?, preset: FilterPreset = .original, enhance: Bool = true) -> CIImage {
        process(image: image, bounds: bounds, preset: preset, mode: .mixed, enhance: enhance)
    }
    
    // MARK: - High-Quality Export for Apple Books
    
    /// Export image with settings optimized for Apple Books
    func exportForAppleBooks(
        image: CIImage,
        quality: ExportQuality = .high,
        targetWidth: CGFloat? = nil
    ) -> Data? {
        let extent = image.extent
        
        // Calculate target size based on DPI
        let scale: CGFloat
        if let targetWidth = targetWidth {
            scale = targetWidth / extent.width
        } else {
            // Default to 8.5" width at specified DPI
            let targetWidthInches: CGFloat = 8.5
            let targetPixelWidth = targetWidthInches * quality.dpi
            scale = targetPixelWidth / extent.width
        }
        
        // Scale image if needed
        var exportImage = image
        if abs(scale - 1.0) > 0.01 {
            let scaleFilter = CIFilter.lanczosScaleTransform()
            scaleFilter.inputImage = image
            scaleFilter.scale = Float(scale)
            scaleFilter.aspectRatio = 1.0
            if let scaled = scaleFilter.outputImage {
                exportImage = scaled
            }
        }
        
        guard let cgImage = context.createCGImage(exportImage, from: exportImage.extent) else {
            return nil
        }
        
        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = NSSize(width: cgImage.width, height: cgImage.height)
        
        // Set DPI metadata
        rep.setProperty(.init(rawValue: "DPIWidth"), withValue: quality.dpi)
        rep.setProperty(.init(rawValue: "DPIHeight"), withValue: quality.dpi)
        
        // Use PNG for maximum quality archival, JPEG for smaller files
        if quality == .maximum {
            return rep.representation(using: .png, properties: [:])
        } else {
            return rep.representation(using: .jpeg, properties: [
                .compressionFactor: quality.compressionQuality,
                .progressive: true
            ])
        }
    }
    
    // MARK: - Image Conversion
    
    /// Convert CIImage to NSImage
    func nsImage(from ciImage: CIImage) -> NSImage? {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    /// Save CIImage to disk with maximum quality
    func save(image: CIImage, to url: URL, quality: ExportQuality = .high) throws {
        guard let data = exportForAppleBooks(image: image, quality: quality) else {
            throw ImageProcessorError.conversionFailed
        }
        try data.write(to: url)
    }
    
    /// Save CIImage to disk (legacy method)
    func save(image: CIImage, to url: URL) throws {
        try save(image: image, to: url, quality: .high)
    }
    
    /// Create high-resolution thumbnail
    func createHighResThumbnail(from ciImage: CIImage, size: NSSize) -> NSImage? {
        // Scale factor for Retina displays
        let scaleFactor: CGFloat = 2.0
        let scaledSize = NSSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
        
        guard let nsImage = self.nsImage(from: ciImage) else { return nil }
        return nsImage.resized(to: scaledSize)
    }
    
    // MARK: - Batch Processing
    
    /// Process multiple images in parallel for efficiency
    func processBatch(
        images: [(CIImage, DocumentBounds?)],
        preset: FilterPreset = .original,
        mode: ProcessingMode = .mixed
    ) async -> [CIImage] {
        await withTaskGroup(of: (Int, CIImage).self) { group in
            for (index, (image, bounds)) in images.enumerated() {
                group.addTask {
                    let processed = self.process(
                        image: image,
                        bounds: bounds,
                        preset: preset,
                        mode: mode,
                        enhance: true
                    )
                    return (index, processed)
                }
            }
            
            var results = [(Int, CIImage)]()
            for await result in group {
                results.append(result)
            }
            
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
    
    // MARK: - Errors
    
    enum ImageProcessorError: LocalizedError {
        case conversionFailed
        case saveFailed
        case processingFailed
        
        var errorDescription: String? {
            switch self {
            case .conversionFailed:
                return "Failed to convert image"
            case .saveFailed:
                return "Failed to save image to disk"
            case .processingFailed:
                return "Failed to process image"
            }
        }
    }
}
