import SwiftUI

// Presentation · Shared — единый «хром» карточек списков (Goals / Tasks / Habits / Memo): фон, скругление, тонкая обводка, hit-testing.

enum MainListCardChrome {
    static let cornerRadius: CGFloat = 16
}

private struct MainListCardChromeModifier<S: ShapeStyle>: ViewModifier {
    let fill: S
    let stroke: Color
    var cornerRadius: CGFloat = MainListCardChrome.cornerRadius

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(alignment: .center) {
                let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                shape
                    .stroke(stroke, lineWidth: 0.5)
                    .background(shape.fill(Color.clear))
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contentShape(Rectangle())
    }
}

extension View {
    func mainListCardChrome<S: ShapeStyle>(
        fill: S,
        stroke: Color,
        cornerRadius: CGFloat = MainListCardChrome.cornerRadius
    ) -> some View {
        modifier(MainListCardChromeModifier(fill: fill, stroke: stroke, cornerRadius: cornerRadius))
    }
}
