import SwiftUI // edited
import SwiftData

// Presentation · Vision — радарная диаграмма по сферам; тяжёлые запросы — `@Query` здесь для контекста AI/подписей.
// Координатор вкладок: при необходимости переключить таб — `RootCoordinator`.

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
    
    @State private var showGrid: Bool = false
    @State private var draggingSphereID: UUID?
    @State private var dragInitialValue: Double = 0
    @State private var dragPreviewValue: Double?
    @State private var dragIsAligned: Bool = true
    @State private var lastHapticValue: Double = -1
    @State private var showConfirmationDialog = false
    @State private var pendingSphere: Sphere?
    @State private var pendingNewValue: Double = 0
    @State private var isConfirmedByButton = false
    
    private func displaySatisfaction(for sphere: Sphere) -> Double {
        if draggingSphereID == sphere.id, let preview = dragPreviewValue { return preview }
        if pendingSphere?.id == sphere.id { return pendingNewValue }
        return sphere.satisfaction
    }
    
    /// 0…1 along the radar axis (outer ring = 100%). Linear in satisfaction so drag, vertex, and % label match.
    private func displayValue(for sphere: Sphere) -> CGFloat {
        let sat = displaySatisfaction(for: sphere)
        return CGFloat(min(100, max(0, sat))) / 100.0
    }
    
    var body: some View {
        GeometryReader { geo in
            // Use the minimum size considering the padding for labels and other elements
            let availableWidth = geo.size.width
            let availableHeight = geo.size.height
            // Inset from min dimension — radar diameter as fraction of the shorter side.
            let baseSize = min(availableWidth, availableHeight)
            let size = baseSize * 0.85
            let centerYOffset: CGFloat = 6
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2 + centerYOffset)
            
            let limitedSpheres = Array(spheres.prefix(12)) // LIMIT SPHERES TO KEEP RADAR READABLE
            let count = max(1, limitedSpheres.count)
            let angleStep = 2 * .pi / CGFloat(count)
            let sphereAngles: [UUID: CGFloat] = Dictionary(uniqueKeysWithValues: limitedSpheres.enumerated().map { index, sphere in
                (sphere.id, CGFloat(index) * angleStep - .pi/2)
            })
            let values: [CGFloat] = limitedSpheres.map { displayValue(for: $0) }
            let points: [CGPoint] = limitedSpheres.enumerated().map { (i, s) in
                let r = size/2 * values[i]
                let a = CGFloat(i) * angleStep - .pi/2
                return CGPoint(x: center.x + cos(a)*r, y: center.y + sin(a)*r)
            }
            
            let projectedValues: [CGFloat] = limitedSpheres.map { s in // Projected values with potential growth (same linear axis as polygon)
                let currentNormalized = displayValue(for: s)
                let positiveImpact = CGFloat(totalPositiveImpact(for: s))
                let normalizedImpact = min(1.0 - currentNormalized, positiveImpact / 100.0)
                return min(1.0, currentNormalized + normalizedImpact)
            }
            let projectedPoints: [CGPoint] = limitedSpheres.enumerated().map { (i, s) in
                let r = size/2 * projectedValues[i]
                let a = CGFloat(i) * angleStep - .pi/2
                return CGPoint(x: center.x + cos(a)*r, y: center.y + sin(a)*r)
            }
            
            let borderColor = selectedSphere.map { Color(hex: $0.colorHex) } ?? (limitedSpheres.first.map { Color(hex: $0.colorHex) } ?? .accentColor)
            
            let gridInnerLevels: [CGFloat] = [0.25, 0.5, 0.75]
            let gridOuterLevels: [CGFloat] = [1.0]
            
            ZStack {
                RadarGrid(
                    gridLevels: gridInnerLevels,
                    count: count,
                    size: size,
                    center: center,
                    color: borderColor
                )
                    .opacity(showGrid ? 1 : 0)
                    .animation(.easeInOut(duration: 0.35), value: showGrid)
                
                if !limitedSpheres.isEmpty {
                    RadarProjectedPolygon( // Projected polygon (potential growth)
                        projectedPoints: projectedPoints,
                        sphereColors: limitedSpheres.map { Color(hex: $0.colorHex) },
                        center: center,
                        angleStep: angleStep,
                        outlineTint: borderColor,
                        singleFillColor: selectedSphere.map { Color(hex: $0.colorHex) }
                    )
                    .transition(.opacity.combined(with: .scale))
                }
                
                // MAIN POLYGON — multi-color when no selection; single selected sphere color when one is chosen
                Group {
                    if let selected = selectedSphere {
                        RadarPolygon(points: points, color: Color(hex: selected.colorHex))
                    } else {
                        RadarSegmentedPolygon(
                            center: center,
                            points: points,
                            sphereColors: limitedSpheres.map { Color(hex: $0.colorHex) },
                            angleStep: angleStep,
                            outlineColor: borderColor
                        )
                    }
                }
                .allowsHitTesting(false)
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
                    draggingSphereID: draggingSphereID,
                    size: size,
                    center: center,
                    angleStep: angleStep,
                    onSelect: { s in
                        hapticManager.selectionChanged()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selectedSphere = s }
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
                
                // Center tap target: single clears selection; double adds a sphere.
                // `ExclusiveGesture` keeps single tap from firing on double tap.
                Color.clear
                    .frame(width: min(size * 0.32, 120), height: min(size * 0.32, 120))
                    .contentShape(Circle())
                    .position(center)
                    .zIndex(120)
                    .gesture(
                        TapGesture(count: 2)
                            .exclusively(before: TapGesture(count: 1))
                            .onEnded { value in
                                switch value {
                                case .first:
                                    onAddSphere()
                                case .second:
                                    hapticManager.selectionChanged()
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        selectedSphere = nil
                                    }
                                }
                            }
                    )
                
                // Outer rim (100%) above axes so spoke tips are hidden at the frame; non-interactive.
                RadarGrid(
                    gridLevels: gridOuterLevels,
                    count: count,
                    size: size,
                    center: center,
                    color: borderColor,
                    rimOverlay: true
                )
                .opacity(showGrid ? 1 : 0)
                .animation(.easeInOut(duration: 0.35), value: showGrid)
                .allowsHitTesting(false)

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
                    onDelete: { deleteSphere($0) },
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
                
                let centerColor = borderColor
                DualRingSphereIcon(
                    iconName: nil,
                    color: centerColor,
                    size: 15,
                    isSelected: false,
                    forcePulse: true
                )
                .allowsHitTesting(false)
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
            if oldValue == true && newValue == false && !isConfirmedByButton && pendingSphere != nil {
                cancelSatisfactionChange()
            }
            if newValue == false { isConfirmedByButton = false }
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
            if abs(result.value - lastHapticValue) >= 5 {
                hapticManager.selectionChanged()
                lastHapticValue = result.value
            }
        }
    }
    
    func finalizeDrag(for sphere: Sphere, location: CGPoint, center: CGPoint, angle: CGFloat, size: CGFloat) {
        guard draggingSphereID == sphere.id else { return }
        let result = dragResult(for: sphere, location: location, center: center, angle: angle, size: size)
        if result.isAligned && abs(result.value - dragInitialValue) > 0.1 {
            pendingNewValue = result.value
            pendingSphere = sphere
            dragPreviewValue = result.value
            hapticManager.completionSuccess()
            showConfirmationDialog = true
        } else {
            if result.isAligned {
                sphere.satisfaction = result.value
                try? modelContext.save()
                hapticManager.completionSuccess()
            } else {
                hapticManager.selectionChanged()
            }
        }
        draggingSphereID = nil
        dragPreviewValue = nil
        dragIsAligned = true
    }
    
    private func keepSatisfactionChange() {
        guard let sphere = pendingSphere else { return }
        isConfirmedByButton = true
        sphere.satisfaction = pendingNewValue
        try? modelContext.save()
        pendingSphere = nil
        showConfirmationDialog = false
        hapticManager.selectionChanged()
    }
    
    private func cancelSatisfactionChange() {
        guard let sphere = pendingSphere else { return }
        isConfirmedByButton = true
        withAnimation(.spring(response: 1.2, dampingFraction: 0.8)) {
            sphere.satisfaction = dragInitialValue
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            try? self.modelContext.save()
            self.hapticManager.selectionChanged()
        }
        pendingSphere = nil
        showConfirmationDialog = false
    }
    
    func dragResult(for _: Sphere, location: CGPoint, center: CGPoint, angle: CGFloat, size: CGFloat) -> (value: Double, isAligned: Bool) {
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
        let rawPercent = Double(clamped * 100.0)
        let snappedValue = (round(rawPercent * 2) / 2.0)
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
    
}

