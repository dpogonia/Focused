import SwiftUI
import SwiftData

// Presentation · Vision — стиль «столбики» для сравнения сфер (чистая визуализация).
// Удовлетворённость для подписей берётся снаружи (часто через `VisionsViewModel` → `SphereSatisfactionFacade` → `ImpactEngineProtocol`).

enum BarsWidthMode: String, CaseIterable, Identifiable, Codable {
    case narrow
    case regular
    case wide

    var id: String { rawValue }

    var multiplier: CGFloat {
        switch self {
        case .narrow: return 0.10
        case .regular: return 0.15
        case .wide: return 0.20
        }
    }

    var title: String {
        switch self {
        case .narrow: return "Narrow"
        case .regular: return "Regular"
        case .wide: return "Wide"
        }
    }
}

struct SphereBarCard: View {
    let sphere: Sphere
    let isSelected: Bool
    let potentialIncrease: Double
    let containerWidth: CGFloat
    let containerHeight: CGFloat
    let showLabelAbove: Bool
    let widthMode: BarsWidthMode
    let dragPreviewValue: Double?
    let dragIsAligned: Bool
    let onIconLongPress: (() -> Void)?
    
    @State private var pulse = false
    
    private var color: Color { Color(hex: sphere.colorHex) }
    
    private var barWidth: CGFloat {
        containerWidth * widthMode.multiplier
    }
    
    private var reservedVerticalSpace: CGFloat {
        var value: CGFloat = 6 /* spacing below bar */ + 22 /* icon */ + 6 /* spacing */ + 14 /* percentage label */ + 6 /* inner padding */
        if showLabelAbove {
            value += 6 /* spacing above */ + 18 /* label height */
        }
        return value
    }
    
