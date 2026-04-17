import SwiftUI
import SwiftData

/// Triangle-based visualization (20% stepped) with the same outer ring labels as Circle Pro.
struct VisionTriangleProView: View {
    let spheres: [Sphere]
    let goals: [Goal]
    @Binding var selectedSphere: Sphere?
    @Binding var isGenerating: Bool
    let onEdit: (Sphere) -> Void
    let onRequestActions: (Sphere) -> Void
    let onAdd: () -> Void
    let onDragStateChange: (Bool) -> Void

    var body: some View {
        GeometryReader { geo in
            let minDim = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let limited = Array(spheres.prefix(12))

            // Total radius must always fit inside the square container.
            // Using > 0.5 * minDim makes the polygon spill outside on some counts (e.g. 4 spheres).
            let totalRadius = max(0, (minDim / 2) - 6)
            // Outer label band thickness = 20% (matches the 20% step).
            let labelBandThickness = totalRadius * 0.20
            let innerWheelRadius = max(0, totalRadius - labelBandThickness)

            // `VisionTriangleView` is designed around outer radius ratio 0.495.
            // Scale it so its outer edge touches the inner edge of the label band (gap = 0).
            let innerWheelScale = innerWheelRadius / (minDim * 0.495)

            ZStack {
                VisionTriangleView(
                    spheres: spheres,
                    goals: goals,
                    selectedSphere: $selectedSphere,
                    isGenerating: $isGenerating,
                    stepPercent: 20,
                    onEdit: onEdit,
                    onAdd: onAdd,
                    onDragStateChange: onDragStateChange
                )
                .scaleEffect(innerWheelScale)

                // Внешний пояс: та же геометрия `TriangleBandShape`, обводка как у внешнего кольца Radar (без отдельных дуг/радиалов).
                let sectorCount = max(limited.count, 1)
                let sectorAngle = Angle.degrees(360.0 / Double(sectorCount))

                ForEach(Array(limited.enumerated()), id: \.element.id) { index, sphere in
                    let start = sectorAngle * Double(index) - .degrees(90)
                    let end = start + sectorAngle
                    let color = Color(hex: sphere.colorHex)

                    TriangleBandShape(
                        startAngle: start,
                        endAngle: end,
                        innerRadius: innerWheelRadius,
                        outerRadius: totalRadius
                    )
                    .fill(color.opacity(0.18))
                    .overlay(
                        TriangleBandShape(
                            startAngle: start,
                            endAngle: end,
                            innerRadius: innerWheelRadius,
                            outerRadius: totalRadius
                        )
                        .stroke(
                            color.opacity(0.45),
                            style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
                        )
                    )
                    .allowsHitTesting(false)
                }

                ForEach(Array(limited.enumerated()), id: \.element.id) { index, sphere in
                    let start = sectorAngle * Double(index) - .degrees(90)
                    let end = start + sectorAngle
                    let color = Color(hex: sphere.colorHex)
                    TriangleBandChordTitle(
                        title: sphere.title,
                        iconName: sphere.iconName,
                        center: center,
                        startAngle: start,
                        endAngle: end,
                        innerRadius: innerWheelRadius,
                        outerRadius: totalRadius,
                        textColor: color,
                        iconColor: color,
                        isLabelSelected: selectedSphere?.id == sphere.id,
                        onRequestActions: { onRequestActions(sphere) }
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct TriangleBandChordTitle: View {
    let title: String
    let iconName: String
    let center: CGPoint
    let startAngle: Angle
    let endAngle: Angle
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let textColor: Color
    let iconColor: Color
    /// Как вершины Radar: `DualRingSphereIcon` + крупнее подпись.
    let isLabelSelected: Bool
    let onRequestActions: () -> Void

    var body: some View {
        // Place label in the geometric center of the outer band sector,
        // and rotate strictly along the outer base chord (sector foundation).
        let a1 = startAngle.radians
        let a2 = endAngle.radians
        let o1 = CGPoint(x: center.x + outerRadius * CGFloat(cos(a1)), y: center.y + outerRadius * CGFloat(sin(a1)))
        let o2 = CGPoint(x: center.x + outerRadius * CGFloat(cos(a2)), y: center.y + outerRadius * CGFloat(sin(a2)))
        let i2 = CGPoint(x: center.x + innerRadius * CGFloat(cos(a2)), y: center.y + innerRadius * CGFloat(sin(a2)))
        let i1 = CGPoint(x: center.x + innerRadius * CGFloat(cos(a1)), y: center.y + innerRadius * CGFloat(sin(a1)))
        let pos = CGPoint(
            x: (o1.x + o2.x + i2.x + i1.x) / 4.0,
            y: (o1.y + o2.y + i2.y + i1.y) / 4.0
        )

        let edge = CGVector(dx: o2.x - o1.x, dy: o2.y - o1.y)
        let edgeLen = max(1.0, sqrt(edge.dx * edge.dx + edge.dy * edge.dy))
        let chordLen = max(28, edgeLen)
        let chordAngle = Angle(radians: atan2(Double(edge.dy), Double(edge.dx)))
        // Keep readable: rotate 180° only when text would be upside down.
        let deg = (chordAngle.degrees.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        let flip = deg > 90 && deg < 270
        let rotation = chordAngle + (flip ? .degrees(180) : .degrees(0))

        let iconSize: CGFloat = isLabelSelected ? 23 : 22
        let textMaxWidth = max(48, chordLen - (iconSize + 8) - 10)

        return HStack(alignment: .center, spacing: 6) {
            DualRingSphereIcon(
                iconName: iconName,
                color: iconColor,
                size: iconSize,
                isSelected: isLabelSelected
            )
            .fixedSize()
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: min(textMaxWidth, 200))
        }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.4) {
                onRequestActions()
            }
            .fixedSize(horizontal: true, vertical: false)
            // Important: rotate first, then place. Otherwise the placement transform is also rotated,
            // which makes some labels drift/stack along axes.
            .rotationEffect(rotation)
            .position(x: pos.x, y: pos.y)
    }
}

// MARK: - Triangle inner view

private struct TriangleSliceShape: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var outerRadius: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let a1 = startAngle.radians
        let a2 = endAngle.radians
        let p1 = CGPoint(x: center.x + outerRadius * cos(a1), y: center.y + outerRadius * sin(a1))
        let p2 = CGPoint(x: center.x + outerRadius * cos(a2), y: center.y + outerRadius * sin(a2))
        p.move(to: center)
        p.addLine(to: p1)
        p.addLine(to: p2)
        p.closeSubpath()
        return p
    }
}

private struct TriangleBandShape: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var innerRadius: Double
    var outerRadius: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let a1 = startAngle.radians
        let a2 = endAngle.radians

        let o1 = CGPoint(x: center.x + outerRadius * cos(a1), y: center.y + outerRadius * sin(a1))
        let o2 = CGPoint(x: center.x + outerRadius * cos(a2), y: center.y + outerRadius * sin(a2))
        let i2 = CGPoint(x: center.x + innerRadius * cos(a2), y: center.y + innerRadius * sin(a2))
        let i1 = CGPoint(x: center.x + innerRadius * cos(a1), y: center.y + innerRadius * sin(a1))

        p.move(to: o1)
        p.addLine(to: o2)
        p.addLine(to: i2)
        p.addLine(to: i1)
        p.closeSubpath()
        return p
    }
}

private struct VisionTriangleView: View {
    let spheres: [Sphere]
    let goals: [Goal]
    @Binding var selectedSphere: Sphere?
    @Binding var isGenerating: Bool
    let stepPercent: Double
    let onEdit: (Sphere) -> Void
    let onAdd: () -> Void
    let onDragStateChange: (Bool) -> Void

