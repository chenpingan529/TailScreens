import Foundation
import SwiftUI
import Combine

/// ViewModel managing the device library, Tailnet discovery, and active sessions.
@MainActor
public final class DeviceListViewModel: ObservableObject {
    @Published public var devices: [RemoteDevice] = []
    @Published public var searchText: String = ""
    @Published public var isSyncingTailscale: Bool = false
    @Published public var tailscaleApiKey: String = ""
    @Published public var tailnetName: String = ""
    @Published public var activeSessionDevice: RemoteDevice?
    @Published public var errorMessage: String?

    private let store: DeviceStore

    public init(store: DeviceStore = .shared) {
        self.store = store
        self.devices = store.devices
        
        // Seed default demo / local Mac if store is empty
        if self.devices.isEmpty {
            let defaultMac = RemoteDevice(
                name: "My Mac (Screen Sharing)",
                host: "100.80.1.50",
                port: RFBConstants.defaultPort,
                deviceType: .mac,
                authMethod: .vncPassword,
                isOnline: true,
                isTailscaleNode: true
            )
            store.addDevice(defaultMac)
            self.devices = store.devices
        }
    }

    public var filteredDevices: [RemoteDevice] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return devices
        }
        return devices.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.host.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Reload devices from store
    public func reload() {
        store.loadDevices()
        self.devices = store.devices
    }

    /// Add a new device manually
    public func addDevice(name: String, host: String, port: UInt16, type: RemoteDevice.DeviceType, password: String?) {
        let dev = RemoteDevice(
            name: name,
            host: host,
            port: port,
            deviceType: type,
            authMethod: password == nil ? .none : .vncPassword,
            isOnline: true
        )
        store.addDevice(dev, password: password)
        reload()
    }

    /// Delete a device
    public func deleteDevice(_ device: RemoteDevice) {
        store.deleteDevice(device)
        reload()
    }

    /// Sync online devices from Tailscale API
    public func syncTailscale() async {
        guard !tailscaleApiKey.isEmpty else {
            errorMessage = "Please enter your Tailscale API Key in Settings"
            return
        }

        isSyncingTailscale = true
        errorMessage = nil

        let client = TailscaleClient(apiKey: tailscaleApiKey, tailnet: tailnetName)
        do {
            let nodes = try await client.fetchDevices()
            store.mergeTailscaleDevices(nodes)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSyncingTailscale = false
    }

    /// Start a remote desktop session with the given device
    public func connect(to device: RemoteDevice) {
        store.recordConnection(for: device)
        activeSessionDevice = device
    }
}
