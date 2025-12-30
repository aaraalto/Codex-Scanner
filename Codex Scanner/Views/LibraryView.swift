//
//  LibraryView.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// View displaying saved books and their pages
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @State private var selectedBook: Book?
    @State private var selectedPage: Page?
    @State private var isExporting = false
    @State private var showingRenameSheet = false
    @State private var newTitle = ""
    
    private let pdfGenerator = PDFGenerator()
    
    var body: some View {
        NavigationSplitView {
            booksList
                .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } content: {
            if let book = selectedBook {
                pagesGrid(for: book)
                    .navigationSplitViewColumnWidth(min: 300, ideal: 400)
            } else {
                ContentUnavailableView(
                    "No Book Selected",
                    systemImage: "book.closed",
                    description: Text("Select a book from the sidebar")
                )
            }
        } detail: {
            if let page = selectedPage {
                EditorView(page: page)
            } else {
                ContentUnavailableView(
                    "No Page Selected",
                    systemImage: "doc.text.image",
                    description: Text("Select a page to view")
                )
            }
        }
        .sheet(isPresented: $showingRenameSheet) {
            renameSheet
        }
    }
    
    // MARK: - Books List
    
    private var booksList: some View {
        List(selection: $selectedBook) {
            ForEach(books) { book in
                NavigationLink(value: book) {
                    HStack {
                        Image(systemName: "book.closed.fill")
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(book.title)
                                .lineLimit(1)
                            
                            Text("\(book.pageCount) pages")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .contextMenu {
                    Button("Rename...") {
                        selectedBook = book
                        newTitle = book.title
                        showingRenameSheet = true
                    }
                    
                    Button("Export PDF...") {
                        selectedBook = book
                        exportPDF(book: book)
                    }
                    
                    Divider()
                    
                    Button("Delete", role: .destructive) {
                        deleteBook(book)
                    }
                }
            }
            .onDelete(perform: deleteBooks)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    createNewBook()
                } label: {
                    Label("New Book", systemImage: "plus")
                }
            }
        }
        .navigationTitle("Library")
    }
    
    // MARK: - Pages Grid
    
    private func pagesGrid(for book: Book) -> some View {
        VStack(spacing: 0) {
            // Header with actions
            HStack {
                Text(book.title)
                    .font(.headline)
                
                Spacer()
                
                Button {
                    exportPDF(book: book)
                } label: {
                    Label("Export PDF", systemImage: "square.and.arrow.up")
                }
                .disabled(book.pages.isEmpty)
            }
            .padding()
            
            Divider()
            
            if book.pages.isEmpty {
                ContentUnavailableView(
                    "No Pages",
                    systemImage: "doc.text.image",
                    description: Text("Add pages by scanning")
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150, maximum: 200))],
                        spacing: 16
                    ) {
                        ForEach(book.sortedPages) { page in
                            PageThumbnail(page: page, isSelected: selectedPage?.id == page.id)
                                .onTapGesture {
                                    selectedPage = page
                                }
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        deletePage(page, from: book)
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: - Rename Sheet
    
    private var renameSheet: some View {
        VStack(spacing: 20) {
            Text("Rename Book")
                .font(.headline)
            
            TextField("Title", text: $newTitle)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel") {
                    showingRenameSheet = false
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Button("Save") {
                    if let book = selectedBook {
                        book.title = newTitle
                    }
                    showingRenameSheet = false
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(newTitle.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
    
    // MARK: - Actions
    
    private func createNewBook() {
        let book = Book(title: "Untitled Book")
        modelContext.insert(book)
        selectedBook = book
    }
    
    private func deleteBooks(at offsets: IndexSet) {
        for index in offsets {
            deleteBook(books[index])
        }
    }
    
    private func deleteBook(_ book: Book) {
        // Delete all page images
        for page in book.pages {
            page.deleteImageFile()
        }
        
        if selectedBook?.id == book.id {
            selectedBook = nil
        }
        
        modelContext.delete(book)
    }
    
    private func deletePage(_ page: Page, from book: Book) {
        page.deleteImageFile()
        book.removePage(page)
        
        if selectedPage?.id == page.id {
            selectedPage = nil
        }
    }
    
    private func exportPDF(book: Book) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(book.title).pdf"
        panel.canCreateDirectories = true
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try pdfGenerator.export(book: book, to: url)
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } catch {
                    print("Export error: \(error)")
                }
            }
        }
    }
}

// MARK: - Page Thumbnail

struct PageThumbnail: View {
    let page: Page
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            if let image = page.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 180)
                    .cornerRadius(8)
                    .shadow(radius: isSelected ? 4 : 2)
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: 180)
                    .cornerRadius(8)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                    }
            }
            
            Text("Page \(page.order + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: [Book.self, Page.self], inMemory: true)
}
