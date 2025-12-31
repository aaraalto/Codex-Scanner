//
//  RecordButton.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/30/25.
//

import SwiftUI

/// Large circular record button with refined macOS styling
/// Shows red square when recording, circle when idle
struct RecordButton: View {
    let isRecording: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    // Design constants
    private let outerSize: CGFloat = 80
    private let innerSquareSize: CGFloat = 32
    private let innerCircleSize: CGFloat = 60
    private let borderWidth: CGFloat = 3
    
    init(isRecording: Bool, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.isRecording = isRecording
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: outerSize, height: outerSize)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isRecording ? Color.red : Color.primary.opacity(0.15),
                                lineWidth: borderWidth
                            )
                    )
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                
                // Inner shape - square when recording, circle when idle
                if isRecording {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.red)
                        .frame(width: innerSquareSize, height: innerSquareSize)
                        .shadow(color: Color.red.opacity(0.5), radius: 8)
                } else {
                    Circle()
                        .fill(Color.primary.opacity(0.85))
                        .frame(width: innerCircleSize, height: innerCircleSize)
                }
            }
            .scaleEffect(isPressed ? 0.94 : (isHovered ? 1.03 : 1.0))
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
        .onHover { hovering in
            guard isEnabled else { return }
            isHovered = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .help(isRecording ? "Stop Scanning" : "Start Scanning")
    }
}

#Preview {
    VStack(spacing: 40) {
        RecordButton(isRecording: false) {
            print("Start recording")
        }
        
        RecordButton(isRecording: true) {
            print("Stop recording")
        }
        
        RecordButton(isRecording: false, isEnabled: false) {
            print("Disabled")
        }
    }
    .padding(40)
    .background(Color(nsColor: .windowBackgroundColor))
}
