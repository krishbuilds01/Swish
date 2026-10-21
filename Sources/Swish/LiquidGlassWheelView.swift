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
                // MARK: 1. Green Liquid Success Shockwaves
                if isSuccess {
                    // Primary Outward Green Shockwave
                    Circle()
                        .stroke(
                            Color(red: 0.22, green: 0.88, blue: 0.44).opacity(state.rippleOpacity),
                            lineWidth: 3.0
                        )
                        .frame(
                            width: (outerRadius * 2) * state.rippleScale,
                            height: (outerRadius * 2) * state.rippleScale
                        )

                    // Secondary Echo Green Wave
                    Circle()
                        .stroke(
                            Color(red: 0.22, green: 0.88, blue: 0.44).opacity(state.secondRippleOpacity),
                            lineWidth: 1.8
                        )
                        .frame(
                            width: (outerRadius * 2) * state.secondRippleScale,
                            height: (outerRadius * 2) * state.secondRippleScale
                        )
                }

                // MARK: 2. Floating Liquid Glass Petals (NO background circle!)
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
                    }
                }

                // MARK: 3. Center Liquid Glass Pill / Green Success Tick View
                if isSuccess {
                    greenSuccessTickCard
                        .transition(.scale(scale: 0.75).combined(with: .opacity))
                } else if isConverting {
                    convertingCenterOrb(format: activeFormat)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                } else {
                    liquidCenterPillView(format: activeFormat)
                        .transition(.scale(scale: 0.90).combined(with: .opacity))
                }
            }
        }
        .frame(width: canvasSize, height: canvasSize)
        .scaleEffect(state.isPresented ? 1.0 : 0.88)
        .opacity(state.isPresented ? 1.0 : 0.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.74), value: state.isPresented)
        .animation(.spring(response: 0.18, dampingFraction: 0.70), value: state.hoveredIndex)
        .animation(.spring(response: 0.35, dampingFraction: 0.76), value: state.phase)
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

    // MARK: - Converting Orb

    @ViewBuilder
    private func convertingCenterOrb(format: FormatOption?) -> some View {
        ZStack {
            // Live Hardware Glass Blur
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(Circle())
                .frame(width: 82, height: 82)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.24), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 82, height: 82)

            Circle()
                .stroke(Color.white.opacity(0.60), lineWidth: 1.4)
                .frame(width: 82, height: 82)

            // Spinning Liquid Comet Ring
            Circle()
                .trim(from: 0.0, to: 0.70)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.45),
                            Color.white
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3.0, lineCap: .round)
                )
                .frame(width: 88, height: 88)
                .rotationEffect(Angle(degrees: state.progressRotation))
                .onAppear {
                    withAnimation(.linear(duration: 0.95).repeatForever(autoreverses: false)) {
                        state.progressRotation = 360
                    }
                }

            VStack(spacing: 2) {
                if let fmt = format {
                    Image(systemName: fmt.iconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }

                Text("Converting")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))
            }
        }
    }

    // MARK: - Green Success Tick (Exact Match to User Request)

    private var greenSuccessTickCard: some View {
        ZStack {
            // Concentric Green Pulse Wave 1
            Circle()
                .stroke(Color(red: 0.20, green: 0.85, blue: 0.44).opacity(0.45), lineWidth: 2.0)
                .frame(width: 104, height: 104)

            // Concentric Green Pulse Wave 2
            Circle()
                .stroke(Color(red: 0.20, green: 0.85, blue: 0.44).opacity(0.75), lineWidth: 2.5)
                .frame(width: 90, height: 90)

            // Glowing Vibrant Apple-Green Circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.24, green: 0.90, blue: 0.50),
                            Color(red: 0.16, green: 0.78, blue: 0.40)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 40
                    )
                )
                .frame(width: 76, height: 76)
                .shadow(color: Color(red: 0.20, green: 0.85, blue: 0.44).opacity(0.80), radius: 18)

            // White Specular Rim
            Circle()
                .stroke(Color.white.opacity(0.90), lineWidth: 2.0)
                .frame(width: 76, height: 76)

            // Crisp White Checkmark Tick
            Image(systemName: "checkmark")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.30), radius: 4, y: 2)
        }
    }

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
