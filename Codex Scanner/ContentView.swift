//
//  ContentView.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI
import SwiftData

/// Main content view with tab-based navigation
struct ContentView: View {
    @State private var selectedTab: Tab = .scanner
    
    enum Tab: String, CaseIterable {
        case scanner = "Scanner"
        case library = "Library"
        
        var icon: String {
            switch self {
            case .scanner: return "camera.viewfinder"
            case .library: return "books.vertical"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch selectedTab {
                case .scanner:
                    ScannerView()
                case .library:
                    LibraryView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Picker("View", selection: $selectedTab) {
                        ForEach(Tab.allCases, id: \.self) { tab in
                            Label(tab.rawValue, systemImage: tab.icon)
                                .tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Book.self, Page.self], inMemory: true)
}
