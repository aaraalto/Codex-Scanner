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
        Group {
            switch selectedTab {
            case .scanner:
                ScannerView(onNavigateToLibrary: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedTab = .library
                    }
                })
            case .library:
                LibraryView()
            }
        }
        .frame(minWidth: 900, minHeight: 650)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Picker("View", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Book.self, Page.self], inMemory: true)
}
