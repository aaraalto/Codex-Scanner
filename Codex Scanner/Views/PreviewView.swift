//
//  PreviewView.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI
import AppKit

/// Document preview before committing to a book
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
                Text("\(viewModel.capturedPages.count) pages")
                    .font(.caption)
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
                
                Text("\(Int(zoomLevel * 100))%")
                    .font(.caption)
                    .frame(width: 50)
                
                Button {
                    zoomLevel = min(4.0, zoomLevel + 0.25)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.borderless)
                
                Button {
                    zoomLevel = 1.0
                } label: {
                    Text("Fit")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
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
                        Button("Delete Page", role: .destructive) {
                            viewModel.removePage(page)
                            if selectedPageIndex >= viewModel.capturedPages.count {
                                selectedPageIndex = max(0, viewModel.capturedPages.count - 1)
                            }
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
                    } else {
                        ProgressView()
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
            HStack(spacing: 16) {
                Button {
                    selectedPageIndex = max(0, selectedPageIndex - 1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(selectedPageIndex == 0)
                
                Text("Page \(selectedPageIndex + 1) of \(viewModel.capturedPages.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button {
                    selectedPageIndex = min(viewModel.capturedPages.count - 1, selectedPageIndex + 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(selectedPageIndex >= viewModel.capturedPages.count - 1)
            }
            .disabled(viewModel.capturedPages.isEmpty)
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                Button("Clear All", role: .destructive) {
                    viewModel.clearAllPages()
                    isPresented = false
                }
                .disabled(viewModel.capturedPages.isEmpty)
                
                Button("Continue Scanning") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

// MARK: - Preview Thumbnail

struct PreviewThumbnail: View {
    let page: ScannerViewModel.CapturedPage
    let pageNumber: Int
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            if let thumbnail = page.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(color: .black.opacity(0.2), radius: isSelected ? 4 : 2)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
                    .frame(height: 100)
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
            }
            
            Text("\(pageNumber)")
                .font(.caption2)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    PreviewView(
        viewModel: ScannerViewModel(),
        isPresented: .constant(true)
    )
}
