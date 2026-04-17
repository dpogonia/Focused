import SwiftUI
import SwiftData
import Foundation

extension AllMemoView {
    func createNewMemo(_ type: MemoItemType) {
        memoToEdit = nil
        pendingMemoType = type
    }
    
    func memoImpactInfo(_ memo: MemoItem) -> (sphereID: UUID?, negativeImpact: Double) {
        let info = memo.impactInfo()
        return (info.sphereID, info.negativeImpact)
    }
    
    func applyNegativeImpactIfNeeded(sphereID: UUID?, negativeImpact: Double, apply: Bool) {
        MemoImpactApplier.applyNegativeImpactIfNeeded(
            modelContext: modelContext,
            sphereID: sphereID,
            negativeImpact: negativeImpact,
            apply: apply
        )
    }
    
    func deleteMemo(_ memo: MemoItem, applyNegativeImpact: Bool) {
        let info = memoImpactInfo(memo)
        applyNegativeImpactIfNeeded(sphereID: info.sphereID, negativeImpact: info.negativeImpact, apply: applyNegativeImpact)
        modelContext.delete(memo)
        do {
            try modelContext.save()
            NotificationCenter.default.postAppEvent(.memoStatusDidChange)
        } catch {
            print("Error deleting memo: \(error)")
        }
    }
    
    func deleteMemo(at offsets: IndexSet) {
        guard let first = offsets.first, first < filteredAndSortedItems.count else { return }
        let memo = filteredAndSortedItems[first]
        memoPendingDeletion = memo
        showDeleteMemoConfirmation = true
    }
    
    func archiveMemo(_ memo: MemoItem, applyNegativeImpact: Bool) {
        let info = memoImpactInfo(memo)
        // Only makes sense to apply miss decrease when archiving (not unarchiving).
        if memo.status != .archived {
            applyNegativeImpactIfNeeded(sphereID: info.sphereID, negativeImpact: info.negativeImpact, apply: applyNegativeImpact)
        }
        memo.status = memo.status == .archived ? .active : .archived
        try? modelContext.save()
        NotificationCenter.default.postAppEvent(.memoStatusDidChange)
    }
    