    @Query private var memoItems: [MemoItem]
    @Environment(\.modelContext) private var modelContext
    private let hapticManager = HapticSoundManager.shared

    // Bigger to almost reach the container edges (VisionsView still adds horizontal padding).
    private let maxOuterRadiusRatio: CGFloat = 0.495

    @State private var draggingSphereID: UUID?
    @State private var dragInitialValue: Double = 0
    @State private var dragPreviewValue: Double?
    @State private var dragIsAligned: Bool = true
    @State private var lastHapticValue: Double = -1
    @State private var showConfirmationDialog: Bool = false
    @State private var pendingNewValue: Double = 0
    @State private var pendingSphere: Sphere?
    @State private var isConfirmedByButton: Bool = false

    var body: some View {
        GeometryReader { geometry in
            let minDim = min(geometry.size.width, geometry.size.height)
            let outerRadius = minDim * maxOuterRadiusRatio
            let limited = Array(spheres.prefix(12))
            let sectorAngle = Angle.degrees(360.0 / Double(max(limited.count, 1)))
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            // sector mid-angle (axis) for drag alignment
            let sphereAngles: [UUID: Angle] = Dictionary(uniqueKeysWithValues: limited.enumerated().map { idx, s in
                (s.id, sectorAngle * (Double(idx) + 0.5) - .degrees(90))
            })

            ZStack {
                ForEach(Array(limited.enumerated()), id: \.element.id) { index, sphere in
                    let start = sectorAngle * Double(index)
                    let end = start + sectorAngle
                    let axis = sphereAngles[sphere.id] ?? (start + end) / 2 - .degrees(90)
                    let startAdjusted = start - .degrees(90)
                    let endAdjusted = end - .degrees(90)

                    let raw = (draggingSphereID == sphere.id && dragPreviewValue != nil) ? dragPreviewValue! : sphere.satisfaction
                    let visual = visualFillPercentage(raw)
                    let projectedRaw = max(0.0, min(100.0, raw + totalPositiveImpact(for: sphere)))
                    let visualProjected = visualFillPercentage(projectedRaw)

                    TriangleSectorView(
                        sphere: sphere,
                        startAngle: startAdjusted,
                        endAngle: endAdjusted,
                        center: center,
                        outerRadius: outerRadius,
                        stepPercent: stepPercent,
                        visual: visual,
                        visualProjected: visualProjected,
                        isSelected: sphere.id == selectedSphere?.id,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedSphere = sphere
                            }
                        },
                        onDoubleTap: { onEdit(sphere) },
                        onLongPress: { beginDrag(for: sphere) },
                        onDragChanged: { value in
                            if draggingSphereID == nil { beginDrag(for: sphere) }
                            guard draggingSphereID == sphere.id else { return }
                            updateDrag(for: sphere, location: value.location, center: center, axis: axis, maxRadius: outerRadius)
                        },
                        onDragEnded: { value in
                            guard draggingSphereID == sphere.id else { return }
                            finalizeDrag(for: sphere, location: value.location, center: center, axis: axis, maxRadius: outerRadius)
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay {
            if showConfirmationDialog {
                FrostedConfirmationDialog(
                    title: "Satisfaction Changed",
                    message: "Satisfaction changed from \(String(format: "%.1f", dragInitialValue))% to \(String(format: "%.1f", pendingNewValue))%",
                    primaryTitle: "Keep Change",
                    primaryTint: nil,
                    onPrimary: { keepSatisfactionChange() },
                    onTapOutside: { cancelSatisfactionChange() }
                )
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showConfirmationDialog)
            }
        }
        .onChange(of: showConfirmationDialog) { oldValue, newValue in
            // If dialog closed without confirming via button, revert change.
            if oldValue == true && newValue == false && !isConfirmedByButton && pendingSphere != nil {
                if let sphere = pendingSphere {
                    withAnimation(.spring(response: 1.2, dampingFraction: 0.8)) {
                        sphere.satisfaction = dragInitialValue
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        try? modelContext.save()
                        hapticManager.selectionChanged()
                    }
                }
                pendingSphere = nil
            }
            if newValue == false {
                isConfirmedByButton = false
            }
        }
    }

    private func visualFillPercentage(_ satisfaction: Double) -> Double {
        let clamped = min(100.0, max(0.0, satisfaction))
        return floor(clamped / stepPercent) * stepPercent
    }

    private func totalPositiveImpact(for sphere: Sphere) -> Double {
        let relatedGoals = goals.filter { $0.sphereID == sphere.id && $0.status != .completed }
        let goalSum = relatedGoals.reduce(0.0) { $0 + max(0.0, $1.positiveImpact) }
        let memoSum: Double = memoItems.reduce(0.0) { partial, memo in
            guard let data = memo.contentData,
                  let content = try? JSONDecoder().decode(MemoCounterContent.self, from: data) else { return partial }
            var total = partial
            if content.sphereID == sphere.id { total += max(0.0, content.positiveImpact) }
            for imp in content.additionalImpacts where imp.sphereID == sphere.id {
                total += max(0.0, imp.positiveImpact)
            }
            return total
        }
        return goalSum + memoSum
    }

    private func beginDrag(for sphere: Sphere) {
        draggingSphereID = sphere.id
        dragInitialValue = sphere.satisfaction
        dragPreviewValue = sphere.satisfaction
        dragIsAligned = true
        lastHapticValue = sphere.satisfaction
        selectedSphere = sphere
        hapticManager.selectionChanged()
        onDragStateChange(true)
    }

    private func updateDrag(for sphere: Sphere, location: CGPoint, center: CGPoint, axis: Angle, maxRadius: CGFloat) {
        let result = dragResult(
            location: location,
            center: center,
            axis: axis,
            maxRadius: maxRadius,
            sectorAngle: Angle.degrees(360.0 / Double(max(Array(spheres.prefix(12)).count, 1)))
        )
        dragIsAligned = result.isAligned
        dragPreviewValue = result.value
        if result.isAligned, abs(result.value - lastHapticValue) >= stepPercent {
            hapticManager.selectionChanged()
            lastHapticValue = result.value
        }
    }

    private func finalizeDrag(for sphere: Sphere, location: CGPoint, center: CGPoint, axis: Angle, maxRadius: CGFloat) {
        let result = dragResult(
            location: location,
            center: center,
            axis: axis,
            maxRadius: maxRadius,
            sectorAngle: Angle.degrees(360.0 / Double(max(Array(spheres.prefix(12)).count, 1)))
        )
        if result.isAligned, abs(result.value - dragInitialValue) > 0.1 {
            // Apply immediately (like Circle), then allow user to revert via confirmation dialog.
            sphere.satisfaction = result.value
            try? modelContext.save()
            hapticManager.completionSuccess()

            pendingNewValue = result.value
            pendingSphere = sphere
            showConfirmationDialog = true
        } else {
            sphere.satisfaction = dragInitialValue
            hapticManager.selectionChanged()
        }
        draggingSphereID = nil
        dragPreviewValue = nil
        dragIsAligned = true
        onDragStateChange(false)
    }

    private func cancelSatisfactionChange() {
        guard let sphere = pendingSphere else { return }
        isConfirmedByButton = true
        withAnimation(.spring(response: 1.2, dampingFraction: 0.8)) {
            sphere.satisfaction = dragInitialValue
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            try? modelContext.save()
            hapticManager.selectionChanged()
        }
        pendingSphere = nil
        showConfirmationDialog = false
    }

    private func keepSatisfactionChange() {
        isConfirmedByButton = true
        pendingSphere = nil
        showConfirmationDialog = false
    }

    private func dragResult(
        location: CGPoint,
        center: CGPoint,
        axis: Angle,
        maxRadius: CGFloat,
        sectorAngle: Angle
    ) -> (value: Double, isAligned: Bool) {
        let dx = location.x - center.x
        let dy = location.y - center.y
        let axisX = cos(axis.radians)
        let axisY = sin(axis.radians)
        let projection = dx * axisX + dy * axisY
        let normalized = projection / maxRadius
        let clamped = min(max(normalized, 0), 1)
        let perpendicular = abs(dx * -axisY + dy * axisX)
        // For small sphere counts, sectors get wide (e.g. 4 -> 90°),
        // so the "must drag on the axis" rule becomes too strict and feels broken.
        // Allow more lateral deviation proportional to half the sector angle.
        let half = max(0.01, sectorAngle.radians / 2.0)
        let tolerance = maxRadius * CGFloat(sin(half)) * 0.85
        let isAligned = perpendicular <= tolerance
        let raw = Double(clamped * 100)
        let snapped = round(raw / stepPercent) * stepPercent
        return (min(100, max(0, snapped)), isAligned)
    }
}

private struct TriangleSectorView: View {
    let sphere: Sphere
    let startAngle: Angle
    let endAngle: Angle
    let center: CGPoint
    let outerRadius: CGFloat
    let stepPercent: Double
    let visual: Double
    let visualProjected: Double
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onLongPress: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: (DragGesture.Value) -> Void

    var body: some View {
        let color = Color(hex: sphere.colorHex)

        let dragGesture = DragGesture(minimumDistance: 5)
            .onChanged { v in onDragChanged(v) }
            .onEnded { v in onDragEnded(v) }

        ZStack {
            TriangleSliceShape(startAngle: startAngle, endAngle: endAngle, outerRadius: outerRadius)
                .fill(color.opacity(0.14))

            TriangleDashedChordsView(
                center: center,
                startAngle: startAngle,
                endAngle: endAngle,
                outerRadius: outerRadius,
                stepPercent: stepPercent
            )

            TriangleSliceShape(
                startAngle: startAngle,
                endAngle: endAngle,
                outerRadius: outerRadius * (visual / 100.0)
            )
            .fill(color.opacity(0.95))

            if visualProjected > visual {
                TriangleProjectedOverlayView(
                    startAngle: startAngle,
                    endAngle: endAngle,
                    outerRadius: outerRadius,
                    visual: visual,
                    visualProjected: visualProjected,
                    color: color
                )
            }

            if isSelected {
                TriangleSliceShape(
                    startAngle: startAngle,
                    endAngle: endAngle,
                    outerRadius: outerRadius * (max(visual, stepPercent) / 100.0)
                )
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 2)
            }

            Color.clear
                .contentShape(TriangleSliceShape(startAngle: startAngle, endAngle: endAngle, outerRadius: outerRadius))
                .onTapGesture { onTap() }
                .onTapGesture(count: 2) { onDoubleTap() }
                .onLongPressGesture(minimumDuration: 0.25) { onLongPress() }
                .simultaneousGesture(dragGesture)
        }
    }
}

private struct TriangleOuterBandTitle: View {
    let title: String
    let center: CGPoint
    let startAngle: Angle
    let endAngle: Angle
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let color: Color

