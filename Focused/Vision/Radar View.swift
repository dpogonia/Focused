import SwiftUI // edited
import SwiftData

// MARK: - RADAR STYLE
struct RadarStyleView: View {
    let spheres: [Sphere]
    @Binding var selectedSphere: Sphere?
    let onEdit: (Sphere) -> Void
    let onAddSphere: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    private let hapticManager = HapticSoundManager.shared
    
    @Query private var goals: [Goal]
    @Query private var tasks: [SuperTask]
    @Query private var habits: [Habit]
    @Query private var memoItems: [MemoItem]
    
    private let gridLevels: [CGFloat] = [0.25, 0.5, 0.75, 1.0]
    @State private var showGrid: Bool = false
    @State private var draggingSphereID: UUID?
    @State private var dragInitialValue: Double = 0
    @State private var dragPreviewValue: Double?
    @State private var dragIsAligned: Bool = true
    @State private var lastHapticValue: Double = -1
    @State private var menuSphere: Sphere?
    @State private var showSphereMenuDialog = false
    
    private func linkedItemsCount(for sphere: Sphere) -> Int {
        let g = goals.filter { $0.sphereID == sphere.id }.count
        let t = tasks.filter { $0.sphereID == sphere.id }.count
        let h = habits.filter { $0.sphereID == sphere.id }.count
        return g + t + h
    }
//
    private func normalizationWeight(for sphere: Sphere) -> CGFloat {
        min(2.0, 1.0 + 0.05 * CGFloat(linkedItemsCount(for: sphere)))
    }
    
    private func value(for sphere: Sphere) -> CGFloat {
        let base = CGFloat(max(0, min(100, sphere.satisfaction))) / 100.0
        guard base < 1.0 else { return 1.0 }
        let weight = normalizationWeight(for: sphere)
        return min(1.0, base / weight)
    }
    
    private func satisfaction(from normalized: CGFloat, for sphere: Sphere) -> Double {
        let weight = normalizationWeight(for: sphere)
        let raw = min(1.0, max(0.0, normalized * weight))
        return Double(raw * 100.0)
    }
    
