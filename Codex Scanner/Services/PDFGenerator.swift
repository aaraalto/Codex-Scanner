//
//  PDFGenerator.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import PDFKit
import AppKit
import CoreImage

/// Generates PDF documents from scanned pages
final class PDFGenerator {
    
    // MARK: - Private Properties
    
    private let context = CIContext()
    
    // MARK: - Public Methods
    
    /// Generate a PDF from a book's pages
    func generatePDF(from book: Book) throws -> PDFDocument {
        let pdfDocument = PDFDocument()
        
        for (index, page) in book.sortedPages.enumerated() {
            guard let image = page.image else { continue }
            
            if let pdfPage = PDFPage(image: image) {
                pdfDocument.insert(pdfPage, at: index)
            }
        }
        
        guard pdfDocument.pageCount > 0 else {
            throw PDFGeneratorError.noPages
        }
        
        return pdfDocument
    }
    
    /// Generate a PDF from an array of NSImages
    func generatePDF(from images: [NSImage]) throws -> PDFDocument {
        let pdfDocument = PDFDocument()
        
        for (index, image) in images.enumerated() {
            if let pdfPage = PDFPage(image: image) {
                pdfDocument.insert(pdfPage, at: index)
            }
        }
        
        guard pdfDocument.pageCount > 0 else {
            throw PDFGeneratorError.noPages
        }
        
        return pdfDocument
    }
    
    /// Save a PDF to disk
    func save(pdf: PDFDocument, to url: URL) throws {
        guard pdf.write(to: url) else {
            throw PDFGeneratorError.saveFailed
        }
    }
    
    /// Generate and save a PDF from a book
    func export(book: Book, to url: URL) throws {
        let pdf = try generatePDF(from: book)
        try save(pdf: pdf, to: url)
    }
    
    // MARK: - Errors
    
    enum PDFGeneratorError: LocalizedError {
        case noPages
        case saveFailed
        
        var errorDescription: String? {
            switch self {
            case .noPages:
                return "No pages to export"
            case .saveFailed:
                return "Failed to save PDF to disk"
            }
        }
    }
}
