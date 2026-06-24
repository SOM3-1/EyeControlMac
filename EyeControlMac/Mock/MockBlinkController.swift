//
//  MockBlinkController.swift
//  EyeControlMac
//
//  Created by Dushyanth N Gowda on 6/24/26.
//

import Foundation

@MainActor
struct MockBlinkController {
    func simulateDoubleBlink(appState: AppState, actionExecutor: ActionExecutor) {
        appState.handleMockDoubleBlink(actionExecutor: actionExecutor)
    }
}
