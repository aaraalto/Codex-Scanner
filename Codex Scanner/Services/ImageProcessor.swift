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

/// Handles document detection, perspective correction, and image enhancement
final class ImageProcessor: @unchecked Sendable {
    
    // MARK: - Types
    
    enum FilterPreset: String, CaseIterable, Identifiable {
        case original = "Original"
        case grayscale = "Grayscale"
        case highContrastBW = "High Contrast B&W"
        
        var id: String { rawValue }
    }
    
    struct DocumentBounds: Sendable {
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
    }
    
    // MARK: - Private Properties
    
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private let processingQueue = DispatchQueue(label: "com.codexscanner.imageProcessing", qos: .userInitiated)
    
    // MARK: - Document Detection
    
    /// Detect document bounds in a pixel buffer (for live preview)
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
    
    /// Detect document bounds in a CIImage
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
    
    // MARK: - Perspective Correction
    
    /// Apply perspective correction to straighten document
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
    
    // MARK: - Image Enhancement
    
    /// Enhance image for document scanning (shadow removal, contrast)
    func enhance(image: CIImage) -> CIImage {
        var output = image
        
        // Apply tone curve for shadow removal
        let toneCurve = CIFilter.toneCurve()
        toneCurve.inputImage = output
        toneCurve.point0 = CGPoint(x: 0.0, y: 0.05)    // Lift shadows slightly
        toneCurve.point1 = CGPoint(x: 0.25, y: 0.25)
        toneCurve.point2 = CGPoint(x: 0.5, y: 0.5)
        toneCurve.point3 = CGPoint(x: 0.75, y: 0.75)
        toneCurve.point4 = CGPoint(x: 1.0, y: 1.0)
        
        if let toneOutput = toneCurve.outputImage {
            output = toneOutput
        }
        
        // Increase contrast slightly
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = output
        colorControls.contrast = 1.1
        colorControls.saturation = 1.0
        colorControls.brightness = 0.02
        
        if let colorOutput = colorControls.outputImage {
            output = colorOutput
        }
        
        // Sharpen for text clarity
        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = output
        sharpen.sharpness = 0.4
        
        if let sharpOutput = sharpen.outputImage {
            output = sharpOutput
        }
        
        return output
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
            // First convert to grayscale
            let mono = CIFilter.photoEffectMono()
            mono.inputImage = image
            guard let grayImage = mono.outputImage else { return image }
            
            // Apply high contrast
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = grayImage
            colorControls.contrast = 1.5
            colorControls.brightness = 0.05
            
            return colorControls.outputImage ?? grayImage
        }
    }
    
    // MARK: - Full Processing Pipeline
    
    /// Process a captured image through the full pipeline
    func process(image: CIImage, bounds: DocumentBounds?, preset: FilterPreset = .original, enhance: Bool = true) -> CIImage {
        var output = image
        
        // Apply perspective correction if bounds provided
        if let bounds = bounds {
            output = correctPerspective(image: output, bounds: bounds)
        }
        
        // Apply enhancement
        if enhance {
            output = self.enhance(image: output)
        }
        
        // Apply filter preset
        output = applyPreset(preset, to: output)
        
        return output
    }
    
    // MARK: - Image Conversion
    
    /// Convert CIImage to NSImage
    func nsImage(from ciImage: CIImage) -> NSImage? {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    /// Save CIImage to disk
    func save(image: CIImage, to url: URL) throws {
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            throw ImageProcessorError.conversionFailed
        }
        
        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = NSSize(width: cgImage.width, height: cgImage.height)
        
        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
            throw ImageProcessorError.saveFailed
        }
        
        try data.write(to: url)
    }
    
    // MARK: - Errors
    
    enum ImageProcessorError: LocalizedError {
        case conversionFailed
        case saveFailed
        
        var errorDescription: String? {
            switch self {
            case .conversionFailed:
                return "Failed to convert image"
            case .saveFailed:
                return "Failed to save image to disk"
            }
        }
    }
}
