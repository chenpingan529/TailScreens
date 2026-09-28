import XCTest
import Network
@testable import TailScreensCore

final class TailscaleLiveHandshakeTests: XCTestCase {

    let targetHost = "100.64.0.3"
    let targetPort: UInt16 = 5900

    func testLiveTailscaleHandshakeIfReachable() throws {
        let expectation = XCTestExpectation(description: "RFB handshake with Tailscale node 100.64.0.3")

        let nwHost = NWEndpoint.Host(targetHost)
        let nwPort = NWEndpoint.Port(rawValue: targetPort)!
        let params = NWParameters.tcp
        let conn = NWConnection(host: nwHost, port: nwPort, using: params)
        let queue = DispatchQueue(label: "com.tailscreens.livetest")

        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:
                // 1. Receive 12-byte Server Version (e.g. "RFB 003.889\n")
                conn.receive(minimumIncompleteLength: 12, maximumLength: 12) { content, _, _, error in
                    guard let content = content, error == nil else {
                        XCTFail("Failed to receive RFB version: \(String(describing: error))")
                        expectation.fulfill()
                        return
                    }

                    guard let (major, minor) = RFBDecoder.parseVersion(content) else {
                        XCTFail("Could not parse RFB version: \(content)")
                        expectation.fulfill()
                        return
                    }

                    XCTAssertEqual(major, 3, "Major version should be 3")
                    XCTAssertTrue(minor >= 8, "Minor version should be at least 8 (got \(minor))")

                    // 2. Client replies with RFB 003.008\n
                    let clientVer = Data(RFBConstants.protocolVersion38.utf8)
                    conn.send(content: clientVer, completion: .contentProcessed({ sendErr in
                        guard sendErr == nil else {
                            XCTFail("Failed to send version reply")
                            expectation.fulfill()
                            return
                        }

                        // 3. Receive security types count
                        conn.receive(minimumIncompleteLength: 1, maximumLength: 1) { countData, _, _, _ in
                            guard let countData = countData, !countData.isEmpty else {
                                XCTFail("Failed to receive security types count")
                                expectation.fulfill()
                                return
                            }

                            let count = Int(countData[0])
                            XCTAssertGreaterThan(count, 0, "Server must offer at least 1 security type")

                            // 4. Receive security types array
                            conn.receive(minimumIncompleteLength: count, maximumLength: count) { typesData, _, _, _ in
                                guard let typesData = typesData else {
                                    XCTFail("Failed to receive security types data")
                                    expectation.fulfill()
                                    return
                                }

                                let types = typesData.map { RFBConstants.SecurityType(rawValue: $0) }
                                XCTAssertTrue(types.contains(.vncAuth), "Server should support VNC Auth (2)")

                                // 5. Select VNC Auth (2)
                                conn.send(content: Data([RFBConstants.SecurityType.vncAuth.rawValue]), completion: .contentProcessed({ _ in
                                    // 6. Receive 16-byte random challenge
                                    conn.receive(minimumIncompleteLength: 16, maximumLength: 16) { challengeData, _, _, _ in
                                        guard let challenge = challengeData else {
                                            XCTFail("Failed to receive 16-byte auth challenge")
                                            expectation.fulfill()
                                            return
                                        }

                                        XCTAssertEqual(challenge.count, 16, "VNC Auth challenge must be exactly 16 bytes")

                                        // Test Challenge Encryption with dummy password
                                        let encrypted = VNCAuthCrypto.encryptChallenge(challenge, password: "test_password")
                                        XCTAssertEqual(encrypted.count, 16, "Encrypted challenge response must be 16 bytes")

                                        conn.cancel()
                                        expectation.fulfill()
                                    }
                                }))
                            }
                        }
                    }))
                }

            case .failed(let err):
                // If Tailscale node is unreachable in this test environment, pass gracefully
                print("[TailscaleLiveHandshakeTests] Node \(self.targetHost) unreachable: \(err)")
                expectation.fulfill()

            default:
                break
            }
        }

        conn.start(queue: queue)
        wait(for: [expectation], timeout: 5.0)
    }

    func testLiveTailscaleFullSessionWithSavedPassword() throws {
        var dev = DeviceStore.shared.devices.first(where: { $0.host == targetHost })
        if dev == nil {
            if let appDefaults = UserDefaults(suiteName: "com.chenpingan.TailScreens"),
               let data = appDefaults.data(forKey: "com.tailscreens.devices.list"),
               let devs = try? JSONDecoder().decode([RemoteDevice].self, from: data) {
                dev = devs.first(where: { $0.host == targetHost })
            }
        }

        guard let targetDev = dev,
              let pwd = DeviceStore.shared.getPassword(for: targetDev), !pwd.isEmpty else {
            print("[TailscaleLiveHandshakeTests] No saved password found for \(targetHost), skipping full session test")
            return
        }

        print("[TailscaleLiveHandshakeTests] Found saved password for \(targetHost), running live session test...")
        let frameExpectation = expectation(description: "Receive at least 1 screen frame from remote Mac")
        frameExpectation.assertForOverFulfill = false

        let client = RFBClient(host: targetHost, port: targetPort, password: pwd)
        client.onStateChanged = { state in
            print("[TailscaleLiveHandshakeTests] Client state changed: \(state)")
        }
        client.onFrameUpdated = {
            print("[TailscaleLiveHandshakeTests] Frame received! Dimensions: \(client.framebuffer.width)x\(client.framebuffer.height)")
            frameExpectation.fulfill()
        }

        client.connect()
        wait(for: [frameExpectation], timeout: 60.0)
        client.disconnect()
    }
}
