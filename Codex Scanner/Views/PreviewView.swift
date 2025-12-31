//
//  PreviewView.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI
import AppKit

/// Document preview with native macOS styling before committing to a book
struct PreviewView: View {
    @ObservedObject var viewModel: ScannerViewModel
    @Binding var isPresented: Bool
    @State private var selectedPageIndex: Int = 0
    @State private var zoomLevel: Double = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Main content
            HSplitView {
                // Page thumbnails
                thumbnailSidebar
                    .frame(minWidth: 140, maxWidth: 180)
                
                // Selected page preview
                pagePreview
            }
            
            Divider()
            
            // Footer with actions
            footer
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Document Preview")
                    .font(.headline)
                Text("\(viewModel.capturedPages.count) \(viewModel.capturedPages.count == 1 ? "page" : "pages")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Zoom controls
            HStack(spacing: 12) {
                Button {
                    zoomLevel = max(0.25, zoomLevel - 0.25)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.borderless)
                .disabled(zoomLevel <= 0.25)
                
                Text("\(Int(zoomLevel * 100))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 50)
                
                Button {
                    zoomLevel = min(4.0, zoomLevel + 0.25)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.borderless)
                .disabled(zoomLevel >= 4.0)
                
                Divider()
                    .frame(height: 16)
                
                Button {
                    zoomLevel = 1.0
                } label: {
                    Text("Fit")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close Preview")
        }
        .padding()
        .background(.bar)
    }
    
    // MARK: - Thumbnail Sidebar
    
    private var thumbnailSidebar: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(viewModel.capturedPages.enumerated()), id: \.element.id) { index, page in
                    PreviewThumbnail(
                        page: page,
                        pageNumber: index + 1,
                        isSelected: index == selectedPageIndex
                    )
                    .onTapGesture {
                        selectedPageIndex = index
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.removePage(page)
                            if selectedPageIndex >= viewModel.capturedPages.count {
                                selectedPageIndex = max(0, viewModel.capturedPages.count - 1)
                            }
                        } label: {
                            Label("Delete Page", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Page Preview
    
    private var pagePreview: some View {
        Group {
            if viewModel.capturedPages.isEmpty {
                ContentUnavailableView(
                    "No Pages",
                    systemImage: "doc.text.image",
                    description: Text("Capture some pages to preview")
                )
            } else if selectedPageIndex < viewModel.capturedPages.count {
                let page = viewModel.capturedPages[selectedPageIndex]
                
                ScrollView([.horizontal, .vertical]) {
                    if let image = page.displayImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(zoomLevel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(24)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            // Page navigation
            HStack(spacing: 12) {
                Button {
                    selectedPageIndex = max(0, selectedPageIndex - 1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .disabled(selectedPageIndex == 0)
                
                Text("Page \(selectedPageIndex + 1) of \(viewModel.capturedPages.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 120)
                
                Button {
                    selectedPageIndex = min(viewModel.capturedPages.count - 1, selectedPageIndex + 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(selectedPageIndex >= viewModel.capturedPages.count - 1)
            }
            .disabled(viewModel.capturedPages.isEmpty)
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                Button(role: .destructive) {
                    viewModel.clearAllPages()
                    isPresented = false
                } label: {
                    Text("Clear All")
                }
                .disabled(viewModel.capturedPages.isEmpty)
                
                Button("Continue Scanning") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.bar)
    }
}

#Preview {
    PreviewView(
        viewModel: ScannerViewModel(),
        isPresented: .constant(true)
    )
}
