//
//  ScannerScreen.swift
//  Codex Scanner
//
//  Camera-first scanning, pushed onto the library's navigation stack.
//

import SwiftUI
import SwiftData

struct ScannerScreen: View {
    /// Called after a successful save to return to the library root (pop the whole stack).
    var onFinished: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = ScannerModel()
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]

    @State private var showSaveSheet = false
    @State private var showDiscardConfirm = false
    @State private var newBookTitle = "Untitled Book"
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {
            cameraStage
            CaptureControlsBar(model: model)
            if !model.capturedPages.isEmpty {
                Divider()
                CapturedPagesStrip(pages: model.capturedPages, onDelete: { model.removePage($0) })
            }
        }
        .navigationTitle("Scan")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { attemptLeave() } label: {
                    Label("Library", systemImage: "chevron.backward")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Save to Book…") { showSaveSheet = true }
                    .disabled(model.capturedPages.isEmpty || isSaving)
            }
        }
        .task { await model.initializeCamera() }
        .onDisappear { model.stop() }
        .alert("Camera Error", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .confirmationDialog(
            "Discard \(model.capturedPages.count) captured page\(model.capturedPages.count == 1 ? "" : "s")?",
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep Scanning", role: .cancel) {}
        }
        .sheet(isPresented: $showSaveSheet) { saveSheet }
    }

    // MARK: - Camera stage
    private var cameraStage: some View {
        ZStack {
            CameraPreview(session: model.cameraManager.session)
            if let bounds = model.detectedBounds, model.phase == .scanning {
                GeometryReader { geo in
                    DocumentFrameOverlay(bounds: bounds, viewSize: geo.size)
                }
            }
            if model.phase == .processing {
                ProgressView()
                    .controlSize(.large)
                    .padding(Theme.Spacing.lg)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }

    // MARK: - Save sheet
    private var saveSheet: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("Save \(model.capturedPages.count) Page\(model.capturedPages.count == 1 ? "" : "s")")
                .font(.headline)

            HStack {
                TextField("New book title", text: $newBookTitle)
                    .textFieldStyle(.roundedBorder)
                Button("Create & Save") {
                    let book = Book(title: newBookTitle.isEmpty ? "Untitled Book" : newBookTitle)
                    modelContext.insert(book)
                    save(to: book)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSaving)
            }

            if !books.isEmpty {
                Divider()
                Text("Or add to an existing book")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                List(books) { book in
                    Button { save(to: book) } label: {
                        HStack {
                            Text(book.title)
                            Spacer()
                            Text("\(book.pageCount) page\(book.pageCount == 1 ? "" : "s")")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                }
                .frame(height: min(CGFloat(books.count) * 32 + 8, 200))
            }

            HStack {
                Spacer()
                Button("Cancel") { showSaveSheet = false }
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 420)
    }

    // MARK: - Actions
    private func attemptLeave() {
        if model.capturedPages.isEmpty {
            dismiss()
        } else {
            showDiscardConfirm = true
        }
    }

    private func save(to book: Book) {
        isSaving = true
        Task {
            do {
                try await model.saveToBook(book, modelContext: modelContext)
                showSaveSheet = false
                newBookTitle = "Untitled Book"
                onFinished()
            } catch {
                model.errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
