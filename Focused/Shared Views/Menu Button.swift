import SwiftUI

struct EllipsisMenuButton<Content: View>: View {
    let size: CGFloat
    let weight: Font.Weight
    let color: Color
    let content: () -> Content

    init(
        size: CGFloat = 30,
        weight: Font.Weight = .bold,
        color: Color = .accentColor,
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
            Image(systemName: "ellipsis")
                .font(.system(size: size, weight: weight))
                .foregroundStyle(color)
                .padding(.vertical, 10) // Увеличиваем область нажатия сверху и снизу
                .contentShape(Rectangle()) // Делаем всю область кликабельной
        }
    }
}


