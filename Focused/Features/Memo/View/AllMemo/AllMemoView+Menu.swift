import SwiftUI
import SwiftData


extension AllMemoView {
    var currentMemoSettings: MemoSettings {
        if let first = memoSettings.first { return first }
        let s = MemoSettings()
        modelContext.insert(s)
        return s
    }
    
    @ViewBuilder
    var memoMenuContent: some View {
        addMemoMenu
        Divider()
        filterMenu
        if hasActiveFilters {
            Button {
                hapticManager.selectionChanged()
                withAnimation {
                    showSearchBar = false
                    searchText = ""
                    selectedTypeFilter = nil
                    selectedTagFilter = nil
                }
            } label: {
                Label("Clear filters", systemImage: "xmark.circle")
            }
        }
        Divider()
        settingsMenuButton
    }
    
    var addMemoMenu: some View {
        Menu {
            // Order: List, Counter, Streak, Skill, Health, Notes, Time, Budget, Mood
            Button {
                createNewMemo(.list)
            } label: {
                Label("List", systemImage: MemoItemType.list.iconName)
            }

            Button {
                createNewMemo(.counter)
            } label: {
                Label("Counter", systemImage: MemoItemType.counter.iconName)
            }

            Button {
                createNewMemo(.streak)
            } label: {
                Label("Streak", systemImage: MemoItemType.streak.iconName)
            }

            Button {
                createNewMemo(.skill)
            } label: {
                Label("Skill", systemImage: MemoItemType.skill.iconName)
            }

            Button {
                createNewMemo(.time)
            } label: {
                Label("Time", systemImage: MemoItemType.time.iconName)
            }

            Button {
                createNewMemo(.budget)
            } label: {
                Label("Budget", systemImage: MemoItemType.budget.iconName)
            }

            Button {
                createNewMemo(.health)
            } label: {
                Label("Health", systemImage: MemoItemType.health.iconName)
            }

            Button {
                createNewMemo(.noteAlbum)
            } label: {
                Label("Notes", systemImage: MemoItemType.noteAlbum.iconName)
            }

            Button {
                createNewMemo(.calendar)
            } label: {
                Label("Calendar", systemImage: MemoItemType.calendar.iconName)
            }

            Button {
                createNewMemo(.mood)
            } label: {
                Label("Mood", systemImage: MemoItemType.mood.iconName)
            }
        } label: {
            Label("Add memo", systemImage: "plus.circle")
        }
    }
    
    @ViewBuilder
    var filterMenu: some View {
        Menu {
            filterSearchButton
            toggleArchivedButton
            filterByTypeMenu
            filterByTagMenu
            Divider()
            filtersPanelButton
            calendarFilterMenu
            Button("Statistics") { showStatistics = true }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
    
    var settingsMenuButton: some View {
        Button {
            hapticManager.selectionChanged()
            showSettingsSheet = true
        } label: {
            Label("Settings", systemImage: "gearshape")
        }
    }
    
    var filterSearchButton: some View {
        Button {
            hapticManager.selectionChanged()
            withAnimation(.easeInOut(duration: 0.3)) {
                if globalCalendarVisibility {
                    // Calendar visibility is controlled globally from Vision
                }
                showSearchBar.toggle()
                if !showSearchBar {
                    searchText = ""
                }
            }
        } label: {
            Label(showSearchBar ? "Hide Search" : "Show Search", systemImage: "magnifyingglass")
        }
    }
    
    private var hasActiveFilters: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty || selectedTypeFilter != nil || selectedTagFilter != nil
    }
    
    var toggleArchivedButton: some View {
        Group {
            let archivedCount = memoItems.filter { $0.status == .archived }.count
            if archivedCount > 0 {
                Button {
                    hapticManager.selectionChanged()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        localShowArchivedMemos.toggle()
                        let settings = currentMemoSettings
                        settings.showArchivedMemos = localShowArchivedMemos
                        try? modelContext.save()
                    }
                } label: {
                    Label(
                        localShowArchivedMemos ? "Hide Archived" : "Show Archived (\(archivedCount))",
                        systemImage: localShowArchivedMemos ? "archivebox.fill" : "archivebox"
                    )
                }
            }
        }
    }
    
    var filterByTypeMenu: some View {
        Menu("Filter by type") {
            Button {
                selectedTypeFilter = nil
            } label: {
                HStack {
                    Text("All Types")
                    Spacer()
                    if selectedTypeFilter == nil { Image(systemName: "checkmark") }
                }
            }
            ForEach(MemoItemType.allCases, id: \.self) { type in
                Button {
                    selectedTypeFilter = type
                } label: {
                    HStack {
                        Text(type.displayName)
                        Spacer()
                        if selectedTypeFilter == type { Image(systemName: "checkmark") }
                    }
                }
            }
        }
    }
    
    var filterByTagMenu: some View {
        Menu("Filter by tag") {
            Button {
                selectedTagFilter = nil
            } label: {
                HStack {
                    Text("All Tags")
                    Spacer()
                    if selectedTagFilter == nil { Image(systemName: "checkmark") }
                }
            }
            ForEach(Array(Set(memoItems.flatMap { $0.tags })).sorted(), id: \.self) { tag in
                Button {
                    selectedTagFilter = tag
                } label: {
                    HStack {
                        Text(tag)
                        Spacer()
                        if selectedTagFilter == tag { Image(systemName: "checkmark") }
                    }
                }
            }
        }
    }
    
    var filtersPanelButton: some View {
        Button {
            hapticManager.selectionChanged()
            showFilters.toggle()
        } label: {
            Label(showFilters ? "Hide Filters Panel" : "Show Filters Panel", systemImage: showFilters ? "eye.slash" : "line.3.horizontal.decrease.circle")
        }
    }
    
    var calendarFilterMenu: some View {
        Menu("Calendar filter") {
            Button {
                calendarManager.goToToday()
                hapticManager.selectionChanged()
            } label: {
                Label("Today", systemImage: "calendar")
            }
            
            Button {
                hapticManager.selectionChanged()
                calendarManager.selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: calendarManager.selectedDate) ?? .now
            } label: {
                Label("Previous Day", systemImage: "chevron.left")
            }
            
            Button {
                hapticManager.selectionChanged()
                calendarManager.selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: calendarManager.selectedDate) ?? .now
            } label: {
                Label("Next Day", systemImage: "chevron.right")
            }
        }
    }
}

