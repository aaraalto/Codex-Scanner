//
//  Page.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import Foundation
import SwiftData
import AppKit

@Model
final class Page {
    var id: UUID
    var imagePath: String
    var order: Int
    var createdAt: Date
    
    var book: Book?
    
    init(imagePath: String, order: Int = 0) {
        self.id = UUID()
        self.imagePath = imagePath
        self.order = order
        self.createdAt = Date()
    }
    
    /// Returns the full URL to the image file
    var imageURL: URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsPath?.appendingPathComponent(imagePath)
    }
    
    /// Loads the image from disk
    var image: NSImage? {
        guard let url = imageURL else { return nil }
        return NSImage(contentsOf: url)
    }
    
    /// Deletes the image file from disk
    func deleteImageFile() {
        guard let url = imageURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