    var body: some View {
        let a1 = startAngle.radians
        let a2 = endAngle.radians
        // Outer edge chord endpoints.
        let o1 = CGPoint(x: center.x + outerRadius * CGFloat(cos(a1)), y: center.y + outerRadius * CGFloat(sin(a1)))
        let o2 = CGPoint(x: center.x + outerRadius * CGFloat(cos(a2)), y: center.y + outerRadius * CGFloat(sin(a2)))
        let outerMid = CGPoint(x: (o1.x + o2.x) / 2.0, y: (o1.y + o2.y) / 2.0)
        let edge = CGVector(dx: o2.x - o1.x, dy: o2.y - o1.y)
        let chordLength = max(28, hypot(edge.dx, edge.dy))
        let chordAngle = Angle(radians: atan2(Double(edge.dy), Double(edge.dx)))

        // Robust 0...360 normalization for flip decision.
        let deg = (chordAngle.degrees.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        let flip = deg > 90 && deg < 270

        // Place at exact middle of band thickness: outer-mid + inward-normal * halfThickness.
        let eLen = max(1.0, sqrt(edge.dx * edge.dx + edge.dy * edge.dy))
        let baseN = CGVector(dx: -edge.dy / eLen, dy: edge.dx / eLen) // one of two normals
        let toCenter = CGVector(dx: center.x - outerMid.x, dy: center.y - outerMid.y)
        let dot = baseN.dx * toCenter.dx + baseN.dy * toCenter.dy
        let sign: CGFloat = dot < 0 ? -1 : 1
        let inward = CGVector(dx: baseN.dx * sign, dy: baseN.dy * sign)
        let halfThickness = max(1, (outerRadius - innerRadius) * 0.5)
        let pos = CGPoint(x: outerMid.x + inward.dx * halfThickness, y: outerMid.y + inward.dy * halfThickness)

        return Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(width: chordLength * 0.86)
            .clipped()
            .padding(.vertical, 2)
            .position(x: pos.x, y: pos.y)
            .rotationEffect(chordAngle + (flip ? .degrees(180) : .degrees(0)))
    }
}

private struct TriangleDashedChordsView: View {
    let center: CGPoint
    let startAngle: Angle
    let endAngle: Angle
    let outerRadius: CGFloat
    let stepPercent: Double

