//
//  CapturedPageRow.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI

/// A row displaying a captured page thumbnail with metadata and delete action
struct CapturedPageRow: View {
    let page: CapturedPage
    let pageNumber: Int
    var isHighlighted: Bool = false
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Page number
            Text("\(pageNumber)")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(isHighlighted ? Color(hex: "10B981") : .white.opacity(0.5))
                .frame(width: 24)
            
            // Thumbnail
            if let thumbnail = page.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 65)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: isHighlighted ? Color(hex: "10B981").opacity(0.5) : .black.opacity(0.3), radius: isHighlighted ? 8 : 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isHighlighted ? Color(hex: "10B981") : .clear, lineWidth: 2)
                    )
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 50, height: 65)
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(.white)
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(page.preset.rawValue)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                
                if let bounds = page.bounds {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text("\(Int(bounds.confidence * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(8)
                    .background(Color.red.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHighlighted ? Color(hex: "10B981").opacity(0.15) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isHighlighted ? Color(hex: "10B981").opacity(0.5) : .clear, lineWidth: 1)
        )
        .scaleEffect(isHighlighted ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHighlighted)
    }
}
