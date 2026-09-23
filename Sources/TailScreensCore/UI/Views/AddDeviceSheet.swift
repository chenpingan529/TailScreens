import SwiftUI

/// Sheet for adding a new remote computer manually.
public struct AddDeviceSheet: View {
    @ObservedObject public var viewModel: DeviceListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var portString: String = "5900"
    @State private var deviceType: RemoteDevice.DeviceType = .mac
    @State private var password: String = ""

    public init(viewModel: DeviceListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Device Information")) {
                    TextField("Name (e.g. Studio Mac)", text: $name)
                    TextField("Tailscale IP / Host (e.g. 100.80.1.25)", text: $host)
                        .autocorrectionDisabled()
                        #if canImport(UIKit)
                        .keyboardType(.URL)
                        #endif
                    TextField("Port", text: $portString)
                        #if canImport(UIKit)
                        .keyboardType(.numberPad)
                        #endif
                }

                Section(header: Text("Operating System")) {
                    Picker("Device Type", selection: $deviceType) {
                        ForEach(RemoteDevice.DeviceType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.systemIcon).tag(type)
                        }
                    }
                }

                Section(
                    header: Text("Authentication"),
                    footer: Text("For macOS Screen Sharing, set a VNC password under System Settings > General > Sharing > Screen Sharing > Computer Settings.")
                ) {
                    SecureField("VNC Password (Optional)", text: $password)
                }
            }
            .navigationTitle("Add Computer")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let port = UInt16(portString) ?? RFBConstants.defaultPort
                        let finalName = name.isEmpty ? host : name
                        viewModel.addDevice(
                            name: finalName,
                            host: host,
                            port: port,
                            type: deviceType,
                            password: password.isEmpty ? nil : password
                        )
                        dismiss()
                    }
                    .disabled(host.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
