//
//  EyeControlMacTests.swift
//  EyeControlMacTests
//
//  Created by Dushyanth N Gowda on 6/24/26.
//

import AppKit
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
        let documentActionController = MockDocumentActionController()
        let actionExecutor = ActionExecutor(documentActionController: documentActionController)

        let expectedMessages: [(EyeCommand, String)] = [
            (.scrollUp, "Scroll Up used directScrollToPid for Preview"),
            (.scrollDown, "Scroll Down used directScrollToPid for Preview"),
            (.nextPage, "Next Page sent Page Down to Preview using directKeyToPid"),
            (.previousPage, "Previous Page sent Page Up to Preview using directKeyToPid"),
            (.recalibrate, "Recalibrate placeholder executed"),
            (.settings, "Settings placeholder executed")
        ]

        for (command, expectedMessage) in expectedMessages {
            actionExecutor.execute(command, appState: appState)

            XCTAssertEqual(appState.lastAction, expectedMessage)
            XCTAssertNil(appState.lastBlockedReason)
            XCTAssertFalse(appState.isPaused)
        }

        XCTAssertEqual(documentActionController.scrollUpCallCount, 1)
        XCTAssertEqual(documentActionController.scrollDownCallCount, 1)
        XCTAssertEqual(documentActionController.nextPageCallCount, 1)
        XCTAssertEqual(documentActionController.previousPageCallCount, 1)
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
        let documentActionController = MockDocumentActionController()
        let actionExecutor = ActionExecutor(documentActionController: documentActionController)

        appState.select(.nextPage)
        appState.handleMockDoubleBlink(actionExecutor: actionExecutor)

        XCTAssertEqual(appState.lastAction, "Next Page sent Page Down to Preview using directKeyToPid")
        XCTAssertNil(appState.lastBlockedReason)
        XCTAssertEqual(appState.mockDoubleBlinkCount, 1)
        XCTAssertEqual(documentActionController.nextPageCallCount, 1)
        XCTAssertEqual(appState.documentTargetAppName, "Preview")
        XCTAssertEqual(appState.documentTargetPID, "101")
        XCTAssertEqual(appState.documentTargetSource, "Mouse Hover")
        XCTAssertEqual(appState.lastKeySent, "Page Down")
        XCTAssertEqual(appState.lastDocumentStrategyUsed, "directKeyToPid")

        appState.select(.minimizeCurrentWindow)
        appState.handleMockDoubleBlink(actionExecutor: actionExecutor)

        XCTAssertEqual(appState.lastAction, "Blocked Minimize")
        XCTAssertEqual(appState.lastBlockedReason, "Minimize is not allowed in Reading Mode.")
        XCTAssertEqual(appState.mockDoubleBlinkCount, 2)
        XCTAssertEqual(documentActionController.nextPageCallCount, 1)
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
        let documentActionController = MockDocumentActionController()
        let actionExecutor = ActionExecutor(documentActionController: documentActionController)

        for command in [EyeCommand.scrollUp, .scrollDown, .nextPage, .previousPage] {
            actionExecutor.execute(command, appState: appState)

            XCTAssertTrue(appState.isPaused)
            XCTAssertEqual(appState.permission(for: command).blockedKind, .paused)
        }

        XCTAssertEqual(documentActionController.scrollUpCallCount, 0)
        XCTAssertEqual(documentActionController.scrollDownCallCount, 0)
        XCTAssertEqual(documentActionController.nextPageCallCount, 0)
        XCTAssertEqual(documentActionController.previousPageCallCount, 0)
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

    func testActionExecutorRoutesDocumentCommandsThroughDocumentActionController() {
        let appState = activeAppState(mode: .reading)
        let documentActionController = MockDocumentActionController()
        let actionExecutor = ActionExecutor(documentActionController: documentActionController)

        actionExecutor.execute(.scrollUp, appState: appState)
        actionExecutor.execute(.scrollDown, appState: appState)
        actionExecutor.execute(.nextPage, appState: appState)
        actionExecutor.execute(.previousPage, appState: appState)

        XCTAssertEqual(documentActionController.scrollUpCallCount, 1)
        XCTAssertEqual(documentActionController.scrollDownCallCount, 1)
        XCTAssertEqual(documentActionController.nextPageCallCount, 1)
        XCTAssertEqual(documentActionController.previousPageCallCount, 1)
        XCTAssertEqual(appState.lastAction, "Previous Page sent Page Up to Preview using directKeyToPid")
    }

    func testActionExecutorReportsConfiguredDocumentActionStrategies() {
        let appState = activeAppState(mode: .reading)
        let documentActionController = MockDocumentActionController(
            nextPageResult: .sent(
                targetAppName: "Preview",
                targetPID: 101,
                strategy: .activateThenKey,
                keySent: "Right Arrow",
                scrollEvent: "None",
                directPostStatus: "directKeyToPid failed"
            ),
            previousPageResult: .sent(
                targetAppName: "Preview",
                targetPID: 101,
                strategy: .activateThenKey,
                keySent: "Left Arrow",
                scrollEvent: "None",
                directPostStatus: "directKeyToPid failed"
            )
        )
        let actionExecutor = ActionExecutor(documentActionController: documentActionController)

        actionExecutor.execute(.nextPage, appState: appState)
        XCTAssertEqual(appState.lastAction, "Next Page sent Right Arrow to Preview using activateThenKey")
        XCTAssertEqual(appState.directPostStatus, "directKeyToPid failed")

        actionExecutor.execute(.previousPage, appState: appState)
        XCTAssertEqual(appState.lastAction, "Previous Page sent Left Arrow to Preview using activateThenKey")
        XCTAssertEqual(documentActionController.nextPageCallCount, 1)
        XCTAssertEqual(documentActionController.previousPageCallCount, 1)
    }

    func testActionExecutorBlocksPageNavigationWhenNoTargetAppIsFound() {
        let appState = activeAppState(mode: .reading)
        let documentActionController = MockDocumentActionController(
            nextPageResult: .blocked(reason: "No valid document app target found.")
        )
        let actionExecutor = ActionExecutor(documentActionController: documentActionController)

        actionExecutor.execute(.nextPage, appState: appState)

        XCTAssertEqual(documentActionController.nextPageCallCount, 1)
        XCTAssertEqual(appState.documentTargetAppName, "None")
        XCTAssertEqual(appState.documentTargetPID, "None")
        XCTAssertEqual(appState.documentTargetSource, "None")
        XCTAssertEqual(appState.lastKeySent, "None")
        XCTAssertEqual(appState.lastAction, "Blocked Next Page: No valid document app target found.")
        XCTAssertEqual(appState.lastBlockedReason, "No valid document app target found.")
    }

    func testActionExecutorBlocksScrollWhenNoTargetAppIsFound() {
        let appState = activeAppState(mode: .reading)
        let documentActionController = MockDocumentActionController(
            scrollDownResult: .blocked(reason: "No valid document app target found.")
        )
        let actionExecutor = ActionExecutor(documentActionController: documentActionController)

        actionExecutor.execute(.scrollDown, appState: appState)

        XCTAssertEqual(documentActionController.scrollDownCallCount, 1)
        XCTAssertEqual(appState.documentTargetAppName, "None")
        XCTAssertEqual(appState.documentTargetPID, "None")
        XCTAssertEqual(appState.documentTargetSource, "None")
        XCTAssertEqual(appState.lastKeySent, "None")
        XCTAssertEqual(appState.lastDocumentStrategyUsed, "None")
        XCTAssertEqual(appState.directPostStatus, "Not attempted")
        XCTAssertEqual(appState.lastAction, "Blocked Scroll Down: No valid document app target found.")
        XCTAssertEqual(appState.lastBlockedReason, "No valid document app target found.")
    }

    func testScrollActionsUseDirectDocumentScrollWhenTargetIsFound() {
        let appState = activeAppState(mode: .reading)
        let documentActionController = MockDocumentActionController()
        let actionExecutor = ActionExecutor(documentActionController: documentActionController)

        actionExecutor.execute(.scrollDown, appState: appState)

        XCTAssertEqual(documentActionController.scrollDownCallCount, 1)
        XCTAssertEqual(appState.documentTargetAppName, "Preview")
        XCTAssertEqual(appState.documentTargetPID, "101")
        XCTAssertEqual(appState.documentTargetSource, "Mouse Hover")
        XCTAssertEqual(appState.lastKeySent, "None")
        XCTAssertEqual(appState.lastScrollMethod, "CGEvent")
        XCTAssertEqual(appState.lastDocumentStrategyUsed, "directScrollToPid")
        XCTAssertEqual(appState.directPostStatus, "directScrollToPid succeeded")
        XCTAssertEqual(appState.lastScrollEvent, "line, 6/6 pulses, value -1")
        XCTAssertEqual(appState.lastAction, "Scroll Down used directScrollToPid for Preview")
    }

    func testHoveredDocumentTargetChoosesPreviewUnderMouse() {
        let result = MacPageNavigationTargetResolver.resolveHoveredTarget(
            from: [
                DocumentWindowCandidate(
                    processIdentifier: 101,
                    ownerName: "Preview",
                    bundleIdentifier: "com.apple.Preview",
                    layer: 0,
                    bounds: CGRect(x: 0, y: 0, width: 400, height: 400)
                ),
                DocumentWindowCandidate(
                    processIdentifier: 202,
                    ownerName: "Xcode",
                    bundleIdentifier: "com.apple.dt.Xcode",
                    layer: 0,
                    bounds: CGRect(x: 500, y: 0, width: 400, height: 400)
                )
            ],
            mouseLocations: [CGPoint(x: 100, y: 100)],
            excludingBundleIdentifier: "com.dg.EyeControlMac"
        )

        XCTAssertEqual(result, .target(processIdentifier: 101))
    }

    func testGlobalMockShortcutMappingRequiresControlOptionCommand() {
        XCTAssertEqual(
            GlobalMockShortcut(keyCode: 126, modifierFlags: [.control, .option, .command]),
            .scrollUp
        )
        XCTAssertEqual(
            GlobalMockShortcut(keyCode: 125, modifierFlags: [.control, .option, .command]),
            .scrollDown
        )
        XCTAssertEqual(
            GlobalMockShortcut(keyCode: 124, modifierFlags: [.control, .option, .command]),
            .nextPage
        )
        XCTAssertEqual(
            GlobalMockShortcut(keyCode: 123, modifierFlags: [.control, .option, .command]),
            .previousPage
        )
        XCTAssertEqual(
            GlobalMockShortcut(keyCode: 49, modifierFlags: [.control, .option, .command]),
            .confirmSelectedCommand
        )
        XCTAssertEqual(
            GlobalMockShortcut(keyCode: 14, modifierFlags: [.control, .option, .command]),
            .togglePause
        )
        XCTAssertEqual(
            GlobalMockShortcut(keyCode: 15, modifierFlags: [.control, .option, .command]),
            .readingMode
        )
        XCTAssertEqual(
            GlobalMockShortcut(keyCode: 2, modifierFlags: [.control, .option, .command]),
            .desktopMode
        )

        XCTAssertNil(GlobalMockShortcut(keyCode: 49, modifierFlags: []))
        XCTAssertNil(GlobalMockShortcut(keyCode: 49, modifierFlags: [.control]))
        XCTAssertNil(GlobalMockShortcut(keyCode: 49, modifierFlags: [.option]))
        XCTAssertNil(GlobalMockShortcut(keyCode: 49, modifierFlags: [.command]))
        XCTAssertNil(GlobalMockShortcut(keyCode: 49, modifierFlags: [.control, .option]))
    }

    func testGlobalMockShortcutMapsCarbonHotKeyIDs() {
        XCTAssertEqual(GlobalMockShortcut(hotKeyID: GlobalMockShortcut.scrollUp.hotKeyID), .scrollUp)
        XCTAssertEqual(GlobalMockShortcut(hotKeyID: GlobalMockShortcut.scrollDown.hotKeyID), .scrollDown)
        XCTAssertEqual(GlobalMockShortcut(hotKeyID: GlobalMockShortcut.nextPage.hotKeyID), .nextPage)
        XCTAssertEqual(GlobalMockShortcut(hotKeyID: GlobalMockShortcut.previousPage.hotKeyID), .previousPage)
        XCTAssertEqual(GlobalMockShortcut(hotKeyID: GlobalMockShortcut.confirmSelectedCommand.hotKeyID), .confirmSelectedCommand)
        XCTAssertEqual(GlobalMockShortcut(hotKeyID: GlobalMockShortcut.togglePause.hotKeyID), .togglePause)
        XCTAssertEqual(GlobalMockShortcut(hotKeyID: GlobalMockShortcut.readingMode.hotKeyID), .readingMode)
        XCTAssertEqual(GlobalMockShortcut(hotKeyID: GlobalMockShortcut.desktopMode.hotKeyID), .desktopMode)
        XCTAssertNil(GlobalMockShortcut(hotKeyID: 999))
    }

    func testBackgroundControlRoutesDocumentShortcutThroughActionExecutor() {
        let appState = activeAppState(mode: .reading)
        let documentActionController = MockDocumentActionController()
        let actionExecutor = ActionExecutor(documentActionController: documentActionController)
        let backgroundControlManager = BackgroundControlManager()
        backgroundControlManager.configure(
            appState: appState,
            actionExecutor: actionExecutor
        )

        backgroundControlManager.handle(.scrollDown)

        XCTAssertEqual(documentActionController.scrollDownCallCount, 1)
        XCTAssertEqual(appState.lastGlobalShortcut, "Control+Option+Command+Down")
        XCTAssertEqual(appState.lastScrollMethod, "CGEvent")
        XCTAssertEqual(appState.lastDocumentStrategyUsed, "directScrollToPid")
        XCTAssertEqual(appState.lastScrollEvent, "line, 6/6 pulses, value -1")
        XCTAssertEqual(appState.lastAction, "Scroll Down used directScrollToPid for Preview")
    }

    func testBackgroundControlRespectsPausedPermissionRules() {
        let appState = AppState()
        let documentActionController = MockDocumentActionController()
        let actionExecutor = ActionExecutor(documentActionController: documentActionController)
        let backgroundControlManager = BackgroundControlManager()
        backgroundControlManager.configure(
            appState: appState,
            actionExecutor: actionExecutor
        )

        backgroundControlManager.handle(.scrollDown)

        XCTAssertEqual(documentActionController.scrollDownCallCount, 0)
        XCTAssertEqual(appState.lastGlobalShortcut, "Control+Option+Command+Down")
        XCTAssertEqual(appState.lastAction, "Blocked Scroll Down")
        XCTAssertEqual(appState.lastBlockedReason, "Paused Mode blocks all eye-triggered actions except Resume.")
    }

    func testBackgroundControlConfirmExecutesSelectedAllowedCommand() {
        let appState = activeAppState(mode: .reading)
        let documentActionController = MockDocumentActionController()
        let actionExecutor = ActionExecutor(documentActionController: documentActionController)
        let backgroundControlManager = BackgroundControlManager()
        backgroundControlManager.configure(
            appState: appState,
            actionExecutor: actionExecutor
        )

        appState.select(.nextPage)
        backgroundControlManager.handle(.confirmSelectedCommand)

        XCTAssertEqual(appState.mockDoubleBlinkCount, 1)
        XCTAssertEqual(documentActionController.nextPageCallCount, 1)
        XCTAssertEqual(appState.lastGlobalShortcut, "Control+Option+Command+Space")
        XCTAssertEqual(appState.lastAction, "Next Page sent Page Down to Preview using directKeyToPid")
    }

    func testBackgroundControlTogglePauseAndResume() {
        let appState = AppState()
        let actionExecutor = ActionExecutor(documentActionController: MockDocumentActionController())
        let backgroundControlManager = BackgroundControlManager()
        backgroundControlManager.configure(
            appState: appState,
            actionExecutor: actionExecutor
        )

        backgroundControlManager.handle(.togglePause)
        XCTAssertFalse(appState.isPaused)
        XCTAssertEqual(appState.lastGlobalShortcut, "Control+Option+Command+E")
        XCTAssertEqual(appState.lastAction, "Resumed eye control")

        backgroundControlManager.handle(.togglePause)
        XCTAssertTrue(appState.isPaused)
        XCTAssertEqual(appState.lastAction, "Paused eye control")
    }

    func testBackgroundControlSwitchesReadingAndDesktopModeExplicitly() {
        let appState = activeAppState(mode: .reading)
        let actionExecutor = ActionExecutor(documentActionController: MockDocumentActionController())
        let backgroundControlManager = BackgroundControlManager()
        backgroundControlManager.configure(
            appState: appState,
            actionExecutor: actionExecutor
        )

        backgroundControlManager.handle(.desktopMode)
        XCTAssertEqual(appState.controlMode, .desktop)
        XCTAssertFalse(appState.isPaused)
        XCTAssertEqual(appState.lastGlobalShortcut, "Control+Option+Command+D")
        XCTAssertEqual(appState.lastAction, "Switched to Desktop Mode")

        backgroundControlManager.handle(.readingMode)
        XCTAssertEqual(appState.controlMode, .reading)
        XCTAssertFalse(appState.isPaused)
        XCTAssertEqual(appState.lastGlobalShortcut, "Control+Option+Command+R")
        XCTAssertEqual(appState.lastAction, "Switched to Reading Mode")
    }

    func testHoveredDocumentTargetBlocksEyeControlMacWindow() {
        let result = MacPageNavigationTargetResolver.resolveHoveredTarget(
            from: [
                DocumentWindowCandidate(
                    processIdentifier: 303,
                    ownerName: "EyeControlMac",
                    bundleIdentifier: "com.dg.EyeControlMac",
                    layer: 0,
                    bounds: CGRect(x: 0, y: 0, width: 400, height: 400)
                ),
                DocumentWindowCandidate(
                    processIdentifier: 101,
                    ownerName: "Preview",
                    bundleIdentifier: "com.apple.Preview",
                    layer: 0,
                    bounds: CGRect(x: 0, y: 0, width: 400, height: 400)
                )
            ],
            mouseLocations: [CGPoint(x: 100, y: 100)],
            excludingBundleIdentifier: "com.dg.EyeControlMac"
        )

        XCTAssertEqual(result, .blocked(reason: "Mouse is over EyeControlMac, so no document app was targeted."))
    }

    func testHoveredDocumentTargetDoesNotFallbackToXcode() {
        let result = MacPageNavigationTargetResolver.resolveHoveredTarget(
            from: [
                DocumentWindowCandidate(
                    processIdentifier: 202,
                    ownerName: "Xcode",
                    bundleIdentifier: "com.apple.dt.Xcode",
                    layer: 0,
                    bounds: CGRect(x: 500, y: 0, width: 400, height: 400)
                )
            ],
            mouseLocations: [CGPoint(x: 100, y: 100)],
            excludingBundleIdentifier: "com.dg.EyeControlMac"
        )

        XCTAssertEqual(result, .notFound(reason: "No valid document app window found under mouse."))
    }

    func testHoveredDocumentTargetMatchesConvertedMouseCoordinate() {
        let result = MacPageNavigationTargetResolver.resolveHoveredTarget(
            from: [
                DocumentWindowCandidate(
                    processIdentifier: 101,
                    ownerName: "Preview",
                    bundleIdentifier: "com.apple.Preview",
                    layer: 0,
                    bounds: CGRect(x: 0, y: 0, width: 400, height: 400)
                )
            ],
            mouseLocations: [
                CGPoint(x: 900, y: 900),
                CGPoint(x: 100, y: 100)
            ],
            excludingBundleIdentifier: "com.dg.EyeControlMac"
        )

        XCTAssertEqual(result, .target(processIdentifier: 101))
    }

    func testBlockedDocumentCommandsDoNotCallControllers() {
        let appState = AppState()
        let documentActionController = MockDocumentActionController()
        let actionExecutor = ActionExecutor(documentActionController: documentActionController)

        actionExecutor.execute(.scrollUp, appState: appState)
        actionExecutor.execute(.scrollDown, appState: appState)
        actionExecutor.execute(.nextPage, appState: appState)
        actionExecutor.execute(.previousPage, appState: appState)

        XCTAssertEqual(documentActionController.scrollUpCallCount, 0)
        XCTAssertEqual(documentActionController.scrollDownCallCount, 0)
        XCTAssertEqual(documentActionController.nextPageCallCount, 0)
        XCTAssertEqual(documentActionController.previousPageCallCount, 0)
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
private final class MockDocumentActionController: DocumentActionControlling {
    private(set) var scrollUpCallCount = 0
    private(set) var scrollDownCallCount = 0
    private(set) var nextPageCallCount = 0
    private(set) var previousPageCallCount = 0

    private let scrollUpResult: DocumentActionResult
    private let scrollDownResult: DocumentActionResult
    private let nextPageResult: DocumentActionResult
    private let previousPageResult: DocumentActionResult

    init(
        scrollUpResult: DocumentActionResult = .sent(
            targetAppName: "Preview",
            targetPID: 101,
            strategy: .directScrollToPid,
            keySent: "None",
            scrollEvent: "line, 6/6 pulses, value 1",
            directPostStatus: "directScrollToPid succeeded"
        ),
        scrollDownResult: DocumentActionResult = .sent(
            targetAppName: "Preview",
            targetPID: 101,
            strategy: .directScrollToPid,
            keySent: "None",
            scrollEvent: "line, 6/6 pulses, value -1",
            directPostStatus: "directScrollToPid succeeded"
        ),
        nextPageResult: DocumentActionResult = .sent(
            targetAppName: "Preview",
            targetPID: 101,
            strategy: .directKeyToPid,
            keySent: "Page Down",
            scrollEvent: "None",
            directPostStatus: "directKeyToPid succeeded"
        ),
        previousPageResult: DocumentActionResult = .sent(
            targetAppName: "Preview",
            targetPID: 101,
            strategy: .directKeyToPid,
            keySent: "Page Up",
            scrollEvent: "None",
            directPostStatus: "directKeyToPid succeeded"
        )
    ) {
        self.scrollUpResult = scrollUpResult
        self.scrollDownResult = scrollDownResult
        self.nextPageResult = nextPageResult
        self.previousPageResult = previousPageResult
    }

    func scrollUp() -> DocumentActionResult {
        scrollUpCallCount += 1
        return scrollUpResult
    }

    func scrollDown() -> DocumentActionResult {
        scrollDownCallCount += 1
        return scrollDownResult
    }

    func nextPage() -> DocumentActionResult {
        nextPageCallCount += 1
        return nextPageResult
    }

    func previousPage() -> DocumentActionResult {
        previousPageCallCount += 1
        return previousPageResult
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
    private(set) var scrollUpCallCount = 0
    private(set) var scrollDownCallCount = 0
    private(set) var nextPageCallCount = 0
    private(set) var previousPageCallCount = 0
    private let nextStrategy: PageNavigationKeyStrategy
    private let previousStrategy: PageNavigationKeyStrategy
    private let targetAppName: String?

    init(
        nextStrategy: PageNavigationKeyStrategy = .pageDown,
        previousStrategy: PageNavigationKeyStrategy = .pageUp,
        targetAppName: String? = "Preview"
    ) {
        self.nextStrategy = nextStrategy
        self.previousStrategy = previousStrategy
        self.targetAppName = targetAppName
    }

    func scrollUp() -> PageNavigationActionResult {
        scrollUpCallCount += 1
        guard let targetAppName else {
            return .blocked(
                strategy: .upArrow,
                reason: "No document app target found for Up Arrow."
            )
        }

        return .sent(strategy: .upArrow, targetAppName: targetAppName, pulseCount: 3)
    }

    func scrollDown() -> PageNavigationActionResult {
        scrollDownCallCount += 1
        guard let targetAppName else {
            return .blocked(
                strategy: .downArrow,
                reason: "No document app target found for Down Arrow."
            )
        }

        return .sent(strategy: .downArrow, targetAppName: targetAppName, pulseCount: 3)
    }

    func nextPage() -> PageNavigationActionResult {
        nextPageCallCount += 1
        guard let targetAppName else {
            return .blocked(
                strategy: nextStrategy,
                reason: "No document app target found for \(nextStrategy.debugName)."
            )
        }

        return .sent(strategy: nextStrategy, targetAppName: targetAppName)
    }

    func previousPage() -> PageNavigationActionResult {
        previousPageCallCount += 1
        guard let targetAppName else {
            return .blocked(
                strategy: previousStrategy,
                reason: "No document app target found for \(previousStrategy.debugName)."
            )
        }

        return .sent(strategy: previousStrategy, targetAppName: targetAppName)
    }
}
