import SwiftUI

// Presentation · Shared — пустые состояния для главных вкладок (Goals, Tasks, Habits, Memo) и связанных экранов.
//
// **Паттерн static factory / presets**: методы `EmptyStateView.noTasks()`, `.noGoals()` и т.д. возвращают
// уже настроенный экземпляр — в табах не дублируются иконка, заголовок и подпись. Это вариант **Factory Method**
// на уровне SwiftUI-вью (без отдельного класса).

// MARK: - Пустое состояние (иконка, текст, опциональная кнопка)

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.1), .green.opacity(0.1), .mint.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).repeatForever(autoreverses: true), value: UUID())
            }

            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 24)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.blue, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Пресеты по вкладкам / сценариям

extension EmptyStateView {
    static func noTasks() -> EmptyStateView {
        EmptyStateView(
            icon: "checkmark.circle.fill",
            title: "All caught up",
            message: "No tasks today"
        )
    }

    static func noHabits() -> EmptyStateView {
        EmptyStateView(
            icon: "repeat",
            title: "All caught up",
            message: "No habits today"
        )
    }

    static func noGoals() -> EmptyStateView {
        EmptyStateView(
            icon: "target",
            title: "All caught up",
            message: "No goals today"
        )
    }

    static func noMemos() -> EmptyStateView {
        EmptyStateView(
            icon: "note.text",
            title: "All caught up",
            message: "No memo today"
        )
    }

    static func noSubtasks() -> EmptyStateView {
        EmptyStateView(
            icon: "checklist",
            title: "All caught up",
            message: "No subtasks today"
        )
    }

    static func noResults(searchText: String) -> EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "Nothing found",
            message: "Try changing your search or filters"
        )
    }
}

// MARK: - Общий контейнер под календарём на главных вкладках

extension View {
    /// Заполняет область под строкой календаря тем же фоном, что и списки на вкладках.
    func tabEmptyStateLayout() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemGroupedBackground))
    }
}
