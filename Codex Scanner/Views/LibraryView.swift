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

/// View displaying saved books and their pages with native macOS styling
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
                .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } content: {
            if let book = selectedBook {
                pagesGrid(for: book)
                    .navigationSplitViewColumnWidth(min: 300, ideal: 400)
            } else {
                ContentUnavailableView(
                    "Select a Book",
                    systemImage: "book.closed",
                    description: Text("Choose a book from the sidebar to view its pages")
                )
            }
        } detail: {
            if let page = selectedPage {
                EditorView(page: page)
            } else {
                ContentUnavailableView(
                    "Select a Page",
                    systemImage: "doc.text.image",
                    description: Text("Choose a page to view and edit")
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
            Section {
                ForEach(books) { book in
                    NavigationLink(value: book) {
                        HStack(spacing: 12) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(book.title)
                                    .lineLimit(1)
                                    .font(.system(.body, weight: .medium))
                                
                                Text("\(book.pageCount) \(book.pageCount == 1 ? "page" : "pages")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .contextMenu {
                        Button {
                            selectedBook = book
                            newTitle = book.title
                            showingRenameSheet = true
                        } label: {
                            Label("Rename...", systemImage: "pencil")
                        }
                        
                        Button {
                            selectedBook = book
                            exportPDF(book: book)
                        } label: {
                            Label("Export as PDF...", systemImage: "square.and.arrow.up")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            deleteBook(book)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: deleteBooks)
            } header: {
                Text("Books")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    createNewBook()
                } label: {
                    Label("New Book", systemImage: "plus")
                }
                .help("Create New Book")
            }
        }
        .navigationTitle("Library")
    }
    
    // MARK: - Pages Grid
    
    private func pagesGrid(for book: Book) -> some View {
        VStack(spacing: 0) {
            // Header with actions
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("\(book.pageCount) \(book.pageCount == 1 ? "page" : "pages")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button {
                        newTitle = book.title
                        showingRenameSheet = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .buttonStyle(.borderless)
                    
                    Button {
                        exportPDF(book: book)
                    } label: {
                        Label("Export PDF", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .disabled(book.pages.isEmpty)
                }
            }
            .padding()
            .background(.bar)
            
            Divider()
            
            if book.pages.isEmpty {
                ContentUnavailableView(
                    "No Pages Yet",
                    systemImage: "doc.text.image",
                    description: Text("Start scanning to add pages to this book")
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 140, maximum: 180))],
                        spacing: 20
                    ) {
                        ForEach(book.sortedPages) { page in
                            PageThumbnail(page: page, isSelected: selectedPage?.id == page.id)
                                .onTapGesture {
                                    selectedPage = page
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deletePage(page, from: book)
                                    } label: {
                                        Label("Delete Page", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
    
    // MARK: - Rename Sheet
    
    private var renameSheet: some View {
        VStack(spacing: 24) {
            Text("Rename Book")
                .font(.headline)
            
            TextField("Title", text: $newTitle)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
            
            HStack(spacing: 12) {
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
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(newTitle.isEmpty)
            }
        }
        .padding(28)
        .frame(width: 340)
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

#Preview {
    LibraryView()
        .modelContainer(for: [Book.self, Page.self], inMemory: true)
}
