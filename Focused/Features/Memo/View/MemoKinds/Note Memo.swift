import SwiftUI

// Presentation · Memo — тип «заметки / альбом»: страницы текста внутри одного `MemoItem`.
// Оглавление: страница заметки → экран альбома → строка в списке → CRUD и сортировка → карточка статистики → sheet редактора → legacy `MemoNoteAlbumContent`.

// MARK: Одна страница заметки в альбоме
struct MemoNoteAlbumItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String = ""
    var content: String = ""
    var creationDate: Date = Date()
    var lastModified: Date = Date()
    var isArchived: Bool = false
    var orderIndex: Int = 0
    
    // Computed properties for statistics
    var characterCount: Int { content.count }
    var wordCount: Int {
        content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    var sentenceCount: Int {
        content.components(separatedBy: ".!?").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }
}

// MARK: Экран альбома заметок
struct NoteAlbumContentView: View {
    let item: MemoItem
    @Binding var isReorderMode: Bool
    @Binding var showNoteAlbumStatistics: Bool
    @Binding var showArchivedNotes: Bool
    @Binding var triggerAddNote: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var noteItems: [MemoNoteAlbumItem] = []
    @State private var showAddSheet: Bool = false
    @State private var editingNote: MemoNoteAlbumItem?
    @State private var sortOrder: NoteAlbumSortOrder = .newest
    @State private var selectedStatsPeriod: MemoStatsPeriod = .month
    @State private var showDeleteNoteConfirmation: Bool = false
    @State private var notePendingDeletion: MemoNoteAlbumItem?
    
    private let hapticManager = HapticSoundManager.shared
    
    private var displayedNotes: [MemoNoteAlbumItem] {
        showArchivedNotes ? noteItems : noteItems.filter { !$0.isArchived }
    }
    
    private var filteredNotes: [MemoNoteAlbumItem] {
        let base = displayedNotes
        guard let start = selectedStatsPeriod.startDate() else {
            return base
        }
        return base.filter { $0.creationDate >= start }
    }
    
    enum NoteAlbumSortOrder {
        case newest, oldest, alphabetical, mostEdited
    }
    
    private var sortedNotes: [MemoNoteAlbumItem] {
        displayedNotes.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    private var totalCharacters: Int {
        filteredNotes.reduce(0) { $0 + $1.characterCount }
    }
    
    private var totalWords: Int {
        filteredNotes.reduce(0) { $0 + $1.wordCount }
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
            
            if displayedNotes.isEmpty {
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
                                    Label("Edit", systemImage: "pencil")
                                }
                                
                                Button {
                                    duplicateNote(noteItem)
                                } label: {
                                    Label("Duplicate", systemImage: "plus.square.on.square")
                                }
                                
                                Button {
                                    toggleArchiveNote(noteItem)
                                } label: {
                                    Label(noteItem.isArchived ? "Unarchive" : "Archive", systemImage: noteItem.isArchived ? "tray.and.arrow.up" : "archivebox")
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    notePendingDeletion = noteItem
                                    showDeleteNoteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    notePendingDeletion = noteItem
                                    showDeleteNoteConfirmation = true
                                } label: {
                                    Image(systemName: "trash")
                                }
                                Button {
                                    toggleArchiveNote(noteItem)
                                } label: {
                                    Image(systemName: noteItem.isArchived ? "tray.and.arrow.up" : "archivebox")
                                }
                                .tint(Color(UIColor.systemGray))
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    showAddSheet = true
                                    hapticManager.playHaptic(style: .light)
                                } label: {
                                    Image(systemName: "plus")
                                }
                                .tint(.green)
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
        .frostedDeleteConfirmation(
            isPresented: $showDeleteNoteConfirmation,
            title: "Delete note?",
            message: "This note will be permanently deleted.",
            onConfirm: {
                if let note = notePendingDeletion {
                    deleteNote(note)
                    notePendingDeletion = nil
                }
            }
        )
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
            if triggerAddNote {
                triggerAddNote = false
                showAddSheet = true
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "note.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No notes")
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)
            
