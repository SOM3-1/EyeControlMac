//
//  EyeControlMacTests.swift
//  EyeControlMacTests
//
//  Created by Dushyanth N Gowda on 6/24/26.
//

import XCTest
@testable import EyeControlMac

@MainActor
final class EyeControlMacTests: XCTestCase {
    func testAppStartsPaused() {
        let appState = AppState()

        XCTAssertTrue(appState.isPaused)
        XCTAssertEqual(appState.controlMode, .reading)
        XCTAssertEqual(appState.selectedCommand, .resume)
    }

    func testPausedModeBlocksAllCommandsExceptResume() {
        let appState = AppState()

        for command in EyeCommand.overlayCommands where command != .resume {
            XCTAssertFalse(appState.canExecute(command), "\(command.title) should be blocked while paused")
            XCTAssertEqual(appState.permission(for: command).blockedKind, .paused)
        }

        XCTAssertTrue(appState.canExecute(.resume))
    }

    func testReadingModeBlocksWindowActions() {
        let appState = activeAppState(mode: .reading)

        XCTAssertFalse(appState.canExecute(.minimizeCurrentWindow))
        XCTAssertFalse(appState.canExecute(.maximizeCurrentWindow))
        XCTAssertFalse(appState.canExecute(.switchWindow))
        XCTAssertEqual(appState.permission(for: .switchWindow).blockedKind, .mode)
    }

    func testDesktopModeAllowsWindowActions() {
        let appState = activeAppState(mode: .desktop)

        XCTAssertTrue(appState.canExecute(.minimizeCurrentWindow))
        XCTAssertTrue(appState.canExecute(.maximizeCurrentWindow))
        XCTAssertTrue(appState.canExecute(.switchWindow))
    }

    func testEscapePausesImmediately() {
        let appState = activeAppState(mode: .desktop)
        let actionExecutor = ActionExecutor()

        appState.emergencyPause(actionExecutor: actionExecutor)

        XCTAssertTrue(appState.isPaused)
        XCTAssertEqual(appState.lastAction, "Paused eye control")
        XCTAssertEqual(appState.selectedCommand, .resume)
    }

    func testActionExecutorDoesNotExecuteBlockedActions() {
        let appState = activeAppState(mode: .reading)
        let actionExecutor = ActionExecutor()

        actionExecutor.execute(.maximizeCurrentWindow, appState: appState)

        XCTAssertFalse(appState.isPaused)
        XCTAssertEqual(appState.controlMode, .reading)
        XCTAssertEqual(appState.lastAction, "Blocked Maximize")
        XCTAssertEqual(appState.lastBlockedReason, "Maximize is not allowed in Reading Mode.")
    }

    func testActionExecutorUpdatesLastActionForAllowedActions() {
        let appState = activeAppState(mode: .reading)
        let scrollController = MockScrollController()
        let pageNavigationController = MockPageNavigationController()
        let actionExecutor = ActionExecutor(
            scrollController: scrollController,
            pageNavigationController: pageNavigationController
        )

        let expectedMessages: [(EyeCommand, String)] = [
            (.scrollUp, "Scroll Up event posted; ScrollController called (pixel, 1/1 pulses, value 18)"),
            (.scrollDown, "Scroll Down event posted; ScrollController called (pixel, 1/1 pulses, value -18)"),
            (.nextPage, "Next Page executed using Page Down"),
            (.previousPage, "Previous Page executed using Page Up"),
            (.recalibrate, "Recalibrate placeholder executed"),
            (.settings, "Settings placeholder executed")
        ]

        for (command, expectedMessage) in expectedMessages {
            actionExecutor.execute(command, appState: appState)

            XCTAssertEqual(appState.lastAction, expectedMessage)
            XCTAssertNil(appState.lastBlockedReason)
            XCTAssertFalse(appState.isPaused)
        }

        XCTAssertEqual(scrollController.scrollUpCallCount, 1)
        XCTAssertEqual(scrollController.scrollDownCallCount, 1)
        XCTAssertEqual(pageNavigationController.nextPageCallCount, 1)
        XCTAssertEqual(pageNavigationController.previousPageCallCount, 1)
    }

    func testPauseActionChangesStateToPaused() {
        let appState = activeAppState(mode: .desktop)
        let actionExecutor = ActionExecutor()

        actionExecutor.execute(.pause, appState: appState)

        XCTAssertTrue(appState.isPaused)
        XCTAssertEqual(appState.lastAction, "Paused eye control")
        XCTAssertEqual(appState.selectedCommand, .resume)
    }

    func testResumeActionChangesStateToActive() {
        let appState = AppState()
        let actionExecutor = ActionExecutor()

        actionExecutor.execute(.resume, appState: appState)

        XCTAssertFalse(appState.isPaused)
        XCTAssertEqual(appState.lastAction, "Resumed eye control")
        XCTAssertEqual(appState.selectedCommand, .scrollDown)
    }

