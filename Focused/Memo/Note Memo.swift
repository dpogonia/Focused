import SwiftUI

struct MemoNoteAlbumItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String = ""
    var content: String = ""
    var creationDate: Date = Date()
    var lastModified: Date = Date()
    
    // Computed properties for statistics
    var characterCount: Int { content.count }
    var wordCount: Int {
        content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    var sentenceCount: Int {
        content.components(separatedBy: ".!?").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }
}

// MARK: - Note Album Content View
struct NoteAlbumContentView: View {
    let item: MemoItem
    @Binding var isReorderMode: Bool
    @Binding var showNoteAlbumStatistics: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var noteItems: [MemoNoteAlbumItem] = []
    @State private var showAddSheet: Bool = false
    @State private var editingNote: MemoNoteAlbumItem?
    @State private var sortOrder: NoteAlbumSortOrder = .newest
    
    private let hapticManager = HapticSoundManager.shared
    
    enum NoteAlbumSortOrder {
        case newest, oldest, alphabetical, mostEdited
    }
    
    private var sortedNotes: [MemoNoteAlbumItem] {
        switch sortOrder {
        case .newest:
            return noteItems.sorted { $0.creationDate > $1.creationDate }
        case .oldest:
            return noteItems.sorted { $0.creationDate < $1.creationDate }
        case .alphabetical:
            return noteItems.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .mostEdited:
            return noteItems.sorted { $0.lastModified > $1.lastModified }
        }
    }
    
    private var totalCharacters: Int {
        noteItems.reduce(0) { $0 + $1.characterCount }
    }
    
