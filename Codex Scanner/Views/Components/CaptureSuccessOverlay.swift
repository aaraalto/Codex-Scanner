//
//  CaptureSuccessOverlay.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI

/// Capture success feedback - subtle edge flash + corner notification
/// Shows page number and prompts to turn the page
struct CaptureSuccessOverlay: View {
    let pageNumber: Int
    let capturedImage: NSImage?
    
    @State private var showFlash = true
    @State private var showNotification = false
    
    init(pageNumber: Int, capturedImage: NSImage? = nil) {
        self.pageNumber = pageNumber
        self.capturedImage = capturedImage
    }
    
    var body: some View {
        ZStack {
            // Quick edge flash effect (fades fast)
            if showFlash {
                Rectangle()
                    .fill(Color.white)
                    .opacity(0.3)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            
            // Corner notification - positioned top-right, non-blocking
            VStack {
                HStack {
                    Spacer()
                    
                    if showNotification {
                        notificationBadge
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                .padding(.top, 16)
                .padding(.trailing, 16)
                
                Spacer()
            }
        }
        .onAppear {
            // Quick flash
            withAnimation(.easeOut(duration: 0.1)) {
                showFlash = true
            }
            
            // Flash fades quickly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeOut(duration: 0.15)) {
                    showFlash = false
                }
            }
            
            // Notification slides in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8).delay(0.05)) {
                showNotification = true
            }
        }
    }
    
    private var notificationBadge: some View {
        HStack(spacing: 10) {
            // Thumbnail preview (if available)
            if let image = capturedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Page \(pageNumber)")
                    .font(.caption.weight(.semibold))
                
                Text("Turn the page →")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 8, y: 4)
    }
}

#Preview {
    ZStack {
        Color.gray
        CaptureSuccessOverlay(pageNumber: 3, capturedImage: nil)
    }
    .frame(width: 800, height: 600)
}
