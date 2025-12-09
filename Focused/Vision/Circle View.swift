import SwiftUI
import SwiftData

// MARK: - PIE SLICE
struct PieSliceShape: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var innerRadius: Double
    var outerRadius: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        let adjustedStartAngle = startAngle
        let adjustedEndAngle = endAngle
        
        path.move(to: CGPoint(x: center.x + outerRadius * cos(adjustedStartAngle.radians),
                              y: center.y + outerRadius * sin(adjustedStartAngle.radians)))
        
        path.addArc(center: center, radius: outerRadius, startAngle: adjustedStartAngle, endAngle: adjustedEndAngle, clockwise: false)
        
        if innerRadius <= 0.0001 { // If inner radius is effectively zero, connect directly to the center without inner arc
            path.addLine(to: center)
            path.addLine(to: CGPoint(x: center.x + outerRadius * cos(adjustedStartAngle.radians),
                                     y: center.y + outerRadius * sin(adjustedStartAngle.radians)))
        } else {
            path.addLine(to: CGPoint(x: center.x + innerRadius * cos(adjustedEndAngle.radians),
                                     y: center.y + innerRadius * sin(adjustedEndAngle.radians)))
            path.addArc(center: center, radius: innerRadius, startAngle: adjustedEndAngle, endAngle: adjustedStartAngle, clockwise: true)
        }
        
        path.closeSubpath()
        return path
    }
}


// MARK: - VISION CIRCLE VIEW
struct VisionCircleView: View {
    let spheres: [Sphere]
    let goals: [Goal]
    @Binding var selectedSphere: Sphere?
    @Binding var isGenerating: Bool
    let showIcons: Bool
    let showDashedLines: Bool
    let showFiftyPercent: Bool
    let onEdit: (Sphere) -> Void
    let onAdd: () -> Void
    let onDragStateChange: (Bool) -> Void
    @Query private var memoItems: [MemoItem]
    @Environment(\.modelContext) private var modelContext
    private let hapticManager = HapticSoundManager.shared
    
    private let baseInnerRadiusRatio: CGFloat = 0.0
    private let maxOuterRadiusRatio: CGFloat = 0.45
    
