//
//  CameraSelector.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/30/25.
//

import SwiftUI
import AVFoundation

/// Camera source selector with native macOS menu styling
/// Shows connection status with a colored indicator dot
struct CameraSelector: View {
    let availableDevices: [AVCaptureDevice]
    let currentDevice: AVCaptureDevice?
    let isConnected: Bool
    let onSelectDevice: (AVCaptureDevice) -> Void
    
    private let statusDotSize: CGFloat = 7
    
    var body: some View {
        Menu {
            if availableDevices.isEmpty {
                Text("No cameras available")
            } else {
                ForEach(availableDevices, id: \.uniqueID) { device in
                    Button {
                        onSelectDevice(device)
                    } label: {
                        HStack {
                            Text(device.localizedName)
                            if device.uniqueID == currentDevice?.uniqueID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                
                // Connection status dot
                Circle()
                    .fill(statusColor)
                    .frame(width: statusDotSize, height: statusDotSize)
                    .shadow(color: statusColor.opacity(0.5), radius: 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
    
    private var statusColor: Color {
        isConnected ? .green : .orange
    }
}

#Preview {
    CameraSelector(
        availableDevices: [],
        currentDevice: nil,
        isConnected: true,
        onSelectDevice: { _ in }
    )
    .padding(20)
}
