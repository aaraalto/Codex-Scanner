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