    func moveMemos(from source: IndexSet, to destination: Int) {
        hapticManager.playHaptic(style: .medium)
        var reordered = filteredAndSortedItems
        guard !reordered.isEmpty else { return }
        reordered.move(fromOffsets: source, toOffset: destination)

        // Пересчитываем `orderIndex` для **всех** мемо: иначе при фильтре получаются дубликаты индексов
        // и при сортировке «по дате» сохранённый порядок всё равно не отображается.
        let filteredIDs = Set(reordered.map(\.id))
        var sortedIDs = memoItems
            .sorted { memoItemsManualBaselineCompare($0, $1) }
            .map(\.id)
        let blockIDs = reordered.map(\.id)
        if let firstIdx = sortedIDs.firstIndex(where: { filteredIDs.contains($0) }) {
            sortedIDs.removeAll { filteredIDs.contains($0) }
            sortedIDs.insert(contentsOf: blockIDs, at: firstIdx)
        } else {
            sortedIDs = blockIDs
        }

        let byID = Dictionary(uniqueKeysWithValues: memoItems.map { ($0.id, $0) })
        for (index, id) in sortedIDs.enumerated() {
            byID[id]?.orderIndex = index
        }

        do {
            try modelContext.save()
            NotificationCenter.default.postAppEvent(.memoStatusDidChange)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                memosOrderKey = UUID()
            }
        } catch {
            print("Error saving memo order: \(error)")
        }
    }

    /// Совпадает с базовой сортировкой `FilterMemoItemsUseCase` (status → orderIndex → creationDate → id).
    private func memoItemsManualBaselineCompare(_ a: MemoItem, _ b: MemoItem) -> Bool {
        if a.status != b.status { return a.status == .active }
        if a.orderIndex != b.orderIndex { return a.orderIndex < b.orderIndex }
        if a.creationDate != b.creationDate { return a.creationDate > b.creationDate }
        return a.id.uuidString < b.id.uuidString
    }
    
    func duplicateMemo(_ memo: MemoItem) {
        let duplicatedMemo = MemoItem(
            title: "\(memo.title) (copy)",
            description: memo.descript,
            orderIndex: memo.orderIndex,
            type: memo.itemType,
            tags: memo.tags,
            status: memo.status,
            isMockData: memo.isMockData
        )
        duplicatedMemo.contentData = memo.contentData
        modelContext.insert(duplicatedMemo)

        do {
            try modelContext.save()
        } catch {
            print("Error duplicating memo: \(error)")
        }
    }

    // Miss decrease flow is now handled via `ImpactActionDialog` (same as Goals/Tasks).

    func incrementCounterByStep(_ item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoCounterContent.self, from: $0) }) else { return }
        let step = counterEffectiveStep(content)
        let oldValue = content.currentValue
        let newValue = content.currentValue + step
        guard newValue != oldValue else { return }
        content.currentValue = newValue
        content.history.append(MemoCounterContent.CounterEntry(date: Date(), value: newValue, note: ""))
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
            memosOrderKey = UUID()
        }
    }

    func decrementCounterByStep(_ item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoCounterContent.self, from: $0) }) else { return }
        let step = counterEffectiveStep(content)
        let oldValue = content.currentValue
        let newValue = max(0, content.currentValue - step)
        guard newValue != oldValue else { return }
        content.currentValue = newValue
        content.history.append(MemoCounterContent.CounterEntry(date: Date(), value: newValue, note: ""))
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
            memosOrderKey = UUID()
        }
    }

    func counterEffectiveStep(_ content: MemoCounterContent) -> Double {
        let raw = content.stepValue
        let positive = raw > 0 ? raw : 1
        let clamped = max(0.01, positive)
        return (clamped * 100).rounded() / 100
    }

    @ViewBuilder
    func leadingSwipeButton(for item: MemoItem) -> some View {
        switch item.itemType {
        case .noteAlbum:
            HStack {
                Button {
                    selectedMemoItem = item
                    triggerAddNoteForAlbum = true
                } label: { Image(systemName: "checkmark") }
                .tint(.green)
            }
        case .counter:
            HStack {
                Button {
                    incrementCounterByStep(item)
                } label: { Image(systemName: "checkmark") }
                .tint(.green)

                Button {
                    decrementCounterByStep(item)
                } label: { Image(systemName: "arrow.uturn.left") }
                .tint(.gray)
            }
        case .list:
            HStack {
                Button {
                    selectedMemoItem = item
                    triggerAddListItemForList = true
                } label: { Image(systemName: "checkmark") }
                .tint(.green)
            }
        case .health:
            HStack {
                Button {
                    incrementHealthByStep(item)
                } label: { Image(systemName: "checkmark") }
                .tint(.green)

                Button {
                    decrementHealthByStep(item)
                } label: { Image(systemName: "arrow.uturn.left") }
                .tint(.gray)
            }
        case .skill:
            HStack {
                Button {
                    incrementSkillByStep(item)
                } label: { Image(systemName: "checkmark") }
                .tint(.green)

                Button {
                    decrementSkillByStep(item)
                } label: { Image(systemName: "arrow.uturn.left") }
                .tint(.gray)
            }
        case .budget:
            HStack {
                Button {
                    addBudgetStep(item)
                } label: { Image(systemName: "checkmark") }
                .tint(.green)

                Button {
                    subtractBudgetStep(item)
                } label: { Image(systemName: "arrow.uturn.left") }
                .tint(.gray)
            }
        case .time:
            HStack {
                Button {
                    addTimeStep(item)
                } label: { Image(systemName: "checkmark") }
                .tint(.green)

                Button {
                    subtractTimeStep(item)
                } label: { Image(systemName: "arrow.uturn.left") }
                .tint(.gray)
            }
        case .mood:
            Button {
                selectedMemoItem = item
            } label: { Image(systemName: "face.smiling") }
            .tint(.green)
        case .streak:
            if hasStreak(on: calendarManager.selectedDate, for: item) {
                Button {
                    toggleStreak(on: calendarManager.selectedDate, for: item)
                } label: { Image(systemName: "arrow.uturn.backward") }
                .tint(Color(UIColor.systemGray))
            } else {
                Button {
                    toggleStreak(on: calendarManager.selectedDate, for: item)
                } label: { Image(systemName: "flame.fill") }
                .tint(.green)
            }
        case .calendar:
            HStack {
                Button {
                    selectedMemoItem = item
                } label: { Image(systemName: "plus.circle") }
                .tint(.green)
            }
        }
    }

    func hasStreak(on referenceDay: Date, for item: MemoItem) -> Bool {
        guard let content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoStreakContent.self, from: $0) }) else { return false }
        let day = Calendar.current.startOfDay(for: referenceDay)
        return content.checkHistory.contains { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    func incrementHealthByStep(_ item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoHealthContent.self, from: $0) }) else { return }
        let step = max(0.1, content.stepValue)
        let oldValue = content.currentValue
        let newValue = content.currentValue + step
        guard newValue != oldValue else { return }
        content.currentValue = newValue
        content.entries.append(MemoHealthContent.HealthEntry(date: Date(), value: step, note: ""))
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
            memosOrderKey = UUID()
        }
    }

    func decrementHealthByStep(_ item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoHealthContent.self, from: $0) }) else { return }
        let step = max(0.1, content.stepValue)
        let oldValue = content.currentValue
        let newValue = max(0, content.currentValue - step)
        guard newValue != oldValue else { return }
        let delta = newValue - oldValue
        content.currentValue = newValue
        content.entries.append(MemoHealthContent.HealthEntry(date: Date(), value: delta, note: ""))
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
            memosOrderKey = UUID()
        }
    }

    func incrementSkillByStep(_ item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoSkillContent.self, from: $0) }) else { return }
        guard var skill = content.skills.first else { return }
        let step = max(0.1, content.stepValue)
        let maxLevel = Double(max(1, content.scale))
        let oldLevel = skill.currentLevel
        let newLevel = min(skill.currentLevel + step, maxLevel)
        guard newLevel != oldLevel else { return }
        skill.currentLevel = newLevel
        skill.history.append(MemoSkillContent.SkillItem.SkillEntry(date: Date(), level: newLevel, note: ""))
        content.skills[0] = skill
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
            memosOrderKey = UUID()
        }
    }

    func decrementSkillByStep(_ item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoSkillContent.self, from: $0) }) else { return }
        guard var skill = content.skills.first else { return }
        let step = max(0.1, content.stepValue)
        let minLevel: Double = 0
        let oldLevel = skill.currentLevel
        let newLevel = max(minLevel, skill.currentLevel - step)
        guard newLevel != oldLevel else { return }
        skill.currentLevel = newLevel
        skill.history.append(MemoSkillContent.SkillItem.SkillEntry(date: Date(), level: newLevel, note: ""))
        content.skills[0] = skill
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
            memosOrderKey = UUID()
        }
    }

    func addBudgetStep(_ item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoBudgetContent.self, from: $0) }) else { return }
        guard var budget = content.budgets.first else { return }
        let step = content.stepValue
        budget.currentBalance += step
        budget.transactions.append(MemoBudgetContent.BudgetItem.BudgetTransaction(date: Date(), amount: step, note: ""))
        content.budgets[0] = budget
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
            memosOrderKey = UUID()
        }
    }

    func subtractBudgetStep(_ item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoBudgetContent.self, from: $0) }) else { return }
        guard var budget = content.budgets.first else { return }
        let step = content.stepValue
        budget.currentBalance -= step
        budget.transactions.append(MemoBudgetContent.BudgetItem.BudgetTransaction(date: Date(), amount: -step, note: ""))
        content.budgets[0] = budget
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
            memosOrderKey = UUID()
        }
    }

    func addTimeStep(_ item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoTimeContent.self, from: $0) }) else { return }
        let step = max(1, content.stepMinutes)
        let oldMinutes = content.currentMinutes
        let newMinutes = content.currentMinutes + step
        guard newMinutes != oldMinutes else { return }
        content.currentMinutes = newMinutes
        content.entries.append(MemoTimeContent.TimeEntry(date: Date(), minutes: step, note: ""))
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
            memosOrderKey = UUID()
        }
    }

    func subtractTimeStep(_ item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoTimeContent.self, from: $0) }) else { return }
        let step = max(1, content.stepMinutes)
        let oldValue = content.currentMinutes
        let newValue = max(0, content.currentMinutes - step)
        guard newValue != oldValue else { return }
        let delta = newValue - oldValue
        content.currentMinutes = newValue
        content.entries.append(MemoTimeContent.TimeEntry(date: Date(), minutes: delta, note: ""))
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
            memosOrderKey = UUID()
        }
    }

    func toggleStreak(on referenceDay: Date, for item: MemoItem) {
        guard var content = (item.contentData.flatMap { try? JSONDecoder().decode(MemoStreakContent.self, from: $0) }) else { return }
        let day = Calendar.current.startOfDay(for: referenceDay)
        let hasDay = content.checkHistory.contains { Calendar.current.isDate($0.date, inSameDayAs: day) }
        if hasDay {
            content.checkHistory.removeAll { Calendar.current.isDate($0.date, inSameDayAs: day) }
        } else {
            content.checkHistory.append(MemoStreakContent.StreakCheckEntry(date: day, note: ""))
        }
        let (current, best) = MemoStreakContent.recalculateStreakValues(history: content.checkHistory, existingBest: content.bestStreak)
        content.currentStreak = current
        content.bestStreak = best
        if let data = try? JSONEncoder().encode(content) {
            item.contentData = data
            try? modelContext.save()
            memosOrderKey = UUID()
        }
    }
    
    func startQuickHealthCreation() {
        hapticManager.selectionChanged()
        let newMemo = MemoItem(
            title: MemoItemType.health.displayName,
            orderIndex: Int(Date().timeIntervalSince1970),
            type: .health
        )
        
        if let data = try? JSONEncoder().encode(MemoHealthContent()) {
            newMemo.contentData = data
        }
        
        modelContext.insert(newMemo)
        
        do {
            try modelContext.save()
            selectedMemoItem = newMemo
        } catch {
            print("Error creating quick health memo: \(error)")
        }
    }
    
    func createMemoFromQuickNoteAlbum(_ note: MemoNoteAlbumItem) {
        var sanitizedNote = note
        let trimmedTitle = sanitizedNote.title.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitizedNote.title = trimmedTitle
        
        let memoTitle = trimmedTitle.isEmpty ? "Untitled" : trimmedTitle
        let orderIndex = Int(Date().timeIntervalSince1970)
        
        let newMemo = MemoItem(
            title: memoTitle,
            orderIndex: orderIndex,
            type: .noteAlbum
        )
        
        if let data = try? JSONEncoder().encode([sanitizedNote]) {
            newMemo.contentData = data
        }
        
        modelContext.insert(newMemo)
        
        do {
            try modelContext.save()
            hapticManager.completionSuccess()
        } catch {
            print("Error saving quick note memo: \(error)")
        }
    }
    
    func createMemoFromQuickSkill(_ skill: MemoSkillContent.SkillItem) {
        var content = MemoSkillContent()
        var sanitizedSkill = skill
        sanitizedSkill.name = sanitizedSkill.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitizedSkill.name.isEmpty {
            sanitizedSkill.name = MemoItemType.skill.displayName
        }
        
        // Add initial history entry
        var skillWithHistory = sanitizedSkill
        skillWithHistory.history.append(
            MemoSkillContent.SkillItem.SkillEntry(
                date: Date(),
                level: sanitizedSkill.currentLevel,
                    note: "Initial level"
            )
        )
        
        content.skills = [skillWithHistory]
        content.currentLevel = sanitizedSkill.currentLevel
        content.colorHex = sanitizedSkill.colorHex
        content.iconName = sanitizedSkill.iconName
        content.customImageData = sanitizedSkill.customImageData
        
        let orderIndex = Int(Date().timeIntervalSince1970)
        let newMemo = MemoItem(
            title: sanitizedSkill.name,
            orderIndex: orderIndex,
            type: .skill
        )
        
        if let data = try? JSONEncoder().encode(content) {
            newMemo.contentData = data
        }
        
        modelContext.insert(newMemo)
        
        do {
            try modelContext.save()
            selectedMemoItem = newMemo
            hapticManager.completionSuccess()
        } catch {
            print("Error creating quick skill memo: \(error)")
        }
    }
    
    

}