            Text("Tap + to create your first note")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private var statisticsView: some View {
        VStack(spacing: 12) {
            MemoStatsPeriodSegmentedPicker(selection: $selectedStatsPeriod)
            
            HStack(spacing: 20) {
                MemoStatisticMetricCard(
                    title: filteredNotes.count == 1 ? "note" : "notes",
                    value: "\(filteredNotes.count)",
                    icon: "note.text",
                    color: .blue,
                    backgroundStyle: .tintWash
                )
                
                MemoStatisticMetricCard(
                    title: "words",
                    value: "\(totalWords)",
                    icon: "text.word.spacing",
                    color: .green,
                    backgroundStyle: .tintWash
                )
                
                MemoStatisticMetricCard(
                    title: "characters",
                    value: "\(totalCharacters)",
                    icon: "character.cursor.ibeam",
                    color: .orange,
                    backgroundStyle: .tintWash
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()
    
    // MARK: Одна карточка заметки в списке
    private func noteItemRow(noteItem: MemoNoteAlbumItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                if !noteItem.title.isEmpty {
                    Text(noteItem.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                } else {
                    Text("Untitled")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                Spacer()
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
                
                Text(Self.dateFormatter.string(from: noteItem.creationDate))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .onTapGesture {
            editingNote = noteItem
        }
    }
    
    // MARK: Загрузка, сохранение, дублирование, архив, reorder
    private func loadNotes() {
        guard let data = item.contentData else { return }
        if let items = try? JSONDecoder().decode([MemoNoteAlbumItem].self, from: data) {
            noteItems = items
            ensureOrderIndices()
        } else if let content = try? JSONDecoder().decode(MemoNoteAlbumContent.self, from: data) {
            noteItems = content.notes.enumerated().map { idx, note in
                MemoNoteAlbumItem(
                    id: note.id,
                    title: note.title,
                    content: note.content,
                    creationDate: note.creationDate,
                    lastModified: note.lastModified,
                    isArchived: note.isArchived,
                    orderIndex: idx
                )
            }
            ensureOrderIndices()
        }
    }
    
    private func ensureOrderIndices() {
        for (idx, _) in noteItems.enumerated() {
            noteItems[idx].orderIndex = idx
        }
    }
    
    private func saveNotes() {
        if let data = try? JSONEncoder().encode(noteItems) {
            item.contentData = data
            try? modelContext.save()
        }
    }
    
    private func addNote(_ note: MemoNoteAlbumItem) {
        var newNote = note
        newNote.orderIndex = noteItems.map(\.orderIndex).max().map { $0 + 1 } ?? 0
        withAnimation {
            noteItems.append(newNote)
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
        newNote.title = note.title + " (copy)"
        newNote.creationDate = Date()
        newNote.lastModified = Date()
        newNote.orderIndex = noteItems.map(\.orderIndex).max().map { $0 + 1 } ?? 0
        
        withAnimation {
            noteItems.append(newNote)
        }
        saveNotes()
        hapticManager.playHaptic(style: .light)
    }
    
    private func moveNote(from source: IndexSet, to destination: Int) {
        guard let fromIdx = source.first, fromIdx < sortedNotes.count, destination <= sortedNotes.count else { return }
        let noteToMove = sortedNotes[fromIdx]
        guard let noteItemsFromIdx = noteItems.firstIndex(where: { $0.id == noteToMove.id }) else { return }
        let noteItemsToIdx: Int
        if destination < sortedNotes.count {
            let targetNote = sortedNotes[destination]
            noteItemsToIdx = noteItems.firstIndex(where: { $0.id == targetNote.id }) ?? noteItemsFromIdx
        } else {
            noteItemsToIdx = noteItems.count
        }
        noteItems.move(fromOffsets: IndexSet([noteItemsFromIdx]), toOffset: noteItemsToIdx)
        for (idx, _) in noteItems.enumerated() {
            noteItems[idx].orderIndex = idx
        }
        saveNotes()
        hapticManager.playHaptic(style: .light)
    }
    
    private func toggleArchiveNote(_ note: MemoNoteAlbumItem) {
        if let index = noteItems.firstIndex(where: { $0.id == note.id }) {
            withAnimation {
                noteItems[index].isArchived.toggle()
            }
            saveNotes()
            hapticManager.playHaptic(style: .light)
        }
    }
}

// MARK: Sheet — полноэкранный редактор страницы
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
                TextField("note title", text: $title)
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
                    Label("\(wordCount) words", systemImage: "text.word.spacing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("\(characterCount) characters", systemImage: "character")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(note == nil ? "New Note" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
                    Button("Done") {
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

// MARK: Legacy: старый формат контента альбома (совместимость)
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
        var isArchived: Bool = false
        var orderIndex: Int = 0
        
        var characterCount: Int { content.count }
        var wordCount: Int {
            content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        }
        var sentenceCount: Int {
            content.components(separatedBy: ".!?").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        }
    }
}