    private var totalWords: Int {
        noteItems.reduce(0) { $0 + $1.wordCount }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Statistics View
            if showNoteAlbumStatistics && !noteItems.isEmpty {
                statisticsView
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            if noteItems.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(sortedNotes) { noteItem in
                        noteItemRow(noteItem: noteItem)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .contextMenu {
                                Button {
                                    editingNote = noteItem
                                } label: {
                                    Label("Редактировать", systemImage: "pencil")
                                }
                                
                                Button {
                                    duplicateNote(noteItem)
                                } label: {
                                    Label("Дублировать", systemImage: "plus.square.on.square")
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    deleteNote(noteItem)
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteNote(noteItem)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    editingNote = noteItem
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                    .onMove { from, to in
                        moveNote(from: from, to: to)
                    }
                }
                .listStyle(.plain)
                .background(Color(UIColor.systemGroupedBackground))
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(isReorderMode ? .active : .inactive))
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .overlay(alignment: .bottomTrailing) {
            // Floating Add Button
            Button {
                showAddSheet = true
                hapticManager.playHaptic(style: .light)
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showAddSheet) {
            NoteAlbumEditorSheet(
                note: nil,
                onSave: { newNote in
                    addNote(newNote)
                },
                onCancel: {
                    showAddSheet = false
                }
            )
        }
        .sheet(item: $editingNote) { note in
            NoteAlbumEditorSheet(
                note: note,
                onSave: { updatedNote in
                    updateNote(updatedNote)
                },
                onCancel: {
                    editingNote = nil
                }
            )
        }
        .onAppear {
            loadNotes()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "note.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("Нет заметок")
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)
            
            Text("Нажмите + чтобы создать первую заметку")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private var statisticsView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                StatCard(
                    value: "\(noteItems.count)",
                    label: noteItems.count == 1 ? "заметка" : "заметок",
                    icon: "note.text",
                    color: .blue
                )
                
                StatCard(
                    value: "\(totalWords)",
                    label: "слов",
                    icon: "text.word.spacing",
                    color: .green
                )
                
                StatCard(
                    value: "\(totalCharacters)",
                    label: "символов",
                    icon: "character.cursor.ibeam",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Note Item Row
    private func noteItemRow(noteItem: MemoNoteAlbumItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if !noteItem.title.isEmpty {
                        Text(noteItem.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    } else {
                        Text("Без названия")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(noteItem.creationDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    editingNote = noteItem
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            
            if !noteItem.content.isEmpty {
                Text(noteItem.content)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            HStack(spacing: 16) {
                Label("\(noteItem.wordCount)", systemImage: "text.word.spacing")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Label("\(noteItem.characterCount)", systemImage: "character")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if noteItem.lastModified != noteItem.creationDate {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.circle")
                            .font(.caption2)
                        Text(noteItem.lastModified, style: .relative)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .onTapGesture {
            editingNote = noteItem
        }
    }
    
    // MARK: - Helper Methods
    private func loadNotes() {
        if let data = item.contentData,
           let items = try? JSONDecoder().decode([MemoNoteAlbumItem].self, from: data) {
            noteItems = items
        }
    }
    
    private func saveNotes() {
        if let data = try? JSONEncoder().encode(noteItems) {
            item.contentData = data
            try? modelContext.save()
        }
    }
    
    private func addNote(_ note: MemoNoteAlbumItem) {
        withAnimation {
            noteItems.append(note)
        }
        saveNotes()
        hapticManager.playHaptic(style: .light)
        showAddSheet = false
    }
    
    private func updateNote(_ note: MemoNoteAlbumItem) {
        if let index = noteItems.firstIndex(where: { $0.id == note.id }) {
            withAnimation {
                noteItems[index] = note
            }
            saveNotes()
            hapticManager.playHaptic(style: .light)
        }
        editingNote = nil
    }
    
    private func deleteNote(_ note: MemoNoteAlbumItem) {
        withAnimation {
            noteItems.removeAll { $0.id == note.id }
        }
        saveNotes()
        hapticManager.playHaptic(style: .medium)
    }
    
    private func duplicateNote(_ note: MemoNoteAlbumItem) {
        var newNote = note
        newNote.id = UUID()
        newNote.title = note.title + " (копия)"
        newNote.creationDate = Date()
        newNote.lastModified = Date()
        
        withAnimation {
            noteItems.append(newNote)
        }
        saveNotes()
        hapticManager.playHaptic(style: .light)
    }
    
    private func moveNote(from source: IndexSet, to destination: Int) {
        noteItems.move(fromOffsets: source, toOffset: destination)
        saveNotes()
        hapticManager.playHaptic(style: .light)
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Note Album Editor Sheet
struct NoteAlbumEditorSheet: View {
    let note: MemoNoteAlbumItem?
    @State private var title: String = ""
    @State private var content: String = ""
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isContentFocused: Bool
    
    let onSave: (MemoNoteAlbumItem) -> Void
    let onCancel: () -> Void
    
    init(note: MemoNoteAlbumItem?, onSave: @escaping (MemoNoteAlbumItem) -> Void, onCancel: @escaping () -> Void) {
        self.note = note
        self.onSave = onSave
        self.onCancel = onCancel
        
        if let note = note {
            _title = State(initialValue: note.title)
            _content = State(initialValue: note.content)
        }
    }
    
    private var wordCount: Int {
        content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    
    private var characterCount: Int {
        content.count
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Title Field
                TextField("Название заметки", text: $title)
                    .font(.title2.bold())
                    .focused($isTitleFocused)
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                
                Divider()
                
                // Content Editor
                TextEditor(text: $content)
                    .focused($isContentFocused)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .background(Color(UIColor.systemGroupedBackground))
                    .padding(.horizontal, 8)
                
                // Statistics Bar
                HStack(spacing: 20) {
                    Label("\(wordCount) слов", systemImage: "text.word.spacing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("\(characterCount) символов", systemImage: "character")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(note == nil ? "Новая заметка" : "Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let savedNote = MemoNoteAlbumItem(
                            id: note?.id ?? UUID(),
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                            creationDate: note?.creationDate ?? Date(),
                            lastModified: Date()
                        )
                        onSave(savedNote)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        isTitleFocused = false
                        isContentFocused = false
                    }
                }
            }
        }
        .onAppear {
            if note == nil {
                isTitleFocused = true
            }
        }
    }
}

// MARK: - Legacy Support (for backward compatibility)
struct MemoNoteAlbumContent: Codable, Hashable {
    var notes: [NoteItem] = []
    var iconName: String = "note.text"
    var customImageData: Data? = nil
    var colorHex: String = "#007AFF" // Default iOS blue
    var sphereID: UUID? = nil
    
    struct NoteItem: Codable, Hashable, Identifiable {
        var id: UUID = UUID()
        var title: String = ""
        var content: String = ""
        var creationDate: Date = Date()
        var lastModified: Date = Date()
        var tags: [String] = []
        
        var characterCount: Int { content.count }
        var wordCount: Int {
            content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        }
        var sentenceCount: Int {
            content.components(separatedBy: ".!?").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        }
    }
}
