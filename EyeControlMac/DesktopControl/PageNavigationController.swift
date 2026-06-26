//
//  PageNavigationController.swift
//  EyeControlMac
//
//  Created by Dushyanth N Gowda on 6/24/26.
//

import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation

@MainActor
protocol PageNavigationControlling {
    func scrollUp() -> PageNavigationActionResult
    func scrollDown() -> PageNavigationActionResult
    func nextPage() -> PageNavigationActionResult
    func previousPage() -> PageNavigationActionResult
}

@MainActor
final class PageNavigationController: PageNavigationControlling {
    private let nextPageStrategy: PageNavigationKeyStrategy
    private let previousPageStrategy: PageNavigationKeyStrategy
    private let targetResolver: PageNavigationTargetResolving
    private let appBundleIdentifier: String?
    private let activationDelay: TimeInterval
    private let scrollKeyPulseCount: Int
    private let scrollKeyPulseDelay: TimeInterval

    init(
        nextPageStrategy: PageNavigationKeyStrategy = .pageDown,
        previousPageStrategy: PageNavigationKeyStrategy = .pageUp,
        targetResolver: PageNavigationTargetResolving? = nil,
        appBundleIdentifier: String? = nil,
        activationDelay: TimeInterval = 0.05,
        scrollKeyPulseCount: Int = 3,
        scrollKeyPulseDelay: TimeInterval = 0.012
    ) {
        self.nextPageStrategy = nextPageStrategy
        self.previousPageStrategy = previousPageStrategy
        self.targetResolver = targetResolver ?? MacPageNavigationTargetResolver()
        self.appBundleIdentifier = appBundleIdentifier ?? Bundle.main.bundleIdentifier
        self.activationDelay = activationDelay
        self.scrollKeyPulseCount = max(2, min(scrollKeyPulseCount, 4))
        self.scrollKeyPulseDelay = scrollKeyPulseDelay
    }

    func scrollUp() -> PageNavigationActionResult {
        send(.upArrow, pulseCount: scrollKeyPulseCount, pulseDelay: scrollKeyPulseDelay)
    }

    func scrollDown() -> PageNavigationActionResult {
        send(.downArrow, pulseCount: scrollKeyPulseCount, pulseDelay: scrollKeyPulseDelay)
    }

    func nextPage() -> PageNavigationActionResult {
        send(nextPageStrategy)
    }

    func previousPage() -> PageNavigationActionResult {
        send(previousPageStrategy)
    }

    func nextPageWithRightArrow() -> PageNavigationActionResult {
        send(.rightArrow)
    }

    func previousPageWithLeftArrow() -> PageNavigationActionResult {
        send(.leftArrow)
    }

    func nextPageWithDownArrow() -> PageNavigationActionResult {
        send(.downArrow)
    }

    func previousPageWithUpArrow() -> PageNavigationActionResult {
        send(.upArrow)
    }

    private func send(
        _ strategy: PageNavigationKeyStrategy,
        pulseCount: Int = 1,
        pulseDelay: TimeInterval = 0
    ) -> PageNavigationActionResult {
        let targetResult = targetResolver.documentTarget(excludingBundleIdentifier: appBundleIdentifier)

        guard let targetApplication = targetResult.application else {
            return .blocked(
                strategy: strategy,
                reason: targetResult.blockedReason ?? "No valid app under mouse for \(strategy.debugName).",
                targetSource: targetResult.source
            )
        }

        targetApplication.activate()

        if activationDelay > 0 {
            Thread.sleep(forTimeInterval: activationDelay)
        }

        postKey(strategy.keyCode, pulseCount: pulseCount, pulseDelay: pulseDelay)

        return .sent(
            strategy: strategy,
            targetAppName: targetApplication.localizedName ?? "Unknown App",
            targetSource: targetResult.source,
            pulseCount: pulseCount
        )
    }

    private func postKey(_ keyCode: CGKeyCode, pulseCount: Int, pulseDelay: TimeInterval) {
        let source = CGEventSource(stateID: .hidSystemState)

        for pulseIndex in 0..<max(1, pulseCount) {
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)

            if pulseIndex < pulseCount - 1, pulseDelay > 0 {
                Thread.sleep(forTimeInterval: pulseDelay)
            }
        }
    }
}

struct PageNavigationActionResult: Equatable {
    let didSend: Bool
    let strategy: PageNavigationKeyStrategy
    let targetAppName: String?
    let targetSource: DocumentActionTargetSource
    let blockedReason: String?
    let pulseCount: Int

    static func sent(
        strategy: PageNavigationKeyStrategy,
        targetAppName: String,
        targetSource: DocumentActionTargetSource = .mouseHover,
        pulseCount: Int = 1
    ) -> PageNavigationActionResult {
        PageNavigationActionResult(
            didSend: true,
            strategy: strategy,
            targetAppName: targetAppName,
            targetSource: targetSource,
            blockedReason: nil,
            pulseCount: pulseCount
        )
    }

    static func blocked(
        strategy: PageNavigationKeyStrategy,
        reason: String,
        targetSource: DocumentActionTargetSource = .none
    ) -> PageNavigationActionResult {
        PageNavigationActionResult(
            didSend: false,
            strategy: strategy,
            targetAppName: nil,
            targetSource: targetSource,
            blockedReason: reason,
            pulseCount: 0
        )
    }
}

