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
    private let scrollController: ScrollControlling
    private let pageNavigationController: PageNavigationControlling

    init() {
        self.scrollController = ScrollController()
        self.pageNavigationController = PageNavigationController()
    }

    init(scrollController: ScrollControlling, pageNavigationController: PageNavigationControlling) {
        self.scrollController = scrollController
        self.pageNavigationController = pageNavigationController
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
            let result = scrollController.scrollUp()
            message = "Scroll Up event posted; ScrollController called (\(result.debugDescription))"
        case .scrollDown:
            let result = scrollController.scrollDown()
            message = "Scroll Down event posted; ScrollController called (\(result.debugDescription))"
        case .nextPage:
            let strategy = pageNavigationController.nextPage()
            message = "Next Page executed using \(strategy.debugName)"
        case .previousPage:
            let strategy = pageNavigationController.previousPage()
            message = "Previous Page executed using \(strategy.debugName)"
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
}
