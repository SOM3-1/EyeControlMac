//
//  AppState.swift
//  EyeControlMac
//
//  Created by Dushyanth N Gowda on 6/24/26.
//

import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var isPaused = true
    @Published var controlMode: ControlMode = .reading
    @Published var isCommandOverlayVisible = true
    @Published var isDebugPanelVisible = true
    @Published var selectedCommand: EyeCommand = .resume
    @Published var lastAction: String = "App started in Paused Mode"
    @Published var lastBlockedReason: String?
    @Published var mockDoubleBlinkCount = 0

    let commands = EyeCommand.overlayCommands

    var statusTitle: String {
        isPaused ? "Paused" : "Active"
    }

    func select(_ command: EyeCommand) {
        selectedCommand = command
        lastBlockedReason = nil
    }

    func moveSelection(by offset: Int) {
        guard let currentIndex = commands.firstIndex(of: selectedCommand) else {
            selectedCommand = commands.first ?? .resume
            return
        }

        let nextIndex = (currentIndex + offset + commands.count) % commands.count
        selectedCommand = commands[nextIndex]
        lastBlockedReason = nil
    }

    func canExecute(_ command: EyeCommand) -> Bool {
        if isPaused {
            return command == .resume
        }

        return controlMode.allows(command)
    }

    func blockedReason(for command: EyeCommand) -> String? {
        if isPaused && command != .resume {
            return "Paused Mode blocks all eye-triggered actions except Resume."
        }

        if !controlMode.allows(command) {
            return "\(command.title) is not allowed in \(controlMode.title) Mode."
        }

        return nil
    }

    func handleMockDoubleBlink(actionExecutor: ActionExecutor) {
        mockDoubleBlinkCount += 1
        actionExecutor.execute(selectedCommand, appState: self)
    }

    func togglePause(actionExecutor: ActionExecutor) {
        actionExecutor.execute(isPaused ? .resume : .pause, appState: self)
    }

    func emergencyPause(actionExecutor: ActionExecutor) {
        actionExecutor.execute(.pause, appState: self)
    }

    func markExecuted(_ command: EyeCommand, message: String) {
        lastAction = message
        lastBlockedReason = nil

        switch command {
        case .pause:
            isPaused = true
            selectedCommand = .resume
        case .resume:
            isPaused = false
            selectedCommand = .scrollDown
        case .switchWindow:
            controlMode = .windowSwitcher
        case .recalibrate:
            controlMode = .calibration
        case .settings:
            break
        default:
            break
        }
    }

    func markBlocked(_ command: EyeCommand, reason: String) {
        lastBlockedReason = reason
        lastAction = "Blocked \(command.title)"
    }
}
