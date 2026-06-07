//
//  BookDetailView.swift
//  Codex Scanner
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct BookDetailView: View {
    @Bindable var book: Book
    @State private var showRename = false
    @State private var newTitle = ""

    private let pdfGenerator = PDFGenerator()

    var body: some View {
        Group {
            if book.pages.isEmpty {
                ContentUnavailableView(
                    "No Pages Yet",
                    systemImage: "doc.text.image",
                    description: Text("Scan pages to add them to this book.")
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: Theme.Spacing.lg)],
                        spacing: Theme.Spacing.xl
                    ) {
                        ForEach(Array(book.sortedPages.enumerated()), id: \.element.id) { index, page in
                            PageGridCell(page: page, pageNumber: index + 1)
                                .contextMenu {
                                    Button(role: .destructive) { deletePage(page) } label: {
                                        Label("Delete Page", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(Theme.Spacing.xl)
                }
            }
        }
        .navigationTitle(book.title)
        .toolbar {
            ToolbarItem {
                Button { newTitle = book.title; showRename = true } label: {
                    Label("Rename", systemImage: "pencil")
                }
            }
            ToolbarItem {
                Button { exportPDF() } label: { Label("Export PDF", systemImage: "arrow.up.doc") }
                    .disabled(book.pages.isEmpty)
            }
        }
        .sheet(isPresented: $showRename) { renameSheet }
    }

    private var renameSheet: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("Rename Book").font(.headline)
            TextField("Title", text: $newTitle).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { showRename = false }
                Button("Save") {
                    book.title = newTitle
                    showRename = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newTitle.isEmpty)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 320)
    }

    private func deletePage(_ page: Page) {
        page.deleteImageFile()
        book.removePage(page)
    }

    private func exportPDF() {
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
