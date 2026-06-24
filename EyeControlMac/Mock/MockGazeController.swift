//
//  MockGazeController.swift
//  EyeControlMac
//
//  Created by Dushyanth N Gowda on 6/24/26.
//

import Foundation

@MainActor
struct MockGazeController {
    func moveSelectionUp(appState: AppState) {
        appState.moveSelection(by: -1)
    }

    func moveSelectionDown(appState: AppState) {
        appState.moveSelection(by: 1)
    }

    func moveSelectionLeft(appState: AppState) {
        appState.moveSelection(by: -1)
    }

    func moveSelectionRight(appState: AppState) {
        appState.moveSelection(by: 1)
    }
}
