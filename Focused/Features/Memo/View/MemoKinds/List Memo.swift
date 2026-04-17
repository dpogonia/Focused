import SwiftUI

// Presentation · Memo — тип «список»: чек-листы и пункты внутри мемо.
// Оглавление: пункт → `MemoListContent` → экран → строки → хелперы → picker иконки.

struct MemoListItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var text: String = ""
    var iconName: String? = nil
    var customImageData: Data? = nil
    var useCustomImage: Bool = false
    var isCompleted: Bool = false
}

// MARK: Модель контента list-мемо
struct MemoListContent: Codable, Hashable {
    var items: [MemoListItem] = []
    var iconName: String = "list.bullet"
    var customImageData: Data? = nil
    var colorHex: String = "#34C759" // Default green
    var sphereID: UUID? = nil
    var positiveImpact: Double = 0.0
    var negativeImpact: Double = 0.0
    var additionalImpacts: [SphereImpact] = []
    
    // Для обратной совместимости
    init(items: [MemoListItem] = [], iconName: String = "list.bullet", customImageData: Data? = nil, colorHex: String = "#34C759", sphereID: UUID? = nil, positiveImpact: Double = 0.0, negativeImpact: Double = 0.0, additionalImpacts: [SphereImpact] = []) {
        self.items = items
        self.iconName = iconName
        self.customImageData = customImageData
        self.colorHex = colorHex
        self.sphereID = sphereID
        self.positiveImpact = positiveImpact
        self.negativeImpact = negativeImpact
        self.additionalImpacts = additionalImpacts
    }
}

// MARK: Экран редактирования list-мемо
struct ListContentView: View {
    let item: MemoItem
    @Binding var isReorderMode: Bool
    @Binding var showCompleted: Bool
    @Binding var showListStatistics: Bool
    @Binding var triggerAddListItem: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var listContent: MemoListContent = MemoListContent()
    @State private var newItemText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var editingItemId: UUID?
    @State private var editingText: String = ""
    @FocusState private var isEditingFocused: Bool
    @State private var showIconPicker: Bool = false
    @State private var selectedItemForIcon: MemoListItem?
    @State private var showDeleteListItemConfirmation: Bool = false
    @State private var listItemPendingDeletion: MemoListItem?
    
    private let hapticManager = HapticSoundManager.shared
    
    private var filteredItems: [MemoListItem] {
        if showCompleted {
            return listContent.items
        } else {
            return listContent.items.filter { !$0.isCompleted }
        }
    }
    
