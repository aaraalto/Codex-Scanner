//
//  ScanningSettings.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import Foundation
import SwiftUI
import Combine

/// Observable settings object for scanning behavior and quality
final class ScanningSettings: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = ScanningSettings()
    
    // MARK: - Presets
    
    enum ScanningPreset: String, CaseIterable, Identifiable {
        case quick = "Quick"
        case balanced = "Balanced"
        case quality = "Quality"
        
        var id: String { rawValue }
        
        var description: String {
            switch self {
            case .quick:
                return "Fast capture, lower quality"
            case .balanced:
                return "Good balance of speed and quality"
            case .quality:
                return "Best quality, slower"
            }
        }
    }
    
    enum ThumbnailSize: String, CaseIterable, Identifiable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"
        
        var id: String { rawValue }
        
        var dimensions: NSSize {
            switch self {
            case .small: return NSSize(width: 80, height: 100)
            case .medium: return NSSize(width: 120, height: 160)
            case .large: return NSSize(width: 180, height: 240)
            }
        }
    }
    
    // MARK: - Capture Settings
    
    /// Number of stable frames before auto-capture
    @Published var stabilityThreshold: Int = 15
    
    /// Maximum document movement to consider stable (0-1 normalized)
    @Published var movementTolerance: CGFloat = 0.02
    
    /// Minimum confidence for document detection (0-1)
    @Published var detectionConfidenceThreshold: Float = 0.5
    
    // MARK: - Processing Settings
    
    /// Apply enhanced sharpening for text
    @Published var enhancedSharpening: Bool = true
    
    /// Enable shadow removal
    @Published var shadowRemoval: Bool = true
    
    /// JPEG compression quality (0.7 - 1.0)
    @Published var imageCompressionQuality: Double = 0.9
    
    // MARK: - Performance Settings
    
    /// Milliseconds between frame processing for detection
    @Published var frameProcessingInterval: Int = 100
    
    /// Thumbnail size for captured pages
    @Published var thumbnailSize: ThumbnailSize = .medium
    
    /// Maximum pages to keep in memory before caching to disk
    @Published var maxPagesInMemory: Int = 20
    
    // MARK: - UserDefaults Keys
    
    private enum Keys: String {
        case stabilityThreshold
        case movementTolerance
        case detectionConfidenceThreshold
        case enhancedSharpening
        case shadowRemoval
        case imageCompressionQuality
        case frameProcessingInterval
        case thumbnailSize
        case maxPagesInMemory
    }
    
    // MARK: - Initialization
    
    private init() {
        loadFromUserDefaults()
    }
    
    // MARK: - Public Methods
    
    /// Apply a preset configuration
    func applyPreset(_ preset: ScanningPreset) {
        switch preset {
        case .quick:
            stabilityThreshold = 8
            movementTolerance = 0.04
            detectionConfidenceThreshold = 0.4
            enhancedSharpening = false
            shadowRemoval = false
            imageCompressionQuality = 0.75
            frameProcessingInterval = 150
            thumbnailSize = .small
            
        case .balanced:
            stabilityThreshold = 15
            movementTolerance = 0.02
            detectionConfidenceThreshold = 0.5
            enhancedSharpening = true
            shadowRemoval = true
            imageCompressionQuality = 0.85
            frameProcessingInterval = 100
            thumbnailSize = .medium
            
        case .quality:
            stabilityThreshold = 20
            movementTolerance = 0.015
            detectionConfidenceThreshold = 0.6
            enhancedSharpening = true
            shadowRemoval = true
            imageCompressionQuality = 0.95
            frameProcessingInterval = 80
            thumbnailSize = .large
        }
    }
    
    /// Reset all settings to default values
    func resetToDefaults() {
        stabilityThreshold = 15
        movementTolerance = 0.02
        detectionConfidenceThreshold = 0.5
        enhancedSharpening = true
        shadowRemoval = true
        imageCompressionQuality = 0.9
        frameProcessingInterval = 100
        thumbnailSize = .medium
        maxPagesInMemory = 20
    }
    
    /// Save current settings to UserDefaults
    func saveToUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(stabilityThreshold, forKey: Keys.stabilityThreshold.rawValue)
        defaults.set(movementTolerance, forKey: Keys.movementTolerance.rawValue)
        defaults.set(detectionConfidenceThreshold, forKey: Keys.detectionConfidenceThreshold.rawValue)
        defaults.set(enhancedSharpening, forKey: Keys.enhancedSharpening.rawValue)
        defaults.set(shadowRemoval, forKey: Keys.shadowRemoval.rawValue)
        defaults.set(imageCompressionQuality, forKey: Keys.imageCompressionQuality.rawValue)
        defaults.set(frameProcessingInterval, forKey: Keys.frameProcessingInterval.rawValue)
        defaults.set(thumbnailSize.rawValue, forKey: Keys.thumbnailSize.rawValue)
        defaults.set(maxPagesInMemory, forKey: Keys.maxPagesInMemory.rawValue)
    }
    
    /// Load settings from UserDefaults
    func loadFromUserDefaults() {
        let defaults = UserDefaults.standard
        
        if defaults.object(forKey: Keys.stabilityThreshold.rawValue) != nil {
            stabilityThreshold = defaults.integer(forKey: Keys.stabilityThreshold.rawValue)
        }
        if defaults.object(forKey: Keys.movementTolerance.rawValue) != nil {
            movementTolerance = defaults.double(forKey: Keys.movementTolerance.rawValue)
        }
        if defaults.object(forKey: Keys.detectionConfidenceThreshold.rawValue) != nil {
            detectionConfidenceThreshold = defaults.float(forKey: Keys.detectionConfidenceThreshold.rawValue)
        }
        if defaults.object(forKey: Keys.enhancedSharpening.rawValue) != nil {
            enhancedSharpening = defaults.bool(forKey: Keys.enhancedSharpening.rawValue)
        }
        if defaults.object(forKey: Keys.shadowRemoval.rawValue) != nil {
            shadowRemoval = defaults.bool(forKey: Keys.shadowRemoval.rawValue)
        }
        if defaults.object(forKey: Keys.imageCompressionQuality.rawValue) != nil {
            imageCompressionQuality = defaults.double(forKey: Keys.imageCompressionQuality.rawValue)
        }
        if defaults.object(forKey: Keys.frameProcessingInterval.rawValue) != nil {
            frameProcessingInterval = defaults.integer(forKey: Keys.frameProcessingInterval.rawValue)
        }
        if let sizeRaw = defaults.string(forKey: Keys.thumbnailSize.rawValue),
           let size = ThumbnailSize(rawValue: sizeRaw) {
            thumbnailSize = size
        }
        if defaults.object(forKey: Keys.maxPagesInMemory.rawValue) != nil {
            maxPagesInMemory = defaults.integer(forKey: Keys.maxPagesInMemory.rawValue)
        }
    }
}
