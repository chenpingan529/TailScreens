import Foundation
import SwiftUI
import CoreGraphics
import Combine

/// Manages a live remote screen sharing session with a Mac.
@MainActor
public final class SessionViewModel: ObservableObject, Identifiable {
    public let device: RemoteDevice
    public nonisolated var id: UUID { device.id }
    private let client: RFBClient
    public let trackpadEngine: TrackpadEngine

    @Published public var sessionState: RFBClient.State = .disconnected
    @Published public var currentImage: CGImage?
    @Published public var inputMode: TrackpadEngine.Mode = .trackpad {
        didSet {
            trackpadEngine.mode = inputMode
        }
    }
    @Published public var isKeyboardVisible: Bool = false
    @Published public var showShortcutsMenu: Bool = false

    // Modifiers state (Sticky keys)
    @Published public var isCmdActive: Bool = false
    @Published public var isOptActive: Bool = false
    @Published public var isCtrlActive: Bool = false
    @Published public var isShiftActive: Bool = false

    // Zoom and pan
    @Published public var zoomScale: CGFloat = 1.0
    @Published public var viewOffset: CGSize = .zero

    public init(device: RemoteDevice, password: String?) {
        self.device = device
        let rfb = RFBClient(
            host: device.host,
            port: device.port,
            password: password
        )
        self.client = rfb
        self.trackpadEngine = TrackpadEngine(remoteWidth: 1920, remoteHeight: 1080)

        setupBindings()
    }

    private func setupBindings() {
        // Handle pointer events from trackpad engine
        trackpadEngine.onPointerEvent = { [weak self] mask, x, y in
            guard let self = self else { return }
            self.client.sendPointerEvent(buttonMask: mask, x: x, y: y)
        }

        // Handle RFB client state changes
        client.onStateChanged = { [weak self] state in
            Task { @MainActor in
                self?.sessionState = state
            }
        }

        // Handle incoming screen frame updates
        client.onFrameUpdated = { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                self.currentImage = self.client.framebuffer.makeCGImage()
                self.trackpadEngine.remoteWidth = CGFloat(self.client.framebuffer.width)
                self.trackpadEngine.remoteHeight = CGFloat(self.client.framebuffer.height)
            }
        }

        // Handle incoming clipboard text
        client.onClipboardReceived = { text in
            #if canImport(UIKit)
            Task { @MainActor in
                UIPasteboard.general.string = text
            }
            #elseif canImport(AppKit)
            Task { @MainActor in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
            #endif
        }
    }

    /// Connect to remote Mac
    public func startSession() {
        client.connect()
    }

    /// Disconnect from remote Mac
    public func endSession() {
        client.disconnect()
    }

    // MARK: - Modifiers & Keyboard Control

    public func toggleCmd() {
        isCmdActive.toggle()
        client.sendKeyEvent(down: isCmdActive, keySym: MacKeyMap.commandLeft)
    }

    public func toggleOption() {
        isOptActive.toggle()
        client.sendKeyEvent(down: isOptActive, keySym: MacKeyMap.optionLeft)
    }

    public func toggleControl() {
        isCtrlActive.toggle()
        client.sendKeyEvent(down: isCtrlActive, keySym: MacKeyMap.controlLeft)
    }

    public func toggleShift() {
        isShiftActive.toggle()
        client.sendKeyEvent(down: isShiftActive, keySym: MacKeyMap.shiftLeft)
    }

    /// Reset all sticky modifiers to released state
    public func releaseAllModifiers() {
        if isCmdActive {
            isCmdActive = false
            client.sendKeyEvent(down: false, keySym: MacKeyMap.commandLeft)
        }
        if isOptActive {
            isOptActive = false
            client.sendKeyEvent(down: false, keySym: MacKeyMap.optionLeft)
        }
        if isCtrlActive {
            isCtrlActive = false
            client.sendKeyEvent(down: false, keySym: MacKeyMap.controlLeft)
        }
        if isShiftActive {
            isShiftActive = false
            client.sendKeyEvent(down: false, keySym: MacKeyMap.shiftLeft)
        }
    }

    /// Send a single key tap (down + up)
    public func sendKeyTap(_ keySym: UInt32) {
        client.sendKeyEvent(down: true, keySym: keySym)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.client.sendKeyEvent(down: false, keySym: keySym)
            self?.releaseAllModifiers()
        }
    }

    /// Send a text character
    public func sendCharacter(_ char: Character) {
        if let sym = MacKeyMap.keySym(for: char) {
            sendKeyTap(sym)
        }
    }

    /// Execute a predefined Mac shortcut
    public func executeShortcut(_ shortcut: MacKeyMap.MacShortcut) {
        let sequence = shortcut.keySequence
        for item in sequence {
            client.sendKeyEvent(down: item.down, keySym: item.key)
        }
    }

    /// Sync iOS clipboard text to remote Mac
    public func syncClipboardToMac() {
        #if canImport(UIKit)
        if let string = UIPasteboard.general.string {
            client.sendCutText(string)
        }
        #elseif canImport(AppKit)
        if let string = NSPasteboard.general.string(forType: .string) {
            client.sendCutText(string)
        }
        #endif
    }
}
