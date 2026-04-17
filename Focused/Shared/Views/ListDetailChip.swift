import SwiftUI

// Presentation · Shared — мини-чипы метаданных на карточках списков (Goals / Tasks / Habits / Memo).

enum ListDetailChipMetrics {
    static let cornerRadius: CGFloat = 6
    static let horizontalPadding: CGFloat = 6
    static let verticalPadding: CGFloat = 2
}

/// Обёртка с единым скруглением и отступами, как у чипов даты / impact / тегов на карточках.
struct ListDetailChip<Content: View>: View {
    let background: Color
    private let content: () -> Content

    init(background: Color, @ViewBuilder content: @escaping () -> Content) {
        self.background = background
        self.content = content
    }

    var body: some View {
        content()
            .padding(.horizontal, ListDetailChipMetrics.horizontalPadding)
            .padding(.vertical, ListDetailChipMetrics.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: ListDetailChipMetrics.cornerRadius, style: .continuous)
                    .fill(background)
            )
    }
}

extension View {
    /// Тот же фон и скругление, что у `ListDetailChip`, без отдельной обёртки (если контент уже собран).
    func listDetailChipBackground(_ color: Color) -> some View {
        padding(.horizontal, ListDetailChipMetrics.horizontalPadding)
            .padding(.vertical, ListDetailChipMetrics.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: ListDetailChipMetrics.cornerRadius, style: .continuous)
                    .fill(color)
            )
    }
}
