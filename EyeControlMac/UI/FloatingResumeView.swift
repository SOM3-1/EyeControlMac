//
//  FloatingResumeView.swift
//  EyeControlMac
//
//  Created by Dushyanth N Gowda on 6/24/26.
//

import SwiftUI

struct FloatingResumeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var actionExecutor: ActionExecutor

    var body: some View {
        Button {
            appState.select(.resume)
            appState.handleMockDoubleBlink(actionExecutor: actionExecutor)
        } label: {
            Label("Resume", systemImage: "play.fill")
                .font(.headline)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(Color.green, in: Capsule())
        }
        .buttonStyle(.plain)
        .shadow(radius: 8)
        .accessibilityLabel("Resume EyeControlMac")
    }
}

struct FloatingResumeView_Previews: PreviewProvider {
    static var previews: some View {
        FloatingResumeView()
            .environmentObject(AppState())
            .environmentObject(ActionExecutor())
    }
}
