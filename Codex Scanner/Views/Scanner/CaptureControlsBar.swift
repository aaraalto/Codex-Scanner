//
//  CaptureControlsBar.swift
//  Codex Scanner
//

import SwiftUI
import AVFoundation

struct CaptureControlsBar: View {
    @ObservedObject var model: ScannerModel

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            captureButton

            Toggle("Auto", isOn: $model.isAutoCaptureEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.white)
                .foregroundStyle(.white)

            Picker("Mode", selection: $model.processingMode) {
                ForEach(ImageProcessor.ProcessingMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 130)

            if model.cameraManager.availableDevices.count > 1 {
                Picker("Camera", selection: deviceBinding) {
                    ForEach(model.cameraManager.availableDevices, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(Optional(device))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 170)
            }

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(Color.scannerControlBackground)
    }

    private var captureButton: some View {
        Button {
            model.capturePhoto()
        } label: {
            ZStack {
                Circle().strokeBorder(.white.opacity(0.7), lineWidth: 3).frame(width: 46, height: 46)
                Circle().fill(.white).frame(width: 36, height: 36)
            }
        }
        .buttonStyle(.plain)
        .disabled(model.phase != .scanning)
        .help("Capture page")
    }

    private var deviceBinding: Binding<AVCaptureDevice?> {
        Binding(
            get: { model.cameraManager.currentDevice },
            set: { device in
                if let device { Task { await model.cameraManager.switchDevice(to: device) } }
            }
        )
    }
}

#Preview {
    CaptureControlsBar(model: ScannerModel())
        .frame(width: 600)
        .background(.black)
}
