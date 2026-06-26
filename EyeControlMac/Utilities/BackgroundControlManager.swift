//
//  BackgroundControlManager.swift
//  EyeControlMac
//
//  Created by Codex on 6/24/26.
//

import AppKit
import Carbon.HIToolbox
import Combine

@MainActor
final class GlobalShortcutManager: ObservableObject {
    @Published private(set) var isEnabled = false

    private var registeredHotKeys: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var terminationObserver: NSObjectProtocol?
    private weak var appState: AppState?
    private weak var actionExecutor: ActionExecutor?

    func configure(appState: AppState, actionExecutor: ActionExecutor) {
        self.appState = appState
        self.actionExecutor = actionExecutor
    }

    func start(appState: AppState, actionExecutor: ActionExecutor) {
        configure(appState: appState, actionExecutor: actionExecutor)

        guard registeredHotKeys.isEmpty else {
            isEnabled = true
            appState.isBackgroundControlEnabled = true
            appState.isGlobalShortcutManagerStarted = true
            return
        }

        let handlerStatus = installEventHandlerIfNeeded()

        guard handlerStatus == noErr else {
            isEnabled = false
            appState.isBackgroundControlEnabled = false
            appState.isGlobalShortcutManagerStarted = false
            appState.registeredHotkeysCount = 0
            appState.hotkeyRegistrationStatuses = ["Event handler failed: \(handlerStatus)"]
            appState.backgroundControlStatus = "Global shortcut event handler failed: \(handlerStatus)"
            appState.lastAction = appState.backgroundControlStatus
            return
        }

        var registrationStatuses: [String] = []
        var failedRegistrations: [String] = []

        for shortcut in GlobalMockShortcut.allCases {
            let status = register(shortcut)
            let statusText = "\(shortcut.title): \(status)"
            registrationStatuses.append(statusText)

            if status != noErr {
                failedRegistrations.append(statusText)
            }
        }

        isEnabled = failedRegistrations.isEmpty && registeredHotKeys.count == GlobalMockShortcut.allCases.count
        appState.isBackgroundControlEnabled = isEnabled
        appState.isGlobalShortcutManagerStarted = eventHandler != nil
        appState.registeredHotkeysCount = registeredHotKeys.count
        appState.hotkeyRegistrationStatuses = registrationStatuses

        if failedRegistrations.isEmpty {
            appState.backgroundControlStatus = "Carbon global hotkeys registered on application event target"
        } else {
            appState.backgroundControlStatus = "Hotkey registration failed: \(failedRegistrations.joined(separator: ", "))"
            appState.lastAction = appState.backgroundControlStatus
        }
    }

    func stop() {
        for hotKeyRef in registeredHotKeys.values {
            UnregisterEventHotKey(hotKeyRef)
        }

        registeredHotKeys.removeAll()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }

        eventHandler = nil

        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }

        terminationObserver = nil
        isEnabled = false
        appState?.isBackgroundControlEnabled = false
        appState?.isGlobalShortcutManagerStarted = false
        appState?.registeredHotkeysCount = 0
    }

    func handle(_ shortcut: GlobalMockShortcut) {
        guard let appState,
              let actionExecutor else {
            return
        }

        appState.lastGlobalShortcut = shortcut.title

        switch shortcut {
        case .scrollUp:
            actionExecutor.execute(.scrollUp, appState: appState)
        case .scrollDown:
            actionExecutor.execute(.scrollDown, appState: appState)
        case .nextPage:
            actionExecutor.execute(.nextPage, appState: appState)
        case .previousPage:
            actionExecutor.execute(.previousPage, appState: appState)
        case .confirmSelectedCommand:
            appState.handleMockDoubleBlink(actionExecutor: actionExecutor)
        case .togglePause:
            appState.togglePause(actionExecutor: actionExecutor)
        case .readingMode:
            appState.setControlMode(.reading)
            appState.lastAction = "Switched to Reading Mode"
            appState.lastBlockedReason = nil
        case .desktopMode:
            appState.setControlMode(.desktop)
            appState.lastAction = "Switched to Desktop Mode"
            appState.lastBlockedReason = nil
        }
    }

    func handleHotKeyID(_ id: UInt32) {
        guard let shortcut = GlobalMockShortcut(hotKeyID: id) else {
            return
        }

        handle(shortcut)
    }

    private func installEventHandlerIfNeeded() -> OSStatus {
        guard eventHandler == nil else {
            return noErr
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event,
                      let userData else {
                    return OSStatus(eventNotHandledErr)
                }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr else {
                    return status
                }

                let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
                let id = hotKeyID.id

                Task { @MainActor in
                    manager.handleHotKeyID(id)
                }

                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandler
        )

        return status
    }

    private func register(_ shortcut: GlobalMockShortcut) -> OSStatus {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(
            signature: GlobalMockShortcut.hotKeySignature,
            id: shortcut.hotKeyID
        )

        let status = RegisterEventHotKey(
            shortcut.carbonKeyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let hotKeyRef {
            registeredHotKeys[shortcut.hotKeyID] = hotKeyRef
        }

        return status
    }

    deinit {
        for hotKeyRef in registeredHotKeys.values {
            UnregisterEventHotKey(hotKeyRef)
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }

        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
    }
}