    var body: some View {
        let percentages: [Double] = stride(from: stepPercent, to: 100.0, by: stepPercent).map { $0 }
        return ForEach(percentages, id: \.self) { pct in
            TriangleChordLine(
                center: center,
                startAngle: startAngle,
                endAngle: endAngle,
                radius: outerRadius * (pct / 100.0)
            )
        }
    }
}

private struct TriangleChordLine: View {
    let center: CGPoint
    let startAngle: Angle
    let endAngle: Angle
    let radius: CGFloat

    var body: some View {
        let a1 = startAngle.radians
        let a2 = endAngle.radians
        let rawP1 = CGPoint(x: center.x + radius * CGFloat(cos(a1)), y: center.y + radius * CGFloat(sin(a1)))
        let rawP2 = CGPoint(x: center.x + radius * CGFloat(cos(a2)), y: center.y + radius * CGFloat(sin(a2)))

        // Match Circle dashed rings: leave a tiny gap near the sector boundaries.
        let v = CGVector(dx: rawP2.x - rawP1.x, dy: rawP2.y - rawP1.y)
        let len = max(1.0, sqrt(v.dx * v.dx + v.dy * v.dy))
        let ux = v.dx / len
        let uy = v.dy / len
        let inset = min(10.0, len * 0.08)
        let p1 = CGPoint(x: rawP1.x + ux * inset, y: rawP1.y + uy * inset)
        let p2 = CGPoint(x: rawP2.x - ux * inset, y: rawP2.y - uy * inset)
        return Path { p in
            p.move(to: p1)
            p.addLine(to: p2)
        }
        .stroke(
            Color.primary.opacity(0.42),
            style: StrokeStyle(
                lineWidth: 1.0,
                lineCap: .round,
                lineJoin: .round,
                dash: [1, 2]
            )
        )
    }
}

private struct TriangleProjectedOverlayView: View {
    let startAngle: Angle
    let endAngle: Angle
    let outerRadius: CGFloat
    let visual: Double
    let visualProjected: Double
    let color: Color

    var body: some View {
        ZStack {
            TriangleSliceShape(
                startAngle: startAngle,
                endAngle: endAngle,
                outerRadius: outerRadius * (visualProjected / 100.0)
            )
            .fill(color.opacity(0.25))
            TriangleSliceShape(
                startAngle: startAngle,
                endAngle: endAngle,
                outerRadius: outerRadius * (visual / 100.0)
            )
            .fill(color)
            .blendMode(.destinationOut)
        }
        .compositingGroup()
    }
}

