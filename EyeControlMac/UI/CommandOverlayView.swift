//
//  CommandOverlayView.swift
//  EyeControlMac
//
//  Created by Dushyanth N Gowda on 6/24/26.
//

import SwiftUI

struct CommandOverlayView: View {
    @EnvironmentObject private var appState: AppState

    private let columns = [
        GridItem(.adaptive(minimum: 128), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Command Overlay", systemImage: "eye")
                    .font(.headline)

                Spacer()

                Text(appState.statusTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appState.isPaused ? .orange : .green)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(appState.commands) { command in
                    CommandButton(
                        command: command,
                        isSelected: appState.selectedCommand == command,
                        isAllowed: appState.canExecute(command)
                    ) {
                        appState.select(command)
                    }
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct CommandButton: View {
    let command: EyeCommand
    let isSelected: Bool
    let isAllowed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: command.systemImage)
                    .frame(width: 18)

                Text(command.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .foregroundStyle(foregroundStyle)
            .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(borderStyle, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .opacity(isAllowed ? 1 : 0.45)
        .accessibilityLabel(command.title)
    }

    private var foregroundStyle: Color {
        isSelected ? .white : .primary
    }

    private var backgroundStyle: Color {
        if isSelected {
            return isAllowed ? .blue : .gray
        }

        return Color(nsColor: .controlBackgroundColor)
    }

    private var borderStyle: Color {
        if isSelected {
            return isAllowed ? .blue : .gray
        }

        return .secondary.opacity(0.35)
    }
}

struct CommandOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        CommandOverlayView()
            .environmentObject(AppState())
    }
}
