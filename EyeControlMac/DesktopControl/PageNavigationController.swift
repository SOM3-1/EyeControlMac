//
//  PageNavigationController.swift
//  EyeControlMac
//
//  Created by Dushyanth N Gowda on 6/24/26.
//

import Carbon.HIToolbox
import CoreGraphics
import Foundation

@MainActor
protocol PageNavigationControlling {
    func nextPage() -> PageNavigationKeyStrategy
    func previousPage() -> PageNavigationKeyStrategy
}

@MainActor
final class PageNavigationController: PageNavigationControlling {
    private let nextPageStrategy: PageNavigationKeyStrategy
    private let previousPageStrategy: PageNavigationKeyStrategy

    init(
        nextPageStrategy: PageNavigationKeyStrategy = .pageDown,
        previousPageStrategy: PageNavigationKeyStrategy = .pageUp
    ) {
        self.nextPageStrategy = nextPageStrategy
        self.previousPageStrategy = previousPageStrategy
    }

    func nextPage() -> PageNavigationKeyStrategy {
        postKey(nextPageStrategy.keyCode)
        return nextPageStrategy
    }

    func previousPage() -> PageNavigationKeyStrategy {
        postKey(previousPageStrategy.keyCode)
        return previousPageStrategy
    }

    func nextPageWithRightArrow() -> PageNavigationKeyStrategy {
        postKey(PageNavigationKeyStrategy.rightArrow.keyCode)
        return .rightArrow
    }

    func previousPageWithLeftArrow() -> PageNavigationKeyStrategy {
        postKey(PageNavigationKeyStrategy.leftArrow.keyCode)
        return .leftArrow
    }

    func nextPageWithDownArrow() -> PageNavigationKeyStrategy {
        postKey(PageNavigationKeyStrategy.downArrow.keyCode)
        return .downArrow
    }

    func previousPageWithUpArrow() -> PageNavigationKeyStrategy {
        postKey(PageNavigationKeyStrategy.upArrow.keyCode)
        return .upArrow
    }

    private func postKey(_ keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

enum PageNavigationKeyStrategy: Equatable {
    case pageDown
    case pageUp
    case rightArrow
    case leftArrow
    case downArrow
    case upArrow

    var keyCode: CGKeyCode {
        switch self {
        case .pageDown:
            return CGKeyCode(kVK_PageDown)
        case .pageUp:
            return CGKeyCode(kVK_PageUp)
        case .rightArrow:
            return CGKeyCode(kVK_RightArrow)
        case .leftArrow:
            return CGKeyCode(kVK_LeftArrow)
        case .downArrow:
            return CGKeyCode(kVK_DownArrow)
        case .upArrow:
            return CGKeyCode(kVK_UpArrow)
        }
    }

    var debugName: String {
        switch self {
        case .pageDown:
            return "Page Down"
        case .pageUp:
            return "Page Up"
        case .rightArrow:
            return "Right Arrow"
        case .leftArrow:
            return "Left Arrow"
        case .downArrow:
            return "Down Arrow"
        case .upArrow:
            return "Up Arrow"
        }
    }
}
