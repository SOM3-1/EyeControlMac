//
//  EyeControlMacApp.swift
//  EyeControlMac
//
//  Created by Dushyanth N Gowda on 6/24/26.
//

import AppKit
import SwiftUI

@MainActor
final class EyeControlMacAppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    let actionExecutor = ActionExecutor()
    let globalShortcutManager = GlobalShortcutManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        globalShortcutManager.start(
            appState: appState,
            actionExecutor: actionExecutor
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        globalShortcutManager.stop()
    }
}

@main
struct EyeControlMacApp: App {
    @NSApplicationDelegateAdaptor(EyeControlMacAppDelegate.self) private var appDelegate

    private var appState: AppState {
        appDelegate.appState
    }

    private var actionExecutor: ActionExecutor {
        appDelegate.actionExecutor
    }

    private var globalShortcutManager: GlobalShortcutManager {
        appDelegate.globalShortcutManager
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(actionExecutor)
                .environmentObject(globalShortcutManager)
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
