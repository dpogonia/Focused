import SwiftUI
import SwiftData

extension AllMemoView {
    @ViewBuilder
    func memoDetailNoteAlbum(_ item: MemoItem) -> some View {
    NoteAlbumContentView(item: item, isReorderMode: $isNoteAlbumReorderMode, showNoteAlbumStatistics: $showNoteAlbumStatistics, showArchivedNotes: $showArchivedNotes, triggerAddNote: $triggerAddNoteForAlbum)
        .navigationTitle(noteAlbumDisplayTitle(item.title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    selectedMemoItem = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        withAnimation {
                            isNoteAlbumReorderMode.toggle()
                        }
                    } label: {
                        Image(systemName: isNoteAlbumReorderMode ? "checkmark" : "arrow.up.arrow.down")
                            .font(.body.weight(.semibold))
                    }
                    
                    Menu {
                    Button {
                        withAnimation {
                            showNoteAlbumStatistics.toggle()
                        }
                    } label: {
                        Label(showNoteAlbumStatistics ? "Hide statistics" : "Show statistics",
                              systemImage: showNoteAlbumStatistics ? "chart.bar.fill" : "chart.bar")
                    }
                    
                    Button {
                        withAnimation {
                            showArchivedNotes.toggle()
                        }
                    } label: {
                        Label(showArchivedNotes ? "Hide archived" : "Show archived",
                              systemImage: showArchivedNotes ? "archivebox.fill" : "archivebox")
                    }
                    
                    Divider()
                    
                    Button {
                        memoToEdit = item
                        newMemoType = .noteAlbum
                        currentSheetId = UUID()
                        showAddEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        memoPendingDeletion = item
                        selectedMemoItem = nil
                        showDeleteMemoConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }
            }
        }

    }
}
