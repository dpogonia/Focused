// BUILD 24
//
// Точка входа приложения: регистрирует SwiftData `modelContainer` и корневой `ContentView`.
// **Composition root** для DI: `ContentView` вызывает `AppFactory.makeAppDependencies` через `AppDependencies.live`
// и модификатор `.appDependencies(...)` (см. `Core/AppFactory.swift`).
// Обзор этапов рефакторинга и карта папок — `Core/ArchitectureStagesAndMap.swift`.
// Обучение начинающих — `Core/LEARNING_GUIDE.md` (пошаговый гид по слоям и папкам).
//
// EN — **App entry:** `FocusedApp` wires SwiftData models into `modelContainer`; `ContentView` hosts TabView + DI + shared `CalendarManager`.
// **Architecture map:** `Core/ArchitectureStagesAndMap.swift` (RU + EN sections). **Tutorial:** `Core/LEARNING_GUIDE.md`.

import SwiftUI
import SwiftData

@main
struct FocusedApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Habit.self, HabitsSettings.self, Sphere.self, Tag.self, SuperTask.self, SubTask.self, TasksSettings.self, Goal.self, Counter.self, GoalsSettings.self, MemoItem.self, MemoSettings.self, VisionsSettings.self, AppDesignSettings.self, AppCalendarSettings.self])
    }
}

// MARK: All Tabs Views
//
// Корневой `TabView`: `RootCoordinator` (**Coordinator**) держит выбранную вкладку;
// `AppDependencies` — через `.appDependencies(...)`; общий `CalendarManager` — через `.environmentObject` для всех вкладок.
//
// EN — **Root UI:** five tabs; `rootCoordinator.selectedTab` drives `TabView`; `calendarManager` shares the selected day across tabs that show the strip calendar.

struct ContentView: View {
    @StateObject private var rootCoordinator = RootCoordinator()
    /// Общий календарь по всем вкладкам (выбранный день и видимая неделя).
    @StateObject private var calendarManager = CalendarManager()
    @Environment(\.modelContext) private var modelContext
    @Query private var appDesignSettings: [AppDesignSettings]
    @Query private var appCalendarSettings: [AppCalendarSettings]
    @State private var isInitializingData: Bool = !UserDefaults.standard.bool(forKey: "defaultSampleDataAdded")
    
    var body: some View {
        ZStack {
            TabView(selection: $rootCoordinator.selectedTab) {
                VisionsTabView()
                    .tabItem {
                        Label("Vision", systemImage: "circle.hexagonpath")
                    }
                    .tag(AppRootTab.vision)
                
                GoalsTabView()
                    .tabItem {
                        Label("Goals", systemImage: "target")
                    }
                    .tag(AppRootTab.goals)
                
                TasksTabView()
                    .tabItem {
                        Label("Tasks", systemImage: "text.badge.checkmark")
                    }
                    .tag(AppRootTab.tasks)
                
                HabitsTabView()
                    .tabItem {
                        Label("Habits", systemImage: "repeat")
                    }
                    .tag(AppRootTab.habits)
                
                MemoTabView()
                    .tabItem {
                        Label("Memo", systemImage: "note.text")
                    }
                    .tag(AppRootTab.memo)
            }
            .accentColor(.blue)
            .background(Color(UIColor.systemGroupedBackground))
            
            if isInitializingData {
                InitializingDataView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        // Dependency Injection: один контейнер `AppDependencies` на всё дерево вкладок.
        .appDependencies(AppDependencies.live(modelContext: modelContext))
        .environmentObject(rootCoordinator)
        .environmentObject(calendarManager)
        .onChange(of: rootCoordinator.selectedTab) { _, _ in
            calendarManager.refreshObservationForTabChange()
        }
        .onAppear {
            // Ensure default AppDesignSettings exists
            if appDesignSettings.isEmpty {
                let defaultSettings = AppDesignSettings(design: .basic)
                modelContext.insert(defaultSettings)
                try? modelContext.save()
            }
            // Ensure default AppCalendarSettings exists
            if appCalendarSettings.isEmpty {
                let defaultCalendarSettings = AppCalendarSettings(isVisible: true)
                modelContext.insert(defaultCalendarSettings)
                try? modelContext.save()
            }
            
            let defaults = UserDefaults.standard
            let seedKey = "defaultSampleDataAdded"
            
            if !defaults.bool(forKey: seedKey) {
                isInitializingData = true
                Task {
                    SampleDataSeeder.shared.seedIfNeeded(using: modelContext)
                    await MainActor.run {
                        isInitializingData = false
                    }
                }
            }
        }
    }
}


// MARK: - Initializing Data Overlay
struct InitializingDataView: View {
    @State private var isPulsing: Bool = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.15), lineWidth: 8)
                        .frame(width: 88, height: 88)
                        .scaleEffect(isPulsing ? 1.08 : 0.92)
                    
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .animation(
                    .easeInOut(duration: 1.1)
                        .repeatForever(autoreverses: true),
                    value: isPulsing
                )
                
                Text("Initializing data…")
                    .font(.headline)
                
                Text("This may take a few seconds on first launch.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .onAppear {
            isPulsing = true
        }
    }
}


// MARK: TAB VIEWS
//
// Тонкие обёртки вкладок. Переключение вкладок программно — через `@EnvironmentObject var rootCoordinator: RootCoordinator` и `selectTab(_:)`.

struct VisionsTabView: View {
    var body: some View {
        VisionsView()
    }
}

struct GoalsTabView: View {
    var body: some View {
        AllGoalsView()
    }
}

struct TasksTabView: View {
    var body: some View {
        AllTasksView()
    }
}

struct HabitsTabView: View {
    var body: some View {
        AllHabitsView()
    }
}

struct MemoTabView: View {
    var body: some View {
        AllMemoView()
    }
}