    var body: some View {
        GeometryReader { geo in
            // Use the minimum size considering the padding for labels and other elements
            let availableWidth = geo.size.width
            let availableHeight = geo.size.height
            // Reduce the size to leave space for labels and other elements outside the main radius
            let baseSize = min(availableWidth, availableHeight)
            let size = baseSize * 0.90 // Reduce to ensure that labels are not clipped
            let center = CGPoint(x: geo.size.width/2, y: geo.size.height/2)
            
            let limitedSpheres = Array(spheres.prefix(12)) // LIMIT SPHERES TO KEEP RADAR READABLE
            let count = max(1, limitedSpheres.count)
            let angleStep = 2 * .pi / CGFloat(count)
            let sphereAngles: [UUID: CGFloat] = Dictionary(uniqueKeysWithValues: limitedSpheres.enumerated().map { index, sphere in
                (sphere.id, CGFloat(index) * angleStep - .pi/2)
            })
            let values: [CGFloat] = limitedSpheres.map { value(for: $0) }
            let points: [CGPoint] = limitedSpheres.enumerated().map { (i, s) in
                let r = size/2 * values[i]
                let a = CGFloat(i) * angleStep - .pi/2
                return CGPoint(x: center.x + cos(a)*r, y: center.y + sin(a)*r)
            }
            
            let projectedValues: [CGFloat] = limitedSpheres.map { s in // Projected values with potential growth
                let currentNormalized = value(for: s)
                let positiveImpact = CGFloat(totalPositiveImpact(for: s))
                let weight = min(2.0, 1.0 + 0.05 * CGFloat(linkedItemsCount(for: s)))
                let normalizedImpact = min(1.0 - currentNormalized, positiveImpact / 100.0 / weight) // Convert positiveImpact to normalized space (considering weight)
                return min(1.0, currentNormalized + normalizedImpact)
            }
            let projectedPoints: [CGPoint] = limitedSpheres.enumerated().map { (i, s) in
                let r = size/2 * projectedValues[i]
                let a = CGFloat(i) * angleStep - .pi/2
                return CGPoint(x: center.x + cos(a)*r, y: center.y + sin(a)*r)
            }
            
            let borderColor = selectedSphere.map { Color(hex: $0.colorHex) } ?? (limitedSpheres.first.map { Color(hex: $0.colorHex) } ?? .accentColor)
            
            ZStack {
                RadarGrid(
                    gridLevels: gridLevels,
                    count: count,
                    size: size,
                    center: center,
                    color: borderColor
                )
                    .opacity(showGrid ? 1 : 0)
                    .animation(.easeInOut(duration: 0.35), value: showGrid)
                
                if !limitedSpheres.isEmpty {
                    RadarProjectedPolygon( // Projected polygon (potential growth)
                        basePoints: points,
                        projectedPoints: projectedPoints,
                        color: (selectedSphere != nil ? Color(hex: (selectedSphere?.colorHex)!) : (limitedSpheres.first.map { Color(hex: $0.colorHex) } ?? .accentColor))
                    )
                    .transition(.opacity.combined(with: .scale))
                }
                
                // MAIN POLYGON
                RadarPolygon(points: points, color: (selectedSphere != nil ? Color(hex: (selectedSphere?.colorHex)!) : (limitedSpheres.first.map { Color(hex: $0.colorHex) } ?? .accentColor)))
                    .animation(.easeInOut(duration: 0.2), value: selectedSphere?.id)

                if let glowPath = polygonPath(points: iconPolygonPoints(size: size, center: center, spheres: limitedSpheres, angleStep: angleStep)) {
                    glowPath
                        .stroke(borderColor.opacity(0.05), lineWidth: 6)
                        .overlay(
                            glowPath
                                .stroke(borderColor.opacity(0.6), lineWidth: 10)
                                .blur(radius: 10)
                                .opacity(0.6)
                        )
                        .allowsHitTesting(false)
                        .zIndex(-5)
                }

                RadarAxes(
                    spheres: limitedSpheres,
                    selectedSphere: selectedSphere,
                    size: size,
                    center: center,
                    angleStep: angleStep,
                    onSelect: { s in
                        hapticManager.selectionChanged()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selectedSphere = s }
                    }
                )

                RadarVertices(
                    spheres: limitedSpheres,
                    values: values,
                    size: size,
                    center: center,
                    angleStep: angleStep,
                    selectedSphere: selectedSphere,
                    draggingSphereID: draggingSphereID,
                    dragPreviewValue: dragPreviewValue,
                    dragIsValid: dragIsAligned,
                    onSelect: { s in
                        hapticManager.selectionChanged()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selectedSphere = s }
                    },
                    onEdit: { s in
                        hapticManager.selectionChanged(); onEdit(s)
                    },
                    onDragStart: { beginDrag(for: $0) },
                    onDragChanged: { sphere, location in
                        guard let angle = sphereAngles[sphere.id] else { return }
                        updateDrag(for: sphere, location: location, center: center, angle: angle, size: size)
                    },
                    onDragEnd: { sphere, location in
                        guard let angle = sphereAngles[sphere.id] else { return }
                        finalizeDrag(for: sphere, location: location, center: center, angle: angle, size: size)
                    }
                )
                RadarLabels(
                    spheres: limitedSpheres,
                    size: size,
                    center: center,
                    angleStep: angleStep,
                    selectedSphere: selectedSphere,
                    draggingSphereID: draggingSphereID,
                    dragPreviewValue: dragPreviewValue,
                    dragIsValid: dragIsAligned,
                    onSelect: { s in
                        hapticManager.selectionChanged()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selectedSphere = s }
                    },
                    onEdit: { s in
                        hapticManager.selectionChanged(); onEdit(s)
                    },
                    onDelete: { sphere in
                        deleteSphere(sphere)
                    },
                    onDragStart: { beginDrag(for: $0) },
                    onDragChanged: { sphere, location in
                        guard let angle = sphereAngles[sphere.id] else { return }
                        updateDrag(for: sphere, location: location, center: center, angle: angle, size: size)
                    },
                    onDragEnd: { sphere, location in
                        guard let angle = sphereAngles[sphere.id] else { return }
                        finalizeDrag(for: sphere, location: location, center: center, angle: angle, size: size)
                    },
                    onShowMenu: { presentSphereMenu(for: $0) }
                )
                
