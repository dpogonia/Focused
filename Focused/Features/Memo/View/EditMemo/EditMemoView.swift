import SwiftUI
import SwiftData

// Presentation · Memo — универсальная форма редактирования `MemoItem` по типу (`MemoItemType`).
// Папка **EditMemo**: секции и логика — в `EditMemoView+FormSections`, цветовые модификаторы — в `EditMemoColorModifiers`.

// MARK: Корневая форма редактирования мемо
struct EditMemoView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query private var spheres: [Sphere]

    @Binding var memoToEdit: MemoItem?
    let memoType: MemoItemType
    let isEditingMode: Bool

    @StateObject var viewModel: EditMemoViewModel
    @State private var showDeleteConfirmation: Bool = false
    @State private var showArchiveConfirmation: Bool = false

    init(memoToEdit: Binding<MemoItem?>, memoType: MemoItemType) {
        self._memoToEdit = memoToEdit
        self.memoType = memoType
        self.isEditingMode = memoToEdit.wrappedValue != nil
        self._viewModel = StateObject(wrappedValue: EditMemoViewModel(memoToEdit: memoToEdit.wrappedValue, memoType: memoType))
    }

    var body: some View {
        NavigationStack {
            Form {
                titleSection
                sphereSection
                colorSection
                contentSection
                tagsSection
                
                if memoToEdit != nil {
                    Section {
                        Button {
                            showArchiveConfirmation = true
                        } label: {
                            Label(
                                memoToEdit?.status == .archived ? "Unarchive" : "Archive",
                                systemImage: memoToEdit?.status == .archived ? "tray.and.arrow.up" : "archivebox"
                            )
                        }
                        .tint(.gray)
                        
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isEditingMode ? "Edit \(memoType.displayName)" : "New \(memoType.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditingMode ? "Save" : "Create") {
                        saveMemo()
                    }
                    .disabled(!isEditingMode && viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .overlay {
                if showDeleteConfirmation, let memo = memoToEdit {
                    let info = memoImpactInfo(memo)
                    ImpactActionPresenter.dialog(
                        isPresented: $showDeleteConfirmation,
                        spheres: spheres,
                        sphereID: info.sphereID,
                        negativeImpact: info.negativeImpact,
                        title: "Delete memo?",
                        message: "This memo and its data will be permanently deleted.",
                        messageWithImpact: "Delete this memo. You can also apply its miss decrease to the area.",
                        primaryTitle: "Delete",
                        primaryTint: .red,
                        secondaryTitleFormat: "Delete and apply negative impact (-%@%%) on area",
                        secondaryTint: .red,
                        onPrimary: {
                            deleteMemo(memo, applyNegativeImpact: false)
                            memoToEdit = nil
                            dismiss()
                        },
                        onSecondary: {
                            deleteMemo(memo, applyNegativeImpact: true)
                            memoToEdit = nil
                            dismiss()
                        },
                        onCancel: { }
                    )
                }
            }
            .overlay {
                if showArchiveConfirmation, let memo = memoToEdit {
                    let info = memoImpactInfo(memo)
                    let allowSecondary = memo.status != .archived
                    ImpactActionPresenter.dialog(
                        isPresented: $showArchiveConfirmation,
                        spheres: spheres,
                        sphereID: info.sphereID,
                        negativeImpact: info.negativeImpact,
                        allowSecondaryAction: allowSecondary,
                        title: memo.status == .archived ? "Unarchive memo?" : "Archive memo?",
                        message: "This memo will be archived.",
                        messageWithImpact: "Archive this memo. You can also apply its miss decrease to the area.",
                        primaryTitle: memo.status == .archived ? "Unarchive" : "Archive",
                        primaryTint: .gray,
                        secondaryTitleFormat: "Archive and apply negative impact (-%@%%) on area",
                        secondaryTint: .gray,
                        onPrimary: {
                            archiveMemo(memo, applyNegativeImpact: false)
                            dismiss()
                        },
                        onSecondary: {
                            archiveMemo(memo, applyNegativeImpact: true)
                            dismiss()
                        },
                        onCancel: { }
                    )
                }
            }
        }
        .modifier(NoteAlbumColorModifiers(viewModel: viewModel, modelContext: modelContext))
    }
    
    private func memoImpactInfo(_ memo: MemoItem) -> (sphereID: UUID?, negativeImpact: Double) {
        let info = memo.impactInfo()
        return (info.sphereID, info.negativeImpact)
    }
    
    private func applyNegativeImpactIfNeeded(sphereID: UUID?, negativeImpact: Double, apply: Bool) {
        MemoImpactApplier.applyNegativeImpactIfNeeded(
            modelContext: modelContext,
            sphereID: sphereID,
            negativeImpact: negativeImpact,
            apply: apply
        )
    }
    
    private func deleteMemo(_ memo: MemoItem, applyNegativeImpact: Bool) {
        let info = memoImpactInfo(memo)
        applyNegativeImpactIfNeeded(sphereID: info.sphereID, negativeImpact: info.negativeImpact, apply: applyNegativeImpact)
        modelContext.delete(memo)
        try? modelContext.save()
        NotificationCenter.default.postAppEvent(.memoStatusDidChange)
    }
    
    private func archiveMemo(_ memo: MemoItem, applyNegativeImpact: Bool) {
        let info = memoImpactInfo(memo)
        if memo.status != .archived {
            applyNegativeImpactIfNeeded(sphereID: info.sphereID, negativeImpact: info.negativeImpact, apply: applyNegativeImpact)
        }
        memo.status = memo.status == .archived ? .active : .archived
        try? modelContext.save()
        NotificationCenter.default.postAppEvent(.memoStatusDidChange)
    }
}
