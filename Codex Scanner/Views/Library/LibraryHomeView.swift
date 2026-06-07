//
//  LibraryHomeView.swift
//  Codex Scanner
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct LibraryHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    var onNewScan: () -> Void

    @State private var renameTarget: Book?
    @State private var renameText = ""

    private let pdfGenerator = PDFGenerator()

    var body: some View {
        Group {
            if books.isEmpty {
                EmptyLibraryView(onNewScan: onNewScan)
            } else {
                gallery
            }
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onNewScan) { Label("New Scan", systemImage: "plus") }
            }
        }
        .sheet(item: $renameTarget) { book in renameSheet(book) }
    }

    private var gallery: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: Theme.Spacing.lg)],
                spacing: Theme.Spacing.xl
            ) {
                ForEach(books) { book in
                    BookCoverCard(
                        book: book,
                        onRename: { renameText = book.title; renameTarget = book },
                        onExport: { exportPDF(book) },
                        onDelete: { deleteBook(book) }
                    )
                }
            }
            .padding(Theme.Spacing.xl)
        }
    }

    private func renameSheet(_ book: Book) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("Rename Book").font(.headline)
            TextField("Title", text: $renameText).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { renameTarget = nil }
                Button("Save") {
                    book.title = renameText
                    renameTarget = nil
                }
                .keyboardShortcut(.defaultAction)
                .disabled(renameText.isEmpty)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 320)
    }

    private func deleteBook(_ book: Book) {
        for page in book.pages { page.deleteImageFile() }
        modelContext.delete(book)
    }

    private func exportPDF(_ book: Book) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(book.title).pdf"
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try pdfGenerator.export(book: book, to: url)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                NSSound.beep()
            }
        }
    }
}

#Preview {
    NavigationStack {
        LibraryHomeView(onNewScan: {})
    }
    .modelContainer(for: [Book.self, Page.self], inMemory: true)
}