    @State private var showGrid: Bool = false
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
        ZStack {
            GeometryReader { geometry in
                let availableSize = min(geometry.size.width, geometry.size.height)
                let minDimension = availableSize
                let innerRadius = minDimension * baseInnerRadiusRatio
                let maxRadialLength = minDimension * maxOuterRadiusRatio - innerRadius
                let limitedSpheres: [Sphere] = Array(spheres.prefix(12))
                let outerRadiusForBorder = innerRadius + maxRadialLength
                let sectorAngle = Angle.degrees(360.0 / Double(max(limitedSpheres.count, 1)))
                let centerColor = selectedSphere.map { Color(hex: $0.colorHex) }
                    ?? (limitedSpheres.first.map { Color(hex: $0.colorHex) } ?? .accentColor)
                
                let sphereAngles: [UUID: Angle] = Dictionary(uniqueKeysWithValues: limitedSpheres.enumerated().map { index, sphere in
                    (sphere.id, sectorAngle * (Double(index) + 0.5) - .degrees(90))
                })
                
                ForEach(Array(limitedSpheres.enumerated()), id: \.element.id) { index, sphere in
                    sectorView(
                        geometry: geometry,
                        sphere: sphere,
                        index: index,
                        sectorAngle: sectorAngle,
                        innerRadius: innerRadius,
                        maxRadialLength: maxRadialLength,
                        minDimension: minDimension,
                        sphereAngles: sphereAngles
                    )
                }
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedSphere?.id)
                
                // Grid rings every 10% with fade animation
                Group {
                    ForEach(1..<10) { step in
                        let pct = CGFloat(step) / 10.0
                        let radius = innerRadius + maxRadialLength * pct
                        let isFifty = step == 5
                        let isFiftyOrHundred = step % 5 == 0
                        let shouldShow: Bool = {
                            if isFifty {
                                return showFiftyPercent // 50% зависит от настройки
                            } else {
                                return showDashedLines // Остальные пунктирные линии (100% не в этом цикле)
                            }
                        }()
                        
                        Circle()
                            .stroke(
                                Color.accentColor.opacity(0.15),
                                style: StrokeStyle(
                                    lineWidth: isFiftyOrHundred ? 2.5 : 2,
                                    lineCap: .round,
                                    dash: isFiftyOrHundred ? [] : [2, 3] // DOTTED EXCEPT 50% & 100%
                                )
                            )
                            .frame(width: radius * 2, height: radius * 2)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                            .opacity(shouldShow ? 1 : 0)
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: showDashedLines)
                .animation(.easeInOut(duration: 0.35), value: showFiftyPercent)
                .animation(.easeInOut(duration: 0.35), value: showGrid)
                .zIndex(150) // BELOW ICONS
                
                // OUTER BORDER
                let glowInset: CGFloat = 6 // Увеличен для приближения к кругу 100%
                Circle()
                    .stroke(
                        centerColor.opacity(0.2),
                        lineWidth: 6
                    )
                    .frame(width: max(0, (outerRadiusForBorder * 2) - glowInset), height: max(0, (outerRadiusForBorder * 2) - glowInset))
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .overlay(
                        Circle()
                            .stroke(centerColor.opacity(0.65), lineWidth: 6)
                            .blur(radius: 6)
                            .opacity(0.65)
                    )
                    .zIndex(150) // BELOW ICONS
                
                ForEach(limitedSpheres) { sphere in
                    labelForSphere(
                        allSpheres: limitedSpheres,
                        sphere: sphere,
                        geometry: geometry,
                        sectorAngle: sectorAngle,
                        maxRadialLength: maxRadialLength,
                        innerRadius: innerRadius,
                        minDimension: minDimension,
                        center: CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2),
                        angles: sphereAngles,
                        dragPreviewValue: dragPreviewValue,
                        dragIsAligned: dragIsAligned
                    )
                }
                .zIndex(300)
                
                DualRingSphereIcon(
                    iconName: nil,
                    color: centerColor,
                    size: 20,
                    isSelected: false,
                    forcePulse: true
                )
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                .zIndex(400)
                .bold(true)
            }
        }
        .coordinateSpace(name: "circleSpace")
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: spheres)
        .onAppear {
            showGrid = false
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.35)) {
                    showGrid = true
                }
            }
        }
        .onDisappear {
            withAnimation(.easeInOut(duration: 0.25)) {
                showGrid = false
            }
        }
        .confirmationDialog(
            "Satisfaction Changed",
            isPresented: $showConfirmationDialog,
            titleVisibility: .visible,
            presenting: pendingSphere
        ) { sphere in
            Button("Keep Change") {
                keepSatisfactionChange()
            }
        } message: { sphere in
            Text("Satisfaction changed from \(String(format: "%.1f", dragInitialValue))% to \(String(format: "%.1f", pendingNewValue))%")
        }
        .onChange(of: showConfirmationDialog) { oldValue, newValue in
            // Если диалог закрылся без подтверждения через кнопки (тап вне диалога), отменяем изменение
            if oldValue == true && newValue == false && !isConfirmedByButton && pendingSphere != nil {
                // Восстанавливаем старое значение с плавной медленной анимацией
                if let sphere = pendingSphere {
                    withAnimation(.spring(response: 1.2, dampingFraction: 0.8)) {
                        sphere.satisfaction = dragInitialValue
                    }
                    // Сохраняем после небольшой задержки, чтобы анимация успела начаться
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        try? self.modelContext.save()
                        self.hapticManager.selectionChanged()
                    }
                }
                pendingSphere = nil
            }
            // Сбрасываем флаг после обработки
            if newValue == false {
                isConfirmedByButton = false
            }
        }
    }
    
    @ViewBuilder
    private func labelForSphere(
        allSpheres: [Sphere],
        sphere: Sphere,
        geometry: GeometryProxy,
        sectorAngle: Angle,
        maxRadialLength: CGFloat,
        innerRadius: CGFloat,
        minDimension: CGFloat,
        center: CGPoint,
        angles: [UUID: Angle],
        dragPreviewValue: Double?,
        dragIsAligned: Bool
    ) -> some View {
        if let index = allSpheres.firstIndex(where: { $0.id == sphere.id }) {
            let halfWayAngle = sectorAngle * (Double(index) + 0.5)
            let adjustedAngle = halfWayAngle - .degrees(90)
            let dragAngle = angles[sphere.id] ?? adjustedAngle

            let isSelected = sphere.id == selectedSphere?.id
            let lengthMultiplier: CGFloat = isSelected ? 1.03 : 1.0
            
            // Используем preview значение во время drag, иначе реальное значение
            let satisfactionValue = (draggingSphereID == sphere.id && dragPreviewValue != nil) ? dragPreviewValue! : sphere.satisfaction
            let currentOuter = innerRadius + (satisfactionValue / 100.0) * maxRadialLength
            let potentialIncrease = totalPositiveImpact(for: sphere)
            let projectedRaw = max(0.0, min(100.0, satisfactionValue + potentialIncrease))
            let hasProjection = projectedRaw >= 10.0 && projectedRaw > satisfactionValue + 0.1
            let projectedOuter = innerRadius + (projectedRaw / 100.0) * maxRadialLength
            let iconBaseRadius: CGFloat = {
                if hasProjection {
                    return projectedOuter
                }
                if isSelected {
                    let boosted = min(100.0, satisfactionValue + 5.0)
                    let boostedOuter = innerRadius + (boosted / 100.0) * maxRadialLength
                    return max(currentOuter, boostedOuter)
                }
                return currentOuter
            }()
            let outerRadius = min(iconBaseRadius * lengthMultiplier, minDimension / 2)

            ZStack {
                // Icon only: placed outside the outer edge
                // When projected growth exists, align with projected outer radius
                let iconSpacing: CGFloat = isSelected ? 23 : 22
                let maxRadius = minDimension / 2
                let edgeMargin: CGFloat = 10
                let iconRadius = min(outerRadius + iconSpacing, maxRadius - edgeMargin)
                let iconX = cos(adjustedAngle.radians) * iconRadius
                let iconY = sin(adjustedAngle.radians) * iconRadius
                let projectedRatio = projectedRaw / 100.0
                let isTinySector = projectedRatio < 0.15
                let baseSize: CGFloat = isSelected ? 36 : 32
                let iconSize: CGFloat = isTinySector ? baseSize * 0.5 : baseSize
                
                if showIcons || isSelected {
                    DualRingSphereIcon(
                        iconName: showIcons ? sphere.iconName : nil,
                        color: Color(hex: sphere.colorHex),
                        size: iconSize,
                        isSelected: isSelected,
                        forcePulse: false
                    )
                    .contentShape(Circle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSphere = sphere
                        }
                    }
                    .onTapGesture(count: 2) {
                        onEdit(sphere)
                    }
                    .onLongPressGesture(minimumDuration: 0.25) {
                        beginCircleDrag(for: sphere)
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 5, coordinateSpace: .named("circleSpace"))
                            .onChanged { value in
                                // Если drag еще не начат, автоматически начинаем drag
                                if draggingSphereID == nil {
                                    beginCircleDrag(for: sphere)
                                }
                                guard draggingSphereID == sphere.id else { return }
                                updateCircleDrag(for: sphere, location: value.location, center: center, angle: dragAngle, maxRadialLength: maxRadialLength)
                            }
                            .onEnded { value in
                                guard draggingSphereID == sphere.id else { return }
                                finalizeCircleDrag(for: sphere, location: value.location, center: center, angle: dragAngle, maxRadialLength: maxRadialLength)
                            }
                    )
                    .position(x: geometry.size.width / 2 + iconX, y: geometry.size.height / 2 + iconY)
                    .transition(.opacity)
                    .zIndex(400)
                }
                
                if draggingSphereID == sphere.id, let preview = dragPreviewValue {
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
                        .foregroundColor(dragIsAligned ? .primary : .orange)
                        .position(
                            x: geometry.size.width / 2 + iconX,
                            y: geometry.size.height / 2 + iconY - 26
                        )
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
}

private extension VisionCircleView {
    func totalPositiveImpact(for sphere: Sphere) -> Double {
        let relatedGoals = goals.filter { $0.sphereID == sphere.id && $0.status != .completed }
        let goalSum = relatedGoals.reduce(0.0) { $0 + max(0.0, $1.positiveImpact) }
        // Include Counter memo impacts (primary + additional)
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

    @ViewBuilder
    func sectorView(
        geometry: GeometryProxy,
        sphere: Sphere,
        index: Int,
        sectorAngle: Angle,
        innerRadius: CGFloat,
        maxRadialLength: CGFloat,
        minDimension: CGFloat,
        sphereAngles: [UUID: Angle]
    ) -> some View {
        let startAngle = sectorAngle * Double(index)
        let endAngle = startAngle + sectorAngle
        // Используем preview значение во время drag, иначе реальное значение
        let satisfaction = (draggingSphereID == sphere.id && dragPreviewValue != nil) ? dragPreviewValue! : sphere.satisfaction
        // Visual minimum of 10% for display only
        let visualSatisfaction = max(10.0, satisfaction)
        let currentLength = (visualSatisfaction / 100.0) * maxRadialLength
        let baseOuter = innerRadius + currentLength
        let isSelected = sphere.id == selectedSphere?.id
        let lengthMultiplier: CGFloat = isSelected ? 1.03 : 1.0
        let outerRadius = min(baseOuter * lengthMultiplier, minDimension / 2)
        let widthExpansion = Angle(degrees: sectorAngle.degrees * 0.035)
        let adjustedStart = isSelected ? (startAngle - widthExpansion) : startAngle
        let adjustedEnd = isSelected ? (endAngle + widthExpansion) : endAngle
        let sectorColor = Color(hex: sphere.colorHex)
        let viewCenter = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        let dragAngle = sphereAngles[sphere.id] ?? (startAngle + endAngle) / 2 - .degrees(90)

        // Base slice view
        let baseSlice = PieSliceShape(startAngle: adjustedStart, endAngle: adjustedEnd, innerRadius: innerRadius, outerRadius: outerRadius)
            .fill(sectorColor)
            .overlay(
                PieSliceShape(startAngle: adjustedStart, endAngle: adjustedEnd, innerRadius: innerRadius, outerRadius: outerRadius)
                    .stroke(isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.12), lineWidth: isSelected ? 2 : 0.6)
                    .shadow(color: isSelected ? Color.black.opacity(0.25) : Color.clear, radius: isSelected ? 6 : 0, x: 0, y: 2)
            )

        // Highlight view for selected sector
        let highlight: AnyView = {
            guard isSelected else { return AnyView(EmptyView()) }
            let band = PieSliceShape(startAngle: adjustedStart, endAngle: adjustedEnd, innerRadius: max(outerRadius - 3, innerRadius), outerRadius: outerRadius + 3)
                .fill(Color.white.opacity(0.18))
                .blur(radius: 1.0)
            return AnyView(band)
        }()

        // Potential overlay (projected growth)
        let potentialOverlay: AnyView = {
            let potentialIncrease = totalPositiveImpact(for: sphere)
            let projected = max(0.0, min(100.0, satisfaction + potentialIncrease))
            // Only show potential if total reaches at least 10%
            guard projected >= 10.0, projected > satisfaction + 0.1 else { return AnyView(EmptyView()) }
            let projectedLength = (projected / 100.0) * maxRadialLength
            let projectedOuter = innerRadius + projectedLength
            let band = PieSliceShape(startAngle: adjustedStart, endAngle: adjustedEnd, innerRadius: outerRadius, outerRadius: projectedOuter)
                .fill(sectorColor.opacity(0.25))
            let edge = PieSliceShape(startAngle: adjustedStart, endAngle: adjustedEnd, innerRadius: projectedOuter - 2, outerRadius: projectedOuter)
                .fill(sectorColor.opacity(0.0))
            return AnyView(ZStack { band; edge })
        }()

        SectorViewWithPulse(
            baseSlice: baseSlice,
            highlight: highlight,
            potentialOverlay: potentialOverlay,
            isSelected: isSelected,
            isGenerating: isGenerating,
            adjustedStart: adjustedStart,
            adjustedEnd: adjustedEnd,
            innerRadius: innerRadius,
            outerRadius: outerRadius,
            onTap: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedSphere = sphere
                }
            },
            onDoubleTap: {
                onEdit(sphere)
            },
            onLongPress: {
                beginCircleDrag(for: sphere)
            },
            onDragChanged: { value in
                // Если drag еще не начат, автоматически выбираем сферу и начинаем drag
                if draggingSphereID == nil {
                    beginCircleDrag(for: sphere)
                }
                guard draggingSphereID == sphere.id else { return }
                updateCircleDrag(for: sphere, location: value.location, center: viewCenter, angle: dragAngle, maxRadialLength: maxRadialLength)
            },
            onDragEnded: { value in
                guard draggingSphereID == sphere.id else { return }
                finalizeCircleDrag(for: sphere, location: value.location, center: viewCenter, angle: dragAngle, maxRadialLength: maxRadialLength)
            },
            contentShape: PieSliceShape(startAngle: adjustedStart, endAngle: adjustedEnd, innerRadius: innerRadius, outerRadius: outerRadius + 12)
        )
        .zIndex(isSelected ? 100 : 0)
    }
    
    func beginCircleDrag(for sphere: Sphere) {
        draggingSphereID = sphere.id
        dragInitialValue = sphere.satisfaction
        dragPreviewValue = sphere.satisfaction
        dragIsAligned = true
        lastHapticValue = sphere.satisfaction
        selectedSphere = sphere
        hapticManager.selectionChanged()
        onDragStateChange(true)
    }
    
    func updateCircleDrag(for sphere: Sphere, location: CGPoint, center: CGPoint, angle: Angle, maxRadialLength: CGFloat) {
        guard draggingSphereID == sphere.id else { return }
        let result = circleDragResult(for: sphere, location: location, center: center, angle: angle, maxRadialLength: maxRadialLength)
        dragIsAligned = result.isAligned
        dragPreviewValue = result.value
        
        if result.isAligned {
            // Только показываем preview, не применяем изменения
            if abs(result.value - lastHapticValue) >= 5 {
                hapticManager.selectionChanged()
                lastHapticValue = result.value
            }
        }
    }
    
    func finalizeCircleDrag(for sphere: Sphere, location: CGPoint, center: CGPoint, angle: Angle, maxRadialLength: CGFloat) {
        guard draggingSphereID == sphere.id else { return }
        let result = circleDragResult(for: sphere, location: location, center: center, angle: angle, maxRadialLength: maxRadialLength)
        
        if result.isAligned && abs(result.value - dragInitialValue) > 0.1 {
            // Сразу применяем изменение
            sphere.satisfaction = result.value
            try? modelContext.save()
            hapticManager.completionSuccess()
            
            // Сохраняем информацию для возможной отмены
            pendingNewValue = result.value
            pendingSphere = sphere
            showConfirmationDialog = true
        } else {
            // Если значение не изменилось или не выровнено, восстанавливаем исходное
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
        // Отменяем изменение - возвращаем старое значение с плавной медленной анимацией
        isConfirmedByButton = true
        withAnimation(.spring(response: 1.2, dampingFraction: 0.8)) {
            sphere.satisfaction = dragInitialValue
        }
        // Сохраняем после небольшой задержки, чтобы анимация успела начаться
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            try? self.modelContext.save()
            self.hapticManager.selectionChanged()
        }
        pendingSphere = nil
        showConfirmationDialog = false
    }
    
    private func keepSatisfactionChange() {
        // Оставляем изменение как есть (уже применено)
        isConfirmedByButton = true
        pendingSphere = nil
        showConfirmationDialog = false
    }
    
    func circleDragResult(for sphere: Sphere, location: CGPoint, center: CGPoint, angle: Angle, maxRadialLength: CGFloat) -> (value: Double, isAligned: Bool) {
        let dx = location.x - center.x
        let dy = location.y - center.y
        let axisX = cos(angle.radians)
        let axisY = sin(angle.radians)
        let projection = dx * axisX + dy * axisY
        let normalized = projection / maxRadialLength
        let clamped = min(max(normalized, 0), 1)
        let perpendicular = abs(dx * -axisY + dy * axisX)
        let tolerance = maxRadialLength * 0.18
        let isAligned = perpendicular <= tolerance
        let snappedValue = (round(Double(clamped * 100) * 2) / 2.0)
        let finalValue = min(100, max(0, snappedValue))
        return (finalValue, isAligned)
    }
}

