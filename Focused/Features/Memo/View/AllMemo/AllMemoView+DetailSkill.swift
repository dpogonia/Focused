import SwiftUI
import SwiftData

extension AllMemoView {
    @ViewBuilder
    func memoDetailSkill(_ item: MemoItem) -> some View {
    SkillContentView(item: item, showSkillStatistics: $showSkillStatistics)
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
                            showSkillStatistics.toggle()
                        }
                    } label: {
                        Label(showSkillStatistics ? "Hide statistics" : "Show statistics",
                              systemImage: showSkillStatistics ? "chart.bar.fill" : "chart.bar")
                    }
                    
                    Divider()
                    
                    Button {
                        memoToEdit = item
                        newMemoType = .skill
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
