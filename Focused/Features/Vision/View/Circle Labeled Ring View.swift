import SwiftUI

/// Circle (10% stepped) with outer ring labels (icon + title), like the reference wheel.
struct VisionCircleLabeledRingView: View {
    let spheres: [Sphere]
    let goals: [Goal]
    @Binding var selectedSphere: Sphere?
    @Binding var isGenerating: Bool
    let showIcons: Bool
    let onEdit: (Sphere) -> Void
    let onRequestActions: (Sphere) -> Void
    let onAdd: () -> Void
    let onDragStateChange: (Bool) -> Void

    /// Outer ring geometry as a fraction of the full view min dimension.
    /// - Note: `VisionCircleView` uses maxOuterRadiusRatio = 0.45 for its outer border.
    ///   We scale the inner wheel so its outer border touches `ringInnerRadius` (gap = 0).
    private let ringOuterRadiusRatio: CGFloat = 0.495
    private let ringThicknessRatio: CGFloat = 0.07

    var body: some View {
        GeometryReader { geo in
            let minDim = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let limited = Array(spheres.prefix(12))
            let sectorAngle = Angle.degrees(360.0 / Double(max(limited.count, 1)))
            let ringOuterRadius = minDim * ringOuterRadiusRatio
            let ringThickness = minDim * ringThicknessRatio
            let ringInnerRadius = max(0, ringOuterRadius - ringThickness)
            let ringMidRadius = (ringInnerRadius + ringOuterRadius) / 2
            let innerWheelScale = ringInnerRadius / (minDim * 0.45)
            let angularInset = Angle.degrees(0)

            ZStack {
                VisionCircleView(
                    spheres: spheres,
                    goals: goals,
                    selectedSphere: $selectedSphere,
                    isGenerating: $isGenerating,
                    displayMode: .steppedTenPercent,
                    showIcons: showIcons,
                    showEdgeIcons: false,
                    showCenterPulseIcon: false,
                    onEdit: onEdit,
                    onRequestActions: onRequestActions,
                    onAdd: onAdd,
                    onDragStateChange: onDragStateChange
                )
                .scaleEffect(innerWheelScale)

                ForEach(Array(limited.enumerated()), id: \.element.id) { index, sphere in
                    let start = sectorAngle * Double(index)
                    let end = start + sectorAngle
                    let mid = start + sectorAngle * 0.5 - .degrees(90)
                    let color = Color(hex: sphere.colorHex)
                    let startInset = start + angularInset
                    let endInset = end - angularInset
                    let arcStart = startInset - .degrees(90)
                    let arcEnd = endInset - .degrees(90)

                    // Ring segment as an arc-stroke with rounded ends (like the reference).
                    ringArc(
                        center: center,
                        radius: ringMidRadius,
                        start: arcStart,
                        end: arcEnd,
                        thickness: ringThickness,
                        color: color
                    )
                    .allowsHitTesting(false)

                    // Label inside the ring segment.
                    ringLabel(
                        sphere: sphere,
                        center: center,
                        radius: ringMidRadius,
                        angle: mid
                    )
                    .mask(
                        ringArcMask(
                            center: center,
                            radius: ringMidRadius,
                            start: arcStart,
                            end: arcEnd,
                            thickness: ringThickness
                        )
                    )
                    // IMPORTANT: avoid blocking inner wheel gestures (drag/tap) with a full-rect hit area.
                    // Tap handling lives on an arc-shaped hit target below.
                    .allowsHitTesting(false)
                    
                    // Arc-only hit target for selecting a sphere by tap (doesn't block inner wheel).
                    Color.clear
                        .contentShape(RingArcHitShape(radius: ringMidRadius, start: arcStart, end: arcEnd, thickness: ringThickness))
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedSphere = sphere
                            }
                        }
                        .onTapGesture(count: 2) {
                            onEdit(sphere)
                        }
                        .onLongPressGesture(minimumDuration: 0.4) {
                            onRequestActions(sphere)
                        }
                }

                // Thin separators between sectors (match inner wheel style).
                ForEach(0..<max(limited.count, 1), id: \.self) { idx in
                    let a = sectorAngle * Double(idx) - .degrees(90)
                    Path { p in
                        let x1 = center.x + cos(a.radians) * ringInnerRadius
                        let y1 = center.y + sin(a.radians) * ringInnerRadius
                        let x2 = center.x + cos(a.radians) * ringOuterRadius
                        let y2 = center.y + sin(a.radians) * ringOuterRadius
                        p.move(to: CGPoint(x: x1, y: y1))
                        p.addLine(to: CGPoint(x: x2, y: y2))
                    }
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    .allowsHitTesting(false)
                }

                // Outer border circle enclosing the ring.
                // Match the ring segment stroke (color + width) so the outermost rim doesn't visually differ.
                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: {
                                let cols = limited.map { Color(hex: $0.colorHex).opacity(0.26) }
                                // Ensure smooth wrap-around.
                                return cols.isEmpty ? [Color.black.opacity(0.12)] : (cols + [cols[0]])
                            }()),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: ringThickness, lineCap: .butt, lineJoin: .round)
                    )
                    .frame(width: ringMidRadius * 2, height: ringMidRadius * 2)
                    .position(x: center.x, y: center.y)
                    .allowsHitTesting(false)

                // Thin outer-edge outline (on the ring's outer boundary).
                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: {
                                let cols = limited.map { Color(hex: $0.colorHex).opacity(0.95) }
                                return cols.isEmpty ? [Color.black.opacity(0.25)] : (cols + [cols[0]])
                            }()),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: ringOuterRadius * 2, height: ringOuterRadius * 2)
                    .position(x: center.x, y: center.y)
                    .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Hit-test shape for the outer ring segment (arc stroke with thickness).
    private struct RingArcHitShape: Shape {
        var radius: CGFloat
        var start: Angle
        var end: Angle
        var thickness: CGFloat
        
        func path(in rect: CGRect) -> Path {
            let center = CGPoint(x: rect.midX, y: rect.midY)
            var p = Path()
            p.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
            return p.strokedPath(.init(lineWidth: thickness, lineCap: .butt, lineJoin: .round))
        }
    }

    private func ringArc(
        center: CGPoint,
        radius: CGFloat,
        start: Angle,
        end: Angle,
        thickness: CGFloat,
        color: Color
    ) -> some View {
        ZStack {
            Path { p in
                p.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
            }
            .stroke(
                color.opacity(0.20),
                style: StrokeStyle(lineWidth: thickness, lineCap: .butt, lineJoin: .round)
            )
        }
    }

    private func ringArcMask(
        center: CGPoint,
        radius: CGFloat,
        start: Angle,
        end: Angle,
        thickness: CGFloat
    ) -> some View {
        Path { p in
            p.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        }
        .stroke(style: StrokeStyle(lineWidth: thickness, lineCap: .butt, lineJoin: .round))
    }

    @ViewBuilder
    private func ringLabel(
        sphere: Sphere,
        center: CGPoint,
        radius: CGFloat,
        angle: Angle
    ) -> some View {
        let baseRotation = angle + .degrees(90) // tangent-ish orientation
        let deg = baseRotation.degrees.truncatingRemainder(dividingBy: 360)
        let upsideDown = deg > 90 && deg < 270

        ZStack {
            CurvedIconTextOnArcSwiftUI(
                iconSystemName: sphere.iconName,
                iconColor: Color(hex: sphere.colorHex).opacity(0.95),
                text: sphere.title,
                textColor: Color(hex: sphere.colorHex),
                center: center,
                radius: radius,
                centerAngle: angle,
                font: .caption2.weight(.semibold),
                upsideDown: upsideDown
            )
        }
    }
}
