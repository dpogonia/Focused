import SwiftUI

// Presentation · Shared — строка формы «лейбл слева, контент справа».

/// Ведущая иконка в секции Details (как `trophy` у reward в Edit Goal): одинаковый размер и цвет.
struct EditFormDetailLeadingIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 14)
            .accessibilityHidden(true)
    }
}

struct FormLabeledRow<Trailing: View>: View {
    let label: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            trailing()
        }
    }
}
