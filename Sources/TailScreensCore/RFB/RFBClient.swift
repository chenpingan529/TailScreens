import Foundation
import Network

/// High-level client managing an RFB 3.8 remote desktop session over TCP (Network.framework).
public final class RFBClient: @unchecked Sendable {

    public enum State: Equatable, Sendable {
        case disconnected
        case connecting
        case negotiatingVersion
        case authenticating
        case initializing
        case connected
        case failed(String)
    }

    public let host: String
    public let port: UInt16
    public let password: String?
    public let framebuffer: Framebuffer

    public private(set) var state: State = .disconnected {
        didSet {
            onStateChanged?(state)
        }
    }

    // Callbacks
    public var onStateChanged: (@Sendable (State) -> Void)?
    public var onFrameUpdated: (@Sendable () -> Void)?
    public var onClipboardReceived: (@Sendable (String) -> Void)?

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.tailscreens.rfbclient", qos: .userInteractive)
    private var readBuffer = Data()

    public init(
        host: String,
        port: UInt16 = RFBConstants.defaultPort,
        password: String? = nil,
        framebuffer: Framebuffer = Framebuffer()
    ) {
        self.host = host
        self.port = port
        self.password = password
        self.framebuffer = framebuffer
    }

    /// Initiate connection to the remote Mac.
    public func connect() {
        switch state {
        case .disconnected, .failed:
            break
        default:
            return
        }

        state = .connecting
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true // Disable Nagle's algorithm for interactive responsiveness
        let params = NWParameters(tls: nil, tcp: tcpOptions)

        let conn = NWConnection(host: nwHost, port: nwPort, using: params)
        self.connection = conn

        conn.stateUpdateHandler = { [weak self] connState in
            guard let self = self else { return }
            switch connState {
            case .ready:
                self.startHandshake()
            case .failed(let error):
                self.handleFailure("Connection failed: \(error.localizedDescription)")
            case .cancelled:
                self.state = .disconnected
            default:
                break
            }
        }

        conn.start(queue: queue)
    }

    /// Disconnect current session.
    public func disconnect() {
        connection?.cancel()
        connection = nil
        readBuffer.removeAll()
        state = .disconnected
    }

    // MARK: - Handshake Workflow

    private func startHandshake() {
        state = .negotiatingVersion
        // Expect 12 bytes of version: "RFB 003.008\n"
        readExact(12) { [weak self] data in
            guard let self = self, let data = data else { return }
            guard let (_, _) = RFBDecoder.parseVersion(data) else {
                self.handleFailure("Invalid RFB protocol header from server")
                return
            }

            // Reply with RFB 003.008
            let versionReply = Data(RFBConstants.protocolVersion38.utf8)
            self.sendData(versionReply) {
                self.negotiateSecurity()
            }
        }
    }