                let centerColor = borderColor
                DualRingSphereIcon(
                    iconName: nil,
                    color: centerColor,
                    size: 20,
                    isSelected: false,
                    forcePulse: true
                )
                .onTapGesture(count: 2) {
                    onAddSphere()
                }
                .position(center)
                .zIndex(500)
            }
            .clipped()
            .coordinateSpace(name: "radarSpace")
            .onAppear {
                showGrid = false
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.35)) { showGrid = true }
                }
            }
            .onDisappear {
                withAnimation(.easeInOut(duration: 0.25)) { showGrid = false }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog("Sphere actions", isPresented: $showSphereMenuDialog, presenting: menuSphere) { sphere in
            Button("Edit") { onEdit(sphere) }
            Button("Delete", role: .destructive) { deleteSphere(sphere) }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// POSITIVE IMPACT CALCULATION
private extension RadarStyleView {
    func totalPositiveImpact(for sphere: Sphere) -> Double {
        let relatedGoals = goals.filter { $0.sphereID == sphere.id && $0.status != .completed }
        let goalSum = relatedGoals.reduce(0.0) { $0 + max(0.0, $1.positiveImpact) }
        let memoSum: Double = memoItems.reduce(0.0) { partial, memo in
            guard let data = memo.contentData,
                  let content = try? JSONDecoder().decode(MemoCounterContent.self, from: data) else { return partial }
            var total = partial
            if content.sphereID == sphere.id {
                total += max(0.0, content.positiveImpact)
            }
            for imp in content.additionalImpacts where imp.sphereID == sphere.id {
                total += max(0.0, imp.positiveImpact)
            }
            return total
        }
        return goalSum + memoSum
    }
    
    func beginDrag(for sphere: Sphere) {
        draggingSphereID = sphere.id
        dragInitialValue = sphere.satisfaction
        dragPreviewValue = sphere.satisfaction
        dragIsAligned = true
        lastHapticValue = sphere.satisfaction
        selectedSphere = sphere
        hapticManager.selectionChanged()
    }
    
    func updateDrag(for sphere: Sphere, location: CGPoint, center: CGPoint, angle: CGFloat, size: CGFloat) {
        guard draggingSphereID == sphere.id else { return }
        let result = dragResult(for: sphere, location: location, center: center, angle: angle, size: size)
        dragIsAligned = result.isAligned
        dragPreviewValue = result.value
        
        if result.isAligned {
            sphere.satisfaction = result.value
            if abs(result.value - lastHapticValue) >= 5 {
                hapticManager.selectionChanged()
                lastHapticValue = result.value
            }
        } else {
            sphere.satisfaction = dragInitialValue
        }
    }
    
    func finalizeDrag(for sphere: Sphere, location: CGPoint, center: CGPoint, angle: CGFloat, size: CGFloat) {
        guard draggingSphereID == sphere.id else { return }
        let result = dragResult(for: sphere, location: location, center: center, angle: angle, size: size)
        if result.isAligned {
            sphere.satisfaction = result.value
            dragPreviewValue = result.value
            try? modelContext.save()
            hapticManager.completionSuccess()
        } else {
            sphere.satisfaction = dragInitialValue
            hapticManager.selectionChanged()
        }
        draggingSphereID = nil
        dragPreviewValue = nil
        dragIsAligned = true
    }
    
    func dragResult(for sphere: Sphere, location: CGPoint, center: CGPoint, angle: CGFloat, size: CGFloat) -> (value: Double, isAligned: Bool) {
        let dx = location.x - center.x
        let dy = location.y - center.y
        let axisX = cos(angle)
        let axisY = sin(angle)
        let projection = dx * axisX + dy * axisY
        let normalized = projection / (size / 2)
        let clamped = min(max(normalized, 0), 1)
        let perpendicular = abs(dx * -axisY + dy * axisX)
        let tolerance = size * 0.12
        let isAligned = perpendicular <= tolerance
        let snappedValue = (round(satisfaction(from: clamped, for: sphere) * 2) / 2.0)
        let finalValue = min(100, max(0, snappedValue))
        return (finalValue, isAligned)
    }
    
    func deleteSphere(_ sphere: Sphere) {
        guard let index = spheres.firstIndex(where: { $0.id == sphere.id }) else { return }
        modelContext.delete(sphere)
        try? modelContext.save()
        hapticManager.itemDeleted()
        if selectedSphere?.id == sphere.id {
            DispatchQueue.main.async {
                selectedSphere = spheres.indices.contains(index - 1) ? spheres[max(0, index - 1)] : spheres.first
            }
        }
    }
    
    func presentSphereMenu(for sphere: Sphere) {
        menuSphere = sphere
        showSphereMenuDialog = true
    }
}

// RADAR GRIDS VIEW
private struct RadarGrid: View {
    let gridLevels: [CGFloat]
    let count: Int
    let size: CGFloat
    let center: CGPoint
    let color: Color
    var body: some View {
        ZStack(alignment: .center) {
            ForEach(gridLevels, id: \.self) { level in
                let r = (size / 2) * level
                Path { p in
                    let step = 2 * .pi / CGFloat(max(1, count))
                    let start = -CGFloat.pi / 2
                    p.move(to: CGPoint(x: cos(start) * r, y: sin(start) * r))
                    if count > 1 {
                        for i in 1..<count {
                            let a = start + CGFloat(i) * step
                            p.addLine(to: CGPoint(x: cos(a) * r, y: sin(a) * r))
                        }
                    }
                    p.closeSubpath()
                }
                // COLOR OF RADAR NET
                .stroke(color.opacity(0.1), style: StrokeStyle(lineWidth: level == 1.0 ? 6.5 : 6, dash: level == 1.0 ? [] : [3, 2]))
                .offset(x: center.x, y: center.y)
                
            }
        }
    }
}

// RADAR AXES VIEW
private struct RadarAxes: View {
    let spheres: [Sphere]
    let selectedSphere: Sphere?
    let size: CGFloat
    let center: CGPoint
    let angleStep: CGFloat
    let onSelect: (Sphere) -> Void
    @State private var glowPhase: CGFloat = 0
    
    private func matches(_ s: Sphere) -> Bool { return true }
    
    var body: some View {
        ZStack {
            ForEach(Array(spheres.enumerated()), id: \.element.id) { pair in
                let index = pair.offset
                let sphere = pair.element
                let angle = CGFloat(index) * angleStep - .pi/2
                let isSelected = (sphere.id == selectedSphere?.id)
                let isHighlighted = matches(sphere)
                let radius = size / 2
                let iconClearance: CGFloat = isSelected ? 18 : 16 // prevent axis from showing beneath icon
                let effectiveRadius = max(0, radius - iconClearance)
                let endPoint = CGPoint(x: center.x + cos(angle) * effectiveRadius,
                                       y: center.y + sin(angle) * effectiveRadius)
                
                let baseColor = Color(hex: sphere.colorHex)
                let iconOpacity: Double = 0.6
                let strokeColor: Color = {
                    if isSelected { return baseColor.opacity(0.75) }
                                        return baseColor.opacity(iconOpacity)
                }()
                let strokeWidth: CGFloat = isSelected ? 7 : (isHighlighted ? 5 : 3)
                
                AxisLine(start: center, end: endPoint, color: strokeColor, width: strokeWidth)
                    .contentShape(
                        Path { p in
                            p.move(to: center)
                            p.addLine(to: endPoint)
                        }
                        .strokedPath(.init(lineWidth: 5))
                    )
                    .onTapGesture {
                        onSelect(sphere)
                    }

            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedSphere?.id)
    }
}

// AXIS LINE VIEW
private struct AxisLine: View {
    let start: CGPoint
    let end: CGPoint
    let color: Color
    let width: CGFloat
    var body: some View {
        Path { p in
            p.move(to: start)
            p.addLine(to: end)
        }
        .stroke(color, lineWidth: width)
    }
}

// RADAR POLYGON VIEW
private struct RadarPolygon: View {
    let points: [CGPoint]
    let color: Color
    var body: some View {
        let path = Path { p in
            guard let first = points.first else { return }
            p.move(to: first)
            for pt in points.dropFirst() { p.addLine(to: pt) }
            p.closeSubpath()
        }
        
        return path
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.6), color.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(path.stroke(color.opacity(0.6), lineWidth: 3))
            .overlay(
                path
                    .stroke(color.opacity(0.45), lineWidth: 6)
                    .blur(radius: 8)
                    .opacity(0.65)
            )
    }
}

private func polygonPath(points: [CGPoint]) -> Path? {
    guard let first = points.first else { return nil }
    var path = Path()
    path.move(to: first)
    for pt in points.dropFirst() { path.addLine(to: pt) }
    path.closeSubpath()
    return path
}

private func iconPolygonPoints(size: CGFloat, center: CGPoint, spheres: [Sphere], angleStep: CGFloat) -> [CGPoint] {
    spheres.enumerated().map { (index, _) in
        let radius = size / 2
        let angle = CGFloat(index) * angleStep - .pi/2
        return CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }
}

// PROJECTED POTENTIAL POLYGON (very faint to show growth potential)
private struct RadarProjectedPolygon: View {
    let basePoints: [CGPoint]
    let projectedPoints: [CGPoint]
    let color: Color
    var body: some View {
        ZStack {
            Path { p in
                guard !projectedPoints.isEmpty else { return }
                p.move(to: projectedPoints[0])
                for pt in projectedPoints.dropFirst() { p.addLine(to: pt) }
                p.closeSubpath()
            }
            .fill(color.opacity(0.15)) // color of projected
            Path { p in
                guard !projectedPoints.isEmpty else { return }
                p.move(to: projectedPoints[0])
                for pt in projectedPoints.dropFirst() { p.addLine(to: pt) }
                p.closeSubpath()
            }
            // PROJECTED DASHED LINE
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 1]))
            .foregroundStyle(color.opacity(0.4))
        }
    }
}