    private var barHeight: CGFloat {
        max(100, containerHeight - reservedVerticalSpace + 4)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            let projectedPercent = max(0.0, min(100.0, sphere.satisfaction + potentialIncrease))
            if showLabelAbove {
                Text(sphere.title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                    .frame(width: barWidth + 6)
            }
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(UIColor.systemGray6), Color(UIColor.systemGray5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )
                    .frame(width: barWidth, height: barHeight)
                    .shadow(color: .black.opacity(isSelected ? 0.12 : 0.06), radius: isSelected ? 8 : 4, x: 0, y: 2)
                
                // Track grid — every 10% (10…90%); lines inset so they don’t touch bar edges
                let trackH = barHeight - 10
                let trackW = max(0, barWidth - 10)
                let gridLineInset: CGFloat = 6
                let gridLineW = max(0, trackW - gridLineInset * 2)
                let gridLineColor = Color.gray.opacity(0.26)
                ZStack(alignment: .bottom) {
                    ForEach(1..<10, id: \.self) { step in
                        Rectangle()
                            .fill(gridLineColor)
                            .frame(width: gridLineW, height: 1)
                            .offset(y: -trackH * CGFloat(step) / 10.0)
                    }
                }
                .frame(width: trackW, height: trackH)
                
                // FILL & PROJECTION
                // Используем preview значение во время drag, иначе реальное значение
                let satisfactionValue = dragPreviewValue ?? sphere.satisfaction
                let height = CGFloat(max(0, min(100, satisfactionValue))) / 100.0 * (barHeight - 12)
                let projectedHeight = CGFloat(projectedPercent) / 100.0 * (barHeight - 12)
                
                if projectedHeight > height + 1 {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.25), color.opacity(0.15)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: max(0, barWidth - 12), height: projectedHeight)
                        .padding(.bottom, 6)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(color.opacity(0.0))
                                .frame(width: max(0, barWidth - 20), height: 2)
                                .offset(y: -4)
                        }
                }
                
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.95), color.opacity(0.75)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(color.opacity(0.35), lineWidth: 1)
                    )
                    .frame(width: max(0, barWidth - 12), height: max(8, height))
                    .padding(.bottom, 6)
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: sphere.satisfaction)
                    .overlay(alignment: .topTrailing) {
                        // GLOSS HIGHLIGHT
                        LinearGradient(colors: [Color.white.opacity(0.18), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .frame(width: max(12, barWidth * 0.28))
                            .opacity(0.25)
                    }
            }
            .scaleEffect(x: isSelected ? (1.05 * pulseScale) : 1.0, y: 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSelected)
            .onAppear {
                updatePulse()
            }
            .onChange(of: isSelected) { _, _ in
                updatePulse()
            }
            
            DualRingSphereIcon(
                iconName: sphere.iconName,
                color: color,
                size: 22,
                isSelected: isSelected,
                forcePulse: false
            )
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: 0.4) {
                onIconLongPress?()
            }
            
            VisionTintedPercentCapsule(
                text: String(format: "%.0f%%", dragPreviewValue ?? sphere.satisfaction),
                tint: color,
                style: .barsFooter,
                foreground: dragPreviewValue != nil ? (dragIsAligned ? .primary : .orange) : .primary
            )
        }
        .frame(width: barWidth + 6, height: containerHeight, alignment: .bottom)
    }
    
    private var pulseScale: CGFloat {
        guard isSelected else { return 1.0 }
        // Синхронизировано с DualRingSphereIcon: внешнее кольцо пульсирует от 0.96 до 1.08
        return pulse ? 1.08 : 0.96
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

// MARK: - BARS STYLE VIEW
struct SpheresBarsView: View {
    let spheres: [Sphere]
    @Binding var selectedSphere: Sphere?
    let onEdit: (Sphere) -> Void
    let onRequestActions: (Sphere) -> Void
    let onAdd: () -> Void
    let sortDescending: Bool? // nil = по порядку добавления, true = по satisfaction убывание, false = по satisfaction возрастание
    let widthMode: BarsWidthMode
    let onDragStateChange: (Bool) -> Void
    var onDragPreviewChange: ((UUID?, Double?) -> Void) = { _, _ in }
    
    @State private var barCenters: [UUID: CGFloat] = [:]
    @Query private var goals: [Goal]
    @Query private var memoItems: [MemoItem]
    @Environment(\.modelContext) private var modelContext
    private let hapticManager = HapticSoundManager.shared
    
    // USER SETTINGS
    @AppStorage("bars.compact") private var isCompact: Bool = false
    
    // Drag states
    @State private var draggingSphereID: UUID?
    @State private var dragInitialValue: Double = 0
    @State private var dragPreviewValue: Double?
    @State private var dragIsAligned: Bool = true
    @State private var lastHapticValue: Double = -1
    @State private var showConfirmationDialog: Bool = false
    @State private var pendingNewValue: Double = 0
    @State private var pendingSphere: Sphere?
    @State private var isConfirmedByButton: Bool = false
    @State private var barFrames: [UUID: CGRect] = [:]
    @State private var contentWidth: CGFloat = 0
    
    private func totalPositiveImpact(for sphere: Sphere) -> Double {
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
    
    @State private var tooltipSphere: Sphere? = nil
    
    private var orderedSpheres: [Sphere] {
        // Сортировка всегда использует реальные значения satisfaction из модели
        // Preview значения используются только для визуального отображения, но не влияют на сортировку
        // Это предотвращает изменение позиции баров во время drag до подтверждения изменений
        if let sortDescending = sortDescending {
            // Сортировка по satisfaction
            return spheres.sorted { sortDescending ? $0.satisfaction > $1.satisfaction : $0.satisfaction < $1.satisfaction }
        } else {
            // Сортировка по порядку добавления (orderIndex) - от самой ранней (слева) до самой поздней (справа)
            return spheres.sorted { $0.orderIndex < $1.orderIndex }
        }
    }
    
    var body: some View {
        GeometryReader { outerGeo in
            ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 0) {
                        if contentWidth > 0 && contentWidth < outerGeo.size.width {
                            Spacer()
                                .frame(width: (outerGeo.size.width - contentWidth) / 2)
                        }
                        HStack(alignment: .bottom, spacing: isCompact ? 3 : 4) {
                            ForEach(orderedSpheres) { sphere in
                                barCardView(
                                    sphere: sphere,
                                    geometry: outerGeo
                                )
                            }
                        }
                        .background(
                            GeometryReader { contentGeo in
                                Color.clear
                                    .preference(key: ContentWidthPreferenceKey.self, value: contentGeo.size.width)
                            }
                        )
                        if contentWidth > 0 && contentWidth < outerGeo.size.width {
                            Spacer()
                                .frame(width: (outerGeo.size.width - contentWidth) / 2)
                        }
                    }
                    .onPreferenceChange(ContentWidthPreferenceKey.self) { width in
                        contentWidth = width
                    }
                }
            .padding(.bottom, 0)
                .onPreferenceChange(SphereBarCenterPreferenceKey.self) { centers in
                    barCenters = centers
                }
                .onAppear {
                    if let id = selectedSphere?.id {
                        DispatchQueue.main.async {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
                .onChange(of: selectedSphere?.id) { oldValue, newValue in
                    if let id = newValue {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
                .popover(item: $tooltipSphere) { sphere in
                    GoalsTooltipView(sphere: sphere)
                        .frame(width: 280)
                        .presentationDetents([.medium, .large])
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(name: "barsSpace")
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
            // Если диалог закрылся без подтверждения через кнопки (тап вне диалога), очищаем drag состояния
            // Изменение не было применено к модели, так что ничего восстанавливать не нужно
            if oldValue == true && newValue == false && !isConfirmedByButton && pendingSphere != nil {
                draggingSphereID = nil
                dragPreviewValue = nil
                dragIsAligned = true
                onDragStateChange(false)
                onDragPreviewChange(nil, nil)
                pendingSphere = nil
                hapticManager.selectionChanged()
            }
            // Сбрасываем флаг после обработки
            if newValue == false {
                isConfirmedByButton = false
            }
        }
    }
    
    @ViewBuilder
    private func barCardView(sphere: Sphere, geometry: GeometryProxy) -> some View {
        SphereBarCard(
            sphere: sphere,
            isSelected: sphere.id == selectedSphere?.id,
            potentialIncrease: totalPositiveImpact(for: sphere),
            containerWidth: geometry.size.width,
            containerHeight: geometry.size.height,
            showLabelAbove: false,
            widthMode: widthMode,
            dragPreviewValue: (draggingSphereID == sphere.id) ? dragPreviewValue : nil,
            dragIsAligned: dragIsAligned,
            onIconLongPress: { onRequestActions(sphere) }
        )
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: SphereBarCenterPreferenceKey.self, value: [sphere.id: geo.frame(in: .global).midX])
                    .preference(key: SphereBarFramePreferenceKey.self, value: [sphere.id: geo.frame(in: .named("barsSpace"))])
            }
        )
        .onPreferenceChange(SphereBarFramePreferenceKey.self) { frames in
            barFrames.merge(frames) { _, new in new }
        }
        .id(sphere.id)
        .onTapGesture {
            hapticManager.selectionChanged()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedSphere = sphere
            }
        }
        .onTapGesture(count: 2) {
            hapticManager.selectionChanged()
            onEdit(sphere)
        }
        .overlay(alignment: .bottom) {
            // Жест только в центре бара — края карточки свободны для горизонтального скролла
            let barW = geometry.size.width * widthMode.multiplier
            let barH = max(100, geometry.size.height - 50)
            Color.clear
                .frame(width: barW * 0.7, height: barH) // 70% ширины — по краям можно скроллить
                .contentShape(Rectangle())
                .onTapGesture {
                    hapticManager.selectionChanged()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedSphere = sphere
                    }
                }
                .onTapGesture(count: 2) {
                    hapticManager.selectionChanged()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedSphere = sphere
                    }
                    onEdit(sphere)
                }
                .simultaneousGesture(satisfactionDragGesture(for: sphere, geometry: geometry))
        }
    }
    
    private func satisfactionDragGesture(for sphere: Sphere, geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named("barsSpace"))
            .onChanged { [self] value in
                guard sphere.id == selectedSphere?.id else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                // Горизонтальный drag = скролл, не перехватываем
                if draggingSphereID == nil {
                    if abs(dx) >= abs(dy) { return }
                    beginBarsDrag(for: sphere)
                }
                guard draggingSphereID == sphere.id else { return }
                updateBarsDrag(for: sphere, location: value.location, geometry: geometry)
            }
            .onEnded { [self] value in
                guard draggingSphereID == sphere.id else { return }
                finalizeBarsDrag(for: sphere, location: value.location, geometry: geometry)
            }
    }

    func beginBarsDrag(for sphere: Sphere) {
        // Проверяем, что сфера выбрана
        guard sphere.id == selectedSphere?.id else { return }
        
        draggingSphereID = sphere.id
        dragInitialValue = sphere.satisfaction
        dragPreviewValue = sphere.satisfaction
        dragIsAligned = true
        lastHapticValue = sphere.satisfaction
        hapticManager.selectionChanged()
        onDragStateChange(true)
        onDragPreviewChange(sphere.id, dragPreviewValue)
    }
    
    func updateBarsDrag(for sphere: Sphere, location: CGPoint, geometry: GeometryProxy) {
        guard draggingSphereID == sphere.id else { return }
        guard let barFrame = barFrames[sphere.id] else { return }
        
        let result = barsDragResult(for: sphere, location: location, barFrame: barFrame, geometry: geometry)
        dragIsAligned = result.isAligned
        dragPreviewValue = result.value
        onDragPreviewChange(sphere.id, dragPreviewValue)
        
        if result.isAligned {
            // Только показываем preview, не применяем изменения
            if abs(result.value - lastHapticValue) >= 5 {
                hapticManager.selectionChanged()
                lastHapticValue = result.value
            }
        }
    }
    
    func finalizeBarsDrag(for sphere: Sphere, location: CGPoint, geometry: GeometryProxy) {
        guard draggingSphereID == sphere.id else { return }
        guard let barFrame = barFrames[sphere.id] else {
            draggingSphereID = nil
            dragPreviewValue = nil
            dragIsAligned = true
            onDragStateChange(false)
            return
        }
        
        let result = barsDragResult(for: sphere, location: location, barFrame: barFrame, geometry: geometry)
        
        if result.isAligned && abs(result.value - dragInitialValue) > 0.1 {
            // НЕ применяем изменение сразу - только сохраняем для подтверждения
            // Но оставляем dragPreviewValue установленным, чтобы бар визуально показывал новое значение
            pendingNewValue = result.value
            pendingSphere = sphere
            dragPreviewValue = result.value
            // Оставляем draggingSphereID установленным, чтобы preview значение использовалось для отображения
            hapticManager.completionSuccess()
            showConfirmationDialog = true
            onDragPreviewChange(sphere.id, dragPreviewValue)
        } else {
            // Если значение не изменилось или не выровнено, очищаем drag состояния
            draggingSphereID = nil
            dragPreviewValue = nil
            dragIsAligned = true
            onDragStateChange(false)
            onDragPreviewChange(nil, nil)
            hapticManager.selectionChanged()
        }
    }
    
    private func cancelSatisfactionChange() {
        //guard let sphere = pendingSphere else { return }
        // Отменяем изменение - очищаем drag состояния
        // Изменение не было применено к модели, так что ничего восстанавливать не нужно
        isConfirmedByButton = true
        draggingSphereID = nil
        dragPreviewValue = nil
        dragIsAligned = true
        onDragStateChange(false)
        onDragPreviewChange(nil, nil)
        pendingSphere = nil
        showConfirmationDialog = false
        hapticManager.selectionChanged()
    }
    
    private func keepSatisfactionChange() {
        // Применяем изменение только после подтверждения
        guard let sphere = pendingSphere else { return }
        isConfirmedByButton = true
        sphere.satisfaction = pendingNewValue
        try? modelContext.save()
        // Очищаем drag состояния после применения изменения
        draggingSphereID = nil
        dragPreviewValue = nil
        dragIsAligned = true
        onDragStateChange(false)
        onDragPreviewChange(nil, nil)
        pendingSphere = nil
        showConfirmationDialog = false
    }
    
    func barsDragResult(for sphere: Sphere, location: CGPoint, barFrame: CGRect, geometry: GeometryProxy) -> (value: Double, isAligned: Bool) {
        // Вычисляем высоту бара аналогично SphereBarCard
        //let reservedVerticalSpace: CGFloat = 6 + 22 + 6 + 18 + 6
        //let barHeight = max(100, geometry.size.height - reservedVerticalSpace)
        let barWidth = geometry.size.width * widthMode.multiplier
        
        // Вычисляем границы области бара внутри карточки
        // barFrame - это frame всей карточки в координатах barsSpace
        // Бар начинается после верхнего отступа (если есть showLabelAbove) и заканчивается перед нижними элементами
        let topOffset: CGFloat = 0 // нет showLabelAbove в текущей реализации
        let barTop = barFrame.minY + topOffset
        let barBottom = barFrame.maxY - (6 + 22 + 6 + 18 + 6) // отступ снизу для иконки и процента
        
        // Проверяем, находится ли точка в горизонтальных границах бара
        // Используем tolerance аналогично Circle View (18% от размера)
        let horizontalTolerance = barWidth * 0.5 // допуск 50% ширины бара
        let horizontalDistance = abs(location.x - barFrame.midX)
        let isAligned = horizontalDistance <= horizontalTolerance
        
        // Вычисляем процент на основе вертикальной позиции
        // location.y увеличивается вниз, поэтому инвертируем
        // Верх бара = 100%, низ бара = 0%
        let relativeY = location.y - barTop
        let barRange = barBottom - barTop
        guard barRange > 0 else {
            return (sphere.satisfaction, false)
        }
        let normalized = 1.0 - (relativeY / barRange)
        let clamped = min(max(normalized, 0), 1)
        let snappedValue = (round(Double(clamped * 100) * 2) / 2.0)
        let finalValue = min(100, max(0, snappedValue))
        
        return (finalValue, isAligned)
    }
}

