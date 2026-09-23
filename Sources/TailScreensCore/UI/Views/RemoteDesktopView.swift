import SwiftUI
import CoreGraphics

/// Interactive Remote Desktop viewport providing screen rendering, gesture inputs, and floating controls.
public struct RemoteDesktopView: View {
    @ObservedObject public var viewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var lastDragLocation: CGPoint?
    @State private var isDraggingMouse: Bool = false

    public init(viewModel: SessionViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                // Remote Framebuffer Canvas
                if let cgImage = viewModel.currentImage {
                    let imageWidth = CGFloat(cgImage.width)
                    let imageHeight = CGFloat(cgImage.height)

                    ZStack(alignment: .topLeading) {
                        Image(decorative: cgImage, scale: 1.0)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width * viewModel.zoomScale)
                            .offset(viewModel.viewOffset)

                        // Virtual Cursor Overlay (in Trackpad mode)
                        if viewModel.inputMode == .trackpad && imageWidth > 0 && imageHeight > 0 {
                            let scale = (geometry.size.width * viewModel.zoomScale) / imageWidth
                            let cursorScreenX = viewModel.trackpadEngine.cursorX * scale + viewModel.viewOffset.width
                            let cursorScreenY = viewModel.trackpadEngine.cursorY * scale + viewModel.viewOffset.height

                            Circle()
                                .fill(Color.white.opacity(0.85))
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                                .shadow(radius: 3)
                                .position(x: cursorScreenX, y: cursorScreenY)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        // Pan / Drag gesture
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if let last = lastDragLocation {
                                    let dx = value.location.x - last.x
                                    let dy = value.location.y - last.y

                                    if viewModel.inputMode == .trackpad {
                                        viewModel.trackpadEngine.handlePanDelta(dx: dx, dy: dy)
                                    } else {
                                        viewModel.trackpadEngine.handleDirectTouch(point: value.location, viewSize: geometry.size)
                                    }
                                }
                                lastDragLocation = value.location
                            }
                            .onEnded { _ in
                                lastDragLocation = nil
                                if isDraggingMouse {
                                    viewModel.trackpadEngine.endDrag()
                                    isDraggingMouse = false
                                }
                            }
                    )
                    .simultaneousGesture(
                        // Tap Gesture
                        TapGesture()
                            .onEnded {
                                viewModel.trackpadEngine.handleTap()
                            }
                    )
                    .simultaneousGesture(
                        // Magnification (Pinch to Zoom)
                        MagnificationGesture()
                            .onChanged { scale in
                                viewModel.zoomScale = max(1.0, min(scale, 4.0))
                            }
                    )
                } else {
                    // Connecting / Loading State
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(1.3)

                        Text(statusDescription)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))

                        Text(viewModel.device.host)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))

                        if case .failed(let err) = viewModel.sessionState {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundColor(.red.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)

                            Button("Retry Connection") {
                                viewModel.startSession()
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 8)
                        }
                    }
                }

                // Floating Top Controls Bar
                VStack {
                    floatingTopBar
                        .padding(.top, 12)
                    Spacer()

                    // Bottom Mac Keyboard Toolbar (if visible)
                    if viewModel.isKeyboardVisible {
                        MacKeyboardToolbar(viewModel: viewModel)
                            .transition(.move(edge: .bottom))
                    }
                }
            }
        }
        .onAppear {
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.endSession()
        }
    }

    private var statusDescription: String {
        switch viewModel.sessionState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting to Mac via Tailscale..."
        case .negotiatingVersion: return "Negotiating RFB 3.8 protocol..."
        case .authenticating: return "Authenticating with Mac..."
        case .initializing: return "Initializing screen sharing session..."
        case .connected: return "Connected"
        case .failed(let err): return "Connection error: \(err)"
        }
    }

    private var floatingTopBar: some View {
        HStack(spacing: 12) {
            // Back / Close
            Button {
                viewModel.endSession()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }

            // Machine Name & State Dot
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.sessionState == .connected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(viewModel.device.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.6))
            .clipShape(Capsule())

            Spacer()

            // Mode Toggle (Trackpad / Touch)
            Picker("Mode", selection: $viewModel.inputMode) {
                Image(systemName: "hand.point.up.left.fill").tag(TrackpadEngine.Mode.trackpad)
                Image(systemName: "hand.tap.fill").tag(TrackpadEngine.Mode.touch)
            }
            .pickerStyle(.segmented)
            .frame(width: 100)

            // Keyboard Toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.isKeyboardVisible.toggle()
                }
            } label: {
                Image(systemName: "keyboard")
                    .font(.system(size: 14))
                    .foregroundColor(viewModel.isKeyboardVisible ? .accentColor : .white)
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
    }
}
