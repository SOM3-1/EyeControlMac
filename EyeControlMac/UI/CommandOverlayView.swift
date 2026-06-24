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
        GridItem(.adaptive(minimum: 150), spacing: 12)
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
                    let permission = appState.permission(for: command)

                    CommandButton(
                        command: command,
                        isSelected: appState.selectedCommand == command,
                        permission: permission
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
    let permission: CommandPermission
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: command.systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 20)

                    Text(command.title)
                        .font(.callout.weight(isSelected ? .semibold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Spacer(minLength: 0)
                }

                if let badgeText {
                    Text(badgeText)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .foregroundStyle(badgeForegroundStyle)
                        .background(badgeBackgroundStyle, in: Capsule())
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 62, alignment: .leading)
            .foregroundStyle(foregroundStyle)
            .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(borderStyle, lineWidth: isSelected ? 3 : 1)
            }
            .shadow(
                color: isSelected ? selectionColor.opacity(0.25) : .clear,
                radius: isSelected ? 8 : 0,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .opacity(permission.isAllowed ? 1 : 0.66)
        .accessibilityLabel(command.title)
        .accessibilityValue(accessibilityValue)
    }

    private var foregroundStyle: Color {
        if isSelected {
            return permission.isAllowed ? .white : .primary
        }

        return permission.isAllowed ? .primary : .secondary
    }

    private var backgroundStyle: Color {
        if isSelected {
            return permission.isAllowed ? selectionColor : Color.orange.opacity(0.22)
        }

        if permission.isAllowed {
            return Color(nsColor: .controlBackgroundColor)
        }

        return Color(nsColor: .controlBackgroundColor).opacity(0.55)
    }

    private var borderStyle: Color {
        if isSelected {
            return permission.isAllowed ? selectionColor : .orange
        }

        return permission.isAllowed ? .secondary.opacity(0.35) : .orange.opacity(0.55)
    }

    private var selectionColor: Color {
        .blue
    }

    private var badgeText: String? {
        switch permission.blockedKind {
        case .paused:
            return command == .resume ? nil : "Paused"
        case .mode:
            return "Disabled in mode"
        case nil:
            return isSelected ? "Selected" : nil
        }
    }

    private var badgeForegroundStyle: Color {
        permission.isAllowed ? .blue : .orange
    }

    private var badgeBackgroundStyle: Color {
        permission.isAllowed ? .white : .orange.opacity(0.14)
    }

    private var accessibilityValue: String {
        if permission.isAllowed {
            return isSelected ? "Selected and available" : "Available"
        }

        return permission.blockedReason ?? "Unavailable"
    }
}

struct CommandOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        CommandOverlayView()
            .environmentObject(AppState())
    }
}
