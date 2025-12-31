//
//  RecordButton.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/30/25.
//

import SwiftUI

/// Compact play/pause button for scanning control
/// Clean, minimal design that doesn't distract from the content
struct RecordButton: View {
    let isRecording: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    // Compact sizing
    private let buttonSize: CGFloat = 52
    private let iconSize: CGFloat = 18
    
    init(isRecording: Bool, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.isRecording = isRecording
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background
                Circle()
                    .fill(.regularMaterial)
                    .overlay(
                        Circle()
                            .fill(isRecording ? Color.red.opacity(0.15) : Color.clear)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isRecording 
                                    ? Color.red.opacity(0.6)
                                    : Color.white.opacity(isHovered ? 0.3 : 0.15),
                                lineWidth: 1.5
                            )
                    )
                
                // Icon
                Image(systemName: isRecording ? "pause.fill" : "play.fill")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(isRecording ? .red : .primary)
                    .offset(x: isRecording ? 0 : 2) // Optical centering for play icon
            }
            .frame(width: buttonSize, height: buttonSize)
            .scaleEffect(isPressed ? 0.92 : (isHovered ? 1.05 : 1.0))
            .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.4)
        .onHover { hovering in
            guard isEnabled else { return }
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in 
                    if isEnabled { 
                        withAnimation(.easeOut(duration: 0.1)) {
                            isPressed = true 
                        }
                    } 
                }
                .onEnded { _ in 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = false 
                    }
                }
        )
        .help(isRecording ? "Pause Scanning" : "Start Scanning")
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isRecording)
    }
}

#Preview {
    HStack(spacing: 30) {
        RecordButton(isRecording: false) {
            print("Start")
        }
        
        RecordButton(isRecording: true) {
            print("Pause")
        }
        
        RecordButton(isRecording: false, isEnabled: false) {
            print("Disabled")
        }
    }
    .padding(40)
    .background(Color(nsColor: .windowBackgroundColor))
}
