import SwiftUI
import AppKit

// MARK: - Native AppKit Live Backdrop Blur (Hardware-Accelerated Liquid Glass)

public struct VisualEffectBlur: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    public var state: NSVisualEffectView.State

    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.wantsLayer = true
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - True Circular Liquid Glass Petal Shape (True Circular Arcs, Zero Flat Edges)

public struct CircularPetalShape: Shape {
    public let centerAngle: Double // radians
    public let angularSpan: Double // radians
    public let innerRadius: CGFloat
    public let outerRadius: CGFloat
    public let cornerRadius: CGFloat

    public init(
        centerAngle: Double,
        angularSpan: Double,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        cornerRadius: CGFloat = 11
    ) {
        self.centerAngle = centerAngle
        self.angularSpan = angularSpan
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.cornerRadius = cornerRadius
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        let startAngle = centerAngle - angularSpan / 2.0
        let endAngle = centerAngle + angularSpan / 2.0

        let r = cornerRadius
        let Ro = outerRadius
        let Ri = innerRadius

        // Exact analytical corner angle offsets
        let deltaOuter = asin(Double(r / (Ro - r)))
        let thetaOuterStart = startAngle + deltaOuter
        let thetaOuterEnd = endAngle - deltaOuter

        let deltaInner = asin(Double(r / (Ri + r)))
        let thetaInnerStart = startAngle + deltaInner
        let thetaInnerEnd = endAngle - deltaInner

        // 1. Move to start of outer circular arc
        let pOuterStart = CGPoint(
            x: center.x + Ro * CGFloat(cos(thetaOuterStart)),
            y: center.y + Ro * CGFloat(sin(thetaOuterStart))
        )
        path.move(to: pOuterStart)

        // 2. True circular arc along outerRadius (increasing angle / counter-clockwise)
        path.addArc(
            center: center,
            radius: Ro,
            startAngle: Angle(radians: thetaOuterStart),
            endAngle: Angle(radians: thetaOuterEnd),
            clockwise: false
        )

        // 3. Outer-trailing smooth corner arc around cOuterEnd
        let cOuterEnd = CGPoint(
            x: center.x + (Ro - r) * CGFloat(cos(thetaOuterEnd)),
            y: center.y + (Ro - r) * CGFloat(sin(thetaOuterEnd))
        )
        path.addArc(
            center: cOuterEnd,
            radius: r,
            startAngle: Angle(radians: thetaOuterEnd),
            endAngle: Angle(radians: endAngle + .pi / 2.0),
            clockwise: false
        )

        // 4. Straight line along trailing radial edge to inner-trailing corner
        let cInnerEnd = CGPoint(
            x: center.x + (Ri + r) * CGFloat(cos(thetaInnerEnd)),
            y: center.y + (Ri + r) * CGFloat(sin(thetaInnerEnd))
        )
        let pInnerEndTangent = CGPoint(
            x: cInnerEnd.x + r * CGFloat(cos(endAngle + .pi / 2.0)),
            y: cInnerEnd.y + r * CGFloat(sin(endAngle + .pi / 2.0))
        )
        path.addLine(to: pInnerEndTangent)

        // 5. Inner-trailing smooth corner arc around cInnerEnd
        path.addArc(
            center: cInnerEnd,
            radius: r,
            startAngle: Angle(radians: endAngle + .pi / 2.0),
            endAngle: Angle(radians: thetaInnerEnd + .pi),
            clockwise: false
        )

        // 6. True circular arc along innerRadius (decreasing angle / clockwise back to leading edge)
        path.addArc(
            center: center,
            radius: Ri,
            startAngle: Angle(radians: thetaInnerEnd),
            endAngle: Angle(radians: thetaInnerStart),
            clockwise: true
        )

        // 7. Inner-leading smooth corner arc around cInnerStart
        let cInnerStart = CGPoint(
            x: center.x + (Ri + r) * CGFloat(cos(thetaInnerStart)),
            y: center.y + (Ri + r) * CGFloat(sin(thetaInnerStart))
        )
        path.addArc(
            center: cInnerStart,
            radius: r,
            startAngle: Angle(radians: thetaInnerStart + .pi),
            endAngle: Angle(radians: startAngle + 3.0 * .pi / 2.0),
            clockwise: false
        )

        // 8. Straight line along leading radial edge to outer-leading corner
        let cOuterStart = CGPoint(
            x: center.x + (Ro - r) * CGFloat(cos(thetaOuterStart)),
            y: center.y + (Ro - r) * CGFloat(sin(thetaOuterStart))
        )
        let pOuterStartTangent = CGPoint(
            x: cOuterStart.x + r * CGFloat(cos(startAngle + 3.0 * .pi / 2.0)),
            y: cOuterStart.y + r * CGFloat(sin(startAngle + 3.0 * .pi / 2.0))
        )
        path.addLine(to: pOuterStartTangent)

        // 9. Outer-leading smooth corner arc around cOuterStart back to pOuterStart
        path.addArc(
            center: cOuterStart,
            radius: r,
            startAngle: Angle(radians: startAngle + 3.0 * .pi / 2.0),
            endAngle: Angle(radians: thetaOuterStart),
            clockwise: false
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Pure Liquid Glass Radial Petal Wheel (Zero Grey, Zero Backing Circle, No Popup)

public struct LiquidGlassWheelView: View {
    @ObservedObject public var state: WheelState

    // Wheel Geometry (Fixed dimensions, no enlargement on hover)
    private let canvasSize: CGFloat = 440
    private let outerRadius: CGFloat = 165
    private let innerRadius: CGFloat = 58
    private let centerPillWidth: CGFloat = 114
    private let centerPillHeight: CGFloat = 48

    public init(state: WheelState) {
        self.state = state
    }

    public var body: some View {
        let isConverting = state.isConverting
        let isSuccess = state.conversionSuccess
        let activeFormat = state.selectedFormat
        let formats = state.availableFormats
        let count = formats.count

        ZStack {
            if state.isUnsupportedFile {
                // MARK: Unsupported File Indicator Pill
                unsupportedFilePillView
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
            } else {
                // MARK: 1. Floating Liquid Glass Petals (Smoothly collapses and fades on conversion)
                if count > 0 {
                    // Fixed 8-option circular petal shape: exactly (2*pi / 8) - gap
                    // This shape is SHARED by all petals and NEVER changes when the number of formats changes!
                    let fixedPetalSpan: Double = (2.0 * .pi / 8.0) - 0.046
                    let sliceAngle = (2.0 * .pi) / Double(count)

                    ForEach(0..<count, id: \.self) { index in
                        let format = formats[index]
                        let isHovered = state.hoveredIndex == index
                        let centerAngle = -(.pi / 2.0) + Double(index) * sliceAngle

                        liquidPetalView(
                            format: format,
                            centerAngle: centerAngle,
                            angularSpan: fixedPetalSpan,
                            isHovered: isHovered,
                            isDimmed: (isConverting || isSuccess)
                        )
                        .scaleEffect((isConverting || isSuccess) ? 0.82 : 1.0)
                        .opacity((isConverting || isSuccess) ? 0.0 : 1.0)
                        .animation(.spring(response: 0.36, dampingFraction: 0.78), value: isConverting)
                        .animation(.spring(response: 0.36, dampingFraction: 0.78), value: isSuccess)
                    }
                }

                // MARK: 2. Center Liquid Glass Hub (Idle Pill / Converting Orb / Success Orb)
                if isSuccess {
                    LiquidSuccessOrbView(format: activeFormat, state: state)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.85).combined(with: .opacity),
                            removal: .scale(scale: 0.88).combined(with: .opacity)
                        ))
                } else if isConverting {
                    LiquidConvertingOrbView(format: activeFormat)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.88).combined(with: .opacity),
                            removal: .scale(scale: 0.90).combined(with: .opacity)
                        ))
                } else {
                    liquidCenterPillView(format: activeFormat)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.92).combined(with: .opacity),
                            removal: .scale(scale: 0.88).combined(with: .opacity)
                        ))
                }
            }
        }
        .frame(width: canvasSize, height: canvasSize)
        .scaleEffect(state.isPresented ? 1.0 : 0.88)
        .opacity(state.isPresented ? 1.0 : 0.0)
        .animation(.spring(response: 0.32, dampingFraction: 0.76), value: state.isPresented)
        .animation(.spring(response: 0.18, dampingFraction: 0.70), value: state.hoveredIndex)
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: state.phase)
    }

    // MARK: - Individual Pure Liquid Glass Petal (No Popup, Just Highlight)

    @ViewBuilder
    private func liquidPetalView(
        format: FormatOption,
        centerAngle: Double,
        angularSpan: Double,
        isHovered: Bool,
        isDimmed: Bool
    ) -> some View {
        let labelRadius: CGFloat = (innerRadius + outerRadius) / 2.0
        let labelX = (canvasSize / 2.0) + labelRadius * CGFloat(cos(centerAngle))
        let labelY = (canvasSize / 2.0) + labelRadius * CGFloat(sin(centerAngle))

        let shape = CircularPetalShape(
            centerAngle: centerAngle,
            angularSpan: angularSpan,
            innerRadius: innerRadius,
            outerRadius: outerRadius, // FIXED geometry, NO popup!
            cornerRadius: 13
        )

        ZStack {
            // Ambient Soft Shadow under each individual glass petal
            shape
                .fill(Color.black.opacity(0.28))
                .blur(radius: isHovered ? 12 : 6)
                .offset(y: 3)

            // True Hardware Live Backdrop Glass Blur
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(shape)

            // Complete Liquid Glass Translucent Sheen (Zero Grey!)
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            isHovered ? Color.white.opacity(0.35) : Color.white.opacity(0.12),
                            isHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.03),
                            isHovered ? Color.white.opacity(0.10) : Color.white.opacity(0.01)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Specular Hairline Glass Rim (Highlights brilliantly on hover without popping up)
            shape
                .stroke(
                    LinearGradient(
                        colors: [
                            isHovered ? Color.white.opacity(0.98) : Color.white.opacity(0.48),
                            isHovered ? Color.white.opacity(0.70) : Color.white.opacity(0.18),
                            isHovered ? Color.white.opacity(0.50) : Color.white.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isHovered ? 1.8 : 1.0
                )
                .shadow(
                    color: isHovered ? Color.white.opacity(0.55) : Color.clear,
                    radius: 8
                )

            // Content: SF Symbol + Uppercase Format Label
            VStack(spacing: 3) {
                Image(systemName: format.iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(
                        color: isHovered ? Color.white.opacity(0.70) : Color.black.opacity(0.35),
                        radius: isHovered ? 6 : 2
                    )

                Text(format.displayName)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .kerning(0.5)
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.45), radius: 2)
            }
            .position(x: labelX, y: labelY)
        }
        // NO scale effect on hover! Just pure liquid highlight
        .opacity(isDimmed ? 0.30 : 1.0)
    }

    // MARK: - Center Liquid Glass Pill (Pure Liquid Glass, Zero Grey)

    private func liquidCenterPillView(format: FormatOption?) -> some View {
        let count = state.fileURLs.count
        let fileCountText = count > 1 ? "\(count) files" : (count == 1 ? "1 file" : "Drop")

        let titleText: String
        let subText: String

        if state.availableFormats.isEmpty {
            titleText = "UNSUPPORTED"
            subText = "No offline converter"
        } else if let fmt = format {
            titleText = fmt.displayName
            subText = fileCountText
        } else {
            titleText = "CONVERT"
            subText = fileCountText
        }

        return ZStack {
            // Ambient Drop Shadow
            RoundedRectangle(cornerRadius: centerPillHeight / 2.0, style: .continuous)
                .fill(Color.black.opacity(0.30))
                .frame(width: centerPillWidth + (state.availableFormats.isEmpty ? 24 : 0), height: centerPillHeight)
                .blur(radius: 8)
                .offset(y: 3)

            // Live Hardware Glass Blur
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: centerPillHeight / 2.0, style: .continuous))
                .frame(width: centerPillWidth + (state.availableFormats.isEmpty ? 24 : 0), height: centerPillHeight)

            // Pure Liquid Glass Sheen
            RoundedRectangle(cornerRadius: centerPillHeight / 2.0, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(format != nil ? 0.28 : 0.14),
                            Color.white.opacity(format != nil ? 0.12 : 0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: centerPillWidth + (state.availableFormats.isEmpty ? 24 : 0), height: centerPillHeight)

            // Hairline Specular Border
            RoundedRectangle(cornerRadius: centerPillHeight / 2.0, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            format != nil ? Color.white.opacity(0.90) : Color.white.opacity(0.50),
                            format != nil ? Color.white.opacity(0.40) : Color.white.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: format != nil ? 1.5 : 1.0
                )
                .frame(width: centerPillWidth + (state.availableFormats.isEmpty ? 24 : 0), height: centerPillHeight)

            // Readout: Format Name + File Count
            VStack(spacing: 1) {
                Text(titleText)
                    .font(.system(size: state.availableFormats.isEmpty ? 11 : 14.5, weight: .bold, design: .rounded))
                    .kerning(0.8)
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.40), radius: 2)

                Text(subText)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.70))
            }
        }
    }

    // MARK: - Legacy methods replaced with LiquidConvertingOrbView and LiquidSuccessOrbView below

    // MARK: - Unsupported File Floating Liquid Glass Pill

    private var unsupportedFilePillView: some View {
        HStack(spacing: 11) {
            Image(systemName: "slash.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.42, blue: 0.38),
                            Color(red: 1.0, green: 0.24, blue: 0.30)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.red.opacity(0.40), radius: 6, x: 0, y: 1)

            Text("File not supported for conversion")
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .shadow(color: Color.black.opacity(0.40), radius: 4, x: 0, y: 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background {
            ZStack {
                // Ambient Soft Shadow
                Capsule()
                    .fill(Color.black.opacity(0.35))
                    .blur(radius: 12)
                    .offset(y: 4)

                // Hardware Live Backdrop Glass Blur
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                    .clipShape(Capsule())

                // Pure Liquid Glass Translucent Sheen
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.24),
                        Color.white.opacity(0.08),
                        Color.clear,
                        Color.white.opacity(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(Capsule())

                // Luminous Specular Border
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.70),
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.45)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            }
        }
    }
}

