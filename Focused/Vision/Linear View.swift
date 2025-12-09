import SwiftUI // p
import SwiftData

// MARK: - LINEAR STYLE
enum LinearHeightMode: String, CaseIterable, Identifiable, Codable {
    case narrow
    case regular
    case wide
    
    var id: String { rawValue }
    
    var multiplier: CGFloat {
        switch self {
        case .narrow: return 1.0
        case .regular: return 1.5
        case .wide: return 2.0
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

struct SpheresLinearView: View {
    let spheres: [Sphere]
    @Binding var selectedSphere: Sphere?
    let onEdit: (Sphere) -> Void
    @Binding var sortDescending: Bool? // nil = по порядку добавления, true = по satisfaction убывание, false = по satisfaction возрастание
    @Binding var heightMode: LinearHeightMode
    let onDragStateChange: (Bool) -> Void
    var onDragPreviewChange: ((UUID?, Double?) -> Void) = { _, _ in }
    
    @Query private var goals: [Goal]
    @Query private var memoItems: [MemoItem]
    @Environment(\.modelContext) private var modelContext
    private let hapticManager = HapticSoundManager.shared
    
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
    @State private var rowFrames: [UUID: CGRect] = [:]
    
    private var filteredAndSorted: [Sphere] {
        // Сортировка всегда использует реальные значения satisfaction из модели
        // Preview значения используются только для визуального отображения, но не влияют на сортировку
        if let sortDescending = sortDescending {
            // Сортировка по satisfaction
            return spheres.sorted { sortDescending ? $0.satisfaction > $1.satisfaction : $0.satisfaction < $1.satisfaction }
        } else {
            // Сортировка по порядку добавления (orderIndex) - от самой ранней (сверху) до самой поздней (снизу)
            return spheres.sorted { $0.orderIndex < $1.orderIndex }
        }
    }
    
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
    
    var body: some View {
        VStack(spacing: 0) {
            if filteredAndSorted.isEmpty {
                Text("No spheres")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredAndSorted) { sphere in
                            linearRowView(sphere: sphere)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(name: "linearSpace")
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
            // Если диалог закрылся без подтверждения через кнопки (тап вне диалога), очищаем drag состояния
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
    private func linearRowView(sphere: Sphere) -> some View {
        ThermometerRow(
            sphere: sphere,
            isSelected: sphere.id == selectedSphere?.id,
            potentialIncrease: totalPositiveImpact(for: sphere),
            heightMode: heightMode,
            dragPreviewValue: (draggingSphereID == sphere.id) ? dragPreviewValue : nil,
            dragIsAligned: dragIsAligned
        )
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: LinearRowFramePreferenceKey.self, value: [sphere.id: geo.frame(in: .named("linearSpace"))])
            }
        )
        .onPreferenceChange(LinearRowFramePreferenceKey.self) { frames in
            rowFrames.merge(frames) { _, new in new }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            hapticManager.selectionChanged()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                selectedSphere = sphere
            }
        }
        .onLongPressGesture(minimumDuration: 0.25) {
            // Drag только для выбранной сферы
            if sphere.id == selectedSphere?.id {
                beginLinearDrag(for: sphere)
            }
        }
        .onTapGesture(count: 2) {
            hapticManager.selectionChanged()
            onEdit(sphere)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .named("linearSpace"))
                .onChanged { value in
                    // Drag только для выбранной сферы
                    guard sphere.id == selectedSphere?.id else { return }
                    // Если drag еще не начат, начинаем drag
                    if draggingSphereID == nil {
                        beginLinearDrag(for: sphere)
                    }
                    guard draggingSphereID == sphere.id else { return }
                    updateLinearDrag(for: sphere, location: value.location)
                }
                .onEnded { value in
                    guard draggingSphereID == sphere.id else { return }
                    finalizeLinearDrag(for: sphere, location: value.location)
                }
        )
        .contextMenu {
            Button("Select") {
                hapticManager.selectionChanged()
                selectedSphere = sphere
            }
            Button("Edit") {
                hapticManager.selectionChanged()
                onEdit(sphere)
            }
        }
    }
    
    func beginLinearDrag(for sphere: Sphere) {
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
    
    func updateLinearDrag(for sphere: Sphere, location: CGPoint) {
        guard draggingSphereID == sphere.id else { return }
        guard let rowFrame = rowFrames[sphere.id] else { return }
        
        let result = linearDragResult(for: sphere, location: location, rowFrame: rowFrame)
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
    
    func finalizeLinearDrag(for sphere: Sphere, location: CGPoint) {
        guard draggingSphereID == sphere.id else { return }
        guard let rowFrame = rowFrames[sphere.id] else {
            draggingSphereID = nil
            dragPreviewValue = nil
            dragIsAligned = true
            onDragStateChange(false)
            onDragPreviewChange(nil, nil)
            return
        }
        
        let result = linearDragResult(for: sphere, location: location, rowFrame: rowFrame)
        
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
    
    func linearDragResult(for sphere: Sphere, location: CGPoint, rowFrame: CGRect) -> (value: Double, isAligned: Bool) {
        // Вычисляем размеры бара
        let barHeight = 20 * heightMode.multiplier
        // Бар занимает всю ширину rowFrame (отступы уже учтены в rowFrame)
        let barWidth = rowFrame.width
        
        // Проверяем, находится ли точка в вертикальных границах бара
        // Бар находится в нижней части rowFrame, после заголовка и процента
        // Заголовок + процент занимают примерно 40-50 пикселей сверху
        let headerHeight: CGFloat = 50
        let barTop = rowFrame.minY + headerHeight
        let barBottom = barTop + barHeight
        
        // Проверяем вертикальное выравнивание
        // Используем tolerance аналогично Bars View (50% от размера)
        let verticalTolerance = barHeight * 0.5 // допуск 50% высоты бара
        let barCenterY = (barTop + barBottom) / 2
        let verticalDistance = abs(location.y - barCenterY)
        let isAligned = verticalDistance <= verticalTolerance
        
        // Вычисляем процент на основе горизонтальной позиции
        // location.x увеличивается вправо, поэтому используем напрямую
        let relativeX = location.x - rowFrame.minX
        guard barWidth > 0 else {
            return (sphere.satisfaction, false)
        }
        let normalized = relativeX / barWidth
        let clamped = min(max(normalized, 0), 1)
        let snappedValue = (round(Double(clamped * 100) * 2) / 2.0)
        let finalValue = min(100, max(0, snappedValue))
        
        return (finalValue, isAligned)
    }
}

// PreferenceKey for tracking row frames
private struct LinearRowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private struct ThermometerRow: View {
    let sphere: Sphere
    let isSelected: Bool
    let potentialIncrease: Double
    let heightMode: LinearHeightMode
    let dragPreviewValue: Double?
    let dragIsAligned: Bool
    
    private var color: Color { Color(hex: sphere.colorHex) }
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 8) {
                    DualRingSphereIcon(
                        iconName: sphere.iconName,
                        color: color,
                        size: 22,
                        isSelected: isSelected,
                        forcePulse: false
                    )
                    Text(sphere.title)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                Spacer()
                Text(String(format: "%.0f%%", dragPreviewValue ?? sphere.satisfaction))
                    .font(.subheadline).bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.12))
                    .overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 1))
                    .clipShape(Capsule())
                    .foregroundColor(dragPreviewValue != nil ? (dragIsAligned ? .primary : .orange) : .primary)
            }
            .foregroundColor(.primary)
            
            ZStack(alignment: .leading) {
                // grid 25/50/75
                GeometryReader { geo in
                    let fullWidth = geo.size.width
                    let thresholds: [CGFloat] = [0.25, 0.5, 0.75]
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(UIColor.secondarySystemBackground))
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        
                        ForEach(thresholds, id: \.self) { t in
                            Rectangle()
                                .fill(Color.gray.opacity(0.12))
                                .frame(width: 1)
                                .position(x: fullWidth * t, y: geo.size.height / 2)
                        }
                    }
                }
                .frame(height: 20 * heightMode.multiplier)
                
                GeometryReader { geo in
                    // Используем preview значение во время drag, иначе реальное значение
                    let satisfactionValue = dragPreviewValue ?? sphere.satisfaction
                    let currentRatio = max(0, min(1, satisfactionValue / 100.0))
                    let projectedRatio = max(currentRatio, min(1, (satisfactionValue + potentialIncrease) / 100.0))
                    let currentWidth = geo.size.width * currentRatio
                    let projectedWidth = geo.size.width * projectedRatio
                    let barHeight = 20 * heightMode.multiplier
                    let indicatorHeight = barHeight * 0.8
                    
                    if projectedWidth > currentWidth + 2 {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.22), color.opacity(0.08)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: projectedWidth, height: barHeight)
                            .overlay(alignment: .trailing) {
                                Rectangle()
                                    .fill(color.opacity(0.4))
                                    .frame(width: 2, height: indicatorHeight)
                                    .offset(x: -1, y: 0)
                            }
                    }
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.95), color.opacity(0.7)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(color.opacity(0.35), lineWidth: 1)
                        )
                        .frame(width: currentWidth, height: barHeight)
                        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: dragPreviewValue ?? sphere.satisfaction)
                }
            }
            .frame(height: 20 * heightMode.multiplier)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: isSelected ? 2 : 0)
            )
        }
    }
}
