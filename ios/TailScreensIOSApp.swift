import SwiftUI
import TailScreensCore

@main
struct TailScreensIOSApp: App {
    var body: some Scene {
        WindowGroup {
            DeviceListView()
                .tint(.blue)
        }
    }
}