@MainActor
protocol PageNavigationTargetResolving {
    func documentTarget(excludingBundleIdentifier bundleIdentifier: String?) -> DocumentActionTargetResult
}

struct DocumentActionTargetResult {
    let application: NSRunningApplication?
    let source: DocumentActionTargetSource
    let blockedReason: String?

    static func found(
        application: NSRunningApplication,
        source: DocumentActionTargetSource = .mouseHover
    ) -> DocumentActionTargetResult {
        DocumentActionTargetResult(
            application: application,
            source: source,
            blockedReason: nil
        )
    }

    static func blocked(reason: String, source: DocumentActionTargetSource = .none) -> DocumentActionTargetResult {
        DocumentActionTargetResult(
            application: nil,
            source: source,
            blockedReason: reason
        )
    }
}

enum DocumentActionTargetSource: Equatable {
    case mouseHover
    case none

    var debugName: String {
        switch self {
        case .mouseHover:
            return "Mouse Hover"
        case .none:
            return "None"
        }
    }
}

@MainActor
final class MacPageNavigationTargetResolver: PageNavigationTargetResolving {
    func documentTarget(excludingBundleIdentifier bundleIdentifier: String?) -> DocumentActionTargetResult {
        guard let eventPoint = CGEvent(source: nil)?.location else {
            return .blocked(reason: "Could not read current mouse location.")
        }

        let mouseLocations = Self.mouseLocationsForWindowMatching(eventPoint: eventPoint)

        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return .blocked(reason: "Could not inspect windows under mouse.")
        }

        let candidates = windows.compactMap { window -> DocumentWindowCandidate? in
            guard let layer = window[kCGWindowLayer as String] as? Int,
                  let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  let boundsDictionary = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary),
                  let application = NSRunningApplication(processIdentifier: ownerPID) else {
                return nil
            }

            return DocumentWindowCandidate(
                processIdentifier: ownerPID,
                ownerName: application.localizedName,
                bundleIdentifier: application.bundleIdentifier,
                layer: layer,
                bounds: bounds
            )
        }

        switch Self.resolveHoveredTarget(
            from: candidates,
            mouseLocations: mouseLocations,
            excludingBundleIdentifier: bundleIdentifier
        ) {
        case .target(let processIdentifier):
            guard let application = NSRunningApplication(processIdentifier: processIdentifier) else {
                return .blocked(reason: "Could not activate document app under mouse.")
            }

            return .found(application: application)
        case .blocked(let reason):
            return .blocked(reason: reason)
        case .notFound(let reason):
            return .blocked(reason: reason)
        }
    }

    static func resolveHoveredTarget(
        from candidates: [DocumentWindowCandidate],
        mouseLocations: [CGPoint],
        excludingBundleIdentifier bundleIdentifier: String?
    ) -> HoveredDocumentTargetResolution {
        guard !mouseLocations.isEmpty else {
            return .notFound(reason: "No valid mouse location was available.")
        }

        for mouseLocation in mouseLocations {
            for candidate in candidates {
                guard candidate.layer == 0,
                      candidate.bounds.contains(mouseLocation) else {
                    continue
                }

                if isEyeControlMac(candidate, excludingBundleIdentifier: bundleIdentifier) {
                    return .blocked(reason: "Mouse is over EyeControlMac, so no document app was targeted.")
                }

                return .target(processIdentifier: candidate.processIdentifier)
            }
        }

        return .notFound(reason: "No valid document app window found under mouse.")
    }

    static func mouseLocationsForWindowMatching(eventPoint: CGPoint) -> [CGPoint] {
        let appKitPoint = NSEvent.mouseLocation
        let convertedAppKitPoint = cgWindowPoint(fromAppKitMouseLocation: appKitPoint)

        if convertedAppKitPoint == eventPoint {
            return [convertedAppKitPoint]
        }

        return [convertedAppKitPoint, eventPoint]
    }

    static func cgWindowPoint(fromAppKitMouseLocation point: CGPoint) -> CGPoint {
        let desktopBounds = NSScreen.screens.reduce(CGRect.null) { partialResult, screen in
            partialResult.union(screen.frame)
        }

        guard !desktopBounds.isNull else {
            return point
        }

        return CGPoint(
            x: point.x,
            y: desktopBounds.maxY - point.y
        )
    }

    private static func isEyeControlMac(
        _ application: NSRunningApplication,
        excludingBundleIdentifier bundleIdentifier: String?
    ) -> Bool {
        if let bundleIdentifier,
           application.bundleIdentifier == bundleIdentifier {
            return true
        }

        return application.localizedName == "EyeControlMac"
    }

    private static func isEyeControlMac(
        _ candidate: DocumentWindowCandidate,
        excludingBundleIdentifier bundleIdentifier: String?
    ) -> Bool {
        if let bundleIdentifier,
           candidate.bundleIdentifier == bundleIdentifier {
            return true
        }

        return candidate.ownerName == "EyeControlMac"
    }
}

struct DocumentWindowCandidate: Equatable {
    let processIdentifier: pid_t
    let ownerName: String?
    let bundleIdentifier: String?
    let layer: Int
    let bounds: CGRect
}

enum HoveredDocumentTargetResolution: Equatable {
    case target(processIdentifier: pid_t)
    case blocked(reason: String)
    case notFound(reason: String)
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
