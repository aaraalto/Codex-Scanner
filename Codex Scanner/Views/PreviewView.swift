//
//  PreviewView.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI
import AppKit

/// Document preview with native macOS Tahoe styling before committing to a book
/// NOTE: This is now primarily used as a fallback - main preview is integrated into ScannerView
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
                    .frame(minWidth: 150, maxWidth: 200)
                
                // Selected page preview
                pagePreview
            }
            
            Divider()
            
            // Footer with actions
            footer
        }
        .frame(minWidth: 950, minHeight: 650)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Document Preview")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Text("\(viewModel.capturedPages.count) \(viewModel.capturedPages.count == 1 ? "page" : "pages")")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Zoom controls
            HStack(spacing: 14) {
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        zoomLevel = max(0.25, zoomLevel - 0.25)
                    }
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.notionBorderless)
                .disabled(zoomLevel <= 0.25)
                
                Text("\(Int(zoomLevel * 100))%")
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 52)
                
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        zoomLevel = min(4.0, zoomLevel + 0.25)
                    }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.notionBorderless)
                .disabled(zoomLevel >= 4.0)
                
                Divider()
                    .frame(height: 18)
                
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        zoomLevel = 1.0
                    }
                } label: {
                    Text("Fit")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                }
                .buttonStyle(.notionSecondary)
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.notionSurface.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.notionBorder.opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
            
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
        .padding(18)
        .background(.regularMaterial)
    }
    
    // MARK: - Thumbnail Sidebar
    
    private var thumbnailSidebar: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(viewModel.capturedPages.enumerated()), id: \.element.id) { index, page in
                    PreviewThumbnail(
                        page: page,
                        pageNumber: index + 1,
                        isSelected: index == selectedPageIndex
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            selectedPageIndex = index
                        }
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
            .padding(16)
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
                
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    if let image = page.displayImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(zoomLevel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(28)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(16)
            }
        }
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            // Page navigation
            HStack(spacing: 16) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedPageIndex = max(0, selectedPageIndex - 1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.notionSecondary)
                .disabled(selectedPageIndex == 0)
                
                Text("Page \(selectedPageIndex + 1) of \(viewModel.capturedPages.count)")
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 140)
                
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedPageIndex = min(viewModel.capturedPages.count - 1, selectedPageIndex + 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.notionSecondary)
                .disabled(selectedPageIndex >= viewModel.capturedPages.count - 1)
            }
            .disabled(viewModel.capturedPages.isEmpty)
            
            Spacer()
            
            // Actions
            HStack(spacing: 14) {
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
                .buttonStyle(.notionPrimary)
            }
        }
        .padding(18)
        .background(.regularMaterial)
    }
}

#Preview {
    PreviewView(
        viewModel: ScannerViewModel(),
        isPresented: .constant(true)
    )
}
