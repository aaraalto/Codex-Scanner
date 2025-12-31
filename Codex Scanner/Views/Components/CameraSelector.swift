//
//  CameraSelector.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/30/25.
//

import SwiftUI
import AVFoundation

/// Camera source selector with native macOS styling
struct CameraSelector: View {
    let availableDevices: [AVCaptureDevice]
    let currentDevice: AVCaptureDevice?
    let isConnected: Bool
    let onSelectDevice: (AVCaptureDevice) -> Void
    
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
            HStack(spacing: 6) {
                Image(systemName: isConnected ? "camera.fill" : "camera")
                Circle()
                    .fill(isConnected ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
            }
        }
        .menuStyle(.borderlessButton)
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
