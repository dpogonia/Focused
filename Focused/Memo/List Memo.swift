import SwiftUI // 28!!

struct MemoListItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var text: String = ""
    var iconName: String? = nil
    var customImageData: Data? = nil
    var useCustomImage: Bool = false
    var isCompleted: Bool = false
}

// MARK: - List Content Model
struct MemoListContent: Codable, Hashable {
    var items: [MemoListItem] = []
    var iconName: String = "list.bullet"
    var customImageData: Data? = nil
    var colorHex: String = "#34C759" // Default green
    var sphereID: UUID? = nil
    
    // Для обратной совместимости
    init(items: [MemoListItem] = [], iconName: String = "list.bullet", customImageData: Data? = nil, colorHex: String = "#34C759", sphereID: UUID? = nil) {
        self.items = items
        self.iconName = iconName
        self.customImageData = customImageData
        self.colorHex = colorHex
        self.sphereID = sphereID
    }
}

// MARK: - List Content View
struct ListContentView: View {
    let item: MemoItem
    @Binding var isReorderMode: Bool
    @Binding var showCompleted: Bool
    @Binding var showListStatistics: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var listContent: MemoListContent = MemoListContent()
    @State private var newItemText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var editingItemId: UUID?
    @State private var editingText: String = ""
    @FocusState private var isEditingFocused: Bool
    @State private var showIconPicker: Bool = false
    @State private var selectedItemForIcon: MemoListItem?
    
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
            if showListStatistics && !listContent.items.isEmpty {
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
                                Label("Изменить иконку", systemImage: "photo")
                            }
                            
                            Button {
                                startEditing(listItem)
                            } label: {
                                Label("Редактировать", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                deleteItem(listItem)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteItem(listItem)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                toggleComplete(listItem)
                            } label: {
                                Label(listItem.isCompleted ? "Uncomplete" : "Complete",
                                      systemImage: listItem.isCompleted ? "xmark.circle" : "checkmark.circle")
                            }
                            .tint(listItem.isCompleted ? .orange : .green)
                        }
                }
                .onMove { from, to in
                    moveItem(from: from, to: to)
                }
                
                // Add Element TextField
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    TextField("Add an Element", text: $newItemText)
                        .font(.body)
                        .foregroundColor(.primary)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            addNewItem()
                        }
                    
                    Spacer()
                }
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
        .sheet(isPresented: $showIconPicker) {
            if let selectedItem = selectedItemForIcon {
                IconPickerView(
                    selectedIcon: Binding(
                        get: { selectedItem.iconName ?? "" },
                        set: { newIcon in
                            updateItemIcon(selectedItem, iconName: newIcon)
                        }
                    ),
                    isPresented: $showIconPicker
                )
            }
        }
        .onAppear {
            loadItems()
        }
    }
    
    private var circularProgressView: some View {
        HStack(spacing: 16) {
            // Circular Progress
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: listContent.items.isEmpty ? 0 : CGFloat(completedCount) / CGFloat(listContent.items.count))
                    .stroke(Color(hex: listContent.colorHex), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: completedCount)
                
                VStack(spacing: 2) {
                    Text("\(completedCount)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    Text("/\(listContent.items.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Прогресс выполнения")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
                let percentage = listContent.items.isEmpty ? 0 : Int((Double(completedCount) / Double(listContent.items.count)) * 100)
                Text("\(percentage)% завершено")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    
    // MARK: - List Item Row
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
    
    // MARK: - Helper Methods
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
        listContent.items.move(fromOffsets: source, toOffset: destination)
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
}

// MARK: - Icon Picker View
struct IconPickerView: View {
    @Binding var selectedIcon: String
    @Binding var isPresented: Bool
    
    let icons = [
        "star.fill", "heart.fill", "flag.fill", "bookmark.fill", "tag.fill",
        "bell.fill", "envelope.fill", "phone.fill", "message.fill", "calendar",
        "clock.fill", "map.fill", "location.fill", "car.fill", "house.fill",
        "cart.fill", "bag.fill", "creditcard.fill", "dollarsign.circle.fill", "gift.fill",
        "book.fill", "graduationcap.fill", "pencil", "paintbrush.fill", "camera.fill",
        "photo.fill", "film.fill", "music.note", "headphones", "mic.fill",
        "gamecontroller.fill", "sportscourt.fill", "dumbbell.fill", "figure.walk", "bicycle",
        "airplane", "tram.fill", "bus.fill", "briefcase.fill", "desktopcomputer",
        "laptopcomputer", "iphone", "apple.logo", "leaf.fill", "tree.fill",
        "cloud.fill", "sun.max.fill", "moon.fill", "sparkles", "flame.fill"
    ]
    
    let columns = [
        GridItem(.adaptive(minimum: 60))
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    // No icon option
                    VStack {
                        ZStack {
                            Circle()
                                .fill(selectedIcon.isEmpty ? Color.blue : Color.gray.opacity(0.2))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "slash.circle")
                                .font(.title3)
                                .foregroundColor(selectedIcon.isEmpty ? .white : .secondary)
                        }
                        
                        Text("Нет")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .onTapGesture {
                        selectedIcon = ""
                        isPresented = false
                    }
                    
                    ForEach(icons, id: \.self) { icon in
                        VStack {
                            ZStack {
                                Circle()
                                    .fill(selectedIcon == icon ? Color.blue : Color.gray.opacity(0.2))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: icon)
                                    .font(.title3)
                                    .foregroundColor(selectedIcon == icon ? .white : .primary)
                            }
                            
                            Text(icon.split(separator: ".").first ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .onTapGesture {
                            selectedIcon = icon
                            isPresented = false
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Выберите иконку")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
