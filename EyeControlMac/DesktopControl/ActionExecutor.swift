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
    func execute(_ command: EyeCommand, appState: AppState) {
        guard appState.canExecute(command) else {
            appState.markBlocked(
                command,
                reason: appState.blockedReason(for: command) ?? "Action is not allowed."
            )
            return
        }

        let message: String

        switch command {
        case .scrollUp:
            message = "Placeholder: Scroll Up"
        case .scrollDown:
            message = "Placeholder: Scroll Down"
        case .nextPage:
            message = "Placeholder: Next Page"
        case .previousPage:
            message = "Placeholder: Previous Page"
        case .minimizeCurrentWindow:
            message = "Placeholder: Minimize Current Window"
        case .maximizeCurrentWindow:
            message = "Placeholder: Maximize Current Window"
        case .switchWindow:
            message = "Placeholder: Open Window Switcher"
        case .pause:
            message = "Paused eye control"
        case .resume:
            message = "Resumed eye control"
        case .recalibrate:
            message = "Placeholder: Start Calibration"
        case .settings:
            message = "Placeholder: Open Settings"
        }

        appState.markExecuted(command, message: message)
    }
}