// RADAR GRIDS VIEW
private struct RadarGrid: View {
    let gridLevels: [CGFloat]
    let count: Int
    let size: CGFloat
    let center: CGPoint
    let color: Color
    /// When true (outer 100% ring drawn above axes), a wide background stroke masks spoke tips.
    var rimOverlay: Bool = false
    
    private func polygonPath(level: CGFloat) -> Path {
        let r = (size / 2) * level
        var p = Path()
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
        return p
    }
    
    var body: some View {
        ZStack(alignment: .center) {
            ForEach(gridLevels, id: \.self) { level in
                let isOuterRing = abs(level - 1.0) < 0.001
                let rimLineWidth: CGFloat = {
                    if rimOverlay && isOuterRing { return 3.25 } // half of 6.5 — top overlay ring
                    return isOuterRing ? 6.5 : 6
                }()
                // Внешний контур (100%) — явный оттенок выбранной сферы; внутренние уровни остаются лёгкими.
                let strokeOpacity = isOuterRing ? 0.48 : 0.1
                ZStack {
                    if rimOverlay && isOuterRing {
                        polygonPath(level: level)
                            .stroke(Color(UIColor.systemBackground), lineWidth: 7) // half of 14 — masks spoke tips
                    }
                    polygonPath(level: level)
                        .stroke(color.opacity(strokeOpacity), style: StrokeStyle(lineWidth: rimLineWidth, lineCap: .round, lineJoin: .round, dash: isOuterRing ? [] : [3, 2]))
                }
                .offset(x: center.x, y: center.y)
            }
        }
    }
}

