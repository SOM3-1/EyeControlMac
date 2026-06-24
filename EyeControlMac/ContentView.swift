//
//  ContentView.swift
//  EyeControlMac
//
//  Created by Dushyanth N Gowda on 6/24/26.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var actionExecutor: ActionExecutor

    private let mockGazeController = MockGazeController()
    private let mockBlinkController = MockBlinkController()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                header

                if appState.isCommandOverlayVisible {
                    CommandOverlayView()
                }

                Spacer(minLength: 0)

                HStack(alignment: .bottom) {
                    if appState.isDebugPanelVisible {
                        DebugPanelView()
                    }

                    Spacer()

                    if appState.isPaused {
                        FloatingResumeView()
                    }
                }
            }
            .padding(24)

            KeyCaptureView { event in
                handleKey(event)
            }
        }
        .frame(minWidth: 760, minHeight: 520)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("EyeControlMac")
                    .font(.largeTitle.weight(.semibold))

                Text("Mock control shell. Arrow keys select commands, Space simulates double blink.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(appState.statusTitle)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(appState.isPaused ? .orange : .green)

                Text("\(appState.controlMode.title) Mode")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func handleKey(_ event: NSEvent) {
        if event.modifierFlags.contains(.command),
           event.modifierFlags.contains(.shift),
           event.charactersIgnoringModifiers?.lowercased() == "e" {
            appState.togglePause(actionExecutor: actionExecutor)
            return
        }

        switch event.keyCode {
        case 53:
            appState.emergencyPause(actionExecutor: actionExecutor)
        case 49:
            mockBlinkController.simulateDoubleBlink(
                appState: appState,
                actionExecutor: actionExecutor
            )
        case 123, 126:
            mockGazeController.moveSelectionLeft(appState: appState)
        case 124, 125:
            mockGazeController.moveSelectionRight(appState: appState)
        default:
            break
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
            .environmentObject(ActionExecutor())
    }
}

private struct KeyCaptureView: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onKeyDown = onKeyDown

        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onKeyDown = onKeyDown

        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class KeyCaptureNSView: NSView {
    var onKeyDown: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
    }
}
