//
//  DocumentActionController.swift
//  EyeControlMac
//
//  Created by Codex on 6/24/26.
//

import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation

@MainActor
protocol DocumentActionControlling {
    func scrollUp() -> DocumentActionResult
    func scrollDown() -> DocumentActionResult
    func nextPage() -> DocumentActionResult
    func previousPage() -> DocumentActionResult
}

@MainActor
final class DocumentActionController: DocumentActionControlling {
    private let targetResolver: PageNavigationTargetResolving
    private let appBundleIdentifier: String?
    private let activationDelay: TimeInterval
    private let scrollPulseCount: Int
    private let scrollPulseDelay: TimeInterval

    init(
        targetResolver: PageNavigationTargetResolving? = nil,
        appBundleIdentifier: String? = nil,
        activationDelay: TimeInterval = 0.05,
        scrollPulseCount: Int = 6,
        scrollPulseDelay: TimeInterval = 0.012
    ) {
        self.targetResolver = targetResolver ?? MacPageNavigationTargetResolver()
        self.appBundleIdentifier = appBundleIdentifier ?? Bundle.main.bundleIdentifier
        self.activationDelay = activationDelay
        self.scrollPulseCount = max(5, min(scrollPulseCount, 8))
        self.scrollPulseDelay = scrollPulseDelay
    }

    func scrollUp() -> DocumentActionResult {
        scroll(
            direction: .up,
            directStrategy: .directScrollToPid,
            fallbackKey: .upArrow
        )
    }

    func scrollDown() -> DocumentActionResult {
        scroll(
            direction: .down,
            directStrategy: .directScrollToPid,
            fallbackKey: .downArrow
        )
    }

    func nextPage() -> DocumentActionResult {
        sendKey(.pageDown, fallbackKey: .rightArrow)
    }

    func previousPage() -> DocumentActionResult {
        sendKey(.pageUp, fallbackKey: .leftArrow)
    }

    private func scroll(
        direction: DocumentScrollDirection,
        directStrategy: DocumentActionStrategy,
        fallbackKey: PageNavigationKeyStrategy
    ) -> DocumentActionResult {
        let target = resolveTarget()

        guard let application = target.application else {
            return .blocked(reason: target.blockedReason ?? "No valid document app target found.", targetSource: target.source)
        }

        let pid = application.processIdentifier
        let targetAppName = application.localizedName ?? "Unknown App"
        let directResult = postLineScroll(to: pid, direction: direction)

        if directResult.didPost {
            return .sent(
                targetAppName: targetAppName,
                targetPID: pid,
                targetSource: target.source,
                strategy: directStrategy,
                keySent: "None",
                scrollEvent: directResult.debugDescription,
                directPostStatus: directResult.statusDescription
            )
        }

        let fallbackScrollResult = postLineScrollAtMouseLocation(direction: direction)

        if fallbackScrollResult.didPost {
            return .sent(
                targetAppName: targetAppName,
                targetPID: pid,
                targetSource: target.source,
                strategy: .fallbackScrollAtMouseLocation,
                keySent: "None",
                scrollEvent: fallbackScrollResult.debugDescription,
                directPostStatus: directResult.statusDescription
            )
        }

        let keyResult = activateThenSendKey(
            fallbackKey,
            to: application,
            targetAppName: targetAppName,
            targetSource: target.source
        )

        return DocumentActionResult(
            didSend: keyResult.didSend,
            targetAppName: targetAppName,
            targetPID: pid,
            targetSource: target.source,
            strategy: keyResult.strategy,
            keySent: keyResult.keySent,
            scrollEvent: fallbackScrollResult.debugDescription,
            directPostStatus: directResult.statusDescription,
            blockedReason: keyResult.blockedReason
        )
    }

    private func sendKey(
        _ primaryKey: PageNavigationKeyStrategy,
        fallbackKey: PageNavigationKeyStrategy
    ) -> DocumentActionResult {
        let target = resolveTarget()

        guard let application = target.application else {
            return .blocked(reason: target.blockedReason ?? "No valid document app target found.", targetSource: target.source)
        }

        let pid = application.processIdentifier
        let targetAppName = application.localizedName ?? "Unknown App"

        if postKey(primaryKey, to: pid) {
            return .sent(
                targetAppName: targetAppName,
                targetPID: pid,
                targetSource: target.source,
                strategy: .directKeyToPid,
                keySent: primaryKey.debugName,
                scrollEvent: "None",
                directPostStatus: "directKeyToPid succeeded"
            )
        }

        let fallbackResult = activateThenSendKey(
            fallbackKey,
            to: application,
            targetAppName: targetAppName,
            targetSource: target.source
        )

        return DocumentActionResult(
            didSend: fallbackResult.didSend,
            targetAppName: targetAppName,
            targetPID: pid,
            targetSource: target.source,
            strategy: fallbackResult.strategy,
            keySent: fallbackResult.keySent,
            scrollEvent: "None",
            directPostStatus: "directKeyToPid failed",
            blockedReason: fallbackResult.blockedReason
        )
    }

    private func activateThenSendKey(
        _ key: PageNavigationKeyStrategy,
        to application: NSRunningApplication,
        targetAppName: String,
        targetSource: DocumentActionTargetSource
    ) -> DocumentActionResult {
        application.activate()

        if activationDelay > 0 {
            Thread.sleep(forTimeInterval: activationDelay)
        }

        guard postKey(key, tap: .cghidEventTap) else {
            return .blocked(
                reason: "Could not create keyboard event for \(key.debugName).",
                targetAppName: targetAppName,
                targetPID: application.processIdentifier,
                targetSource: targetSource,
                strategy: .activateThenKey,
                keySent: key.debugName,
                directPostStatus: "activateThenKey failed"
            )
        }

        return .sent(
            targetAppName: targetAppName,
            targetPID: application.processIdentifier,
            targetSource: targetSource,
            strategy: .activateThenKey,
            keySent: key.debugName,
            scrollEvent: "None",
            directPostStatus: "activateThenKey succeeded"
        )
    }

