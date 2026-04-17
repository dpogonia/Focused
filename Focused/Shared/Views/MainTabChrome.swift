import SwiftUI

// MARK: - Main tab chrome (shared «оболочка» экранов Goals / Tasks / Habits / Memo)
//
// **Зачем этот файл**
// Одинаковые куски UI копировались в каждом табе: верхняя строка «календарь ИЛИ поиск + меню …»
// и модификаторы строки `List` для карточек.
//
// **Паттерны (кратко)**
// 1) **Composition (слоты)** — `MainTabHeaderRow` не знает про домен; ему передают `@ViewBuilder`-контент
//    для поиска, календаря и меню. Так избегаем наследования и огромных `switch` по вкладкам.
// 2) **DRY через `View` extensions** — `mainTabListCardRowChrome()` собирает одинаковую цепочку
//    `.listRowSeparator` / `.padding` / фон, чтобы не ошибиться в одном из пяти модификаторов.
// 3) **Верхний safe area без UIKit** — фон списка задаётся как
//    `.background { Color(...).ignoresSafeArea(edges: .top) }`, а сам контент (включая `MainTabHeaderRow`)
//    **не** игнорирует safe area: системный отступ под «чёлку» применяется автоматически.

// MARK: - Верхняя строка: календарь или поиск + `…`

struct MainTabHeaderRow<SearchContent: View, CalendarContent: View, MenuContent: View>: View {
    let showSearchBar: Bool
    let calendarVisible: Bool

    @ViewBuilder var searchContent: () -> SearchContent
    @ViewBuilder var calendarContent: () -> CalendarContent
    @ViewBuilder var menuContent: () -> MenuContent

    var body: some View {
        HStack(spacing: 0) {
            if showSearchBar {
                searchContent()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                calendarContent()
                    .opacity(calendarVisible ? 1 : 0)
                    .allowsHitTesting(calendarVisible && !showSearchBar)
                    .animation(.easeInOut(duration: 0.25), value: calendarVisible)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            EllipsisMenuButton {
                menuContent()
            }
            .padding(.trailing, 16)
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.3), value: showSearchBar)
    }
}

// MARK: - Стиль строки `List` для карточек на фоне grouped

extension View {
    /// Цепочка модификаторов для **карточки** внутри `List` (Goals / Tasks): как было вручную в каждом табе.
    func mainTabListCardRowChrome() -> some View {
        self
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .padding(.horizontal, 10)
            .padding(.vertical, 1)
            .background(Color.clear)
    }

    /// Трижды `clipped()` — сохраняем прежнее поведение (анти-артефакты при свайпах на некоторых iOS).
    func mainTabListCardRowSwipeClipping() -> some View {
        self
            .clipped()
            .clipped()
            .clipped()
    }

    /// Habits: карточка на всю ширину строки, без горизонтального padding как у Goals/Tasks.
    func mainTabListRowHabitsChrome() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    /// Memo: узкий горизонтальный inset у строки; общий `padding` списка 10 pt задаётся на `List`.
    func mainTabMemoListRowChrome() -> some View {
        self
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .padding(.horizontal, 1)
            .padding(.vertical, 1)
    }

    /// Два свайпа строки списка в фиксированном порядке: слева, затем справа (`allowsFullSwipe: false`).
    func mainTabListRowSwipeActions(
        @ViewBuilder leading: () -> some View,
        @ViewBuilder trailing: () -> some View
    ) -> some View {
        self
            .swipeActions(edge: .leading, allowsFullSwipe: false, content: leading)
            .swipeActions(edge: .trailing, allowsFullSwipe: false, content: trailing)
    }
}

// MARK: - Общие подменю фильтров (Sphere / Tag)

enum MainTabFilterMenus {
    @ViewBuilder
    static func sphereSubmenu(
        spheres: [Sphere],
        selectedSphereID: Binding<UUID?>,
        onSelectionChange: @escaping () -> Void = {}
    ) -> some View {
        Menu("Filter by Sphere") {
            ForEach(spheres) { sphere in
                Button {
                    onSelectionChange()
                    selectedSphereID.wrappedValue = sphere.id
                } label: {
                    HStack {
                        Text(sphere.title)
                        Spacer()
                        if selectedSphereID.wrappedValue == sphere.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Button {
                onSelectionChange()
                selectedSphereID.wrappedValue = nil
            } label: {
                HStack {
                    Text("Clear filter")
                    Spacer()
                    if selectedSphereID.wrappedValue == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }

    @ViewBuilder
    static func tagSubmenu(
        tags: [String],
        selectedTag: Binding<String?>,
        onSelectionChange: @escaping () -> Void = {}
    ) -> some View {
        Menu("Filter by Tag") {
            ForEach(tags, id: \.self) { tag in
                Button {
                    onSelectionChange()
                    selectedTag.wrappedValue = tag
                } label: {
                    HStack {
                        Text(tag)
                        Spacer()
                        if selectedTag.wrappedValue == tag {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Button {
                onSelectionChange()
                selectedTag.wrappedValue = nil
            } label: {
                HStack {
                    Text("Clear filter")
                    Spacer()
                    if selectedTag.wrappedValue == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }
}