// RADAR VERTICES VIEW
private struct RadarVertices: View {
    let spheres: [Sphere]
    let values: [CGFloat]
    let size: CGFloat
    let center: CGPoint
    let angleStep: CGFloat
    let selectedSphere: Sphere?
    let draggingSphereID: UUID?
    let dragPreviewValue: Double?
    let dragIsValid: Bool
    let onSelect: (Sphere) -> Void
    let onEdit: (Sphere) -> Void
    let onDragStart: (Sphere) -> Void
    let onDragChanged: (Sphere, CGPoint) -> Void
    let onDragEnd: (Sphere, CGPoint) -> Void
    
    private func matches(_ s: Sphere) -> Bool { return true }
    
    var body: some View {
        ZStack {
            ForEach(Array(spheres.enumerated()), id: \.element.id) { i, sphere in
                let r = size/2 * values[i]
                let angle = CGFloat(i) * angleStep - .pi/2
                let point = CGPoint(x: center.x + cos(angle)*r, y: center.y + sin(angle)*r)
                let isSelected = sphere.id == selectedSphere?.id
                let highlighted = matches(sphere)
                let isDragging = draggingSphereID == sphere.id
                let baseSize: CGFloat = isSelected ? 14 : 10
                let vertexSize = isDragging ? baseSize + 6 : baseSize
                let vertexColor: Color = {
                    if isDragging && !dragIsValid { return .orange }
                    return Color(hex: sphere.colorHex)
                }()
                
                Circle()
                    .fill(vertexColor)
                    .frame(width: vertexSize, height: vertexSize)
                    .position(point)
                    .opacity((isSelected || highlighted) ? 1 : 0.6)
                    .scaleEffect(isDragging ? 1.1 : 1.0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isDragging)
                    .onTapGesture { onSelect(sphere) }
                    .onTapGesture(count: 2) { onEdit(sphere) }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.25)
                            .onEnded { _ in onDragStart(sphere) }
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("radarSpace"))
                            .onChanged { value in
                                guard draggingSphereID == sphere.id else { return }
                                onDragChanged(sphere, value.location)
                            }
                            .onEnded { value in
                                onDragEnd(sphere, value.location)
                            }
                    )
                
