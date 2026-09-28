import SwiftUI
import TailScreensCore

@main
struct TailScreensMainApp: App {
    var body: some Scene {
        WindowGroup {
            DeviceListView()
                .tint(.blue)
                #if os(macOS)
                .frame(minWidth: 800, minHeight: 520)
                #endif
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
        }
        #endif
    }
}
