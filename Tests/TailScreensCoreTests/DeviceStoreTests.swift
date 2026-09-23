import XCTest
@testable import TailScreensCore

final class DeviceStoreTests: XCTestCase {

    var tempDefaults: UserDefaults!
    var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "test.tailscreens.\(UUID().uuidString)"
        tempDefaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        tempDefaults.removePersistentDomain(forName: suiteName)
        tempDefaults = nil
        super.tearDown()
    }

    func testAddAndRetrieveDevice() {
        let store = DeviceStore(userDefaults: tempDefaults)
        let device = RemoteDevice(
            name: "Living Room Mac",
            host: "100.80.1.20",
            port: 5900,
            deviceType: .mac
        )

        store.addDevice(device, password: "testPassword123")
        XCTAssertEqual(store.devices.count, 1)
        XCTAssertEqual(store.devices.first?.name, "Living Room Mac")

        // Password retrieval
        let retrievedPwd = store.getPassword(for: device)
        XCTAssertEqual(retrievedPwd, "testPassword123")
    }

    func testDeleteDevice() {
        let store = DeviceStore(userDefaults: tempDefaults)
        let device = RemoteDevice(name: "Test Mac", host: "100.80.1.30")
        store.addDevice(device, password: "secret")
        XCTAssertEqual(store.devices.count, 1)

        store.deleteDevice(device)
        XCTAssertEqual(store.devices.count, 0)
    }

    func testMergeTailscaleNodes() {
        let store = DeviceStore(userDefaults: tempDefaults)

        let initialDevice = RemoteDevice(
            name: "My Work Mac",
            host: "100.80.10.5",
            isOnline: false
        )
        store.addDevice(initialDevice, password: "preservedPassword")

        // Tailscale returns updated status for the same IP
        let tsNode = TailscaleDevice(
            id: "node_abc",
            name: "work-mac.ts.net",
            hostname: "Work Mac Updated",
            addresses: ["100.80.10.5"],
            os: "macOS",
            connectedToControl: true
        )

        store.mergeTailscaleDevices([tsNode])

        XCTAssertEqual(store.devices.count, 1)
        XCTAssertEqual(store.devices.first?.name, "Work Mac Updated")
        XCTAssertTrue(store.devices.first?.isOnline ?? false)

        // Password should still be preserved
        let pwd = store.getPassword(for: store.devices.first!)
        XCTAssertEqual(pwd, "preservedPassword")
    }
}
