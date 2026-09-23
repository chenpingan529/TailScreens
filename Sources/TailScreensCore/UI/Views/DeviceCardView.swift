import SwiftUI

/// Screens-style computer card displaying device status, IP, and remote preview.
public struct DeviceCardView: View {
    public let device: RemoteDevice
    public let onConnect: () -> Void

    public init(device: RemoteDevice, onConnect: @escaping () -> Void) {
        self.device = device
        self.onConnect = onConnect
    }

    public var body: some View {
        Button(action: onConnect) {
            VStack(alignment: .leading, spacing: 10) {
                // Screen Preview Placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 120)

                    Image(systemName: device.deviceType.systemIcon)
                        .font(.system(size: 42, weight: .light))
                        .foregroundColor(.primary.opacity(0.75))

                    // Online Status Indicator
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(device.isOnline ? Color.green : Color.gray)
                                    .frame(width: 8, height: 8)
                                Text(device.isOnline ? "Online" : "Offline")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(8)
                        }
                        Spacer()
                    }
                }

                // Machine Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(device.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if device.isTailscaleNode {
                            Image(systemName: "point.3.filled.connected.trianglepath")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                        }
                    }

                    HStack(spacing: 6) {
                        Text(device.host)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.secondary)

                        Text(":\(device.port)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
            }
            .padding(10)
            .background(Color(red: 0.12, green: 0.12, blue: 0.14).opacity(0.08))
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}
