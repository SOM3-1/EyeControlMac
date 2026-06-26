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
    @Published var documentTargetAppName = "None"
    @Published var documentTargetPID = "None"
    @Published var documentTargetSource = "None"
    @Published var lastKeySent = "None"
    @Published var lastScrollEvent = "None"
    @Published var lastScrollMethod = "None"
    @Published var lastDocumentStrategyUsed = "None"
    @Published var directPostStatus = "Not attempted"
    @Published var isBackgroundControlEnabled = false
    @Published var isGlobalShortcutManagerStarted = false
    @Published var registeredHotkeysCount = 0
    @Published var hotkeyRegistrationStatuses: [String] = []
    @Published var lastGlobalShortcut = "None"
    @Published var backgroundControlStatus = "Not started"
    @Published var mockDoubleBlinkCount = 0

    let commands = EyeCommand.overlayCommands

    var statusTitle: String {
        isPaused ? "Paused" : "Active"
    }

    func setControlMode(_ mode: ControlMode) {
        guard mode == .reading || mode == .desktop else {
            controlMode = mode
            return
        }

        controlMode = mode
        lastBlockedReason = nil
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
        permission(for: command).isAllowed
    }

    func permission(for command: EyeCommand) -> CommandPermission {
        if isPaused && command != .resume {
            return .blocked(
                reason: "Paused Mode blocks all eye-triggered actions except Resume.",
                kind: .paused
            )
        }

        if !controlMode.allows(command) {
            return .blocked(
                reason: "\(command.title) is not allowed in \(controlMode.title) Mode.",
                kind: .mode
            )
        }

        return .allowed
    }

    func blockedReason(for command: EyeCommand) -> String? {
        permission(for: command).blockedReason
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
        default:
            break
        }
    }

    func markBlocked(_ command: EyeCommand, reason: String, includeReasonInLastAction: Bool = false) {
        lastBlockedReason = reason
        lastAction = includeReasonInLastAction ? "Blocked \(command.title): \(reason)" : "Blocked \(command.title)"
    }
}

enum CommandPermission: Equatable {
    case allowed
    case blocked(reason: String, kind: BlockedCommandKind)

    var isAllowed: Bool {
        self == .allowed
    }

    var blockedReason: String? {
        switch self {
        case .allowed:
            return nil
        case .blocked(let reason, _):
            return reason
        }
    }

    var blockedKind: BlockedCommandKind? {
        switch self {
        case .allowed:
            return nil
        case .blocked(_, let kind):
            return kind
        }
    }
}

enum BlockedCommandKind: Equatable {
    case paused
    case mode
}
