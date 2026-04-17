import SwiftUI
import SwiftData

extension AllMemoView {
    @ViewBuilder
    func memoDetailView(for item: MemoItem) -> some View {
        switch item.itemType {
        case .list:
            memoDetailList(item)
        case .noteAlbum:
            memoDetailNoteAlbum(item)
        case .counter:
            memoDetailCounter(item)
        case .streak:
            memoDetailStreak(item)
        case .skill:
            memoDetailSkill(item)
        case .budget:
            memoDetailBudget(item)
        case .mood:
            memoDetailMood(item)
        case .time:
            memoDetailTime(item)
        case .calendar:
            memoDetailCalendar(item)
        case .health:
            memoDetailHealth(item)
        @unknown default:
            memoDetailFallback(item)
        }
    }
}
