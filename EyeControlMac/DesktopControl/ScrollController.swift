//
//  ScrollController.swift
//  EyeControlMac
//
//  Created by Dushyanth N Gowda on 6/24/26.
//

import CoreGraphics
import Foundation

@MainActor
protocol ScrollControlling {
    func scrollUp() -> ScrollEventResult
    func scrollDown() -> ScrollEventResult
}

@MainActor
final class ScrollController: ScrollControlling {
    private let pixelsPerPulse: Int32
    private let pulseCount: Int
    private let pulseDelay: TimeInterval

    init(
        pixelsPerPulse: Int32 = 18,
        pulseCount: Int = 3,
        pulseDelay: TimeInterval = 0.012
    ) {
        self.pixelsPerPulse = pixelsPerPulse
        self.pulseCount = max(1, min(pulseCount, 4))
        self.pulseDelay = pulseDelay
    }

    func scrollUp() -> ScrollEventResult {
        postScroll(direction: .up, deltaY: pixelsPerPulse)
    }

    func scrollDown() -> ScrollEventResult {
        postScroll(direction: .down, deltaY: -pixelsPerPulse)
    }

    private func postScroll(direction: ScrollDirection, deltaY: Int32) -> ScrollEventResult {
        var postedEvents = 0

        for pulseIndex in 0..<pulseCount {
            guard let event = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 1,
                wheel1: deltaY,
                wheel2: 0,
                wheel3: 0
            ) else {
                continue
            }

            event.post(tap: .cghidEventTap)
            postedEvents += 1

            if pulseIndex < pulseCount - 1 {
                Thread.sleep(forTimeInterval: pulseDelay)
            }
        }

        return ScrollEventResult(
            direction: direction,
            units: .pixel,
            pulseCount: pulseCount,
            valuePerPulse: deltaY,
            postedEvents: postedEvents
        )
    }
}

enum ScrollDirection: Equatable {
    case up
    case down

    var title: String {
        switch self {
        case .up:
            return "Scroll Up"
        case .down:
            return "Scroll Down"
        }
    }
}

enum ScrollEventUnits: Equatable {
    case pixel

    var debugName: String {
        switch self {
        case .pixel:
            return "pixel"
        }
    }
}

struct ScrollEventResult: Equatable {
    let direction: ScrollDirection
    let units: ScrollEventUnits
    let pulseCount: Int
    let valuePerPulse: Int32
    let postedEvents: Int

    var debugDescription: String {
        "\(units.debugName), \(postedEvents)/\(pulseCount) pulses, value \(valuePerPulse)"
    }
}