                if isDragging, let preview = dragPreviewValue {
                    Text(String(format: "%.1f%%", preview))
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(UIColor.systemBackground))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
                        )
                        .foregroundColor(dragIsValid ? .primary : .orange)
                        .position(x: point.x, y: point.y - 24)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: selectedSphere?.id)
    }
}

// RADAR LABELS VIEW
private struct RadarLabels: View {
    let spheres: [Sphere]
    let size: CGFloat
    let center: CGPoint
    let angleStep: CGFloat
    let selectedSphere: Sphere?
    let draggingSphereID: UUID?
    let dragPreviewValue: Double?
    let dragIsValid: Bool
    let onSelect: (Sphere) -> Void
    let onEdit: (Sphere) -> Void
    let onDelete: (Sphere) -> Void
    let onDragStart: (Sphere) -> Void
    let onDragChanged: (Sphere, CGPoint) -> Void
    let onDragEnd: (Sphere, CGPoint) -> Void
    let onShowMenu: (Sphere) -> Void
    
    private func matches(_ s: Sphere) -> Bool { return true }
    
    var body: some View {
        ZStack {
            ForEach(Array(spheres.enumerated()), id: \.element.id) { i, s in
                let r = size/2 + 0
                let a = CGFloat(i) * angleStep - .pi/2
                let pt = CGPoint(x: center.x + cos(a)*r, y: center.y + sin(a)*r)
                let isSelected = s.id == selectedSphere?.id
                let highlighted = matches(s)
                DualRingSphereIcon(
                    iconName: s.iconName,
                    color: Color(hex: s.colorHex),
                    size: isSelected ? 34 : 30,
                    isSelected: isSelected
                )
                .onTapGesture { onSelect(s) }
                .onLongPressGesture(minimumDuration: 0.25) {
                    onDragStart(s)
                }
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        onShowMenu(s)
                    }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("radarSpace"))
                        .onChanged { value in
                            guard draggingSphereID == s.id else { return }
                            onDragChanged(s, value.location)
                        }
                        .onEnded { value in
                            onDragEnd(s, value.location)
                        }
                )
                .opacity((isSelected || highlighted) ? 1.0 : 0.75)
                .position(pt)
            }
        }
    }
}

