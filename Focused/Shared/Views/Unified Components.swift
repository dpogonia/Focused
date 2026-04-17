import SwiftUI
import SwiftData

// MARK: Переиспользуемые SwiftUI-компоненты
//
// Диалоги, стили карточек, вспомогательные модификаторы. Не добавляйте сюда доменные правила — только UI (**Presentation**).
// Оглавление: пульс иконки → frosted удаление → диалог удаления → слайдер impact → несколько сфер → выбор сферы → пустые состояния → пресеты пустоты → выбор иконки → полноэкранный picker.

// MARK: - Glass / frosted dialog typography (shared)
//
// Единые шрифты для всех модалок на `.ultraThinMaterial`, чтобы UI выглядел консистентно.
enum GlassDialogTypography {
    static let titleFont: Font = .headline
    static let messageFont: Font = .subheadline
    static let messageColor: Color = .secondary
}

extension View {
    func glassDialogTitleTextStyle() -> some View {
        self.font(GlassDialogTypography.titleFont)
    }
    
    func glassDialogMessageTextStyle() -> some View {
        self
            .font(GlassDialogTypography.messageFont)
            .foregroundColor(GlassDialogTypography.messageColor)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Reusable frosted confirmation dialog
struct FrostedConfirmationDialog: View {
    let title: String
    let message: String
    
    let primaryTitle: String
    let primaryTint: Color?
    let onPrimary: () -> Void
    
    let onTapOutside: () -> Void
    
    var width: CGFloat = 280
    var padding: CGFloat = 24
    var cornerRadius: CGFloat = 14
    
    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture { onTapOutside() }
            
            VStack(spacing: 16) {
                Text(title)
                    .glassDialogTitleTextStyle()
                    .foregroundColor(.secondary)
                
                Text(message)
                    .glassDialogMessageTextStyle()
                
                Button(primaryTitle) {
                    onPrimary()
                }
                .buttonStyle(.borderedProminent)
                .tint(primaryTint)
            }
            .padding(padding)
            .frame(width: width)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: Однократный пульс иконки при появлении
struct IconPulseOnAppearModifier: ViewModifier {
    @State private var pulse = false
    @State private var finished = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(finished ? 1.0 : (pulse ? 1.08 : 0.96))
            .onAppear {
                guard !finished else { return }
                withAnimation(.easeInOut(duration: 0.35)) { pulse = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        pulse = false
                        finished = true
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: pulse)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: finished)
    }
}

extension View {
    func iconPulseOnceOnAppear() -> some View {
        modifier(IconPulseOnAppearModifier())
    }
}

// MARK: Матовое подтверждение удаления (как у Vision)
struct FrostedDeleteConfirmationModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let onConfirm: () -> Void
    
    private let hapticManager = HapticSoundManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    ZStack {
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture {
                                hapticManager.selectionChanged()
                                isPresented = false
                            }
                        VStack(spacing: 16) {
                            Text(title)
                                .glassDialogTitleTextStyle()
                            Text(message)
                                .glassDialogMessageTextStyle()
                            Button("Delete") {
                                hapticManager.itemDeleted()
                                onConfirm()
                                isPresented = false
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                        .padding(24)
                        .frame(width: 280)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                        .transition(.scale.combined(with: .opacity))
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPresented)
                }
            }
    }
}

extension View {
    func frostedDeleteConfirmation(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(FrostedDeleteConfirmationModifier(isPresented: isPresented, title: title, message: message, onConfirm: onConfirm))
    }
}

// MARK: Универсальный диалог «Удалить?»
struct DeleteConfirmationButton: View {
    let itemName: String
    let onDelete: () -> Void
    
    @State private var showDeleteConfirmation: Bool = false
    private let hapticManager = HapticSoundManager.shared
    
    init(itemName: String, onDelete: @escaping () -> Void) {
        self.itemName = itemName
        self.onDelete = onDelete
    }
    
    var body: some View {
        Section {
            Button(role: .destructive) {
                hapticManager.playNotificationHaptic(type: .warning)
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("Delete \(itemName)")
                    Spacer()
                }
            }
            .confirmationDialog("Delete \(itemName)", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    hapticManager.itemDeleted()
                    onDelete()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this \(itemName.lowercased())? This action cannot be undone.")
            }
        }
    }
}

// MARK: Слайдер положительного/отрицательного impact
struct ImpactSliderView: View {
    @Binding var positiveImpact: Double
    @Binding var negativeImpact: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    let onApplyMissDecrease: ((Double) -> Void)?
    
    private let hapticManager = HapticSoundManager.shared
    @State private var showApplyConfirm: Bool = false
    
    init(
        positiveImpact: Binding<Double>,
        negativeImpact: Binding<Double>,
        range: ClosedRange<Double> = 0...100,
        step: Double = 0.5,
        unit: String = "%",
        onApplyMissDecrease: ((Double) -> Void)? = nil
    ) {
        self._positiveImpact = positiveImpact
        self._negativeImpact = negativeImpact
        self.range = range
        self.step = step
        self.unit = unit
        self.onApplyMissDecrease = onApplyMissDecrease
    }
    
