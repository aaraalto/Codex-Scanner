//
//  CapturedPage.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import Foundation
import CoreImage
import AppKit

/// Represents a captured page during a scanning session (before saving to a Book)
/// Stores both original and ML-processed images for quality Apple Books export
struct CapturedPage: Identifiable {
    let id = UUID()
    let originalImage: CIImage           // Original capture for reprocessing
    var processedImage: CIImage          // ML-enhanced output
    var bounds: ImageProcessor.DocumentBounds?  // Detected document corners
    var preset: ImageProcessor.FilterPreset     // Visual filter applied
    var processingMode: ImageProcessor.ProcessingMode  // ML processing mode (text/photo/mixed)
    var thumbnail: NSImage?              // High-res thumbnail for preview
    
    /// Initialize with all processing parameters
    init(
        originalImage: CIImage,
        processedImage: CIImage,
        bounds: ImageProcessor.DocumentBounds?,
        preset: ImageProcessor.FilterPreset,
        processingMode: ImageProcessor.ProcessingMode = .mixed,
        thumbnail: NSImage? = nil
    ) {
        self.originalImage = originalImage
        self.processedImage = processedImage
        self.bounds = bounds
        self.preset = preset
        self.processingMode = processingMode
        self.thumbnail = thumbnail
    }
    
    /// Get the display-ready NSImage from the processed CIImage
    var displayImage: NSImage? {
        let context = CIContext()
        guard let cgImage = context.createCGImage(processedImage, from: processedImage.extent) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    /// Returns the detected content type based on processing mode
    var contentTypeLabel: String {
        processingMode.rawValue
    }
    
    /// Icon representing the content type
    var contentTypeIcon: String {
        processingMode.icon
    }
}
