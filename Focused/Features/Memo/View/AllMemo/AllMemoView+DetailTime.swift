import SwiftUI
import SwiftData

extension AllMemoView {
    @ViewBuilder
    func memoDetailTime(_ item: MemoItem) -> some View {
    TimeContentView(item: item, showTimeStatistics: $showTimeStatistics)
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
                Menu {
                    Button {
                        withAnimation {
                            showTimeStatistics.toggle()
                        }
                    } label: {
                        Label(showTimeStatistics ? "Hide statistics" : "Show statistics",
                              systemImage: showTimeStatistics ? "chart.bar.fill" : "chart.bar")
                    }
                    
                    Divider()
                    
                    Button {
                        memoToEdit = item
                        newMemoType = .time
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
