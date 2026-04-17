import SwiftUI

// Presentation · Shared — кнопка меню (три линии) с выпадающим контентом.

struct EllipsisMenuButton<Content: View>: View {
    let size: CGFloat
    let weight: Font.Weight
    let color: Color
    let content: () -> Content

    init(
        size: CGFloat = 18,
        weight: Font.Weight = .medium,
        color: Color = .primary,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.size = size
        self.weight = weight
        self.color = color
        self.content = content
    }

    var body: some View {
        Menu {
            content()
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: size, weight: weight, design: .default))
                .foregroundColor(color)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
    }
}