    private func negotiateSecurity() {
        state = .authenticating
        // Read 1 byte for number of security types
        readExact(1) { [weak self] countData in
            guard let self = self, let countData = countData else { return }
            let count = Int(countData[0])
            if count == 0 {
                // Server reported an error, read reason
                self.readExact(4) { lenData in
                    guard let lenData = lenData else { return }
                    let reasonLen = Int(lenData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
                    self.readExact(reasonLen) { msgData in
                        let reason = msgData.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown server error"
                        self.handleFailure("Server rejected connection: \(reason)")
                    }
                }
                return
            }

            // Read the supported security types
            self.readExact(count) { typesData in
                guard let typesData = typesData else { return }
                let types = typesData.map { RFBConstants.SecurityType(rawValue: $0) }
                
                self.selectSecurityType(from: types)
            }
        }
    }

    private func selectSecurityType(from types: [RFBConstants.SecurityType]) {
        if types.contains(.vncAuth) {
            // Select VNC Auth (2)
            sendData(Data([RFBConstants.SecurityType.vncAuth.rawValue])) {
                self.performVNCAuth()
            }
        } else if types.contains(.none) {
            // Select None (1)
            sendData(Data([RFBConstants.SecurityType.none.rawValue])) {
                self.handleSecurityResult(type: .none)
            }
        } else {
            handleFailure("No compatible security type supported by server. Offered: \(types)")
        }
    }

    private func performVNCAuth() {
        guard let pwd = password, !pwd.isEmpty else {
            handleFailure("Server requires VNC password, but none was provided")
            return
        }

        // Read 16-byte random challenge
        readExact(16) { [weak self] challengeData in
            guard let self = self, let challengeData = challengeData else { return }
            let response = VNCAuthCrypto.encryptChallenge(challengeData, password: pwd)
            self.sendData(response) {
                self.handleSecurityResult(type: .vncAuth)
            }
        }
    }

    private func handleSecurityResult(type: RFBConstants.SecurityType) {
        // Read 4-byte SecurityResult
        readExact(4) { [weak self] resData in
            guard let self = self, let resData = resData else { return }
            guard let code = RFBDecoder.parseSecurityResult(resData) else {
                self.handleFailure("Failed to parse security result")
                return
            }

            if code == 0 {
                // Auth OK, proceed to ClientInit
                self.sendClientInit()
            } else {
                // Auth failed, read reason if 3.8
                self.readExact(4) { lenData in
                    if let lenData = lenData {
                        let len = Int(lenData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
                        self.readExact(len) { errData in
                            let errStr = errData.flatMap { String(data: $0, encoding: .utf8) } ?? "Authentication failed (incorrect password)"
                            self.handleFailure(errStr)
                        }
                    } else {
                        self.handleFailure("Authentication failed (incorrect password)")
                    }
                }
            }
        }
    }

    private func sendClientInit() {
        state = .initializing
        // ClientInit: 1 byte shared-flag (1 = shared, allows existing sessions to continue)
        sendData(Data([1])) { [weak self] in
            self?.readServerInit()
        }
    }

    private func readServerInit() {
        // Minimum ServerInit is 24 bytes
        readExact(24) { [weak self] headerData in
            guard let self = self, let headerData = headerData else { return }
            let nameLen = Int(headerData.subdata(in: 20..<24).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            
            self.readExact(nameLen) { nameData in
                guard let nameData = nameData else { return }
                var fullData = headerData
                fullData.append(nameData)

                guard let (serverInit, _) = RFBDecoder.parseServerInit(fullData) else {
                    self.handleFailure("Failed to parse ServerInit")
                    return
                }

                // Update framebuffer size
                self.framebuffer.resize(newWidth: Int(serverInit.width), newHeight: Int(serverInit.height))

                // Configure encodings & pixel format
                self.setupSession(serverInit: serverInit)
            }
        }
    }

    private func setupSession(serverInit: RFBServerInit) {
        // Request 32-bit standard BGRA format for high-speed iOS rendering
        let pixelFormatData = RFBEncoder.encodeSetPixelFormat(.standardBGRA32)
        sendData(pixelFormatData)

        // Set encodings: Raw, CopyRect, DesktopSize, Cursor
        let encodingsData = RFBEncoder.encodeSetEncodings([
            .raw,
            .copyRect,
            .desktopSize,
            .cursor
        ])
        sendData(encodingsData)

        state = .connected

        // Send initial full screen update request
        requestUpdate(incremental: false)

        // Start server message loop
        startMessageLoop()
    }

    // MARK: - Server Message Loop

    private func startMessageLoop() {
        readExact(1) { [weak self] typeData in
            guard let self = self, let typeData = typeData else { return }
            let msgType = typeData[0]

            switch msgType {
            case RFBConstants.ServerMessageType.framebufferUpdate.rawValue:
                self.handleFramebufferUpdate()
            case RFBConstants.ServerMessageType.serverCutText.rawValue:
                self.handleServerCutText()
            case RFBConstants.ServerMessageType.bell.rawValue:
                // Beep received, loop continues
                self.startMessageLoop()
            default:
                // Unknown/unsupported message, log and loop
                self.startMessageLoop()
            }
        }
    }

    private func handleFramebufferUpdate() {
        // Header: [pad: 1 byte] [numRects: 2 bytes] = 3 bytes
        readExact(3) { [weak self] headerData in
            guard let self = self, let headerData = headerData else { return }
            let numRects = headerData.subdata(in: 1..<3).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
            self.readRectangles(count: Int(numRects))
        }
    }

    private func readRectangles(count: Int) {
        guard count > 0 else {
            // All rectangles processed, notify UI and request next update
            onFrameUpdated?()
            requestUpdate(incremental: true)
            startMessageLoop()
            return
        }

        // Each rect header: 12 bytes
        readExact(12) { [weak self] rectHeaderData in
            guard let self = self, let rectHeaderData = rectHeaderData else { return }
            guard let header = RFBDecoder.parseRectangleHeader(rectHeaderData) else {
                self.handleFailure("Invalid rectangle header")
                return
            }

            switch header.encoding {
            case .raw:
                let pixelBytes = Int(header.width) * Int(header.height) * 4
                self.readExact(pixelBytes) { pixelData in
                    guard let pixelData = pixelData else { return }
                    self.framebuffer.updateRect(
                        x: Int(header.x),
                        y: Int(header.y),
                        width: Int(header.width),
                        height: Int(header.height),
                        rawData: pixelData
                    )
                    self.readRectangles(count: count - 1)
                }

            case .copyRect:
                // 4 bytes: srcX (2), srcY (2)
                self.readExact(4) { srcData in
                    guard let srcData = srcData else { return }
                    let srcX = srcData.subdata(in: 0..<2).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
                    let srcY = srcData.subdata(in: 2..<4).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
                    self.framebuffer.copyRect(
                        srcX: Int(srcX),
                        srcY: Int(srcY),
                        dstX: Int(header.x),
                        dstY: Int(header.y),
                        width: Int(header.width),
                        height: Int(header.height)
                    )
                    self.readRectangles(count: count - 1)
                }

            case .desktopSize:
                // Screen resolution changed on remote Mac!
                self.framebuffer.resize(newWidth: Int(header.width), newHeight: Int(header.height))
                self.readRectangles(count: count - 1)

            default:
                // Skip unknown encoding data or finish
                self.readRectangles(count: count - 1)
            }
        }
    }

    private func handleServerCutText() {
        // [pad: 3 bytes] [length: 4 bytes]
        readExact(7) { [weak self] headerData in
            guard let self = self, let headerData = headerData else { return }
            let length = Int(headerData.subdata(in: 3..<7).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            self.readExact(length) { textData in
                if let textData = textData,
                   let text = String(data: textData, encoding: .utf8) ?? String(data: textData, encoding: .isoLatin1) {
                    self.onClipboardReceived?(text)
                }
                self.startMessageLoop()
            }
        }
    }

    // MARK: - Public Client Controls (Pointer, Keyboard, Clipboard)

    /// Request a screen update from the remote server.
    public func requestUpdate(incremental: Bool) {
        let req = RFBEncoder.encodeFramebufferUpdateRequest(
            incremental: incremental,
            x: 0,
            y: 0,
            width: UInt16(framebuffer.width),
            height: UInt16(framebuffer.height)
        )
        sendData(req)
    }

    /// Send mouse movement or button press.
    public func sendPointerEvent(buttonMask: RFBConstants.ButtonMask, x: UInt16, y: UInt16) {
        let data = RFBEncoder.encodePointerEvent(buttonMask: buttonMask, x: x, y: y)
        sendData(data)
    }

    /// Send a key press or release.
    public func sendKeyEvent(down: Bool, keySym: UInt32) {
        let data = RFBEncoder.encodeKeyEvent(down: down, keySym: keySym)
        sendData(data)
    }

    /// Send clipboard text to remote Mac.
    public func sendCutText(_ text: String) {
        let data = RFBEncoder.encodeClientCutText(text)
        sendData(data)
    }

    // MARK: - Socket Helpers

    private func sendData(_ data: Data, completion: (@Sendable () -> Void)? = nil) {
        connection?.send(content: data, completion: .contentProcessed({ error in
            if let error = error {
                print("[RFBClient] Send error: \(error)")
            }
            completion?()
        }))
    }

    private func readExact(_ count: Int, completion: @escaping @Sendable (Data?) -> Void) {
        guard let conn = connection else {
            completion(nil)
            return
        }

        conn.receive(minimumIncompleteLength: count, maximumLength: count) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }
            if let error = error {
                self.handleFailure("Socket read error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = content, data.count == count else {
                if isComplete {
                    self.handleFailure("Remote host closed connection")
                } else {
                    self.handleFailure("Received partial data (expected \(count) bytes)")
                }
                completion(nil)
                return
            }

            completion(data)
        }
    }

    private func handleFailure(_ message: String) {
        state = .failed(message)
        connection?.cancel()
        connection = nil
    }
}