// RADAR AXES VIEW
private struct RadarAxes: View {
    let spheres: [Sphere]
    let selectedSphere: Sphere?
    let draggingSphereID: UUID?
    let size: CGFloat
    let center: CGPoint
    let angleStep: CGFloat
    let onSelect: (Sphere) -> Void
    let onDragStart: (Sphere) -> Void
    let onDragChanged: (Sphere, CGPoint) -> Void
    let onDragEnd: (Sphere, CGPoint) -> Void
    
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
                let endPoint = CGPoint(x: center.x + cos(angle) * radius,
                                       y: center.y + sin(angle) * radius)
                
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
                    .strokedPath(.init(lineWidth: 12))
                )
                .onTapGesture {
                    onSelect(sphere)
                }
                .gesture(
                    DragGesture(minimumDistance: 8, coordinateSpace: .named("radarSpace"))
                        .onChanged { value in
                            if draggingSphereID != sphere.id {
                                onDragStart(sphere)
                            }
                            onDragChanged(sphere, value.location)
                        }
                        .onEnded { value in
                            onDragEnd(sphere, value.location)
                        }
                )
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

// MARK: - Single-color radar polygon (selected sphere)

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
        
        path
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

// MARK: - Segmented radar fill (half-sector per sphere color along bisectors)

private func crossZ(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    a.x * b.y - a.y * b.x
}

/// Intersection of ray from `center` at `angle` with segment `a`–`b`, for t ≥ 0 and u ∈ [0, 1].
private func rayFromCenterMeetsSegment(center: CGPoint, angle: CGFloat, a: CGPoint, b: CGPoint) -> CGPoint? {
    let dir = CGPoint(x: cos(angle), y: sin(angle))
    let v = CGPoint(x: b.x - a.x, y: b.y - a.y)
    let w = CGPoint(x: a.x - center.x, y: a.y - center.y)
    let det = crossZ(dir, v)
    if abs(det) < 1e-8 { return nil }
    let t = crossZ(w, v) / det
    let u = crossZ(dir, w) / det
    guard t >= 0, u >= 0, u <= 1 else { return nil }
    return CGPoint(x: center.x + t * dir.x, y: center.y + t * dir.y)
}