    var body: some View {
        Section {
            VStack(spacing: 10) {
                HStack {
                    Text("Completion Increase")
                    Slider(value: $positiveImpact, in: range, step: step)
                    TextField("", value: $positiveImpact, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.center)
                        .onChange(of: positiveImpact) { oldValue, newValue in
                            positiveImpact = max(range.lowerBound, min(range.upperBound, newValue))
                        }
                    Text(unit)
                }
                
                // Negative Impact
                HStack {
                    Text("Miss Decrease")
                    Slider(value: $negativeImpact, in: range, step: step)
                    TextField("", value: $negativeImpact, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.center)
                        .onChange(of: negativeImpact) { oldValue, newValue in
                            negativeImpact = max(range.lowerBound, min(range.upperBound, newValue))
                        }
                    Text(unit)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

// MARK: Редактор нескольких влияний на сферы
struct MultipleSphereImpactsView: View {
    @Binding var primarySphereID: UUID?
    @Binding var primaryPositive: Double
    @Binding var primaryNegative: Double
    @Binding var additionalImpacts: [SphereImpact]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Primary impact uses the sphere selected elsewhere (under the title)
            if primarySphereID != nil {
                ImpactSliderView(
                    positiveImpact: $primaryPositive,
                    negativeImpact: $primaryNegative,
                    range: 0...100,
                    step: 0.5,
                    unit: "%"
                )
            }
            // Existing additional impacts
            ForEach($additionalImpacts) { $impact in
                VStack(alignment: .leading, spacing: 8) {
                    SpherePickerView(selectedSphereID: Binding(
                        get: { impact.sphereID },
                        set: { impact.sphereID = $0 }
                    ))
                    if impact.sphereID != nil {
                        ImpactSliderView(
                            positiveImpact: Binding(
                                get: { impact.positiveImpact },
                                set: { impact.positiveImpact = $0 }
                            ),
                            negativeImpact: Binding(
                                get: { impact.negativeImpact },
                                set: { impact.negativeImpact = $0 }
                            ),
                            range: 0...100,
                            step: 0.5,
                            unit: "%"
                        )
                    }
                    HStack {
                        Spacer()
                        Button(role: .destructive) {
                            if let idx = additionalImpacts.firstIndex(where: { $0.id == impact.id }) {
                                // Clear selection to avoid unintended Picker activation and then remove
                                additionalImpacts[idx].sphereID = nil
                                additionalImpacts.remove(at: idx)
                            }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            // Add button should be shown only after selecting the first sphere,
            // and always appear after the last added impact
            if primarySphereID != nil {
                HStack {
                    Label("Add another impact", systemImage: "plus.circle")
                        .foregroundColor(Color.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring()) {
                        additionalImpacts.append(SphereImpact(sphereID: nil))
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: additionalImpacts.count)
    }
}

// MARK: Выбор одной сферы (список / кнопка)
struct SpherePickerView: View {
    @Binding var selectedSphereID: UUID?
    @Query private var spheres: [Sphere]
    
    private var selectedSphere: Sphere? {
        guard let selectedSphereID = selectedSphereID else { return nil }
        return spheres.first { $0.id == selectedSphereID }
    }
    
    private var displayText: String {
        if let sphere = selectedSphere {
            return sphere.title
        }
        return "None"
    }
    
    var body: some View {
        Menu {
            Button {
                selectedSphereID = nil
            } label: {
                Label {
                    HStack {
                        Text("None")
                        if selectedSphereID == nil {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                } icon: {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 12, height: 12)
                }
            }
            
            ForEach(spheres) { sphere in
                Button {
                    selectedSphereID = sphere.id
                } label: {
                    Label {
                        HStack {
                            Text(sphere.title)
                            if selectedSphereID == sphere.id {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    } icon: {
                        Circle()
                            .fill(Color(hex: sphere.colorHex))
                            .frame(width: 12, height: 12)
                    }
                }
            }
        } label: {
            HStack {
                Circle()
                    .fill(selectedSphere != nil ? Color(hex: selectedSphere!.colorHex) : Color.clear)
                    .frame(width: 12, height: 12)
                Text(displayText)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: Компактный выбор SF Symbol
struct IconSelectionView: View {
    @Binding var selectedIconName: String
    let colorForPicker: Color
    @State private var showFullScreenIconPicker: Bool = false
    private let hapticManager = HapticSoundManager.shared
    
    private var displayIconName: String {
        selectedIconName.isEmpty ? "photo" : selectedIconName
    }
    
    var body: some View {
        Button(action: {
            hapticManager.playHaptic(style: .light)
            showFullScreenIconPicker = true
        }) {
            Image(systemName: displayIconName)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorForPicker == .clear ? Color.accentColor : colorForPicker)
                )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showFullScreenIconPicker) {
            IconCatalogPickerView(
                title: "Choose icon",
                tintColor: (colorForPicker == .clear ? Color.accentColor : colorForPicker),
                selectedIconName: Binding(
                    get: { selectedIconName.isEmpty ? nil : selectedIconName },
                    set: { selectedIconName = $0 ?? "" }
                )
            )
        }
    }
}