typealias BackgroundControlManager = GlobalShortcutManager

enum GlobalMockShortcut: CaseIterable, Equatable {
    case scrollUp
    case scrollDown
    case nextPage
    case previousPage
    case confirmSelectedCommand
    case togglePause
    case readingMode
    case desktopMode

    static let hotKeySignature: OSType = 0x45434D43

    init?(hotKeyID: UInt32) {
        guard let shortcut = Self.allCases.first(where: { $0.hotKeyID == hotKeyID }) else {
            return nil
        }

        self = shortcut
    }

    init?(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
        let relevantFlags = modifierFlags.intersection(.deviceIndependentFlagsMask)

        guard relevantFlags.contains(.control),
              relevantFlags.contains(.option),
              relevantFlags.contains(.command),
              !relevantFlags.contains(.shift) else {
            return nil
        }

        switch keyCode {
        case UInt16(kVK_UpArrow):
            self = .scrollUp
        case UInt16(kVK_DownArrow):
            self = .scrollDown
        case UInt16(kVK_RightArrow):
            self = .nextPage
        case UInt16(kVK_LeftArrow):
            self = .previousPage
        case UInt16(kVK_Space):
            self = .confirmSelectedCommand
        case UInt16(kVK_ANSI_E):
            self = .togglePause
        case UInt16(kVK_ANSI_R):
            self = .readingMode
        case UInt16(kVK_ANSI_D):
            self = .desktopMode
        default:
            return nil
        }
    }

    var hotKeyID: UInt32 {
        switch self {
        case .scrollUp:
            return 1
        case .scrollDown:
            return 2
        case .nextPage:
            return 3
        case .previousPage:
            return 4
        case .confirmSelectedCommand:
            return 5
        case .togglePause:
            return 6
        case .readingMode:
            return 7
        case .desktopMode:
            return 8
        }
    }

    var carbonKeyCode: UInt32 {
        switch self {
        case .scrollUp:
            return UInt32(kVK_UpArrow)
        case .scrollDown:
            return UInt32(kVK_DownArrow)
        case .nextPage:
            return UInt32(kVK_RightArrow)
        case .previousPage:
            return UInt32(kVK_LeftArrow)
        case .confirmSelectedCommand:
            return UInt32(kVK_Space)
        case .togglePause:
            return UInt32(kVK_ANSI_E)
        case .readingMode:
            return UInt32(kVK_ANSI_R)
        case .desktopMode:
            return UInt32(kVK_ANSI_D)
        }
    }

    var carbonModifiers: UInt32 {
        UInt32(controlKey | optionKey | cmdKey)
    }

    var title: String {
        switch self {
        case .scrollUp:
            return "Control+Option+Command+Up"
        case .scrollDown:
            return "Control+Option+Command+Down"
        case .nextPage:
            return "Control+Option+Command+Right"
        case .previousPage:
            return "Control+Option+Command+Left"
        case .confirmSelectedCommand:
            return "Control+Option+Command+Space"
        case .togglePause:
            return "Control+Option+Command+E"
        case .readingMode:
            return "Control+Option+Command+R"
        case .desktopMode:
            return "Control+Option+Command+D"
        }
    }
}