    private var completedCount: Int {
        listContent.items.filter { $0.isCompleted }.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Circular Progress View
            if showListStatistics {
                circularProgressView
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            List {
                ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, listItem in
                    listItemRow(index: index, listItem: listItem)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .contextMenu {
                            Button {
                                selectedItemForIcon = listItem
                                showIconPicker = true
                            } label: {
                                Label("Change icon", systemImage: "photo")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                listItemPendingDeletion = listItem
                                showDeleteListItemConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                toggleComplete(listItem)
                            } label: {
                                Image(systemName: listItem.isCompleted ? "arrow.uturn.left" : "checkmark.circle")
                            }
                            .tint(listItem.isCompleted ? Color(UIColor.systemGray) : .green)
                        }
                }
                .onMove { from, to in
                    moveItem(from: from, to: to)
                }
                
                // Add Element Row
                addItemRow
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .background(Color(UIColor.systemGroupedBackground))
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(isReorderMode ? .active : .inactive))
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            if triggerAddListItem {
                triggerAddListItem = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isTextFieldFocused = true
                }
            }
        }
        .onChange(of: triggerAddListItem) { _, newValue in
            if newValue {
                triggerAddListItem = false
                isTextFieldFocused = true
            }
        }
        .sheet(isPresented: $showIconPicker) {
            if let item = selectedItemForIcon {
                ListItemMediaPickerSheet(
                    item: item,
                    tintHex: listContent.colorHex,
                    onSave: { icon, imageData in
                        updateItemMedia(item, iconName: icon, imageData: imageData)
                    }
                )
            } else {
                EmptyView()
            }
        }
        .onAppear {
            loadItems()
        }
        .frostedDeleteConfirmation(
            isPresented: $showDeleteListItemConfirmation,
            title: "Delete item?",
            message: "This list item will be permanently deleted.",
            onConfirm: {
                if let item = listItemPendingDeletion {
                    deleteItem(item)
                    listItemPendingDeletion = nil
                }
            }
        )
    }
    
    private var circularProgressView: some View {
        let total = listContent.items.count
        let ratio = total == 0 ? 0.0 : Double(completedCount) / Double(total)
        let percentage = Int(ratio * 100)

        return HStack(spacing: 16) {
            // Circular Progress
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: CGFloat(ratio))
                    .stroke(Color(hex: listContent.colorHex), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: completedCount)
                
                // Single-line ratio label: "0/5" (show 0/0 when list is empty)
                Text("\(completedCount)/\(total == 0 ? 0 : total)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Completion progress")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text("\(percentage)% completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: Строка быстрого добавления пункта
    private var addItemRow: some View {
        HStack(spacing: 12) {
            // Leading circle with plus icon
            Circle()
                .fill(Color(hex: listContent.colorHex).opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: listContent.colorHex))
                )
            
            // Text field for new element
            TextField("add an element", text: $newItemText)
                .font(.body)
                .foregroundColor(.primary)
                .focused($isTextFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    addNewItem()
                }
            
            // Quick add button
            if !newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    addNewItem()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(hex: listContent.colorHex))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .contentShape(Rectangle())
        .onTapGesture {
            isTextFieldFocused = true
        }
    }
    
    
    // MARK: Одна строка пункта (чекбокс, иконка, свайпы)
    private func listItemRow(index: Int, listItem: MemoListItem) -> some View {
        HStack(spacing: 12) {
            // Circle with number, icon, or custom image
            ZStack {
                if listItem.useCustomImage, let imageData = listItem.customImageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        .opacity(listItem.isCompleted ? 0.5 : 1.0)
                } else if let iconName = listItem.iconName {
                    Circle()
                        .fill(Color(hex: listContent.colorHex).opacity(listItem.isCompleted ? 0.1 : 0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: iconName)
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: listContent.colorHex).opacity(listItem.isCompleted ? 0.5 : 1.0))
                        )
                } else {
                    Circle()
                        .fill(Color(hex: listContent.colorHex).opacity(listItem.isCompleted ? 0.1 : 0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: listContent.colorHex).opacity(listItem.isCompleted ? 0.5 : 1.0))
                        )
                }
            }

            // Editable text or TextField
            if editingItemId == listItem.id {
                TextField("", text: $editingText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .focused($isEditingFocused)
                    .onSubmit {
                        saveEdit(for: listItem)
                    }
            } else {
                Text(listItem.text)
                    .font(.body)
                    .foregroundColor(listItem.isCompleted ? .secondary : .primary)
                    .strikethrough(listItem.isCompleted, color: .secondary)
                    .onTapGesture(count: 2) {
                        startEditing(listItem)
                    }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
    
    // MARK: Сохранение и перестановка
    private func loadItems() {
        if let data = item.contentData {
            // Сначала попробуем загрузить новую структуру
            if let content = try? JSONDecoder().decode(MemoListContent.self, from: data) {
                listContent = content
            } else if let items = try? JSONDecoder().decode([MemoListItem].self, from: data) {
                // Для обратной совместимости - конвертируем старый массив в новую структуру
                listContent = MemoListContent(items: items)
            }
        }
    }
    
    private func saveItems() {
        if let data = try? JSONEncoder().encode(listContent) {
            item.contentData = data
            try? modelContext.save()
        }
    }
    
    private func addNewItem() {
        let text = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        withAnimation {
            listContent.items.append(MemoListItem(text: text))
        }
        saveItems()
        hapticManager.playHaptic(style: .light)
        newItemText = ""
    }
    
    private func deleteItem(_ listItem: MemoListItem) {
        withAnimation {
            listContent.items.removeAll { $0.id == listItem.id }
        }
        saveItems()
        hapticManager.playHaptic(style: .medium)
    }
    
    private func toggleComplete(_ listItem: MemoListItem) {
        if let index = listContent.items.firstIndex(where: { $0.id == listItem.id }) {
            withAnimation {
                listContent.items[index].isCompleted.toggle()
            }
            saveItems()
            hapticManager.playHaptic(style: .light)
        }
    }
    
    private func startEditing(_ listItem: MemoListItem) {
        editingItemId = listItem.id
        editingText = listItem.text
        isEditingFocused = true
    }
    
    private func saveEdit(for listItem: MemoListItem) {
        let text = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            editingItemId = nil
            return
        }
        
        if let index = listContent.items.firstIndex(where: { $0.id == listItem.id }) {
            listContent.items[index].text = text
            saveItems()
            hapticManager.playHaptic(style: .light)
        }
        
        editingItemId = nil
        editingText = ""
    }
    
    private func moveItem(from source: IndexSet, to destination: Int) {
        guard let fromIndexInFiltered = source.first,
              fromIndexInFiltered < filteredItems.count else { return }
        
        // Элемент, который двигаем, берём из отфильтрованного списка
        let itemToMove = filteredItems[fromIndexInFiltered]
        guard let fromIndex = listContent.items.firstIndex(where: { $0.id == itemToMove.id }) else { return }
        
        // Целевой индекс внутри полного списка
        let toIndex: Int
        if destination < filteredItems.count {
            let targetItem = filteredItems[destination]
            toIndex = listContent.items.firstIndex(where: { $0.id == targetItem.id }) ?? fromIndex
        } else {
            toIndex = listContent.items.count
        }
        
        listContent.items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex)
        saveItems()
        hapticManager.playHaptic(style: .light)
    }
    
    private func updateItemIcon(_ listItem: MemoListItem, iconName: String) {
        if let index = listContent.items.firstIndex(where: { $0.id == listItem.id }) {
            listContent.items[index].iconName = iconName.isEmpty ? nil : iconName
            listContent.items[index].useCustomImage = false
            saveItems()
            hapticManager.playHaptic(style: .light)
        }
    }
    
    private func updateItemMedia(_ listItem: MemoListItem, iconName: String?, imageData: Data?) {
        guard let index = listContent.items.firstIndex(where: { $0.id == listItem.id }) else { return }
        listContent.items[index].customImageData = imageData
        listContent.items[index].useCustomImage = (imageData != nil)
        listContent.items[index].iconName = (imageData == nil) ? iconName : nil
        saveItems()
        hapticManager.playHaptic(style: .light)
    }
}

private struct ListItemMediaPickerSheet: View {
    let item: MemoListItem
    let tintHex: String
    let onSave: (String?, Data?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var tempImageData: Data?
    @State private var tempIconName: String?
    
    init(item: MemoListItem, tintHex: String, onSave: @escaping (String?, Data?) -> Void) {
        self.item = item
        self.tintHex = tintHex
        self.onSave = onSave
        _tempImageData = State(initialValue: item.useCustomImage ? item.customImageData : nil)
        _tempIconName = State(initialValue: item.useCustomImage ? nil : item.iconName)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(AppEditFormChrome.itemMediaSectionTitle) {
                    MediaCirclePicker(
                        config: MediaCirclePickerConfiguration(
                            dialogTitle: "Item media",
                            tintHex: tintHex,
                            size: 84,
                            fallbackIconName: "photo"
                        ),
                        imageData: $tempImageData,
                        iconName: $tempIconName
                    )
                }
            }
            .navigationTitle("Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(tempIconName, tempImageData)
                        dismiss()
                    }
                }
            }
        }
    }
}

// `IconPickerView` removed — unused (unified icon picker lives in `IconCatalogPickerView`).
