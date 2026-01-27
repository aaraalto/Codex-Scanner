//
//  ContentView.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI
import SwiftData

/// Main content view with toolbar-based tab navigation (no sidebar)
struct ContentView: View {
    @State private var selectedTab: Tab = .scanner
    @State private var newlySavedBookId: UUID?
    
    enum Tab: String, CaseIterable, Identifiable {
        case scanner = "Scanner"
        case library = "Library"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .scanner: return "camera.viewfinder"
            case .library: return "books.vertical"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Scanner View
            ScannerView(
                onNavigateToLibrary: {
                    navigateToLibrary()
                },
                onBookSaved: { bookId in
                    newlySavedBookId = bookId
                },
                onBookArrived: {
                    // Book arrival animation handled by LibraryView
                }
            )
            .opacity(selectedTab == .scanner ? 1 : 0)
            .scaleEffect(selectedTab == .scanner ? 1 : 0.96)
            .allowsHitTesting(selectedTab == .scanner)
            
            // Library View
            LibraryView(newlySavedBookId: $newlySavedBookId)
                .opacity(selectedTab == .library ? 1 : 0)
                .scaleEffect(selectedTab == .library ? 1 : 1.02)
                .offset(x: selectedTab == .library ? 0 : 30)
                .allowsHitTesting(selectedTab == .library)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedTab)
        .frame(minWidth: 900, minHeight: 650)
        .background {
            // Keyboard shortcuts for tab switching
            Group {
                Button("") { selectedTab = .scanner }
                    .keyboardShortcut("1", modifiers: .command)
                Button("") { selectedTab = .library }
                    .keyboardShortcut("2", modifiers: .command)
            }
            .opacity(0)
            .allowsHitTesting(false)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 0) {
                    ForEach(Tab.allCases) { tab in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedTab = tab
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 11, weight: .medium))
                                Text(tab.rawValue)
                                    .font(.system(size: 12, weight: .medium))
                                if tab == .library && newlySavedBookId != nil {
                                    Circle()
                                        .fill(Color(hex: "34C759"))
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(selectedTab == tab ? Color.primary.opacity(0.08) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                    }
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            }
        }
    }
    
    private func navigateToLibrary() {
        selectedTab = .library
    }
    
}

#Preview {
    ContentView()
        .modelContainer(for: [Book.self, Page.self], inMemory: true)
}
