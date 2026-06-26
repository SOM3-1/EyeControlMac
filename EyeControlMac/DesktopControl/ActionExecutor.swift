//
//  ActionExecutor.swift
//  EyeControlMac
//
//  Created by Dushyanth N Gowda on 6/24/26.
//

import Foundation
import Combine

@MainActor
final class ActionExecutor: ObservableObject {
    private let documentActionController: DocumentActionControlling

    init() {
        self.documentActionController = DocumentActionController()
    }

    init(documentActionController: DocumentActionControlling) {
        self.documentActionController = documentActionController
    }

    func execute(_ command: EyeCommand, appState: AppState) {
        let permission = appState.permission(for: command)

        guard permission.isAllowed else {
            appState.markBlocked(
                command,
                reason: permission.blockedReason ?? "Action is not allowed."
            )
            return
        }

        let message: String

        switch command {
        case .scrollUp:
            let result = documentActionController.scrollUp()
            guard applyDocumentResult(result, command: command, appState: appState) else { return }
            message = "Scroll Up used \(result.strategy.debugName) for \(result.targetAppName ?? "Unknown App")"
        case .scrollDown:
            let result = documentActionController.scrollDown()
            guard applyDocumentResult(result, command: command, appState: appState) else { return }
            message = "Scroll Down used \(result.strategy.debugName) for \(result.targetAppName ?? "Unknown App")"
        case .nextPage:
            let result = documentActionController.nextPage()
            guard applyDocumentResult(result, command: command, appState: appState) else { return }
            message = "Next Page sent \(result.keySent) to \(result.targetAppName ?? "Unknown App") using \(result.strategy.debugName)"
        case .previousPage:
            let result = documentActionController.previousPage()
            guard applyDocumentResult(result, command: command, appState: appState) else { return }
            message = "Previous Page sent \(result.keySent) to \(result.targetAppName ?? "Unknown App") using \(result.strategy.debugName)"
        case .minimizeCurrentWindow:
            message = "Minimize Current Window placeholder executed"
        case .maximizeCurrentWindow:
            message = "Maximize Current Window placeholder executed"
        case .switchWindow:
            message = "Switch Window placeholder executed"
        case .pause:
            message = "Paused eye control"
        case .resume:
            message = "Resumed eye control"
        case .recalibrate:
            message = "Recalibrate placeholder executed"
        case .settings:
            message = "Settings placeholder executed"
        }

        appState.markExecuted(command, message: message)
    }

    private func applyDocumentResult(
        _ result: DocumentActionResult,
        command: EyeCommand,
        appState: AppState
    ) -> Bool {
        appState.documentTargetAppName = result.targetAppName ?? "None"
        appState.documentTargetPID = result.targetPID.map(String.init) ?? "None"
        appState.documentTargetSource = result.targetSource.debugName
        appState.lastDocumentStrategyUsed = result.strategy.debugName
        appState.lastKeySent = result.keySent
        appState.lastScrollEvent = result.scrollEvent
        appState.lastScrollMethod = result.strategy == .directScrollToPid || result.strategy == .fallbackScrollAtMouseLocation ? "CGEvent" : "Keyboard"
        appState.directPostStatus = result.directPostStatus

        guard result.didSend else {
            appState.markBlocked(
                command,
                reason: result.blockedReason ?? "No document app target found.",
                includeReasonInLastAction: true
            )
            return false
        }

        return true
    }
}
