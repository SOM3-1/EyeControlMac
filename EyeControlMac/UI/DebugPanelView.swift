//
//  DebugPanelView.swift
//  EyeControlMac
//
//  Created by Dushyanth N Gowda on 6/24/26.
//

import SwiftUI

struct DebugPanelView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Debug", systemImage: "ladybug")
                .font(.headline)

            DebugRow(label: "Status", value: appState.statusTitle)
            DebugRow(label: "Mode", value: appState.controlMode.title)
            DebugRow(label: "Selected", value: appState.selectedCommand.title)
            DebugRow(label: "Background Control Enabled", value: appState.isBackgroundControlEnabled ? "Yes" : "No")
            DebugRow(label: "Global Shortcut Manager Started", value: appState.isGlobalShortcutManagerStarted ? "Yes" : "No")
            DebugRow(label: "Registered Hotkeys Count", value: "\(appState.registeredHotkeysCount)")
            DebugRow(label: "Last Global Shortcut", value: appState.lastGlobalShortcut)
            DebugRow(label: "Target App", value: appState.documentTargetAppName)
            DebugRow(label: "Target PID", value: appState.documentTargetPID)
            DebugRow(label: "Target Source", value: appState.documentTargetSource)
            DebugRow(label: "Last Document Strategy Used", value: appState.lastDocumentStrategyUsed)
            DebugRow(label: "Last Key Sent", value: appState.lastKeySent)
            DebugRow(label: "Last Scroll Method", value: appState.lastScrollMethod)
            DebugRow(label: "Last Scroll Event", value: appState.lastScrollEvent)
            DebugRow(label: "Direct postToPid Status", value: appState.directPostStatus)
            DebugRow(label: "Background Status", value: appState.backgroundControlStatus)
            RegistrationStatusList(statuses: appState.hotkeyRegistrationStatuses)
            DebugRow(label: "Double Blinks", value: "\(appState.mockDoubleBlinkCount)")
            DebugRow(label: "Last Action", value: appState.lastAction)

            if let blockedReason = appState.lastBlockedReason {
                HStack(alignment: .top) {
                    Text("Blocked Reason")
                        .foregroundStyle(.secondary)
                        .frame(width: 170, alignment: .leading)
                    Text(blockedReason)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(.caption)
        .padding(14)
        .frame(maxWidth: 380, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct RegistrationStatusList: View {
    let statuses: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Registration Status")
                .foregroundStyle(.secondary)

            if statuses.isEmpty {
                Text("None")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(statuses, id: \.self) { status in
                    Text(status)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct DebugRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 170, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DebugPanelView_Previews: PreviewProvider {
    static var previews: some View {
        DebugPanelView()
            .environmentObject(AppState())
    }
}
