import SwiftUI

struct MiniRecorderView: View {
    @ObservedObject var whisperState: WhisperState
    @ObservedObject var recorder: Recorder
    @EnvironmentObject var windowManager: MiniWindowManager
    @EnvironmentObject private var enhancementService: AIEnhancementService
    
    @State private var activePopover: ActivePopoverState = .none
    @State private var showEnhancementOverlay = false
    @State private var lastShortcutEnhancementState = false
    @State private var overlayDismissTask: Task<Void, Never>? = nil
    
    private var backgroundView: some View {
        ZStack {
            Color.black.opacity(0.9)
            LinearGradient(
                colors: [
                    Color.black.opacity(0.95),
                    Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .opacity(0.05)

            // Accent tint overlay when enhancement is enabled
            if enhancementService.isEnhancementEnabled {
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.35),
                        Color.accentColor.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.plusLighter)
                .transition(.opacity)
            }
        }
        .clipShape(Capsule())
        .animation(.easeInOut(duration: 0.25), value: enhancementService.isEnhancementEnabled)
    }
    
    private var statusView: some View {
        RecorderStatusDisplay(
            currentState: whisperState.recordingState,
            audioMeter: recorder.audioMeter
        )
    }
    
    private var contentLayout: some View {
        HStack(spacing: 0) {
            // Left button zone - always visible
            RecorderPromptButton(activePopover: $activePopover)
                .padding(.leading, 7)

            if enhancementService.isEnhancementEnabled {
                EnhancementStatusBadge()
                    .padding(.leading, 6)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            Spacer()

            // Fixed visualizer zone
            statusView
                .frame(maxWidth: .infinity)

            Spacer()

            // Right button zone - always visible
            RecorderPowerModeButton(activePopover: $activePopover)
                .padding(.trailing, 7)
        }
        .padding(.vertical, 9)
    }
    
    private var recorderCapsule: some View {
        Capsule()
            .fill(.clear)
            .background(backgroundView)
            .overlay {
                Capsule()
                    .strokeBorder(
                        enhancementService.isEnhancementEnabled ?
                            Color.accentColor.opacity(0.85) :
                            Color.white.opacity(0.30),
                        lineWidth: enhancementService.isEnhancementEnabled ? 1.6 : 0.5
                    )
                    .shadow(
                        color: enhancementService.isEnhancementEnabled ?
                            Color.accentColor.opacity(0.55) :
                            Color.clear,
                        radius: enhancementService.isEnhancementEnabled ? 10 : 0,
                        x: 0,
                        y: 4
                    )
                    // Soft outer glow ring
                    .overlay(
                        Capsule()
                            .stroke(Color.accentColor.opacity(enhancementService.isEnhancementEnabled ? 0.25 : 0),
                                    lineWidth: 4)
                            .blur(radius: 8)
                    )
            }
            .overlay {
                contentLayout
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: enhancementService.isEnhancementEnabled)
    }
    
    var body: some View {
        Group {
            if windowManager.isVisible {
                ZStack {
                    recorderCapsule
                    if showEnhancementOverlay {
                        EnhancementToggleOverlayView(enabled: lastShortcutEnhancementState)
                            .transition(.scale.combined(with: .opacity))
                            .zIndex(10)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .enhancementToggledByShortcut)) { notification in
                    guard let enabled = notification.userInfo?["enabled"] as? Bool else { return }
                    lastShortcutEnhancementState = enabled
                    overlayDismissTask?.cancel()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        showEnhancementOverlay = true
                    }
                    overlayDismissTask = Task {
                        try? await Task.sleep(nanoseconds: 1_250_000_000)
                        await MainActor.run {
                            withAnimation(.easeOut(duration: 0.25)) {
                                showEnhancementOverlay = false
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct EnhancementStatusBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 12, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
            Text("ENHANCED")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .kerning(0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.75),
                            Color.accentColor.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            Capsule()
                .stroke(Color.accentColor.opacity(0.90), lineWidth: 1)
        )
        .foregroundColor(.white)
        .shadow(color: Color.accentColor.opacity(0.55), radius: 8, x: 0, y: 3)
        .accessibilityLabel("AI Enhancement Enabled")
        .transition(.opacity.combined(with: .scale))
    }
}

private struct EnhancementToggleOverlayView: View {
    let enabled: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: enabled ? "wand.and.stars" : "slash.circle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(enabled ? .accentColor : .secondary)
            Text(enabled ? "Enhancement ON" : "Enhancement OFF")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.accentColor.opacity(enabled ? 0.55 : 0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
        .transition(.scale.combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(enabled ? "Enhancement enabled" : "Enhancement disabled")
    }
}
