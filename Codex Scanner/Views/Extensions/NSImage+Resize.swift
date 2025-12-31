//
//  NSImage+Resize.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import AppKit

extension NSImage {
    /// Resize the image to fit within the target size while maintaining aspect ratio
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