    private func resolveTarget() -> DocumentActionTargetResult {
        targetResolver.documentTarget(excludingBundleIdentifier: appBundleIdentifier)
    }

    private func postLineScroll(to pid: pid_t, direction: DocumentScrollDirection) -> DocumentScrollPostResult {
        postLineScroll(direction: direction) { event in
            event.postToPid(pid)
        }
    }

    private func postLineScrollAtMouseLocation(direction: DocumentScrollDirection) -> DocumentScrollPostResult {
        let mouseLocation = CGEvent(source: nil)?.location

        return postLineScroll(direction: direction) { event in
            if let mouseLocation {
                event.location = mouseLocation
            }

            event.post(tap: .cghidEventTap)
        }
    }

    private func postLineScroll(
        direction: DocumentScrollDirection,
        poster: (CGEvent) -> Void
    ) -> DocumentScrollPostResult {
        var postedEvents = 0

        for pulseIndex in 0..<scrollPulseCount {
            guard let event = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .line,
                wheelCount: 1,
                wheel1: direction.lineDelta,
                wheel2: 0,
                wheel3: 0
            ) else {
                continue
            }

            poster(event)
            postedEvents += 1

            if pulseIndex < scrollPulseCount - 1 {
                Thread.sleep(forTimeInterval: scrollPulseDelay)
            }
        }

        return DocumentScrollPostResult(
            direction: direction,
            units: .line,
            pulseCount: scrollPulseCount,
            valuePerPulse: direction.lineDelta,
            postedEvents: postedEvents
        )
    }

    private func postKey(_ key: PageNavigationKeyStrategy, to pid: pid_t) -> Bool {
        postKey(key, poster: { event in
            event.postToPid(pid)
        })
    }

    private func postKey(_ key: PageNavigationKeyStrategy, tap: CGEventTapLocation) -> Bool {
        postKey(key, poster: { event in
            event.post(tap: tap)
        })
    }

    private func postKey(_ key: PageNavigationKeyStrategy, poster: (CGEvent) -> Void) -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key.keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key.keyCode, keyDown: false) else {
            return false
        }

        poster(keyDown)
        poster(keyUp)
        return true
    }
}

struct DocumentActionResult: Equatable {
    let didSend: Bool
    let targetAppName: String?
    let targetPID: pid_t?
    let targetSource: DocumentActionTargetSource
    let strategy: DocumentActionStrategy
    let keySent: String
    let scrollEvent: String
    let directPostStatus: String
    let blockedReason: String?

    static func sent(
        targetAppName: String,
        targetPID: pid_t,
        targetSource: DocumentActionTargetSource = .mouseHover,
        strategy: DocumentActionStrategy,
        keySent: String,
        scrollEvent: String,
        directPostStatus: String
    ) -> DocumentActionResult {
        DocumentActionResult(
            didSend: true,
            targetAppName: targetAppName,
            targetPID: targetPID,
            targetSource: targetSource,
            strategy: strategy,
            keySent: keySent,
            scrollEvent: scrollEvent,
            directPostStatus: directPostStatus,
            blockedReason: nil
        )
    }

    static func blocked(
        reason: String,
        targetAppName: String? = nil,
        targetPID: pid_t? = nil,
        targetSource: DocumentActionTargetSource = .none,
        strategy: DocumentActionStrategy = .none,
        keySent: String = "None",
        directPostStatus: String = "Not attempted"
    ) -> DocumentActionResult {
        DocumentActionResult(
            didSend: false,
            targetAppName: targetAppName,
            targetPID: targetPID,
            targetSource: targetSource,
            strategy: strategy,
            keySent: keySent,
            scrollEvent: "None",
            directPostStatus: directPostStatus,
            blockedReason: reason
        )
    }
}

enum DocumentActionStrategy: String, Equatable {
    case directScrollToPid
    case directKeyToPid
    case activateThenKey
    case fallbackScrollAtMouseLocation
    case none

    var debugName: String {
        switch self {
        case .directScrollToPid:
            return "directScrollToPid"
        case .directKeyToPid:
            return "directKeyToPid"
        case .activateThenKey:
            return "activateThenKey"
        case .fallbackScrollAtMouseLocation:
            return "fallbackScrollAtMouseLocation"
        case .none:
            return "None"
        }
    }
}

enum DocumentScrollDirection: Equatable {
    case up
    case down

    var lineDelta: Int32 {
        switch self {
        case .up:
            return 1
        case .down:
            return -1
        }
    }

    var debugName: String {
        switch self {
        case .up:
            return "Scroll Up"
        case .down:
            return "Scroll Down"
        }
    }
}

enum DocumentScrollUnits: Equatable {
    case line

    var debugName: String {
        switch self {
        case .line:
            return "line"
        }
    }
}

struct DocumentScrollPostResult: Equatable {
    let direction: DocumentScrollDirection
    let units: DocumentScrollUnits
    let pulseCount: Int
    let valuePerPulse: Int32
    let postedEvents: Int

    var didPost: Bool {
        postedEvents > 0
    }

    var debugDescription: String {
        "\(units.debugName), \(postedEvents)/\(pulseCount) pulses, value \(valuePerPulse)"
    }

    var statusDescription: String {
        didPost ? "directScrollToPid succeeded" : "directScrollToPid failed"
    }
}
