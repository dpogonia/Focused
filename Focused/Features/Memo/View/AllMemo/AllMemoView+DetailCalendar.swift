import SwiftUI
import SwiftData

extension AllMemoView {
    @ViewBuilder
    func memoDetailCalendar(_ item: MemoItem) -> some View {
    CalendarContentView(item: item)
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
                        showCalendarStatistics = true
                    } label: {
                        Label("Statistics", systemImage: "chart.bar")
                    }
                    
                    Divider()
                    
                    Button {
                        memoToEdit = item
                        newMemoType = .calendar
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
        .fullScreenCover(isPresented: $showCalendarStatistics) {
            CalendarMemoStatisticsView(item: item)
        }

    }
}
