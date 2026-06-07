//
//  Book.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import Foundation
import SwiftData

@Model
final class Book {
    var id: UUID
    var title: String
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \Page.book)
    var pages: [Page]
    
    init(title: String = "Untitled Book") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.pages = []
    }
    
    var sortedPages: [Page] {
        pages.sorted { $0.order < $1.order }
    }
    
    var pageCount: Int {
        pages.count
    }

    /// The page used as the book's cover thumbnail (first page in reading order).
    var coverPage: Page? {
        sortedPages.first
    }

    /// Returns true if the book was created within the last 24 hours
    var isNew: Bool {
        let twentyFourHoursAgo = Date().addingTimeInterval(-24 * 60 * 60)
        return createdAt > twentyFourHoursAgo
    }
    
    /// Time remaining until the "New" badge expires (for display)
    var newBadgeTimeRemaining: TimeInterval {
        let expirationDate = createdAt.addingTimeInterval(24 * 60 * 60)
        return max(0, expirationDate.timeIntervalSinceNow)
    }
    
    func addPage(_ page: Page) {
        page.order = pages.count
        pages.append(page)
    }
    
    func removePage(_ page: Page) {
        pages.removeAll { $0.id == page.id }
        // Reorder remaining pages
        for (index, p) in sortedPages.enumerated() {
            p.order = index
        }
    }
    
    func movePage(from source: Int, to destination: Int) {
        var sorted = sortedPages
        let page = sorted.remove(at: source)
        sorted.insert(page, at: destination)
        for (index, p) in sorted.enumerated() {
            p.order = index
        }
    }
}
