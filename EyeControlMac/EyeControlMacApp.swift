//
//  EyeControlMacApp.swift
//  EyeControlMac
//
//  Created by Dushyanth N Gowda on 6/24/26.
//

import SwiftUI

@main
struct EyeControlMacApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var actionExecutor = ActionExecutor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(actionExecutor)
        }
        .commands {
            CommandMenu("Eye Control") {
                Button("Pause") {
                    actionExecutor.execute(.pause, appState: appState)
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Resume") {
                    actionExecutor.execute(.resume, appState: appState)
                }

                Button(appState.isPaused ? "Resume Eye Control" : "Pause Eye Control") {
                    appState.togglePause(actionExecutor: actionExecutor)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Divider()

                Button(appState.isCommandOverlayVisible ? "Hide Command Overlay" : "Show Command Overlay") {
                    appState.isCommandOverlayVisible.toggle()
                }

                Button(appState.isDebugPanelVisible ? "Hide Debug Panel" : "Show Debug Panel") {
                    appState.isDebugPanelVisible.toggle()
                }
            }
        }

        MenuBarExtra("EyeControlMac \(appState.statusTitle)", systemImage: appState.isPaused ? "pause.circle" : "eye") {
            Text("EyeControlMac")
            Text(appState.statusTitle)

            Divider()

            Button("Pause") {
                actionExecutor.execute(.pause, appState: appState)
            }

            Button("Resume") {
                actionExecutor.execute(.resume, appState: appState)
            }

            Button(appState.isCommandOverlayVisible ? "Hide Command Overlay" : "Show Command Overlay") {
                appState.isCommandOverlayVisible.toggle()
            }
        }
    }
}
