import SwiftUI
import SwiftData

// MARK: - Delete Confirmation Component
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

// MARK: - Impact Slider Component
struct ImpactSliderView: View {
    @Binding var positiveImpact: Double
    @Binding var negativeImpact: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    
    init(
        positiveImpact: Binding<Double>,
        negativeImpact: Binding<Double>,
        range: ClosedRange<Double> = 0...100,
        step: Double = 1.0,
        unit: String = "%"
    ) {
        self._positiveImpact = positiveImpact
        self._negativeImpact = negativeImpact
        self.range = range
        self.step = step
        self.unit = unit
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

// MARK: - Multiple Sphere Impacts Editor
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

// MARK: - Sphere Picker Component
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

// MARK: - Empty State Component
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated icon with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.1), .green.opacity(0.1), .mint.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: icon)
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).repeatForever(autoreverses: true), value: UUID())
            }
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 24)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.blue, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


// MARK: - Predefined Empty States
extension EmptyStateView {
    static func noTasks() -> EmptyStateView {
        EmptyStateView(
            icon: "checkmark.circle.fill",
            title: "All caught up! 🎉",
            message: "No tasks to worry about right now.\nTime to plan something amazing!"
        )
    }
    
    static func noHabits() -> EmptyStateView {
        EmptyStateView(
            icon: "sparkles",
            title: "it's time to rest or add new habits",
            message: "Start building healthy habits to improve your life"
        )
    }
    
    static func noGoals() -> EmptyStateView {
        EmptyStateView(
            icon: "target",
            title: "No goals yet",
            message: "Set your first goal to start your journey towards success"
        )
    }
    
    static func noMemos() -> EmptyStateView {
        EmptyStateView(
            icon: "note.text",
            title: "No memos yet",
            message: "Create your first memo to start organizing your thoughts"
        )
    }
    
    static func noSubtasks() -> EmptyStateView {
        EmptyStateView(
            icon: "checklist",
            title: "No subtasks yet",
            message: "Add subtasks to break down this task into smaller, manageable steps"
        )
    }
    
    static func noResults(searchText: String) -> EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "Ничего не найдено",
            message: "Попробуйте изменить поисковый запрос или фильтры"
        )
    }
}

// MARK: - Icon Selection Component
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
        .fullScreenCover(isPresented: $showFullScreenIconPicker) {
            FullScreenIconPickerView(
                selectedIconName: $selectedIconName,
                colorForPicker: colorForPicker,
                isPresented: $showFullScreenIconPicker
            )
        }
    }
}

// MARK: - Full Screen Icon Picker View
struct FullScreenIconPickerView: View {
    @Binding var selectedIconName: String
    let colorForPicker: Color
    @Binding var isPresented: Bool
    @State private var colorUpdateTrigger: Bool = false
    @State private var searchText: String = ""
    private let hapticManager = HapticSoundManager.shared
    
    private var filteredIcons: [String] {
        if searchText.isEmpty {
            return availableHabitIcons
        } else {
            return availableHabitIcons.filter { iconName in
                iconName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search icons", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Icons grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 16) {
                        ForEach(filteredIcons, id: \.self) { iconName in
                            Button(action: {
                                selectedIconName = iconName
                                hapticManager.playHaptic(style: .light)
                                colorUpdateTrigger.toggle()
                                isPresented = false
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: iconName)
                                        .font(.title2)
                                        .foregroundColor(selectedIconName == iconName ? .white : .primary)
                                        .frame(width: 50, height: 50)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedIconName == iconName ? (colorForPicker == .clear ? Color.accentColor : colorForPicker) : Color.gray.opacity(0.1))
                                        )
                                    
                                    Text(formatIconName(iconName))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .minimumScaleFactor(0.7)
                                        .frame(height: 28)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                    .id("\(selectedIconName)_\(colorUpdateTrigger)")
                }
            }
            .navigationTitle("Select Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        hapticManager.playHaptic(style: .light)
                        isPresented = false
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
    
    private func formatIconName(_ iconName: String) -> String {
        var formatted = iconName
            .replacingOccurrences(of: ".fill", with: "")
            .replacingOccurrences(of: ".", with: " ")
            .capitalized
        
        // Улучшаем читаемость некоторых названий
        formatted = formatted.replacingOccurrences(of: "Figure ", with: "")
        formatted = formatted.replacingOccurrences(of: " And ", with: " & ")
        
        return formatted
    }
}
