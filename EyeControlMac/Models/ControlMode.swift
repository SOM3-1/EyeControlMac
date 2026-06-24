//
//  ControlMode.swift
//  EyeControlMac
//
//  Created by Dushyanth N Gowda on 6/24/26.
//

import Foundation

enum ControlMode: String, CaseIterable, Identifiable {
    case reading
    case desktop
    case overlay
    case windowSwitcher
    case calibration
    case debug

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reading:
            return "Reading"
        case .desktop:
            return "Desktop"
        case .overlay:
            return "Overlay"
        case .windowSwitcher:
            return "Window Switcher"
        case .calibration:
            return "Calibration"
        case .debug:
            return "Debug"
        }
    }

    func allows(_ command: EyeCommand) -> Bool {
        switch self {
        case .reading, .overlay, .debug:
            return !command.isWindowAction
        case .desktop, .windowSwitcher:
            return true
        case .calibration:
            return command == .resume || command == .pause || command == .settings
        }
    }
}
