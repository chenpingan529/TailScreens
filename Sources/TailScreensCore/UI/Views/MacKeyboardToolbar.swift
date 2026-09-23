import SwiftUI

/// Mac-tailored keyboard accessory toolbar with sticky modifiers and quick actions.
public struct MacKeyboardToolbar: View {
    @ObservedObject public var viewModel: SessionViewModel

    public init(viewModel: SessionViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Shortcuts Menu
                    Menu {
                        ForEach(MacKeyMap.MacShortcut.allCases) { shortcut in
                            Button {
                                viewModel.executeShortcut(shortcut)
                            } label: {
                                Label(shortcut.rawValue, systemImage: shortcut.iconName)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "command")
                            Text("Actions")
                                .font(.system(size: 13, weight: .medium))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    // Sticky Modifier Keys
                    Group {
                        ModifierKeyButton(
                            title: "⌘",
                            label: "Cmd",
                            isActive: viewModel.isCmdActive
                        ) {
                            viewModel.toggleCmd()
                        }

                        ModifierKeyButton(
                            title: "⌥",
                            label: "Opt",
                            isActive: viewModel.isOptActive
                        ) {
                            viewModel.toggleOption()
                        }

                        ModifierKeyButton(
                            title: "⌃",
                            label: "Ctrl",
                            isActive: viewModel.isCtrlActive
                        ) {
                            viewModel.toggleControl()
                        }

                        ModifierKeyButton(
                            title: "⇧",
                            label: "Shift",
                            isActive: viewModel.isShiftActive
                        ) {
                            viewModel.toggleShift()
                        }
                    }

                    Divider()
                        .frame(height: 24)

                    // Special Single-Tap Keys
                    Group {
                        ActionButton(title: "esc") {
                            viewModel.sendKeyTap(MacKeyMap.escape)
                        }

                        ActionButton(title: "tab") {
                            viewModel.sendKeyTap(MacKeyMap.tab)
                        }

                        ActionButton(title: "space") {
                            viewModel.sendKeyTap(MacKeyMap.space)
                        }

                        ActionButton(title: "return") {
                            viewModel.sendKeyTap(MacKeyMap.return)
                        }

                        ActionButton(title: "del") {
                            viewModel.sendKeyTap(MacKeyMap.delete)
                        }
                    }

                    Divider()
                        .frame(height: 24)

                    // Directional Arrows
                    Group {
                        ActionButton(icon: "arrow.left") {
                            viewModel.sendKeyTap(MacKeyMap.arrowLeft)
                        }
                        ActionButton(icon: "arrow.up") {
                            viewModel.sendKeyTap(MacKeyMap.arrowUp)
                        }
                        ActionButton(icon: "arrow.down") {
                            viewModel.sendKeyTap(MacKeyMap.arrowDown)
                        }
                        ActionButton(icon: "arrow.right") {
                            viewModel.sendKeyTap(MacKeyMap.arrowRight)
                        }
                    }

                    Divider()
                        .frame(height: 24)

                    // Clipboard Paste to Mac
                    Button {
                        viewModel.syncClipboardToMac()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.clipboard")
                            Text("Paste to Mac")
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(.bar)
        }
    }
}

private struct ModifierKeyButton: View {
    let title: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(isActive ? Color.accentColor : Color.secondary.opacity(0.12))
            .foregroundColor(isActive ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ActionButton: View {
    var title: String? = nil
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                } else if let title = title {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(0.12))
            .foregroundColor(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
