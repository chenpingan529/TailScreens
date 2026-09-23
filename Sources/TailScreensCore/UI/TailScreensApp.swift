import SwiftUI

public struct TailScreensApp: App {
    public init() {}
    public var body: some Scene {
        WindowGroup {
            DeviceListView()
                .tint(.blue)
        }
    }
}
