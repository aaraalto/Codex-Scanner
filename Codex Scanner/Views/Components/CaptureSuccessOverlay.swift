//
//  CaptureSuccessOverlay.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI

/// Animated overlay shown after successful page capture with macOS Tahoe styling
struct CaptureSuccessOverlay: View {
    let pageNumber: Int
    @State private var showCheckmark = false
    @State private var showText = false
    @State private var glowPulse = false
    
    var body: some View {
        VStack(spacing: 28) {
            // Success checkmark with glow animation
            ZStack {
                // Pulsing glow
                Circle()
                    .fill(Color.green.opacity(0.35))
                    .frame(width: 110, height: 110)
                    .blur(radius: glowPulse ? 35 : 25)
                    .scaleEffect(glowPulse ? 1.25 : 1.0)
                
                // Glass circle
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 88, height: 88)
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.45), Color.green.opacity(0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.85), Color.green.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5
                            )
                    )
                    .shadow(color: Color.green.opacity(0.55), radius: 25)
                    .scaleEffect(showCheckmark ? 1 : 0.5)
                    .opacity(showCheckmark ? 1 : 0)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: Color.green.opacity(0.6), radius: 6)
                    .scaleEffect(showCheckmark ? 1 : 0)
            }
            
            VStack(spacing: 14) {
                Text("Page \(pageNumber) Captured")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                
                HStack(spacing: 10) {
                    Image(systemName: "arrow.turn.up.right")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Turn the page")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .opacity(showText ? 1 : 0)
            .offset(y: showText ? 0 : 12)
        }
        .padding(44)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 45, y: 14)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                showCheckmark = true
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.2)) {
                showText = true
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }
}

#Preview {
    CaptureSuccessOverlay(pageNumber: 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
}
