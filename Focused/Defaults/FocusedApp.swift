// BUILD 24

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
struct ContentView: View {
    @State private var selectedTab = 1
    @Environment(\.modelContext) private var modelContext
    @Query private var appDesignSettings: [AppDesignSettings]
    @Query private var appCalendarSettings: [AppCalendarSettings]
    
    var body: some View {
        TabView(selection: $selectedTab) {
            VisionsTabView()
                .tabItem {
                    Label("Vision", systemImage: "circle.hexagonpath")
                }
                .tag(1)
            
            GoalsTabView()
                .tabItem {
                    Label("Goals", systemImage: "target")
                }
                .tag(2)
            
            TasksTabView()
                .tabItem {
                    Label("Tasks", systemImage: "text.badge.checkmark")
                }
                .tag(3)
            
            HabitsTabView()
                .tabItem {
                    Label("Habits", systemImage: "repeat")
                }
                .tag(4)
            
            MemoTabView()
                .tabItem {
                    Label("Memo", systemImage: "note.text")
                }
                .tag(5)
        }
        .accentColor(.blue)
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
        }
    }
}

// MARK: TAB VIEWS
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


