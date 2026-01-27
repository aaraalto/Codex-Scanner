//
//  ScanningState.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI

/// Represents the current state of a scanning session
enum ScanningState: String, CaseIterable {
    case stopped = "Stopped"
    case scanning = "Scanning"
    case paused = "Paused"
    
    var icon: String {
        switch self {
        case .stopped: return "stop.fill"
        case .scanning: return "play.fill"
        case .paused: return "pause.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .stopped: return .secondary
        case .scanning: return .green
        case .paused: return .orange
        }
    }
}
