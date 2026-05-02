import SwiftUI

/// Floating glossy robot inspired by EVE-style silhouette: separate head, torso, and fins with no visible joints.
struct BuddyRobotView: View {
    let phase: BuddyInteractionPhase
    /// From `AVSpeechSynthesizer` word-range callbacks — drives a bounce on each spoken chunk.
    let speakingWordPulse: Int
    /// When set, Buddy plays onboarding-specific arm/body loops (does not change chat behavior).
    let onboardingPose: BuddyOnboardingMascotPose?

    @State private var hoverLift: CGFloat = 8
    @State private var shadowPulse: CGFloat = 1.04
    @State private var idleGlow = false
    @State private var listenPulse = false
    @State private var processingWobble = false
    @State private var speakWordNudge: CGFloat = 0

    /// Use `interactionPhase` as the label — avoids clashes with SwiftUI / overload resolution on `phase`.
    init(
        interactionPhase: BuddyInteractionPhase,
        speakingWordPulse: Int = 0,
        onboardingPose: BuddyOnboardingMascotPose? = nil
    ) {
        phase = interactionPhase
        self.speakingWordPulse = speakingWordPulse
        self.onboardingPose = onboardingPose
    }

    var body: some View {
        ZStack {
            if phase == .listening {
                sonarRipples
                    .offset(y: groundShadowY + 18)
            }

            groundShadow
                .offset(y: groundShadowY)
                .scaleEffect(shadowPulse)

            mascotPoseStack
        }
        .onAppear {
            startIdleHoverLoop()
            restartPhaseAnimations(for: phase)
        }
        .onChange(of: phase) { newPhase in
            restartPhaseAnimations(for: newPhase)
            if newPhase != .speaking {
                speakWordNudge = 0
            }
        }
        .onChange(of: speakingWordPulse) { _ in
            guard phase == .speaking else { return }
            triggerSpeakWordNudge()
        }
    }

    private var mascotCore: some View {
        ZStack {
            armsLayer
            torsoAndHeadColumn
        }
    }

