import Foundation

/// Manages persistence, discovery merging, and updates for configured remote devices.
public final class DeviceStore: @unchecked Sendable {
    public static let shared = DeviceStore()

    private let storageKey = "com.tailscreens.devices.list"
    private let userDefaults: UserDefaults
    private let keychain: KeychainStore
    private let lock = NSLock()

    public private(set) var devices: [RemoteDevice] = []

    public init(userDefaults: UserDefaults = .standard, keychain: KeychainStore = .shared) {
        self.userDefaults = userDefaults
        self.keychain = keychain
        loadDevices()
    }

    /// Reload devices from storage.
    public func loadDevices() {
        lock.lock()
        defer { lock.unlock() }

        guard let data = userDefaults.data(forKey: storageKey) else {
            self.devices = []
            return
        }

        do {
            let decoded = try JSONDecoder().decode([RemoteDevice].self, from: data)
            self.devices = decoded
        } catch {
            print("[DeviceStore] Failed to decode devices: \(error)")
            self.devices = []
        }
    }

    /// Add a new device and optionally save its password to Keychain.
    public func addDevice(_ device: RemoteDevice, password: String? = nil) {
        lock.lock()
        defer { lock.unlock() }

        if let idx = devices.firstIndex(where: { $0.id == device.id }) {
            devices[idx] = device
        } else {
            devices.append(device)
        }

        if let pwd = password {
            keychain.savePassword(pwd, forKey: device.id.uuidString)
        }

        persist()
    }

    /// Update an existing device.
    public func updateDevice(_ device: RemoteDevice, password: String? = nil) {
        addDevice(device, password: password)
    }

    /// Remove a device and its stored password.
    public func deleteDevice(_ device: RemoteDevice) {
        lock.lock()
        defer { lock.unlock() }

        devices.removeAll { $0.id == device.id }
        keychain.deletePassword(forKey: device.id.uuidString)
        persist()
    }

    /// Merge discovered Tailscale nodes into the device list (preserves existing saved credentials).
    public func mergeTailscaleDevices(_ tailscaleNodes: [TailscaleDevice]) {
        lock.lock()
        defer { lock.unlock() }

        for ts in tailscaleNodes {
            guard let ip = ts.tailscaleIPv4 else { continue }

            if let existingIdx = devices.firstIndex(where: { $0.host == ip }) {
                // Update online status and name
                devices[existingIdx].isOnline = ts.isOnline
                devices[existingIdx].name = ts.displayName
                devices[existingIdx].isTailscaleNode = true
            } else {
                // Add new discovered Tailscale device
                if let newDev = RemoteDevice.fromTailscaleDevice(ts) {
                    devices.append(newDev)
                }
            }
        }

        persist()
    }

    /// Retrieve the saved password for a device.
    public func getPassword(for device: RemoteDevice) -> String? {
        return keychain.loadPassword(forKey: device.id.uuidString)
    }

    /// Check if a saved password exists for this device.
    public func hasPassword(for device: RemoteDevice) -> Bool {
        guard let pwd = getPassword(for: device) else { return false }
        return !pwd.isEmpty
    }

    /// Update or save password for an existing device.
    public func updatePassword(_ password: String, for device: RemoteDevice) {
        keychain.savePassword(password, forKey: device.id.uuidString)
        AppLogger.shared.info("Updated password in Keychain for device '\(device.name)' (\(device.id.uuidString))", category: "Auth")
    }

    /// Remove password from Keychain for a device.
    public func clearPassword(for device: RemoteDevice) {
        keychain.deletePassword(forKey: device.id.uuidString)
        AppLogger.shared.info("Cleared password in Keychain for device '\(device.name)'", category: "Auth")
    }

    /// Record connection timestamp.
    public func recordConnection(for device: RemoteDevice) {
        lock.lock()
        defer { lock.unlock() }

        if let idx = devices.firstIndex(where: { $0.id == device.id }) {
            devices[idx].lastConnected = Date()
            persist()
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(devices)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            print("[DeviceStore] Failed to persist devices: \(error)")
        }
    }
}
