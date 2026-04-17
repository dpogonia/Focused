import SwiftUI
import SwiftData

extension AllMemoView {
    @ViewBuilder
    func memoDetailBudget(_ item: MemoItem) -> some View {
    BudgetContentView(item: item, showBudgetStatistics: $showBudgetStatistics)
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
                            showBudgetStatistics.toggle()
                        }
                    } label: {
                        Label(showBudgetStatistics ? "Hide statistics" : "Show statistics",
                              systemImage: showBudgetStatistics ? "chart.bar.fill" : "chart.bar")
                    }
                    
                    Divider()
                    
                    Button {
                        memoToEdit = item
                        newMemoType = .budget
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