    @ViewBuilder
    private var mascotPoseStack: some View {
        if let pose = onboardingPose {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                mascotCore
                    .offset(y: mascotVerticalOffset + pose.extraBobPoints(at: t))
                    .rotationEffect(.degrees(processingTiltDegrees + pose.bodyTiltDegrees(at: t)))
            }
        } else {
            mascotCore
                .offset(y: mascotVerticalOffset)
                .rotationEffect(.degrees(processingTiltDegrees))
        }
    }

    private func triggerSpeakWordNudge() {
        withAnimation(.interpolatingSpring(stiffness: 420, damping: 22)) {
            speakWordNudge = -11
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 26)) {
                speakWordNudge = 0
            }
        }
    }

    private var mascotVerticalOffset: CGFloat {
        switch phase {
        case .idle:
            return hoverLift
        case .listening:
            return hoverLift * 0.62
        case .processing:
            return hoverLift * 0.82
        case .speaking:
            return hoverLift * 0.48 + speakWordNudge
        }
    }

    private var processingTiltDegrees: Double {
        guard phase == .processing else { return 0 }
        return processingWobble ? 3.4 : -3.4
    }

    private func startIdleHoverLoop() {
        withAnimation(.easeInOut(duration: 2.35).repeatForever(autoreverses: true)) {
            hoverLift = -10
            shadowPulse = 0.9
        }
    }

    private func restartPhaseAnimations(for phase: BuddyInteractionPhase) {
        idleGlow = false
        listenPulse = false
        processingWobble = false

        switch phase {
        case .idle:
            withAnimation(.easeInOut(duration: 3.1).repeatForever(autoreverses: true)) {
                idleGlow = true
            }
        case .listening:
            withAnimation(.easeInOut(duration: 0.52).repeatForever(autoreverses: true)) {
                listenPulse = true
            }
        case .processing:
            withAnimation(.easeInOut(duration: 0.72).repeatForever(autoreverses: true)) {
                processingWobble = true
            }
        case .speaking:
            break
        }
    }

    private var sonarRipples: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0 ..< 4, id: \.self) { i in
                    let spacing = 1.0 / 4.0
                    let speed = 0.38
                    let local = (t * speed + Double(i) * spacing).truncatingRemainder(dividingBy: 1.0)
                    let scale = 0.68 + CGFloat(local) * 0.95
                    let opacity = Double(1.0 - local) * 0.52
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: 0x7CF0FF).opacity(0.55),
                                    Color(hex: 0x5AB8FF).opacity(0.35)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 56, height: 56)
                        .scaleEffect(scale)
                        .opacity(opacity)
                }
            }
        }
    }

    private var groundShadowY: CGFloat { 198 }

    private var groundShadow: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [Color.black.opacity(0.28), Color.black.opacity(0.06), .clear],
                    center: .center,
                    startRadius: 8,
                    endRadius: 118
                )
            )
            .frame(width: 268, height: 52)
            .blur(radius: 3)
    }

    private var torsoAndHeadColumn: some View {
        VStack(spacing: -6) {
            headCluster
                .shadow(color: .black.opacity(0.14), radius: 14, y: 8)
            EveTeardropTorso()
                .fill(torsoSurfaceGradient)
                .frame(width: 196, height: 248)
                .overlay {
                    EveTeardropTorso()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.95), .white.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .center
                            ),
                            lineWidth: 1.2
                        )
                }
                .shadow(color: .black.opacity(0.13), radius: 12, y: 7)
                .overlay(alignment: .top) {
                    socketShade
                }
        }
    }

    private var socketShade: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [Color(hex: 0xC8D8EE).opacity(0.35), Color(hex: 0x9BB4DC).opacity(0.18), .clear],
                    center: .center,
                    startRadius: 4,
                    endRadius: 52
                )
            )
            .frame(width: 140, height: 48)
            .offset(y: 18)
            .blur(radius: 2)
    }

    private var headCluster: some View {
        Group {
            if phase == .speaking {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { ctx in
                    let beat = Int(ctx.date.timeIntervalSinceReferenceDate / 0.36) % 4
                    let leftSquint: CGFloat = beat == 0 ? 1 : 0
                    let rightSquint: CGFloat = beat == 2 ? 1 : 0
                    headClusterCore(leftSquint: leftSquint, rightSquint: rightSquint)
                }
            } else {
                headClusterCore(leftSquint: 0, rightSquint: 0)
            }
        }
    }

    private func headClusterCore(leftSquint: CGFloat, rightSquint: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(headSurfaceGradient)
                .frame(width: 232, height: 148)
                .overlay(alignment: .topLeading) {
                    Ellipse()
                        .fill(.white.opacity(0.55))
                        .frame(width: 108, height: 42)
                        .offset(x: 34, y: 22)
                        .blur(radius: 0.5)
                }

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x0A1018), Color(hex: 0x05090E)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 172, height: 66)
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                }

            HStack(spacing: 26) {
                eveEye(phase: phase, tilt: -5, squint: leftSquint)
                eveEye(phase: phase, tilt: 5, squint: rightSquint)
            }
            .offset(y: -1)
        }
    }

    private var armsLayer: some View {
        Group {
            if let pose = onboardingPose {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    HStack(spacing: 108) {
                        finArm(side: -1, extraDegrees: pose.leftArmExtraDegrees(at: t))
                        finArm(side: 1, extraDegrees: pose.rightArmExtraDegrees(at: t))
                    }
                    .offset(y: 42)
                }
            } else {
                HStack(spacing: 108) {
                    finArm(side: -1)
                    finArm(side: 1)
                }
                .offset(y: 42)
            }
        }
    }

    private func finArm(side: CGFloat, extraDegrees: Double = 0) -> some View {
        let baseAngle = side < 0 ? -11.0 : 11.0
        let speakBoost = phase == .speaking ? (side < 0 ? -4.0 : 4.0) : 0
        return Ellipse()
            .fill(armSurfaceGradient)
            .frame(width: 38, height: 148)
            .overlay {
                Ellipse()
                    .stroke(.white.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.1), radius: 8, y: 5)
            .rotationEffect(.degrees(baseAngle + speakBoost + extraDegrees))
            .offset(x: side * 4)
    }

    private func eveEye(phase: BuddyInteractionPhase, tilt: Double, squint: CGFloat) -> some View {
        let colors = eyeGradientColors(phase: phase)
        let lineOpacity = phase == .speaking ? 0.34 : 0.26
        let strokeOpacities: (Double, Double) = strokeHighlightOpacity(phase: phase)
        let glow = eyeGlowRadius(phase: phase, squint: squint)

        return ZStack {
            if phase == .processing {
                ProcessingEyeSpinnerRing()
                    .frame(width: 56, height: 56)
            }

            Ellipse()
                .fill(
                    LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 44, height: 26)
                .scaleEffect(x: 1.0 - squint * 0.06, y: eyeVerticalScale(for: phase, squint: squint))
                .overlay {
                    ScanlineEyeOverlay(lineOpacity: lineOpacity)
                        .mask(Ellipse())
                }
                .overlay {
                    Ellipse()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(strokeOpacities.0), .clear],
                                startPoint: .top,
                                endPoint: .center
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 44, height: 26)
                        .scaleEffect(x: 1.0 - squint * 0.06, y: eyeVerticalScale(for: phase, squint: squint))
                }
                .shadow(color: Color(hex: 0x00AEEF).opacity(glow.opacity), radius: glow.radius)
        }
        .rotationEffect(.degrees(tilt))
        .animation(.easeInOut(duration: 0.35), value: phase)
    }

    private func eyeVerticalScale(for phase: BuddyInteractionPhase, squint: CGFloat) -> CGFloat {
        switch phase {
        case .listening:
            return listenPulse ? 1.1 : 0.94
        case .idle:
            return idleGlow ? 1.035 : 0.965
        case .speaking:
            return 1.02 - squint * 0.22
        case .processing:
            return 1.0
        }
    }

    private func strokeHighlightOpacity(phase: BuddyInteractionPhase) -> (Double, Double) {
        switch phase {
        case .speaking: return (0.78, 0.35)
        case .listening: return (0.95, 0.42)
        default: return (0.45, 0.2)
        }
    }

    private func eyeGlowRadius(phase: BuddyInteractionPhase, squint: CGFloat) -> (radius: CGFloat, opacity: Double) {
        switch phase {
        case .idle:
            return (7, idleGlow ? 0.48 : 0.26)
        case .listening:
            return (16, listenPulse ? 1.0 : 0.62)
        case .processing:
            return (11, 0.74)
        case .speaking:
            return (13, 0.52 + Double(squint) * 0.34)
        }
    }

    private func eyeGradientColors(phase: BuddyInteractionPhase) -> [Color] {
        switch phase {
        case .listening:
            return [Color(hex: 0x8CF8FF), Color(hex: 0x33D6FF), Color(hex: 0x0099DD)]
        case .speaking:
            return [Color(hex: 0xB8F0FF), Color(hex: 0x33D6FF), Color(hex: 0x0099DD)]
        case .processing:
            return [Color(hex: 0x66C8FF), Color(hex: 0x00AEEF), Color(hex: 0x006FA8)]
        case .idle:
            return [Color(hex: 0x55D0FF), Color(hex: 0x00AEEF), Color(hex: 0x0077AA)]
        }
    }

    private var headSurfaceGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0xFFFFFF), Color(hex: 0xF0F4FA), Color(hex: 0xDDE6F2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var torsoSurfaceGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0xFEFFFF), Color(hex: 0xEEF3FA), Color(hex: 0xD5E2F0)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var armSurfaceGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0xFFFFFF), Color(hex: 0xE8EEF6), Color(hex: 0xCEDDEA)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct EveTeardropTorso: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let top = h * 0.06

        path.move(to: CGPoint(x: w * 0.11, y: top + h * 0.16))
        path.addCurve(
            to: CGPoint(x: w * 0.36, y: top),
            control1: CGPoint(x: w * 0.16, y: top + h * 0.02),
            control2: CGPoint(x: w * 0.26, y: top)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: top + h * 0.07),
            control1: CGPoint(x: w * 0.42, y: top + h * 0.02),
            control2: CGPoint(x: w * 0.46, y: top + h * 0.06)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.64, y: top),
            control1: CGPoint(x: w * 0.54, y: top + h * 0.06),
            control2: CGPoint(x: w * 0.58, y: top + h * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.89, y: top + h * 0.16),
            control1: CGPoint(x: w * 0.74, y: top),
            control2: CGPoint(x: w * 0.84, y: top + h * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.98),
            control1: CGPoint(x: w * 0.97, y: h * 0.52),
            control2: CGPoint(x: w * 0.76, y: h * 0.93)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.11, y: top + h * 0.16),
            control1: CGPoint(x: w * 0.24, y: h * 0.93),
            control2: CGPoint(x: w * 0.03, y: h * 0.52)
        )
        path.closeSubpath()
        return path
    }
}

private struct ProcessingEyeSpinnerRing: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let angle = (t.truncatingRemainder(dividingBy: 1.25)) / 1.25 * 360
            Circle()
                .trim(from: 0.02, to: 0.42)
                .stroke(Color(hex: 0x00AEEF).opacity(0.75), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .rotationEffect(.degrees(angle))
            Circle()
                .trim(from: 0.52, to: 0.88)
                .stroke(Color(hex: 0x66C8FF).opacity(0.45), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .rotationEffect(.degrees(-angle * 0.85))
        }
        .allowsHitTesting(false)
    }
}

private struct ScanlineEyeOverlay: View {
    let lineOpacity: Double

    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            let pitch: CGFloat = 3.2
            while y < size.height {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 1.1)
                context.fill(Path(rect), with: .color(Color.black.opacity(lineOpacity)))
                y += pitch
            }
        }
        .allowsHitTesting(false)
    }
}
