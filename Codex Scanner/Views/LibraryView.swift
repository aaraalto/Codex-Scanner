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
    
    // Newly saved book for entrance animation
    @Binding var newlySavedBookId: UUID?
    @State private var animatedBookId: UUID?
    @State private var bookEntranceScale: CGFloat = 0.1
    @State private var bookEntranceOpacity: Double = 0
    @State private var bookEntranceOffset: CGFloat = -30
    @State private var showSuccessGlow = false
    @State private var ringScale: CGFloat = 0.5
    @State private var ringOpacity: Double = 0
    
    private let pdfGenerator = PDFGenerator()
    
    init(newlySavedBookId: Binding<UUID?> = .constant(nil)) {
        self._newlySavedBookId = newlySavedBookId
    }
    
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
                    let isNewlyAdded = book.id == animatedBookId
                    
                    NavigationLink(value: book) {
                        HStack(spacing: 12) {
                            // Book cover thumbnail or icon
                            ZStack {
                                if let firstPage = book.sortedPages.first,
                                   let coverImage = firstPage.image {
                                    Image(nsImage: coverImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 36, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                                        )
                                } else {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "4A90D9"), Color(hex: "2F5A8A")],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 36, height: 48)
                                        .overlay(
                                            Image(systemName: "book.closed.fill")
                                                .font(.system(size: 14))
                                                .foregroundStyle(.white.opacity(0.8))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                                        )
                                }
                                
                                // Animated ring burst for newly added (like Instagram)
                                if isNewlyAdded && showSuccessGlow {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color(hex: "34C759"), lineWidth: 2.5)
                                        .frame(width: 46, height: 58)
                                        .scaleEffect(ringScale)
                                        .opacity(ringOpacity)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(book.title)
                                        .lineLimit(1)
                                        .font(.system(.body, weight: .medium))
                                    
                                    // "New" badge - persists for 24 hours after creation
                                    if book.isNew {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color(hex: "34C759"))
                                                .frame(width: 5, height: 5)
                                            Text(isNewlyAdded ? "Just added" : "New")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(Color(hex: "34C759"))
                                        }
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule()
                                                .fill(Color(hex: "34C759").opacity(0.12))
                                        )
                                        .transition(.asymmetric(
                                            insertion: .scale.combined(with: .opacity),
                                            removal: .opacity
                                        ))
                                    }
                                }
                                
                                Text("\(book.pageCount) \(book.pageCount == 1 ? "page" : "pages")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scaleEffect(isNewlyAdded ? bookEntranceScale : 1.0)
                    .opacity(isNewlyAdded ? bookEntranceOpacity : 1.0)
                    .offset(x: isNewlyAdded ? bookEntranceOffset : 0)
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
        .toolbar(removing: .sidebarToggle)
        .onChange(of: newlySavedBookId) { _, newId in
            if let bookId = newId {
                animateNewBook(bookId)
            }
        }
        .onAppear {
            if let bookId = newlySavedBookId {
                animateNewBook(bookId)
            }
        }
    }
    
    private func animateNewBook(_ bookId: UUID) {
        // Reset animation states
        animatedBookId = bookId
        bookEntranceScale = 0.1
        bookEntranceOpacity = 0
        bookEntranceOffset = -30
        showSuccessGlow = false
        ringScale = 0.5
        ringOpacity = 0
        
        // Select the new book after a tiny delay to ensure it's in view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if let book = books.first(where: { $0.id == bookId }) {
                selectedBook = book
            }
        }
        
        // Phase 1: Book "lands" from the flying animation with a bounce
        withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
            bookEntranceScale = 1.0
            bookEntranceOpacity = 1.0
            bookEntranceOffset = 0
        }
        
        // Phase 2: Success ring burst (like Instagram message delivery confirmation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showSuccessGlow = true
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                ringScale = 1.2
                ringOpacity = 1.0
            }
            
            // Ring fades and expands
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.5)) {
                    ringScale = 1.5
                    ringOpacity = 0
                }
            }
        }
        
        // Phase 3: Clean up entrance animation states (badge persists via book.isNew for 24h)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 0.4)) {
                showSuccessGlow = false
                animatedBookId = nil  // Only clears entrance animation, badge stays via book.isNew
            }
            newlySavedBookId = nil
        }
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
                    .buttonStyle(.notionBorderless)
                    
                    Button {
                        exportPDF(book: book)
                    } label: {
                        Label("Export PDF", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.notionSecondary)
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
        Form {
            TextField("Title", text: $newTitle)
        }
        .formStyle(.grouped)
        .frame(width: 300, height: 80)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    showingRenameSheet = false
                }
                .buttonStyle(.notionBorderless)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if let book = selectedBook {
                        book.title = newTitle
                    }
                    showingRenameSheet = false
                }
                .buttonStyle(.notionPrimary)
                .disabled(newTitle.isEmpty)
            }
        }
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
    LibraryView(newlySavedBookId: .constant(nil))
        .modelContainer(for: [Book.self, Page.self], inMemory: true)
}