    func testCommandShiftETogglesPauseAndResume() {
        let appState = AppState()
        let actionExecutor = ActionExecutor()

        appState.togglePause(actionExecutor: actionExecutor)
        XCTAssertFalse(appState.isPaused)
        XCTAssertEqual(appState.lastAction, "Resumed eye control")

        appState.togglePause(actionExecutor: actionExecutor)
        XCTAssertTrue(appState.isPaused)
        XCTAssertEqual(appState.lastAction, "Paused eye control")
    }

    func testSpaceExecutesOnlySelectedAllowedCommand() {
        let appState = activeAppState(mode: .reading)
        let pageNavigationController = MockPageNavigationController()
        let actionExecutor = ActionExecutor(
            scrollController: MockScrollController(),
            pageNavigationController: pageNavigationController
        )

        appState.select(.nextPage)
        appState.handleMockDoubleBlink(actionExecutor: actionExecutor)

        XCTAssertEqual(appState.lastAction, "Next Page executed using Page Down")
        XCTAssertNil(appState.lastBlockedReason)
        XCTAssertEqual(appState.mockDoubleBlinkCount, 1)
        XCTAssertEqual(pageNavigationController.nextPageCallCount, 1)

        appState.select(.minimizeCurrentWindow)
        appState.handleMockDoubleBlink(actionExecutor: actionExecutor)

        XCTAssertEqual(appState.lastAction, "Blocked Minimize")
        XCTAssertEqual(appState.lastBlockedReason, "Minimize is not allowed in Reading Mode.")
        XCTAssertEqual(appState.mockDoubleBlinkCount, 2)
        XCTAssertEqual(pageNavigationController.nextPageCallCount, 1)
    }

    func testSpaceWhilePausedExecutesOnlyResume() {
        let appState = AppState()
        let actionExecutor = ActionExecutor()

        appState.select(.scrollDown)
        appState.handleMockDoubleBlink(actionExecutor: actionExecutor)

        XCTAssertTrue(appState.isPaused)
        XCTAssertEqual(appState.lastAction, "Blocked Scroll Down")

        appState.select(.resume)
        appState.handleMockDoubleBlink(actionExecutor: actionExecutor)

        XCTAssertFalse(appState.isPaused)
        XCTAssertEqual(appState.lastAction, "Resumed eye control")
    }

    func testDesktopModeAllowsWindowActionPlaceholders() {
        let appState = activeAppState(mode: .desktop)
        let actionExecutor = ActionExecutor()

        let expectedMessages: [(EyeCommand, String)] = [
            (.minimizeCurrentWindow, "Minimize Current Window placeholder executed"),
            (.maximizeCurrentWindow, "Maximize Current Window placeholder executed"),
            (.switchWindow, "Switch Window placeholder executed")
        ]

        for (command, expectedMessage) in expectedMessages {
            actionExecutor.execute(command, appState: appState)

            XCTAssertEqual(appState.lastAction, expectedMessage)
            XCTAssertNil(appState.lastBlockedReason)
            XCTAssertEqual(appState.controlMode, .desktop)
            XCTAssertFalse(appState.isPaused)
        }
    }

    func testPausedModeBlocksDocumentActions() {
        let appState = AppState()
        let scrollController = MockScrollController()
        let pageNavigationController = MockPageNavigationController()
        let actionExecutor = ActionExecutor(
            scrollController: scrollController,
            pageNavigationController: pageNavigationController
        )

        for command in [EyeCommand.scrollUp, .scrollDown, .nextPage, .previousPage] {
            actionExecutor.execute(command, appState: appState)

            XCTAssertTrue(appState.isPaused)
            XCTAssertEqual(appState.permission(for: command).blockedKind, .paused)
        }

        XCTAssertEqual(scrollController.scrollUpCallCount, 0)
        XCTAssertEqual(scrollController.scrollDownCallCount, 0)
        XCTAssertEqual(pageNavigationController.nextPageCallCount, 0)
        XCTAssertEqual(pageNavigationController.previousPageCallCount, 0)
    }

    func testActiveReadingModeAllowsDocumentActions() {
        let appState = activeAppState(mode: .reading)

        XCTAssertTrue(appState.canExecute(.scrollUp))
        XCTAssertTrue(appState.canExecute(.scrollDown))
        XCTAssertTrue(appState.canExecute(.nextPage))
        XCTAssertTrue(appState.canExecute(.previousPage))
    }

