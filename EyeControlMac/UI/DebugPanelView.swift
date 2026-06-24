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
            DebugRow(label: "Double Blinks", value: "\(appState.mockDoubleBlinkCount)")
            DebugRow(label: "Last Action", value: appState.lastAction)

            if let blockedReason = appState.lastBlockedReason {
                Text(blockedReason)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.caption)
        .padding(14)
        .frame(maxWidth: 280, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct DebugRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)
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