// MARK: - Sector View with Pulse Animation
private struct SectorViewWithPulse<Content: View, ShapeType: Shape>: View {
    let baseSlice: Content
    let highlight: AnyView
    let potentialOverlay: AnyView
    let isSelected: Bool
    let isGenerating: Bool
    let adjustedStart: Angle
    let adjustedEnd: Angle
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onLongPress: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: (DragGesture.Value) -> Void
    let contentShape: ShapeType
    
    @State private var pulse = false
    
    var body: some View {
        ZStack {
            baseSlice
                .opacity(isSelected ? 1 : 0.92)
                .shadow(color: Color.accentColor.opacity(0.08), radius: isSelected ? 4 : 2, x: 0, y: 2)
                .zIndex(isSelected ? 20 : 0)
                .scaleEffect((isGenerating && isSelected) ? 1.1 : (isSelected ? pulseScale : 1.0))
                .onTapGesture {
                    onTap()
                }
                .onTapGesture(count: 2) {
                    onDoubleTap()
                }

            highlight
                .scaleEffect(isSelected ? pulseScale : 1.0)
            
            potentialOverlay
                .scaleEffect(isSelected ? pulseScale : 1.0)

            // Topmost border to ensure selected edge stays visible over neighbors
            if isSelected {
                PieSliceShape(startAngle: adjustedStart, endAngle: adjustedEnd, innerRadius: innerRadius, outerRadius: outerRadius + 0.01)
                    .stroke(Color.accentColor.opacity(0.7), lineWidth: 1)
                    .scaleEffect(pulseScale)
                    .zIndex(30)
            }
        }
        .contentShape(contentShape)
        .onLongPressGesture(minimumDuration: 0.25) {
            onLongPress()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .named("circleSpace"))
                .onChanged { value in
                    onDragChanged(value)
                }
                .onEnded { value in
                    onDragEnded(value)
                }
        )
        .onAppear {
            updatePulse()
        }
        .onChange(of: isSelected) { _, _ in
            updatePulse()
        }
    }
    
    private var pulseScale: CGFloat {
        guard isSelected else { return 1.0 }
        // Уменьшенная амплитуда пульсации сектора: от 0.99 до 1.02
        return pulse ? 1.02 : 0.99
    }
    
    private func updatePulse() {
        guard isSelected else {
            pulse = false
            return
        }
        pulse = false
        // Синхронизировано с DualRingSphereIcon: .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}

// MARK: - Animated percent text
private struct AnimatedPercentText: View, Animatable {
    var value: Double
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }
    var body: some View {
        Text("\(Int(round(value)))%")
    }
}