// MARK: - Hardware Synchronized Liquid Progress Ring (Zero Stutter, Continuous 60/120Hz)

public struct LiquidProgressRing: View {
    public init() {}

    public var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let angle = (elapsed.truncatingRemainder(dividingBy: 1.05) / 1.05) * 360.0

            ZStack {
                // Subtle track ring
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 3.2)

                // Glowing comet arc
                Circle()
                    .trim(from: 0.05, to: 0.78)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.85),
                                Color.white
                            ]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(angle))
                    .shadow(color: Color.white.opacity(0.65), radius: 6)
            }
        }
    }
}

// MARK: - Premium Liquid Glass Converting Orb

public struct LiquidConvertingOrbView: View {
    public let format: FormatOption?

    public init(format: FormatOption?) {
        self.format = format
    }

    public var body: some View {
        ZStack {
            // Ambient Soft Shadow
            Circle()
                .fill(Color.black.opacity(0.32))
                .frame(width: 96, height: 96)
                .blur(radius: 14)
                .offset(y: 4)

            // Live Hardware Glass Blur
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(Circle())
                .frame(width: 96, height: 96)

            // Pure Liquid Glass Core
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.24),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 96, height: 96)

            // Specular Glass Border
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.85),
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.40)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: 96, height: 96)

            // Silky Smooth Hardware Progress Ring
            LiquidProgressRing()
                .frame(width: 104, height: 104)

            // Format Icon and Label
            VStack(spacing: 3) {
                if let fmt = format {
                    TimelineView(.animation) { timeline in
                        let elapsed = timeline.date.timeIntervalSinceReferenceDate
                        let iconScale = 1.0 + 0.05 * CGFloat(sin(elapsed * 3.4))

                        Image(systemName: fmt.iconName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .scaleEffect(iconScale)
                            .shadow(color: Color.white.opacity(0.45), radius: 6)
                    }

                    Text(fmt.displayName)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.35), radius: 2)

                    Text("Converting…")
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                }
            }
        }
    }
}