    func testDesktopModeAllowsDocumentActions() {
        let appState = activeAppState(mode: .desktop)

        XCTAssertTrue(appState.canExecute(.scrollUp))
        XCTAssertTrue(appState.canExecute(.scrollDown))
        XCTAssertTrue(appState.canExecute(.nextPage))
        XCTAssertTrue(appState.canExecute(.previousPage))
    }

    func testActionExecutorRoutesDocumentCommandsThroughControllers() {
        let appState = activeAppState(mode: .reading)
        let scrollController = MockScrollController()
        let pageNavigationController = MockPageNavigationController()
        let actionExecutor = ActionExecutor(
            scrollController: scrollController,
            pageNavigationController: pageNavigationController
        )

        actionExecutor.execute(.scrollUp, appState: appState)
        actionExecutor.execute(.scrollDown, appState: appState)
        actionExecutor.execute(.nextPage, appState: appState)
        actionExecutor.execute(.previousPage, appState: appState)

        XCTAssertEqual(scrollController.scrollUpCallCount, 1)
        XCTAssertEqual(scrollController.scrollDownCallCount, 1)
        XCTAssertEqual(pageNavigationController.nextPageCallCount, 1)
        XCTAssertEqual(pageNavigationController.previousPageCallCount, 1)
        XCTAssertEqual(appState.lastAction, "Previous Page executed using Page Up")
    }

    func testActionExecutorReportsConfiguredPageNavigationStrategies() {
        let appState = activeAppState(mode: .reading)
        let pageNavigationController = MockPageNavigationController(
            nextStrategy: .rightArrow,
            previousStrategy: .leftArrow
        )
        let actionExecutor = ActionExecutor(
            scrollController: MockScrollController(),
            pageNavigationController: pageNavigationController
        )

        actionExecutor.execute(.nextPage, appState: appState)
        XCTAssertEqual(appState.lastAction, "Next Page executed using Right Arrow")

        actionExecutor.execute(.previousPage, appState: appState)
        XCTAssertEqual(appState.lastAction, "Previous Page executed using Left Arrow")
        XCTAssertEqual(pageNavigationController.nextPageCallCount, 1)
        XCTAssertEqual(pageNavigationController.previousPageCallCount, 1)
    }

    func testBlockedDocumentCommandsDoNotCallControllers() {
        let appState = AppState()
        let scrollController = MockScrollController()
        let pageNavigationController = MockPageNavigationController()
        let actionExecutor = ActionExecutor(
            scrollController: scrollController,
            pageNavigationController: pageNavigationController
        )

        actionExecutor.execute(.scrollUp, appState: appState)
        actionExecutor.execute(.scrollDown, appState: appState)
        actionExecutor.execute(.nextPage, appState: appState)
        actionExecutor.execute(.previousPage, appState: appState)

        XCTAssertEqual(scrollController.scrollUpCallCount, 0)
        XCTAssertEqual(scrollController.scrollDownCallCount, 0)
        XCTAssertEqual(pageNavigationController.nextPageCallCount, 0)
        XCTAssertEqual(pageNavigationController.previousPageCallCount, 0)
        XCTAssertEqual(appState.lastBlockedReason, "Paused Mode blocks all eye-triggered actions except Resume.")
    }

    private func activeAppState(mode: ControlMode) -> AppState {
        let appState = AppState()
        appState.isPaused = false
        appState.setControlMode(mode)
        return appState
    }
}

@MainActor
private final class MockScrollController: ScrollControlling {
    private(set) var scrollUpCallCount = 0
    private(set) var scrollDownCallCount = 0

    func scrollUp() -> ScrollEventResult {
        scrollUpCallCount += 1
        return ScrollEventResult(
            direction: .up,
            units: .pixel,
            pulseCount: 1,
            valuePerPulse: 18,
            postedEvents: 1
        )
    }

    func scrollDown() -> ScrollEventResult {
        scrollDownCallCount += 1
        return ScrollEventResult(
            direction: .down,
            units: .pixel,
            pulseCount: 1,
            valuePerPulse: -18,
            postedEvents: 1
        )
    }
}

@MainActor
private final class MockPageNavigationController: PageNavigationControlling {
    private(set) var nextPageCallCount = 0
    private(set) var previousPageCallCount = 0
    private let nextStrategy: PageNavigationKeyStrategy
    private let previousStrategy: PageNavigationKeyStrategy

    init(
        nextStrategy: PageNavigationKeyStrategy = .pageDown,
        previousStrategy: PageNavigationKeyStrategy = .pageUp
    ) {
        self.nextStrategy = nextStrategy
        self.previousStrategy = previousStrategy
    }

    func nextPage() -> PageNavigationKeyStrategy {
        nextPageCallCount += 1
        return nextStrategy
    }

    func previousPage() -> PageNavigationKeyStrategy {
        previousPageCallCount += 1
        return previousStrategy
    }
}
