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
