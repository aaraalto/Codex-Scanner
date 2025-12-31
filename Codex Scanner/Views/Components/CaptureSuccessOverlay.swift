//
//  CaptureSuccessOverlay.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI

/// Animated overlay shown after successful page capture with native macOS styling
struct CaptureSuccessOverlay: View {
    let pageNumber: Int
    @State private var showCheckmark = false
    @State private var showText = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Success checkmark with animation
            ZStack {
                Circle()
                    .fill(Color.green.gradient)
                    .frame(width: 72, height: 72)
                    .shadow(color: Color.green.opacity(0.4), radius: 16)
                    .scaleEffect(showCheckmark ? 1 : 0.5)
                    .opacity(showCheckmark ? 1 : 0)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .scaleEffect(showCheckmark ? 1 : 0)
            }
            
            VStack(spacing: 10) {
                Text("Page \(pageNumber) Captured")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.up.right")
                        .font(.system(size: 12, weight: .medium))
                    Text("Turn the page")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                }
                .foregroundStyle(.secondary)
            }
            .opacity(showText ? 1 : 0)
            .offset(y: showText ? 0 : 8)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 24, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                showCheckmark = true
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.15)) {
                showText = true
            }
        }
    }
}

#Preview {
    CaptureSuccessOverlay(pageNumber: 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
}
