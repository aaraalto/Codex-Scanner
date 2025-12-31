//
//  CaptureSuccessOverlay.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI

/// Animated overlay shown after successful page capture
struct CaptureSuccessOverlay: View {
    let pageNumber: Int
    @State private var showCheckmark = false
    @State private var showText = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Success checkmark with animation
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "10B981"), Color(hex: "059669")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color(hex: "10B981").opacity(0.5), radius: 20)
                    .scaleEffect(showCheckmark ? 1 : 0.5)
                    .opacity(showCheckmark ? 1 : 0)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(showCheckmark ? 1 : 0)
            }
            
            VStack(spacing: 8) {
                Text("Page \(pageNumber) Captured!")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                
                HStack(spacing: 8) {
                    Image(systemName: "arrow.turn.up.right")
                        .font(.system(size: 14, weight: .medium))
                    Text("Turn the page")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.15), in: Capsule())
            }
            .opacity(showText ? 1 : 0)
            .offset(y: showText ? 0 : 10)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial.opacity(0.95))
                .shadow(color: .black.opacity(0.3), radius: 30)
        )
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showCheckmark = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                showText = true
            }
        }
    }
}

#Preview {
    CaptureSuccessOverlay(pageNumber: 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.5))
}
