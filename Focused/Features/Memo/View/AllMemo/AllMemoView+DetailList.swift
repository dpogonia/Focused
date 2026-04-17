import SwiftUI
import SwiftData

extension AllMemoView {
    @ViewBuilder
    func memoDetailList(_ item: MemoItem) -> some View {
    ListContentView(item: item, isReorderMode: $isReorderMode, showCompleted: $showCompleted, showListStatistics: $showListStatistics, triggerAddListItem: $triggerAddListItemForList)
        .navigationTitle(item.title)
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
                            isReorderMode.toggle()
                        }
                    } label: {
                        Image(systemName: isReorderMode ? "checkmark" : "arrow.up.arrow.down")
                            .font(.body.weight(.semibold))
                    }
                    
                    Menu {
                        Button {
                            withAnimation {
                                showListStatistics.toggle()
                            }
                        } label: {
                            Label(showListStatistics ? "Hide statistics" : "Show statistics",
                                  systemImage: showListStatistics ? "chart.bar.fill" : "chart.bar")
                        }
                        
                        Button {
                            withAnimation {
                                showCompleted.toggle()
                            }
                        } label: {
                            Label(showCompleted ? "Hide completed" : "Show completed",
                                  systemImage: showCompleted ? "eye.slash" : "eye")
                        }
                        
                        Divider()
                        
                        Button {
                            memoToEdit = item
                            newMemoType = .list
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