// MARK: - LISTING GOALS
private struct GoalsTooltipView: View {
    let sphere: Sphere
    @Query private var goals: [Goal]
    @Environment(\.modelContext) private var modelContext
    
    init(sphere: Sphere) {
        self.sphere = sphere
        let sid: UUID? = sphere.id
        self._goals = Query(filter: #Predicate<Goal> { $0.sphereID == sid })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(sphere.title)
                    .font(.headline)
                Spacer()
                Text("\(Int(round(sphere.satisfaction)))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if goals.isEmpty {
                Text("No goals for the sphere")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(goals.sorted { $0.status < $1.status }) { goal in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: goal.colorHex ?? (AppConstants.Colors.palette.first ?? "#3498db")))
                            .frame(width: 8, height: 8)
                        Text(goal.title)
                            .font(.subheadline)
                            .lineLimit(2)
                        Spacer()
                        Button {
                            let oldStatus = goal.status
                            let newStatus: Goal.Status = (oldStatus == .completed) ? .pending : .completed
                            Goal.adjustSphereSatisfaction(goal: goal, oldStatus: oldStatus, newStatus: newStatus, modelContext: modelContext)
                            goal.updateStatus(to: newStatus)
                            try? modelContext.save()
                        } label: {
                            Image(systemName: goal.status == .completed ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(goal.status == .completed ? .green : .gray)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(12)
    }
}

// PreferenceKey for snapping to nearest bar center
private struct SphereBarCenterPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// PreferenceKey for tracking bar frames
private struct SphereBarFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// PreferenceKey for tracking content width in Bars View
private struct ContentWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}


