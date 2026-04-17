import SwiftUI
import SwiftData

extension MemoCardView {
    // MARK: Тап: одиночный — раскрыть/свернуть карточку; двойной — открыть detail (`onDoubleTap`)
    func handleTap() {
        if tapCount == 0 {
            tapCount = 1
            tapWorkItem?.cancel()
            hapticManager.selectionChanged()
            let work = DispatchWorkItem {
                withAnimation(CardExpansionAnimation.spring) {
                    showDetails.toggle()
                }
                tapCount = 0
            }
            tapWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: work)
        } else {
            tapWorkItem?.cancel()
            tapCount = 0
            hapticManager.selectionChanged()
            onDoubleTap?()
        }
    }
    
    // MARK: Пульс кольца и цвета иконки
    var outerPulseScale: CGFloat {
        return outerPulse ? 1.08 : 0.96
    }
    
    var isArchived: Bool {
        memoItem.status == .archived
    }
    
    /// Для streak: есть ли отметка в выбранном дне календаря (или сегодня, если дата не передана).
    var isStreakMarkedOnReferenceDay: Bool {
        guard memoItem.itemType == .streak,
              let data = memoItem.contentData,
              let content = try? JSONDecoder().decode(MemoStreakContent.self, from: data) else {
            return true
        }
        let dayStart = Calendar.current.startOfDay(for: streakReferenceDate ?? Date())
        return content.checkHistory.contains { Calendar.current.isDate($0.date, inSameDayAs: dayStart) }
    }
    
    /// Как в Habits: в Rainbow глифы иконки — белые на градиенте; в Basic — цвет типа.
    func iconColor(for typeColor: Color) -> Color {
        if isArchived { return .gray }
        if design == .rainbow { return .white }
        return typeColor
    }
    
    func iconRingColor(for typeColor: Color) -> Color {
        isArchived ? .gray : (design == .rainbow ? .white : typeColor)
    }
    
    func iconFillColor(for typeColor: Color) -> Color {
        isArchived ? Color.gray.opacity(0.2) : (design == .rainbow ? Color.white.opacity(0.2) : typeColor.opacity(0.2))
    }
    
    func updateOuterPulse() {
        // Отменяем предыдущую анимацию, если она есть
        animationTask?.cancel()
        
        outerPulse = false
        
        // Анимация 1 пульсация
        animationTask = Task {
            for _ in 0..<1 {
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 1.0)) {
                    outerPulse = true
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
                
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 1.0)) {
                    outerPulse = false
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
            }
            // После 1 пульсации остаемся в широком положении
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 1.0)) {
                outerPulse = true
            }
        }
    }

    // MARK: Шаблон: слева иконка, справа заголовок и опционально детали
    @ViewBuilder
    func memoContentWithIcon<ExpandedContent: View>(icon: @escaping () -> AnyView, rightContent: @escaping () -> AnyView, expandedExtraContent: @escaping () -> ExpandedContent = { EmptyView() }) -> some View {
        if showDetails {
            HStack(alignment: .center, spacing: 12) {
                VStack {
                    Spacer(minLength: 0)
                    icon()
                    Spacer(minLength: 0)
                }
                .frame(width: 60, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 10) {
                    titleView
                    expandedExtraContent()
                    memoDetails
                    memoExpandedDescriptionSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.trailing, 16)
            }
            .padding(.leading, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 72, alignment: .center)
        } else {
            HStack(alignment: .center, spacing: 12) {
                VStack {
                    Spacer(minLength: 0)
                    icon()
                    Spacer(minLength: 0)
                }
                .frame(width: 60, alignment: .leading)
                titleView
                    .layoutPriority(0)
                Spacer(minLength: 8)
                rightContent()
                    .memoCollapsedTrailingBadgeChrome()
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 50)
        }
    }
    
    // MARK: List и альбом заметок: иконки и счётчики в бейдже
    @ViewBuilder
    var listIcon: some View {
        let (listIconName, listColor): (String, Color) = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoListContent.self, from: data) {
                return (content.iconName, Color(hex: content.colorHex))
            }
            return (memoItem.itemType.iconName, memoItem.itemType.color)
        }()
        ZStack {
            Circle()
                .stroke(iconRingColor(for: listColor).opacity(outerPulseScale > 1.0 ? 0.6 : 0.3), lineWidth: 3)
                .frame(width: 48, height: 48)
                .scaleEffect(outerPulseScale)
            Circle()
                .fill(iconFillColor(for: listColor))
                .frame(width: 40, height: 40)
            Image(systemName: listIconName)
                .foregroundColor(iconColor(for: listColor))
                .font(.system(size: 20, weight: .semibold))
        }
    }

    @ViewBuilder
    func noteAlbumBadgeView(isDetailChip: Bool = false) -> some View {
        let count: Int = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoNoteAlbumContent.self, from: data) {
                return content.notes.count
            }
            return 0
        }()
        let badgeColor = isArchived ? Color.gray : (memoItem.contentData.flatMap { try? JSONDecoder().decode(MemoNoteAlbumContent.self, from: $0) }.map { Color(hex: $0.colorHex) } ?? memoItem.itemType.color)
        let label = count == 1 ? "note" : "notes"
        let line = "\(count) \(label)"
        if isDetailChip {
            memoValueDetailChip {
                Text(line)
                    .font(.caption2)
                    .foregroundColor(memoDetailChipTextColor)
            }
        } else {
            Text(line)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(design == .rainbow ? .white.opacity(0.9) : (isArchived ? .secondary : badgeColor))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(design == .rainbow ? Color.white.opacity(0.2) : (isArchived ? Color(UIColor.systemGray5) : badgeColor.opacity(0.2)))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .floatingBadgeStyle()
        }
    }

    @ViewBuilder
    func listBadgeView(isDetailChip: Bool = false) -> some View {
        let count: Int = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoListContent.self, from: data) {
                return content.items.count
            }
            return 0
        }()
        let badgeColor = isArchived ? Color.gray : (memoItem.contentData.flatMap { try? JSONDecoder().decode(MemoListContent.self, from: $0) }.map { Color(hex: $0.colorHex) } ?? memoItem.itemType.color)
        let label = count == 1 ? "item" : "items"
        let line = "\(count) \(label)"
        if isDetailChip {
            memoValueDetailChip {
                Text(line)
                    .font(.caption2)
                    .foregroundColor(memoDetailChipTextColor)
            }
        } else {
            Text(line)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(design == .rainbow ? .white.opacity(0.9) : (isArchived ? .secondary : badgeColor))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(design == .rainbow ? Color.white.opacity(0.2) : (isArchived ? Color(UIColor.systemGray5) : badgeColor.opacity(0.2)))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .floatingBadgeStyle()
        }
    }
    
    @ViewBuilder
    var noteAlbumIcon: some View {
        let isArchived = memoItem.status == .archived
        let noteAlbumIconName: String = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoNoteAlbumContent.self, from: data) {
                return content.iconName
            }
            return memoItem.itemType.iconName
        }()
        let noteAlbumColor: Color = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoNoteAlbumContent.self, from: data) {
                return Color(hex: content.colorHex)
            }
            return memoItem.itemType.color
        }()
        let ringColor: Color = isArchived ? .gray : (design == .rainbow ? .white : noteAlbumColor)
        ZStack {
            Circle()
                .stroke(ringColor.opacity(outerPulseScale > 1.0 ? 0.6 : 0.3), lineWidth: 3)
                .frame(width: 48, height: 48)
                .scaleEffect(outerPulseScale)
            Circle()
                .fill((isArchived ? Color.gray.opacity(0.2) : (design == .rainbow ? Color.white.opacity(0.2) : noteAlbumColor.opacity(0.2))))
                .frame(width: 40, height: 40)
            Image(systemName: noteAlbumIconName)
                .foregroundColor(isArchived ? .gray : (design == .rainbow ? .white : noteAlbumColor))
                .font(.system(size: 20, weight: .semibold))
        }
    }
    
    // MARK: Заголовок (как Goals/Tasks/Habits: .headline, без обводки)
    var displayTitle: String {
        if memoItem.itemType == .noteAlbum {
            let t = memoItem.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty || t == "Мои заметки" || t == "Альбом заметок" { return "My notes" }
        }
        return memoItem.title
    }
    
    @ViewBuilder
    var titleView: some View {
        let isArchived = memoItem.status == .archived
        let leftTitleColorBasic = isArchived ? Color.gray.opacity(0.5) : Color.primary.opacity(0.8)
        let leftTitleColorRainbow: Color = isArchived ? Color.gray.opacity(0.7) : .white
        
        Text(displayTitle)
            .font(.headline)
            .foregroundColor(design == .rainbow ? leftTitleColorRainbow : leftTitleColorBasic)
            .strikethrough(isArchived)
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
    }

    // MARK: Диспетчер превью по `MemoItemType`
    @ViewBuilder
    var contentPreview: some View {
        switch memoItem.itemType {
        case .noteAlbum:
            memoContentWithIcon(
                icon: { AnyView(noteAlbumIcon) },
                rightContent: { AnyView(noteAlbumBadgeView()) }
            )

        case .list:
            memoContentWithIcon(icon: { AnyView(listIcon) }, rightContent: { AnyView(listBadgeView()) })

        case .counter:
            if let data = memoItem.contentData, let counter = try? JSONDecoder().decode(MemoCounterContent.self, from: data) {
                let current = counter.currentValue
                let targetRaw = counter.targetValue ?? 1.0
                let target = max(targetRaw, 1.0)
                let iconName = counter.iconName.isEmpty ? memoItem.itemType.iconName : counter.iconName
                let customImageData = counter.customImageData
                let unitText = counter.unit
                let counterColor = Color(hex: counter.colorHex)
                if showDetails {
                    HStack(alignment: .center, spacing: 12) {
                        VStack { Spacer(minLength: 0); streakIconView(name: iconName, customData: customImageData, color: counterColor); Spacer(minLength: 0) }
                            .frame(width: 60, alignment: .leading)
                        VStack(alignment: .leading, spacing: 10) {
                            titleView
                            memoDetails
                            memoExpandedDescriptionSection
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.trailing, 16)
                    }
                    .padding(.leading, 16)
                    .padding(.vertical, 10)
                    .frame(minHeight: 72, alignment: .center)
                } else {
                    HStack(alignment: .center, spacing: 12) {
                        VStack {
                            Spacer(minLength: 0)
                            streakIconView(name: iconName, customData: customImageData, color: counterColor)
                            Spacer(minLength: 0)
                        }
                        .frame(width: 60, alignment: .leading)
                        titleView
                            .layoutPriority(0)
                        Spacer(minLength: 8)
                        counterBadgeView(counter: counter, current: current, target: target, unitText: unitText)
                            .memoCollapsedTrailingBadgeChrome()
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
            } else {
                Text("Counter is not configured")
                    .foregroundColor(.secondary)
            }

        case .streak:
            streakMemoContent

        case .mood:
            moodMemoContent

        case .skill:
            skillMemoContent

        case .budget:
            budgetMemoContent

        case .time:
            timeMemoContent

        case .health:
            healthMemoContent

        case .calendar:
            calendarMemoContent
        }
    }

    // MARK: Счётчик: бейдж и инкремент по тапу
    @ViewBuilder
    func counterBadgeView(counter: MemoCounterContent, current: Double, target: Double, unitText: String, isDetailChip: Bool = false) -> some View {
        let badgeColor = isArchived ? Color.gray : Color(hex: counter.colorHex)
        let hasUnit = !unitText.trimmingCharacters(in: .whitespaces).isEmpty
        let counterTapBlock: () -> Void = {
            var updated = counter
            let oldValue = updated.currentValue
            let newVal = updated.currentValue + 1.0
            if let target = updated.targetValue {
                if newVal <= target {
                    updated.currentValue = newVal
                }
            } else {
                updated.currentValue = newVal
            }
            guard updated.currentValue != oldValue else { return }
            updated.history.append(MemoCounterContent.CounterEntry(date: Date(), value: updated.currentValue, note: ""))
            if let encoded = try? JSONEncoder().encode(updated) {
                memoItem.contentData = encoded
                try? modelContext.save()
            }
        }
        let counterLongPressBlock: () -> Void = {
            var updated = counter
            let oldValue = updated.currentValue
            updated.currentValue = max(updated.currentValue - 1.0, 0)
            guard updated.currentValue != oldValue else { return }
            updated.history.append(MemoCounterContent.CounterEntry(date: Date(), value: updated.currentValue, note: ""))
            if let encoded = try? JSONEncoder().encode(updated) {
                memoItem.contentData = encoded
                try? modelContext.save()
            }
        }
        if isDetailChip {
            memoValueDetailChip {
                counterBadgeCore(counter: counter, current: current, target: target, unitText: unitText, hasUnit: hasUnit, detailChip: true)
            }
            .contentShape(RoundedRectangle(cornerRadius: ListDetailChipMetrics.cornerRadius, style: .continuous))
            .onTapGesture(perform: counterTapBlock)
            .onLongPressGesture(minimumDuration: 0.3, perform: counterLongPressBlock)
        } else {
            counterBadgeCore(counter: counter, current: current, target: target, unitText: unitText, hasUnit: hasUnit, detailChip: false)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(design == .rainbow ? .white.opacity(0.9) : (isArchived ? .secondary : badgeColor))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(design == .rainbow ? Color.white.opacity(0.2) : (isArchived ? Color(UIColor.systemGray5) : badgeColor.opacity(0.2)))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .floatingBadgeStyle()
                .onTapGesture(perform: counterTapBlock)
                .onLongPressGesture(minimumDuration: 0.3, perform: counterLongPressBlock)
        }
    }

    @ViewBuilder
    private func counterBadgeCore(counter: MemoCounterContent, current: Double, target: Double, unitText: String, hasUnit: Bool, detailChip: Bool) -> some View {
        if detailChip {
            if hasUnit {
                if counter.targetValue != nil {
                    Text("\(formatCounterValue(current))/\(formatCounterValue(target)) \(unitText)")
                        .font(.caption2)
                        .foregroundColor(memoDetailChipTextColor)
                } else {
                    Text("\(formatCounterValue(current)) \(unitText)")
                        .font(.caption2)
                        .foregroundColor(memoDetailChipTextColor)
                }
            } else if counter.targetValue != nil {
                Text("\(formatCounterValue(current))/\(formatCounterValue(target))")
                    .font(.caption2)
                    .foregroundColor(memoDetailChipTextColor)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "number")
                        .font(.caption2)
                        .foregroundColor(memoDetailChipIconColor)
                    Text(formatCounterValue(current))
                        .font(.caption2)
                        .foregroundColor(memoDetailChipTextColor)
                }
            }
        } else {
            Group {
                if hasUnit {
                    if counter.targetValue != nil {
                        Text("\(formatCounterValue(current))/\(formatCounterValue(target)) \(unitText)")
                    } else {
                        Text("\(formatCounterValue(current)) \(unitText)")
                    }
                } else if counter.targetValue != nil {
                    Text("\(formatCounterValue(current))/\(formatCounterValue(target))")
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.system(size: 14, weight: .semibold))
                        Text(formatCounterValue(current))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                }
            }
        }
    }

    // MARK: Форматирование числа для бейджа счётчика
    func formatCounterValue(_ value: Double) -> String {
        if value.rounded(.towardZero) == value {
            return String(Int(value))
        }
        // Форматируем с 2 знаками и убираем лишние нули/точку
        var s = String(format: "%.2f", value)
        if let dotIndex = s.firstIndex(of: ".") {
            while s.last == "0" {
                s.removeLast()
            }
            if s.last == "." {
                s.removeLast()
            }
            // Если после обрезки осталось только знак или строка пустая, возвращаем исходное значение
            if s[dotIndex...].isEmpty {
                return String(Int(value))
            }
        }
        return s
    }
    
    // MARK: Streak: разметка превью
    @ViewBuilder
    var streakMemoContent: some View {
        let streakIconName: String = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoStreakContent.self, from: data) {
                return content.iconName
            }
            return memoItem.itemType.iconName
        }()
        let streakCustomImageData: Data? = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoStreakContent.self, from: data) {
                return content.customImageData
            }
            return nil
        }()
        let streakColor: Color = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoStreakContent.self, from: data) {
                return Color(hex: content.colorHex)
            }
            return memoItem.itemType.color
        }()
        let streakValue: Int = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoStreakContent.self, from: data) {
                return content.currentStreak
            }
            return 0
        }()
        let streakBadge = streakBadgeView(value: streakValue, isMarkedOnReferenceDay: isStreakMarkedOnReferenceDay)
        if showDetails {
            HStack(alignment: .center, spacing: 12) {
                VStack { Spacer(minLength: 0); streakIconView(name: streakIconName, customData: streakCustomImageData, color: streakColor); Spacer(minLength: 0) }
                    .frame(width: 60, alignment: .leading)
                VStack(alignment: .leading, spacing: 10) {
                    titleView
                    memoDetails
                    memoExpandedDescriptionSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.trailing, 16)
            }
            .padding(.leading, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 72, alignment: .center)
        } else {
            HStack(alignment: .center, spacing: 12) {
                VStack {
                    Spacer(minLength: 0)
                    streakIconView(name: streakIconName, customData: streakCustomImageData, color: streakColor)
                    Spacer(minLength: 0)
                }
                .frame(width: 60, alignment: .leading)
                titleView
                    .layoutPriority(0)
                Spacer(minLength: 8)
                streakBadge
                    .memoCollapsedTrailingBadgeChrome()
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 50)
        }
    }

    // MARK: Streak: круглая иконка и число дней
    @ViewBuilder
    func streakIconView(name: String, customData: Data?, color: Color) -> some View {
        ZStack {
            Circle()
                .stroke(iconRingColor(for: color).opacity(outerPulseScale > 1.0 ? 0.6 : 0.3), lineWidth: 3)
                .frame(width: 48, height: 48)
                .scaleEffect(outerPulseScale)
            Circle()
                .fill(iconFillColor(for: color))
                .frame(width: 40, height: 40)
            if let imageData = customData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
            } else {
                Image(systemName: name)
                    .foregroundColor(iconColor(for: color))
                    .font(.system(size: 20, weight: .semibold))
            }
        }
    }
    
    // MARK: Streak: бейдж с числом дней
    @ViewBuilder
    func streakBadgeView(value: Int, isDetailChip: Bool = false, isMarkedOnReferenceDay: Bool = true) -> some View {
        let streakColor: Color = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoStreakContent.self, from: data) {
                return isArchived ? .gray : Color(hex: content.colorHex)
            }
            return memoItem.itemType.color
        }()
        let muted = !isMarkedOnReferenceDay && !isArchived
        let badgeIconColor: Color = {
            if muted { return design == .rainbow ? .white.opacity(0.55) : Color.secondary }
            if design == .rainbow { return .white.opacity(0.9) }
            return isArchived ? .secondary : streakColor
        }()
        let badgeFill: Color = {
            if muted { return design == .rainbow ? Color.white.opacity(0.12) : Color(UIColor.systemGray5) }
            if design == .rainbow { return Color.white.opacity(0.2) }
            return isArchived ? Color(UIColor.systemGray5) : streakColor.opacity(0.2)
        }()
        if isDetailChip {
            memoValueDetailChip {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundColor(muted ? Color.secondary : memoDetailChipIconColor)
                    Text("\(value)")
                        .font(.caption2)
                        .foregroundColor(muted ? Color.secondary : memoDetailChipTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(badgeIconColor)
                Text("\(value)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(badgeIconColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(badgeFill)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .floatingBadgeStyle()
        }
    }
    
    // MARK: Настроение: превью и бейдж
    @ViewBuilder
    var moodMemoContent: some View {
        let moodIconName: String = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoMoodContent.self, from: data) {
                return content.iconName
            }
            return memoItem.itemType.iconName
        }()
        let moodCustomImageData: Data? = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoMoodContent.self, from: data) {
                return content.customImageData
            }
            return nil
        }()
        let moodColor: Color = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoMoodContent.self, from: data) {
                return Color(hex: content.colorHex)
            }
            return memoItem.itemType.color
        }()
        let moodBadge = moodBadgeView()
        if showDetails {
            HStack(alignment: .center, spacing: 12) {
                VStack { Spacer(minLength: 0); streakIconView(name: moodIconName, customData: moodCustomImageData, color: moodColor); Spacer(minLength: 0) }
                    .frame(width: 60, alignment: .leading)
                VStack(alignment: .leading, spacing: 10) {
                    titleView
                    memoDetails
                    memoExpandedDescriptionSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.trailing, 16)
            }
            .padding(.leading, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 72, alignment: .center)
        } else {
            HStack(alignment: .center, spacing: 12) {
                VStack {
                    Spacer(minLength: 0)
                    streakIconView(name: moodIconName, customData: moodCustomImageData, color: moodColor)
                    Spacer(minLength: 0)
                }
                .frame(width: 60, alignment: .leading)
                titleView
                    .layoutPriority(0)
                Spacer(minLength: 8)
                moodBadge
                    .memoCollapsedTrailingBadgeChrome()
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 50)
        }
    }
    
    // MARK: Настроение: бейдж (оценка или пусто)
    @ViewBuilder
    func moodBadgeView(isDetailChip: Bool = false) -> some View {
        let moodColor: Color = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoMoodContent.self, from: data) {
                return isArchived ? .gray : Color(hex: content.colorHex)
            }
            return memoItem.itemType.color
        }()
        if let data = memoItem.contentData,
           let content = try? JSONDecoder().decode(MemoMoodContent.self, from: data),
           let todayMood = content.entries.first(where: { Calendar.current.isDateInToday($0.date) }) {
            if isDetailChip {
                memoValueDetailChip {
                    HStack(spacing: 4) {
                        Image(systemName: content.iconName)
                            .font(.caption2)
                            .foregroundColor(memoDetailChipIconColor)
                        Text("\(todayMood.value)")
                            .font(.caption2)
                            .foregroundColor(memoDetailChipTextColor)
                    }
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: content.iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(design == .rainbow ? .white.opacity(0.9) : (isArchived ? .secondary : moodColor))
                    Text("\(todayMood.value)")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(design == .rainbow ? .white.opacity(0.9) : (isArchived ? .secondary : moodColor))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(design == .rainbow ? Color.white.opacity(0.2) : (isArchived ? Color(UIColor.systemGray5) : moodColor.opacity(0.2)))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .floatingBadgeStyle()
            }
        } else if isDetailChip {
            memoValueDetailChip {
                Image(systemName: "circle.dashed")
                    .font(.caption2)
                    .foregroundColor(memoDetailChipIconColor)
            }
        } else {
            Image(systemName: "circle.dashed")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(design == .rainbow ? .white.opacity(0.9) : (isArchived ? .secondary : moodColor))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(design == .rainbow ? Color.white.opacity(0.2) : (isArchived ? Color(UIColor.systemGray5) : moodColor.opacity(0.2)))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .floatingBadgeStyle()
        }
    }
    
    // MARK: Навык: превью и бейдж уровня
    @ViewBuilder
    var skillMemoContent: some View {
        let iconName: String = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoSkillContent.self, from: data) {
                return content.iconName
            }
            return memoItem.itemType.iconName
        }()
        let customData: Data? = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoSkillContent.self, from: data) {
                return content.customImageData
            }
            return nil
        }()
        let color: Color = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoSkillContent.self, from: data) {
                return Color(hex: content.colorHex)
            }
            return memoItem.itemType.color
        }()
        let badge = skillBadgeView()
        if showDetails {
            HStack(alignment: .center, spacing: 12) {
                VStack { Spacer(minLength: 0); streakIconView(name: iconName, customData: customData, color: color); Spacer(minLength: 0) }
                    .frame(width: 60, alignment: .leading)
                VStack(alignment: .leading, spacing: 10) {
                    titleView
                    memoDetails
                    memoExpandedDescriptionSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.trailing, 16)
            }
            .padding(.leading, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 72, alignment: .center)
        } else {
            HStack(alignment: .center, spacing: 12) {
                VStack {
                    Spacer(minLength: 0)
                    streakIconView(name: iconName, customData: customData, color: color)
                    Spacer(minLength: 0)
                }
                .frame(width: 60, alignment: .leading)
                titleView
                    .layoutPriority(0)
                Spacer(minLength: 8)
                badge
                    .memoCollapsedTrailingBadgeChrome()
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 50)
        }
    }
    
    // MARK: Навык: бейдж уровня / цели
    @ViewBuilder
    func skillBadgeView(isDetailChip: Bool = false) -> some View {
        let skillColor: Color = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoSkillContent.self, from: data) {
                return isArchived ? .gray : Color(hex: content.colorHex)
            }
            return memoItem.itemType.color
        }()
        let displayText: String = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoSkillContent.self, from: data),
               let firstSkill = content.skills.first {
                if let target = firstSkill.targetLevel {
                    return "\(Int(firstSkill.currentLevel))/\(Int(target))"
                }
                return String(format: "%.1f", firstSkill.currentLevel)
            }
            return "0"
        }()
        if isDetailChip {
            memoValueDetailChip {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(memoDetailChipIconColor)
                    Text(displayText)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundColor(memoDetailChipTextColor)
                }
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(design == .rainbow ? .white.opacity(0.9) : (isArchived ? .secondary : skillColor))
                Text(displayText)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundColor(design == .rainbow ? .white.opacity(0.9) : (isArchived ? .secondary : skillColor))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(design == .rainbow ? Color.white.opacity(0.2) : (isArchived ? Color(UIColor.systemGray5) : skillColor.opacity(0.2)))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .floatingBadgeStyle()
        }
    }
    
    // MARK: Бюджет: превью и баланс
    @ViewBuilder
    var budgetMemoContent: some View {
        let iconName: String = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoBudgetContent.self, from: data) {
                return content.iconName
            }
            return memoItem.itemType.iconName
        }()
        let customData: Data? = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoBudgetContent.self, from: data) {
                return content.customImageData
            }
            return nil
        }()
        let color: Color = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoBudgetContent.self, from: data) {
                return Color(hex: content.colorHex)
            }
            return memoItem.itemType.color
        }()
        let badge = budgetBadgeView()
        if showDetails {
            HStack(alignment: .center, spacing: 12) {
                VStack { Spacer(minLength: 0); streakIconView(name: iconName, customData: customData, color: color); Spacer(minLength: 0) }
                    .frame(width: 60, alignment: .leading)
                VStack(alignment: .leading, spacing: 10) {
                    titleView
                    memoDetails
                    memoExpandedDescriptionSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.trailing, 16)
            }
            .padding(.leading, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 72, alignment: .center)
        } else {
            HStack(alignment: .center, spacing: 12) {
                VStack {
                    Spacer(minLength: 0)
                    streakIconView(name: iconName, customData: customData, color: color)
                    Spacer(minLength: 0)
                }
                .frame(width: 60, alignment: .leading)
                titleView
                    .layoutPriority(0)
                Spacer(minLength: 8)
                badge
                    .memoCollapsedTrailingBadgeChrome()
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 50)
        }
    }
    
    // MARK: Бюджет: бейдж суммы
    @ViewBuilder
    func budgetBadgeView(isDetailChip: Bool = false) -> some View {
        if let data = memoItem.contentData,
           let content = try? JSONDecoder().decode(MemoBudgetContent.self, from: data),
           let firstBudget = content.budgets.first {
            let badgeTint = isArchived ? Color.gray : Color(hex: content.colorHex)
            let isZero = firstBudget.currentBalance == 0
            let balanceColor: Color = isZero ? Color(hex: content.colorHex) : (firstBudget.currentBalance > 0 ? .green : .red)
            let curr = content.currency.trimmingCharacters(in: .whitespaces)
            let balanceText = curr.isEmpty ? String(format: "%.0f", firstBudget.currentBalance) : "\(String(format: "%.0f", firstBudget.currentBalance)) \(curr)"
            if isDetailChip {
                memoValueDetailChip {
                    Text(balanceText)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundColor(memoDetailChipTextColor)
                }
            } else {
                Text(balanceText)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(design == .rainbow ? (isZero ? Color(hex: content.colorHex).opacity(0.9) : (firstBudget.currentBalance >= 0 ? .white.opacity(0.9) : Color(red: 1.0, green: 0.3, blue: 0.3))) : balanceColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(design == .rainbow ? Color.white.opacity(0.2) : (isArchived ? Color(UIColor.systemGray5) : badgeTint.opacity(0.2)))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .floatingBadgeStyle()
            }
        } else {
            let cardColor: Color = {
                if let data = memoItem.contentData,
                   let content = try? JSONDecoder().decode(MemoBudgetContent.self, from: data) {
                    return Color(hex: content.colorHex)
                }
                return memoItem.itemType.color
            }()
            let badgeTint = isArchived ? Color.gray : cardColor
            if isDetailChip {
                memoValueDetailChip {
                    Text("0")
                        .font(.caption2)
                        .foregroundColor(memoDetailChipTextColor)
                }
            } else {
                Text("0")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(design == .rainbow ? cardColor.opacity(0.9) : cardColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(design == .rainbow ? Color.white.opacity(0.2) : (isArchived ? Color(UIColor.systemGray5) : badgeTint.opacity(0.2)))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .floatingBadgeStyle()
            }
        }
    }
    
    // MARK: Время: превью и накопленные минуты
    @ViewBuilder
    var timeMemoContent: some View {
        let iconName: String = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoTimeContent.self, from: data) {
                return content.iconName
            }
            return memoItem.itemType.iconName
        }()
        let customData: Data? = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoTimeContent.self, from: data) {
                return content.customImageData
            }
            return nil
        }()
        let color: Color = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoTimeContent.self, from: data) {
                return Color(hex: content.colorHex)
            }
            return memoItem.itemType.color
        }()
        let badge = timeBadgeView()
        if showDetails {
            HStack(alignment: .center, spacing: 12) {
                VStack { Spacer(minLength: 0); streakIconView(name: iconName, customData: customData, color: color); Spacer(minLength: 0) }
                    .frame(width: 60, alignment: .leading)
                VStack(alignment: .leading, spacing: 10) {
                    titleView
                    memoDetails
                    memoExpandedDescriptionSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.trailing, 16)
            }
            .padding(.leading, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 72, alignment: .center)
        } else {
            HStack(alignment: .center, spacing: 12) {
                VStack {
                    Spacer(minLength: 0)
                    streakIconView(name: iconName, customData: customData, color: color)
                    Spacer(minLength: 0)
                }
                .frame(width: 60, alignment: .leading)
                titleView
                    .layoutPriority(0)
                Spacer(minLength: 8)
                badge
                    .memoCollapsedTrailingBadgeChrome()
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 50)
        }
    }
    
    // MARK: Время: бейдж длительности
    @ViewBuilder
    func timeBadgeView(isDetailChip: Bool = false) -> some View {
        let timeColor: Color = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoTimeContent.self, from: data) {
                return isArchived ? .gray : Color(hex: content.colorHex)
            }
            return memoItem.itemType.color
        }()
        let displayText: String = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoTimeContent.self, from: data) {
                let mins = Int(content.currentMinutes)
                let hrs = mins / 60
                let rem = mins % 60
                if hrs > 0 {
                    let hourText = hrs == 1 ? "1 hr" : "\(hrs) hrs"
                    if rem > 0 {
                        let minText = rem == 1 ? "1 min" : "\(rem) mins"
                        return "\(hourText) \(minText)"
                    } else {
                        return hourText
                    }
                } else {
                    return rem == 1 ? "1 min" : "\(rem) mins"
                }
            }
            return "0 mins"
        }()
        if isDetailChip {
            memoValueDetailChip {
                Text(displayText)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .foregroundColor(memoDetailChipTextColor)
            }
        } else {
            Text(displayText)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(design == .rainbow ? .white.opacity(0.9) : (isArchived ? .secondary : timeColor))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(design == .rainbow ? Color.white.opacity(0.2) : (isArchived ? Color(UIColor.systemGray5) : timeColor.opacity(0.2)))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .floatingBadgeStyle()
        }
    }
    
    // MARK: Здоровье: превью
    @ViewBuilder
    var healthMemoContent: some View {
        let iconName: String = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoHealthContent.self, from: data) {
                return content.iconName
            }
            return memoItem.itemType.iconName
        }()
        let customData: Data? = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoHealthContent.self, from: data) {
                return content.customImageData
            }
            return nil
        }()
        let color: Color = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoHealthContent.self, from: data) {
                return Color(hex: content.colorHex)
            }
            return memoItem.itemType.color
        }()
        let badge = healthBadgeView()
        if showDetails {
            HStack(alignment: .center, spacing: 12) {
                VStack { Spacer(minLength: 0); streakIconView(name: iconName, customData: customData, color: color); Spacer(minLength: 0) }
                    .frame(width: 60, alignment: .leading)
                VStack(alignment: .leading, spacing: 10) {
                    titleView
                    memoDetails
                    memoExpandedDescriptionSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.trailing, 16)
            }
            .padding(.leading, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 72, alignment: .center)
        } else {
            HStack(alignment: .center, spacing: 12) {
                VStack {
                    Spacer(minLength: 0)
                    streakIconView(name: iconName, customData: customData, color: color)
                    Spacer(minLength: 0)
                }
                .frame(width: 60, alignment: .leading)
                titleView
                    .layoutPriority(0)
                Spacer(minLength: 8)
                badge
                    .memoCollapsedTrailingBadgeChrome()
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 50)
        }
    }
    
    // MARK: Календарь: превью и число записей
    @ViewBuilder
    var calendarMemoContent: some View {
        let iconName: String = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoCalendarContent.self, from: data) {
                return content.iconName
            }
            return memoItem.itemType.iconName
        }()
        let customData: Data? = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoCalendarContent.self, from: data) {
                return content.customImageData
            }
            return nil
        }()
        let color: Color = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoCalendarContent.self, from: data) {
                return Color(hex: content.colorHex)
            }
            return memoItem.itemType.color
        }()
        let badge = calendarBadgeView()
        if showDetails {
            HStack(alignment: .center, spacing: 12) {
                VStack { Spacer(minLength: 0); streakIconView(name: iconName, customData: customData, color: color); Spacer(minLength: 0) }
                    .frame(width: 60, alignment: .leading)
                VStack(alignment: .leading, spacing: 10) {
                    titleView
                    memoDetails
                    memoExpandedDescriptionSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.trailing, 16)
            }
            .padding(.leading, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 72, alignment: .center)
        } else {
            HStack(alignment: .center, spacing: 12) {
                VStack {
                    Spacer(minLength: 0)
                    streakIconView(name: iconName, customData: customData, color: color)
                    Spacer(minLength: 0)
                }
                .frame(width: 60, alignment: .leading)
                titleView
                    .layoutPriority(0)
                Spacer(minLength: 8)
                badge
                    .memoCollapsedTrailingBadgeChrome()
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 50)
        }
    }
    
    // MARK: Календарь: бейдж количества записей
    @ViewBuilder
    func calendarBadgeView(isDetailChip: Bool = false) -> some View {
        let calendarColor: Color = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoCalendarContent.self, from: data) {
                return isArchived ? .gray : Color(hex: content.colorHex)
            }
            return memoItem.itemType.color
        }()
        let count: Int = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoCalendarContent.self, from: data) {
                return content.entries.values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
            }
            return 0
        }()
        let label = count == 1 ? "entry" : "entries"
        let countText = "\(count) \(label)"
        if isDetailChip {
            memoValueDetailChip {
                Text(countText)
                    .font(.caption2)
                    .foregroundColor(memoDetailChipTextColor)
            }
        } else {
            Text(countText)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(design == .rainbow ? .white.opacity(0.9) : (isArchived ? .secondary : calendarColor))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(design == .rainbow ? Color.white.opacity(0.2) : (isArchived ? Color(UIColor.systemGray5) : calendarColor.opacity(0.2)))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .floatingBadgeStyle()
        }
    }
    
    // MARK: Здоровье: бейдж значения и единицы
    @ViewBuilder
    func healthBadgeView(isDetailChip: Bool = false) -> some View {
        let color: Color = {
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoHealthContent.self, from: data) {
                return isArchived ? .gray : Color(hex: content.colorHex)
            }
            return memoItem.itemType.color
        }()
        if let data = memoItem.contentData,
           let content = try? JSONDecoder().decode(MemoHealthContent.self, from: data) {
            let isZero = content.currentValue == 0
            let valueColor: Color = isZero ? color : (content.currentValue > 0 ? .green : .red)
            let unitText = content.unit.isEmpty ? "unit" : content.unit
            let displayValue = abs(content.currentValue).truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", content.currentValue)
                : String(format: "%.1f", content.currentValue)
            let line = "\(displayValue) \(unitText)"
            if isDetailChip {
                memoValueDetailChip {
                    Text(line)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .foregroundColor(memoDetailChipTextColor)
                }
            } else {
                Text(line)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(design == .rainbow ? (isZero ? color.opacity(0.9) : .white.opacity(0.9)) : (isArchived ? .secondary : valueColor))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(design == .rainbow ? Color.white.opacity(0.2) : (isArchived ? Color(UIColor.systemGray5) : color.opacity(0.2)))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .floatingBadgeStyle()
            }
        } else if isDetailChip {
            memoValueDetailChip {
                Text("0 unit")
                    .font(.caption2)
                    .foregroundColor(memoDetailChipTextColor)
            }
        } else {
            Text("0 unit")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(design == .rainbow ? .white.opacity(0.9) : (isArchived ? .secondary : color))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(design == .rainbow ? Color.white.opacity(0.2) : (isArchived ? Color(UIColor.systemGray5) : color.opacity(0.2)))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .floatingBadgeStyle()
        }
    }
    
    // MARK: Относительная дата для подписи
    func relativeDateString(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    /// Цвет акцента карточки — для иконок в чипах `memoDetails` (как `cardAccentColor` у Goals).
    var memoCardAccentColor: Color {
        if isArchived { return .gray }
        guard let data = memoItem.contentData else {
            return memoItem.itemType.color
        }
        switch memoItem.itemType {
        case .noteAlbum:
            if let c = try? JSONDecoder().decode(MemoNoteAlbumContent.self, from: data) { return Color(hex: c.colorHex) }
        case .list:
            if let c = try? JSONDecoder().decode(MemoListContent.self, from: data) { return Color(hex: c.colorHex) }
        case .counter:
            if let c = try? JSONDecoder().decode(MemoCounterContent.self, from: data) { return Color(hex: c.colorHex) }
        case .streak:
            if let c = try? JSONDecoder().decode(MemoStreakContent.self, from: data) { return Color(hex: c.colorHex) }
        case .mood:
            if let c = try? JSONDecoder().decode(MemoMoodContent.self, from: data) { return Color(hex: c.colorHex) }
        case .skill:
            if let c = try? JSONDecoder().decode(MemoSkillContent.self, from: data) { return Color(hex: c.colorHex) }
        case .budget:
            if let c = try? JSONDecoder().decode(MemoBudgetContent.self, from: data) { return Color(hex: c.colorHex) }
        case .time:
            if let c = try? JSONDecoder().decode(MemoTimeContent.self, from: data) { return Color(hex: c.colorHex) }
        case .health:
            if let c = try? JSONDecoder().decode(MemoHealthContent.self, from: data) { return Color(hex: c.colorHex) }
        case .calendar:
            if let c = try? JSONDecoder().decode(MemoCalendarContent.self, from: data) { return Color(hex: c.colorHex) }
        }
        return memoItem.itemType.color
    }
    
    /// Фон чипов в `memoDetails`: Basic — лёгкий tint типа; Rainbow — нейтрально, как `propertiesScroller` у Tasks.
    private var memoDetailChipBackground: Color {
        if isArchived { return Color(UIColor.systemGray5) }
        if design == .rainbow, colorScheme == .dark { return Color.white.opacity(0.14) }
        if design == .rainbow, colorScheme == .light { return Color.white.opacity(0.22) }
        return memoCardAccentColor.opacity(0.2)
    }

    private var memoDetailChipIconColor: Color {
        if isArchived { return Color.secondary }
        if design == .rainbow, colorScheme == .dark { return Color.white.opacity(0.9) }
        if design == .rainbow, colorScheme == .light { return Color.white.opacity(0.95) }
        if design == .rainbow { return memoCardAccentColor }
        return memoCardAccentColor
    }

    private var memoDetailChipTextColor: Color {
        if isArchived { return Color.secondary }
        if design == .rainbow, colorScheme == .dark { return Color.white.opacity(0.9) }
        if design == .rainbow, colorScheme == .light { return Color.white.opacity(0.95) }
        return memoCardAccentColor
    }

    /// Строка мини-чипов под заголовком: тот же фон/скругление, что у даты и тегов.
    @ViewBuilder
    private func memoValueDetailChip<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        ListDetailChip(background: memoDetailChipBackground) {
            content()
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    /// Первый чип в `memoDetails`: бывший бейдж справа (развёрнутая карточка).
    @ViewBuilder
    private var memoExpandedPrimaryChip: some View {
        switch memoItem.itemType {
        case .counter:
            if let data = memoItem.contentData,
               let counter = try? JSONDecoder().decode(MemoCounterContent.self, from: data) {
                let current = counter.currentValue
                let targetRaw = counter.targetValue ?? 1.0
                let target = max(targetRaw, 1.0)
                counterBadgeView(counter: counter, current: current, target: target, unitText: counter.unit, isDetailChip: true)
            }
        case .streak:
            if let data = memoItem.contentData,
               let content = try? JSONDecoder().decode(MemoStreakContent.self, from: data) {
                streakBadgeView(value: content.currentStreak, isDetailChip: true, isMarkedOnReferenceDay: isStreakMarkedOnReferenceDay)
            }
        case .mood:
            moodBadgeView(isDetailChip: true)
        case .skill:
            skillBadgeView(isDetailChip: true)
        case .budget:
            budgetBadgeView(isDetailChip: true)
        case .time:
            timeBadgeView(isDetailChip: true)
        case .health:
            healthBadgeView(isDetailChip: true)
        case .calendar:
            calendarBadgeView(isDetailChip: true)
        case .list:
            listBadgeView(isDetailChip: true)
        case .noteAlbum:
            noteAlbumBadgeView(isDetailChip: true)
        }
    }

    /// Primary sphere + impact из JSON контента (как в Goals — один чип с иконкой и %).
    private func memoPrimarySphereImpact() -> (sphereID: UUID?, positive: Double, negative: Double) {
        guard let data = memoItem.contentData else { return (nil, 0, 0) }
        switch memoItem.itemType {
        case .list:
            if let c = try? JSONDecoder().decode(MemoListContent.self, from: data) { return (c.sphereID, c.positiveImpact, c.negativeImpact) }
        case .counter:
            if let c = try? JSONDecoder().decode(MemoCounterContent.self, from: data) { return (c.sphereID, c.positiveImpact, c.negativeImpact) }
        case .streak:
            if let c = try? JSONDecoder().decode(MemoStreakContent.self, from: data) { return (c.sphereID, c.positiveImpact, c.negativeImpact) }
        case .mood:
            if let c = try? JSONDecoder().decode(MemoMoodContent.self, from: data) { return (c.sphereID, c.positiveImpact, c.negativeImpact) }
        case .skill:
            if let c = try? JSONDecoder().decode(MemoSkillContent.self, from: data) { return (c.sphereID, c.positiveImpact, c.negativeImpact) }
        case .budget:
            if let c = try? JSONDecoder().decode(MemoBudgetContent.self, from: data) { return (c.sphereID, c.positiveImpact, c.negativeImpact) }
        case .time:
            if let c = try? JSONDecoder().decode(MemoTimeContent.self, from: data) { return (c.sphereID, c.positiveImpact, c.negativeImpact) }
        case .health:
            if let c = try? JSONDecoder().decode(MemoHealthContent.self, from: data) { return (c.sphereID, c.positiveImpact, c.negativeImpact) }
        case .calendar:
            if let c = try? JSONDecoder().decode(MemoCalendarContent.self, from: data) { return (c.sphereID, c.positiveImpact, c.negativeImpact) }
        case .noteAlbum:
            if let c = try? JSONDecoder().decode(MemoNoteAlbumContent.self, from: data) { return (c.sphereID, 0, 0) }
        }
        return (nil, 0, 0)
    }

    private func memoImpactDisplayString(positive: Double, negative: Double) -> String {
        var parts: [String] = []
        if positive > 0 { parts.append("+\(String(format: "%.0f", positive))%") }
        if negative > 0 { parts.append("-\(String(format: "%.0f", negative))%") }
        return parts.joined(separator: " ")
    }

    @ViewBuilder
    private func memoSphereImpactDetailsRow() -> some View {
        let spi = memoPrimarySphereImpact()
        if let sid = spi.sphereID, let sphere = spheres.first(where: { $0.id == sid }) {
            ListDetailChip(background: memoDetailChipBackground) {
                HStack(spacing: 4) {
                    Image(systemName: sphere.iconName)
                        .font(.caption2)
                        .foregroundColor(memoDetailChipIconColor)
                    if spi.positive > 0 || spi.negative > 0 {
                        Text(memoImpactDisplayString(positive: spi.positive, negative: spi.negative))
                            .font(.caption2)
                            .foregroundColor(memoDetailChipTextColor)
                    }
                }
            }
        } else if spi.positive > 0 || spi.negative > 0 {
            ListDetailChip(background: memoDetailChipBackground) {
                Text(memoImpactDisplayString(positive: spi.positive, negative: spi.negative))
                    .font(.caption2)
                    .foregroundColor(memoDetailChipTextColor)
            }
        }
    }

    @ViewBuilder
    var memoExpandedDescriptionSection: some View {
        if let raw = memoItem.descript {
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
            Text(text)
                .font(.caption2)
                .foregroundColor(design == .rainbow ? Color.white.opacity(0.9) : .secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    // MARK: Нижняя полоса: дата создания, последнее изменение счётчика, теги (только развёрнутая карточка)
    var memoDetails: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                memoExpandedPrimaryChip
                memoSphereImpactDetailsRow()
                // Creation date
                ListDetailChip(background: memoDetailChipBackground) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundColor(memoDetailChipIconColor)
                        Text(relativeDateString(for: memoItem.creationDate))
                            .font(.caption2)
                            .foregroundColor(memoDetailChipTextColor)
                    }
                }
                
                // Counter last change (only for counter type)
                if memoItem.itemType == .counter,
                   let data = memoItem.contentData,
                   let counter = try? JSONDecoder().decode(MemoCounterContent.self, from: data),
                   let lastDate = counter.history.map(\.date).max() {
                    ListDetailChip(background: memoDetailChipBackground) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundColor(memoDetailChipIconColor)
                            Text(lastDate, style: .relative)
                                .font(.caption2)
                                .foregroundColor(memoDetailChipTextColor)
                        }
                    }
                }
                
                // Tags
                ForEach(memoItem.tags, id: \.self) { tag in
                    ListDetailChip(background: memoDetailChipBackground) {
                        HStack(spacing: 0) {
                            Text("#")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(memoDetailChipIconColor)
                            Text(tag)
                                .font(.caption2)
                                .foregroundColor(memoDetailChipTextColor)
                        }
                    }
                }
            }
        }
    }
}
