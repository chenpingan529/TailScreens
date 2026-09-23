import SwiftUI

/// Main dashboard displaying remote machines, Tailscale sync status, and quick connect.
public struct DeviceListView: View {
    @StateObject private var viewModel = DeviceListViewModel()
    @State private var showingAddSheet = false
    @State private var showingSettingsSheet = false
    @State private var activeSessionVM: SessionViewModel?

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 16)
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                if let err = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }

                if viewModel.filteredDevices.isEmpty {
                    emptyStateView
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.filteredDevices) { device in
                            DeviceCardView(device: device) {
                                openSession(for: device)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel.deleteDevice(device)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("TailScreens")
            .searchable(text: $viewModel.searchText, prompt: "Search computers or IP")
            .refreshable {
                await viewModel.syncTailscale()
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    // Sync Tailscale Button
                    Button {
                        Task {
                            await viewModel.syncTailscale()
                        }
                    } label: {
                        if viewModel.isSyncingTailscale {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }

                    // Add Computer Button
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                #if canImport(UIKit)
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettingsSheet = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                #endif
            }
            .sheet(isPresented: $showingAddSheet) {
                AddDeviceSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingSettingsSheet) {
                TailscaleSettingsSheet(viewModel: viewModel)
            }
            #if os(macOS)
            .sheet(item: $activeSessionVM) { sessionVM in
                RemoteDesktopView(viewModel: sessionVM)
                    .frame(minWidth: 800, minHeight: 600)
            }
            #else
            .fullScreenCover(item: $activeSessionVM) { sessionVM in
                RemoteDesktopView(viewModel: sessionVM)
            }
            #endif
        }
    }

    private func openSession(for device: RemoteDevice) {
        let password = DeviceStore.shared.getPassword(for: device)
        let session = SessionViewModel(device: device, password: password)
        self.activeSessionVM = session
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "display.2")
                .font(.system(size: 64, weight: .thin))
                .foregroundColor(.secondary)
                .padding(.top, 60)

            Text("No Computers Found")
                .font(.system(size: 20, weight: .bold))

            Text("Connect your Mac by adding its Tailscale IP (e.g. 100.x.y.z) or configure your Tailscale API Key to automatically discover online nodes.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showingAddSheet = true
            } label: {
                Label("Add Computer", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 10)
        }
    }
}

/// Settings sheet for configuring Tailscale API credentials
public struct TailscaleSettingsSheet: View {
    @ObservedObject public var viewModel: DeviceListViewModel
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            Form {
                Section(
                    header: Text("Tailscale API Credentials"),
                    footer: Text("Generate an API Access Token or OAuth Client in your Tailscale Admin Console (Settings > Keys). This allows TailScreens to automatically discover your online devices.")
                ) {
                    SecureField("API Access Token (tskey-api-...)", text: $viewModel.tailscaleApiKey)
                    TextField("Tailnet Name (Optional, e.g. example.com)", text: $viewModel.tailnetName)
                }

                Section(header: Text("About macOS Screen Sharing")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("1. Open System Settings on Mac > General > Sharing.")
                            .font(.system(size: 13))
                        Text("2. Turn on Screen Sharing.")
                            .font(.system(size: 13))
                        Text("3. Click ℹ️ > Computer Settings > Enable 'VNC viewers may control screen with password'.")
                            .font(.system(size: 13))
                        Text("4. Ensure Tailscale is running on both iPhone and Mac.")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Tailscale Settings")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
