//
//  EyeCommand.swift
//  EyeControlMac
//
//  Created by Dushyanth N Gowda on 6/24/26.
//

import Foundation

enum EyeCommand: String, CaseIterable, Identifiable {
    case scrollUp
    case scrollDown
    case nextPage
    case previousPage
    case minimizeCurrentWindow
    case maximizeCurrentWindow
    case switchWindow
    case pause
    case resume
    case recalibrate
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scrollUp:
            return "Scroll Up"
        case .scrollDown:
            return "Scroll Down"
        case .nextPage:
            return "Next Page"
        case .previousPage:
            return "Previous Page"
        case .minimizeCurrentWindow:
            return "Minimize"
        case .maximizeCurrentWindow:
            return "Maximize"
        case .switchWindow:
            return "Switch Window"
        case .pause:
            return "Pause"
        case .resume:
            return "Resume"
        case .recalibrate:
            return "Recalibrate"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .scrollUp:
            return "arrow.up"
        case .scrollDown:
            return "arrow.down"
        case .nextPage:
            return "chevron.right"
        case .previousPage:
            return "chevron.left"
        case .minimizeCurrentWindow:
            return "minus"
        case .maximizeCurrentWindow:
            return "arrow.up.left.and.arrow.down.right"
        case .switchWindow:
            return "rectangle.on.rectangle"
        case .pause:
            return "pause.fill"
        case .resume:
            return "play.fill"
        case .recalibrate:
            return "scope"
        case .settings:
            return "gearshape"
        }
    }

    var isWindowAction: Bool {
        switch self {
        case .minimizeCurrentWindow, .maximizeCurrentWindow, .switchWindow:
            return true
        default:
            return false
        }
    }

    static let overlayCommands: [EyeCommand] = [
        .scrollUp,
        .scrollDown,
        .previousPage,
        .nextPage,
        .minimizeCurrentWindow,
        .maximizeCurrentWindow,
        .switchWindow,
        .pause,
        .resume,
        .recalibrate,
        .settings
    ]
}
