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
    @State private var isTransitioning = false
    @State private var libraryIconPop = false
    @State private var showBookArrivalBurst = false
    
    @Namespace private var navigationNamespace
    
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
                    triggerLibraryIconPop()
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
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 2) {
                    ForEach(Tab.allCases) { tab in
                        TabButton(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            hasNotification: tab == .library && newlySavedBookId != nil,
                            isPoppingWithArrival: tab == .library && libraryIconPop,
                            showArrivalBurst: tab == .library && showBookArrivalBurst
                        ) {
                            if selectedTab != tab {
                                selectedTab = tab
                            }
                        }
                    }
                }
                .padding(3)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
            }
        }
    }
    
    private func navigateToLibrary() {
        selectedTab = .library
    }
    
    private func triggerLibraryIconPop() {
        // Trigger the burst effect
        showBookArrivalBurst = true
        
        // Pop animation
        withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
            libraryIconPop = true
        }
        
        // Reset pop
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                libraryIconPop = false
            }
        }
        
        // Clear burst after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showBookArrivalBurst = false
        }
    }
}

// MARK: - Custom Tab Button with notification indicator and arrival animation

private struct TabButton: View {
    let tab: ContentView.Tab
    let isSelected: Bool
    let hasNotification: Bool
    let isPoppingWithArrival: Bool
    let showArrivalBurst: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var burstRingScale: CGFloat = 0.3
    @State private var burstRingOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var iconWiggle: Double = 0
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer expanding ring burst
                if showArrivalBurst {
                    Circle()
                        .strokeBorder(Color(hex: "34C759"), lineWidth: 2)
                        .frame(width: 60, height: 60)
                        .scaleEffect(burstRingScale)
                        .opacity(burstRingOpacity)
                    
                    // Inner glow
                    Circle()
                        .fill(Color(hex: "34C759").opacity(glowOpacity * 0.3))
                        .frame(width: 44, height: 44)
                        .blur(radius: 8)
                }
                
                HStack(spacing: 6) {
                    ZStack {
                        // Main icon with wiggle on arrival
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: isPoppingWithArrival ? .bold : .medium))
                            .rotationEffect(.degrees(iconWiggle))
                        
                        // Mini incoming book indicator
                        if showArrivalBurst && tab == .library {
                            Image(systemName: "plus")
                                .font(.system(size: 7, weight: .black))
                                .foregroundStyle(Color(hex: "34C759"))
                                .offset(x: 9, y: -7)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .scaleEffect(isPoppingWithArrival ? 1.35 : 1.0)
                    
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: isPoppingWithArrival ? .semibold : .medium))
                    
                    // Notification dot
                    if hasNotification {
                        Circle()
                            .fill(Color(hex: "34C759"))
                            .frame(width: 7, height: 7)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .foregroundColor(
                    isPoppingWithArrival ? Color(hex: "34C759") :
                    (isSelected ? Color.primary : (isHovered ? Color.secondary : Color(nsColor: .tertiaryLabelColor)))
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(isSelected ? Color(nsColor: .controlBackgroundColor) : Color.clear)
                            .shadow(color: isSelected ? Color.black.opacity(0.06) : Color.clear, radius: 2, y: 1)
                        
                        // Success glow background on arrival
                        if showArrivalBurst && tab == .library {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color(hex: "34C759").opacity(glowOpacity * 0.12))
                        }
                    }
                )
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPoppingWithArrival ? 1.08 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hasNotification)
        .animation(.spring(response: 0.2, dampingFraction: 0.35), value: isPoppingWithArrival)
        .onChange(of: showArrivalBurst) { _, newValue in
            if newValue {
                // Start burst ring animation
                burstRingScale = 0.3
                burstRingOpacity = 1.0
                glowOpacity = 1.0
                
                withAnimation(.easeOut(duration: 0.7)) {
                    burstRingScale = 2.5
                    burstRingOpacity = 0
                }
                
                // Wiggle the icon
                withAnimation(.interpolatingSpring(stiffness: 500, damping: 8)) {
                    iconWiggle = 12
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.interpolatingSpring(stiffness: 500, damping: 8)) {
                        iconWiggle = -8
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.interpolatingSpring(stiffness: 500, damping: 12)) {
                        iconWiggle = 0
                    }
                }
                
                // Fade glow
                withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                    glowOpacity = 0
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Book.self, Page.self], inMemory: true)
}