private func trianglePath(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Path {
    var p = Path()
    p.move(to: o)
    p.addLine(to: a)
    p.addLine(to: b)
    p.closeSubpath()
    return p
}

/// Wedge fill: each edge is split at the angle bisector — half tint from sphere `i`, half from `i+1`.
private struct RadarSegmentedPolygon: View {
    let center: CGPoint
    let points: [CGPoint]
    let sphereColors: [Color]
    let angleStep: CGFloat
    let outlineColor: Color
    /// Scales gradient opacities (main ≈ 1; projected layer ≈ 0.2–0.35).
    var fillOpacityScale: CGFloat = 1
    var drawsOutline: Bool = true
    var drawsGlowStroke: Bool = true
    
    var body: some View {
        let n = points.count
        if n < 2 || sphereColors.count != n {
            EmptyView()
        } else {
            let outerPath: Path = {
                var p = Path()
                guard let first = points.first else { return p }
                p.move(to: first)
                for pt in points.dropFirst() { p.addLine(to: pt) }
                p.closeSubpath()
                return p
            }()
            
            let wedges: [(Path, Color)] = (0..<n).flatMap { i -> [(Path, Color)] in
                let a = points[i]
                let b = points[(i + 1) % n]
                let angleMid = CGFloat(i) * angleStep - .pi / 2 + angleStep / 2
                let m = rayFromCenterMeetsSegment(center: center, angle: angleMid, a: a, b: b)
                    ?? CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                let cLeft = sphereColors[i]
                let cRight = sphereColors[(i + 1) % n]
                let p1 = trianglePath(center, a, m)
                let p2 = trianglePath(center, m, b)
                return [(p1, cLeft), (p2, cRight)]
            }
            
            ZStack {
                ForEach(0..<wedges.count, id: \.self) { idx in
                    let item = wedges[idx]
                    item.0.fill(
                        LinearGradient(
                            colors: [
                                item.1.opacity(0.08 * fillOpacityScale),
                                item.1.opacity(0.52 * fillOpacityScale),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                if drawsOutline {
                    outerPath
                        .stroke(outlineColor.opacity(0.6), lineWidth: 3)
                }
                if drawsGlowStroke {
                    outerPath
                        .stroke(outlineColor.opacity(0.45), lineWidth: 6)
                        .blur(radius: 8)
                        .opacity(0.65)
                }
            }
        }
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
    let projectedPoints: [CGPoint]
    let sphereColors: [Color]
    let center: CGPoint
    let angleStep: CGFloat
    let outlineTint: Color
    /// When non-nil, flat fill like legacy single-sphere radar; otherwise multi-color wedges.
    let singleFillColor: Color?
    
    var body: some View {
        ZStack {
            if let fill = singleFillColor {
                Path { p in
                    guard !projectedPoints.isEmpty else { return }
                    p.move(to: projectedPoints[0])
                    for pt in projectedPoints.dropFirst() { p.addLine(to: pt) }
                    p.closeSubpath()
                }
                .fill(fill.opacity(0.15))
            } else {
                RadarSegmentedPolygon(
                    center: center,
                    points: projectedPoints,
                    sphereColors: sphereColors,
                    angleStep: angleStep,
                    outlineColor: outlineTint,
                    fillOpacityScale: 0.28,
                    drawsOutline: false,
                    drawsGlowStroke: false
                )
            }
            Path { p in
                guard !projectedPoints.isEmpty else { return }
                p.move(to: projectedPoints[0])
                for pt in projectedPoints.dropFirst() { p.addLine(to: pt) }
                p.closeSubpath()
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 1]))
            .foregroundStyle(outlineTint.opacity(0.4))
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
    let onDelete: (Sphere) -> Void
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
                let baseIcon: CGFloat = isSelected ? 23.0 : 22.0
                let iconSize = isDragging ? baseIcon + 4 : baseIcon
                let sphereColor: Color = {
                    if isDragging && !dragIsValid { return .orange }
                    return Color(hex: sphere.colorHex)
                }()
                let showGoldGlow = values[i] >= 0.9 // 90% and above
                let goldGlow = Color(red: 0.96, green: 0.78, blue: 0.22)
                
                DualRingSphereIcon(
                    iconName: sphere.iconName,
                    color: sphereColor,
                    size: iconSize,
                    isSelected: isSelected || isDragging
                )
                .shadow(color: goldGlow.opacity(showGoldGlow ? 0.95 : 0), radius: showGoldGlow ? 5 : 0, x: 0, y: 0)
                .shadow(color: goldGlow.opacity(showGoldGlow ? 0.55 : 0), radius: showGoldGlow ? 12 : 0, x: 0, y: 0)
                .shadow(color: goldGlow.opacity(showGoldGlow ? 0.35 : 0), radius: showGoldGlow ? 20 : 0, x: 0, y: 0)
                .opacity((isSelected || highlighted) ? 1 : 0.75)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isDragging)
                .animation(.easeInOut(duration: 0.35), value: showGoldGlow)
                .position(point)
                .contextMenu {
                    Button("Edit") { onEdit(sphere) }
                    Button("Delete", role: .destructive) { onDelete(sphere) }
                }
                .onTapGesture { onSelect(sphere) }
                .onTapGesture(count: 2) { onEdit(sphere) }
                .gesture(
                    DragGesture(minimumDistance: 8, coordinateSpace: .named("radarSpace"))
                        .onChanged { value in
                            if draggingSphereID != sphere.id {
                                onDragStart(sphere)
                            }
                            onDragChanged(sphere, value.location)
                        }
                        .onEnded { value in
                            onDragEnd(sphere, value.location)
                        }
                )
                
                if isDragging, let preview = dragPreviewValue {
                    VisionDragPreviewCalloutBadge(
                        text: String(format: "%.1f%%", preview),
                        isAligned: dragIsValid
                    )
                    .position(x: point.x, y: point.y - iconSize * 0.55 - 18)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: selectedSphere?.id)
    }
}
