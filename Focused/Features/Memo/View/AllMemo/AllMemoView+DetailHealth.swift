import SwiftUI
import SwiftData

extension AllMemoView {
    @ViewBuilder
    func memoDetailHealth(_ item: MemoItem) -> some View {
    HealthContentView(item: item, showHealthStatistics: $showHealthStatistics)
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
                            showHealthStatistics.toggle()
                        }
                    } label: {
                        Label(showHealthStatistics ? "Hide statistics" : "Show statistics",
                              systemImage: showHealthStatistics ? "chart.bar.fill" : "chart.bar")
                    }
                    
                    Divider()
                    
                    Button {
                        memoToEdit = item
                        newMemoType = .health
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
