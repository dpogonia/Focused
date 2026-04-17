import SwiftUI

// Presentation · Memo — точка расширения стиля бейджа; сейчас без доп. модификаторов (раньше был пустой `ViewModifier`).

extension View {
    /// Зарезервировано для будущей унификации бейджей; не меняет внешний вид.
    func floatingBadgeStyle() -> some View {
        self
    }

    /// Свёрнутый бейдж справа: у `titleView` стоит `layoutPriority(1)`, иначе SwiftUI сжимает trailing-контент.
    func memoCollapsedTrailingBadgeChrome() -> some View {
        self
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(2)
    }
}