// MARK: - Premium Apple Liquid Emerald Success Card

public struct LiquidSuccessOrbView: View {
    public let format: FormatOption?
    @ObservedObject public var state: WheelState

    public init(format: FormatOption?, state: WheelState) {
        self.format = format
        self.state = state
    }

    public var body: some View {
        ZStack {
            // Soft Outward Emerald Ripple Wave
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.88, blue: 0.44).opacity(state.rippleOpacity),
                            Color(red: 0.10, green: 0.75, blue: 0.38).opacity(0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3.0
                )
                .frame(width: 96 * state.rippleScale, height: 96 * state.rippleScale)

            // Outer Soft Ambient Emerald Glow
            Circle()
                .fill(Color(red: 0.20, green: 0.85, blue: 0.44).opacity(0.40))
                .frame(width: 96, height: 96)
                .blur(radius: 16)

            // Hardware Glass Backdrop
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(Circle())
                .frame(width: 96, height: 96)

            // Glowing Liquid Emerald Core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.26, green: 0.92, blue: 0.52).opacity(0.95),
                            Color(red: 0.12, green: 0.76, blue: 0.38).opacity(0.96)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 48
                    )
                )
                .frame(width: 96, height: 96)
                .shadow(color: Color(red: 0.18, green: 0.84, blue: 0.42).opacity(0.70), radius: 16, y: 3)

            // Specular Rim Highlight
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.40),
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.60)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.8
                )
                .frame(width: 96, height: 96)

            // Content: Animated Checkmark & Done Typography
            VStack(spacing: 3) {
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.30), radius: 3, y: 1.5)
                    .scaleEffect(state.checkmarkScale)

                if let fmt = format {
                    Text(fmt.displayName)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.96))
                        .shadow(color: Color.black.opacity(0.20), radius: 2)
                }
            }
        }
    }
}


