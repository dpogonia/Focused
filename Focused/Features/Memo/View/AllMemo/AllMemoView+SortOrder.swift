import SwiftUI

// MARK: Лейблы сортировки для UI (`MemoListSortOrder`)
extension MemoListSortOrder {
    var displayName: String {
        switch self {
        case .newest: "Newest first"
        case .oldest: "Older first"
        case .alphabetical: "Alphabetically"
        case .type: "Type sorted"
        case .manual: "Custom order"
        }
    }

    var icon: String {
        switch self {
        case .newest: "clock.arrow.circlepath"
        case .oldest: "clock.badge.checkmark"
        case .alphabetical: "textformat.abc"
        case .type: "folder"
        case .manual: "line.3.horizontal"
        }
    }
}
