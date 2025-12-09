import SwiftUI
import SwiftData

// MARK: - Memo Card View
struct MemoCardView: View {
    let memoItem: MemoItem
    let design: AppDesign
    @Environment(\.modelContext) private var modelContext
    @State private var showDetails: Bool = false
    @State private var outerPulse = false
    @State private var animationTask: Task<Void, Never>?

    init(memoItem: MemoItem, design: AppDesign = .basic) {
        self.memoItem = memoItem
        self.design = design
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content based on type
            contentPreview

            // Tags
            if !memoItem.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(memoItem.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
        }
        .frame(minHeight: 72, alignment: .center)
        .background(
            Group {
                let isArchived = memoItem.status == .archived
                if design == .rainbow {
                    if isArchived {
                        Color(UIColor.systemGray4)
                    } else {
                        memoItem.itemType.gradient
                    }
                } else {
                    Color(UIColor.systemBackground)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            Group {
                let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
                if design == .rainbow {
                    let strokeColor = isArchived ? Color.gray.opacity(0.35) : memoItem.itemType.color.opacity(0.35)
                    shape
                        .stroke(strokeColor, lineWidth: 0.5)
                        .background(shape.fill(Color.clear))
                } else {
                    shape
                        .stroke(Color(UIColor.systemGray5), lineWidth: 0.5)
                        .background(shape.fill(Color.clear))
                }
            }
        )
        // Removed shadow for unified flat design across all cards
        // .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        // Ensure system highlight uses the same rounded shape to avoid white edges
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(count: 2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showDetails.toggle()
            }
        }
        .onAppear {
            updateOuterPulse()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }
    
    private var outerPulseScale: CGFloat {
        return outerPulse ? 1.08 : 0.96
    }
    
    private var isArchived: Bool {
        memoItem.status == .archived
    }
    
    private func iconColor(for typeColor: Color) -> Color {
        isArchived ? .gray : typeColor
    }
    
    private func iconRingColor(for typeColor: Color) -> Color {
        isArchived ? .gray : (design == .rainbow ? .white : typeColor)
    }
    
    private func iconFillColor(for typeColor: Color) -> Color {
        isArchived ? Color.gray.opacity(0.2) : (design == .rainbow ? Color.white.opacity(0.2) : typeColor.opacity(0.2))
    }
    
    private func updateOuterPulse() {
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

    @ViewBuilder
    private var titleView: some View {
        let isArchived = memoItem.status == .archived
        let leftTitleColorBasic = isArchived ? Color.gray.opacity(0.5) : Color.primary.opacity(0.8)
        let leftTitleColorRainbow: Color = isArchived ? Color.gray.opacity(0.7) : .white
        
        ZStack(alignment: .leading) {
            strokedText(
                memoItem.title,
                uiFont: UIFont.preferredFont(forTextStyle: .headline),
                color: .systemGray5,
                width: 1
            )
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .allowsHitTesting(false)

            Text(memoItem.title)
                .font(.headline)
                .foregroundColor(design == .rainbow ? leftTitleColorRainbow : leftTitleColorBasic)
                .strikethrough(isArchived)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
        }
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch memoItem.itemType {
        case .noteAlbum:
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Иконка слева
                    ZStack {
                        let isArchived = memoItem.status == .archived
                        // Outer pulsing ring
                        let noteAlbumIconName: String = {
                            if let data = memoItem.contentData,
                               let content = try? JSONDecoder().decode(MemoNoteAlbumContent.self, from: data) {
                                return content.iconName
                            }
                            return memoItem.itemType.iconName
                        }()
                        let ringColor: Color = isArchived ? .gray : (design == .rainbow ? .white : memoItem.itemType.color)
                        Circle()
                            .stroke(ringColor.opacity(outerPulseScale > 1.0 ? 0.6 : 0.3), lineWidth: 3)
                            .frame(width: 48, height: 48)
                            .scaleEffect(outerPulseScale)
                        
                        Circle()
                            .fill((isArchived ? Color.gray.opacity(0.2) : (design == .rainbow ? Color.white.opacity(0.2) : memoItem.itemType.color.opacity(0.2))))
                            .frame(width: 40, height: 40)

                        Image(systemName: noteAlbumIconName)
                            .foregroundColor(isArchived ? .gray : (design == .rainbow ? .white : memoItem.itemType.color))
                            .font(.system(size: 20, weight: .semibold))
                            .symbolEffect(.pulse)
                    }

                    // Название
                    titleView

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            if showDetails {
                Rectangle()
                    .fill(LinearGradient(colors: [Color.gray.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                    .opacity(0.9)
                memoDetails
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

        case .list:
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Иконка слева
                    ZStack {
                        // Outer pulsing ring
                        let listIconName: String = {
                            if let data = memoItem.contentData,
                               let content = try? JSONDecoder().decode(MemoListContent.self, from: data) {
                                return content.iconName
                            }
                            return memoItem.itemType.iconName
                        }()
                        let ringColor = iconRingColor(for: memoItem.itemType.color)
                        Circle()
                            .stroke(ringColor.opacity(outerPulseScale > 1.0 ? 0.6 : 0.3), lineWidth: 3)
                            .frame(width: 48, height: 48)
                            .scaleEffect(outerPulseScale)
                        
                        Circle()
                            .fill(iconFillColor(for: memoItem.itemType.color))
                            .frame(width: 40, height: 40)

                        Image(systemName: listIconName)
                            .foregroundColor(iconColor(for: memoItem.itemType.color))
                            .font(.system(size: 20, weight: .semibold))
                            .symbolEffect(.pulse)
                    }

                    // Название
                    titleView

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            if showDetails {
                Rectangle()
                    .fill(LinearGradient(colors: [Color.gray.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                    .opacity(0.9)
                memoDetails
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

        case .counter:
            if let data = memoItem.contentData, let counter = try? JSONDecoder().decode(MemoCounterContent.self, from: data) {
                // Безопасные локальные значения
                let current = counter.currentValue
                let targetRaw = counter.targetValue ?? 1
                let target = max(targetRaw, 1)
                let iconName = counter.iconName
                let customImageData = counter.customImageData
                let unitText = counter.unit
                let mainColor = Color(hex: counter.colorHex)
                HStack(spacing: 12) {
                    HStack(spacing: 12) {
                        // Иконка слева в стандартном стиле
                        ZStack {
                            // Outer pulsing ring
                            let ringColor = iconRingColor(for: mainColor)
                            Circle()
                                .stroke(ringColor.opacity(outerPulseScale > 1.0 ? 0.6 : 0.3), lineWidth: 3)
                                .frame(width: 48, height: 48)
                                .scaleEffect(outerPulseScale)
                            
                            Circle()
                                .fill(iconFillColor(for: mainColor))
                                .frame(width: 40, height: 40)

                            // Кастомное изображение или системная иконка
                            if let imageData = customImageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: iconName.isEmpty ? "number.circle" : iconName)
                                    .foregroundColor(iconColor(for: mainColor))
                                    .font(.system(size: 20, weight: .semibold))
                                    .symbolEffect(.pulse)
                            }
                        }
                        
                        // Название
                        titleView
                        
                        Spacer()
                        
                        // Счетчик справа в стиле Apple
                        if counter.targetValue != nil {
                            Text("\(current)/\(target) \(unitText)")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(design == .rainbow ? .white.opacity(0.9) : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(UIColor.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .onTapGesture {
                                    var updated = counter
                                    let newVal = updated.currentValue + 1
                                    if newVal <= (updated.targetValue ?? Int.max) {
                                        updated.currentValue = newVal
                                        if let encoded = try? JSONEncoder().encode(updated) {
                                            memoItem.contentData = encoded
                                            try? modelContext.save()
                                        }
                                    }
                                }
                                .onLongPressGesture(minimumDuration: 0.3) {
                                    var updated = counter
                                    updated.currentValue = max(updated.currentValue - 1, 0)
                                    if let encoded = try? JSONEncoder().encode(updated) {
                                        memoItem.contentData = encoded
                                        try? modelContext.save()
                                    }
                                }
                        } else {
                            Text("\(current) \(unitText)")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(design == .rainbow ? .white.opacity(0.9) : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(UIColor.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .onTapGesture {
                                    var updated = counter
                                    updated.currentValue += 1
                                    if let encoded = try? JSONEncoder().encode(updated) {
                                        memoItem.contentData = encoded
                                        try? modelContext.save()
                                    }
                                }
                                .onLongPressGesture(minimumDuration: 0.3) {
                                    var updated = counter
                                    updated.currentValue = max(updated.currentValue - 1, 0)
                                    if let encoded = try? JSONEncoder().encode(updated) {
                                        memoItem.contentData = encoded
                                        try? modelContext.save()
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                if showDetails {
                    Rectangle()
                        .fill(LinearGradient(colors: [Color.gray.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)
                        .opacity(0.9)
                    memoDetails
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            } else {
                Text("Счётчик не настроен")
                    .foregroundColor(.secondary)
            }

        case .streak:
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Иконка слева
                    ZStack {
                        // Outer pulsing ring
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
                        let ringColor = iconRingColor(for: streakColor)
                        Circle()
                            .stroke(ringColor.opacity(outerPulseScale > 1.0 ? 0.6 : 0.3), lineWidth: 3)
                            .frame(width: 48, height: 48)
                            .scaleEffect(outerPulseScale)
                        
                        Circle()
                            .fill(iconFillColor(for: streakColor))
                            .frame(width: 40, height: 40)

                        // Кастомное изображение или системная иконка
                        if let imageData = streakCustomImageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: streakIconName)
                                .foregroundColor(iconColor(for: streakColor))
                                .font(.system(size: 20, weight: .semibold))
                                .symbolEffect(.pulse)
                        }
                    }

                    // Название
                    titleView

                    Spacer()

                    // Количество дней стрика справа в стиле Apple
                    if let data = memoItem.contentData,
                       let content = try? JSONDecoder().decode(MemoStreakContent.self, from: data) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(content.currentStreak > 0 ? .orange : (design == .rainbow ? .white.opacity(0.9) : .primary))
                            Text("\(content.currentStreak)")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(design == .rainbow ? .white.opacity(0.9) : .primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(design == .rainbow ? .white.opacity(0.9) : .primary)
                            Text("0")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(design == .rainbow ? .white.opacity(0.9) : .primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            if showDetails {
                Rectangle()
                    .fill(LinearGradient(colors: [Color.gray.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                    .opacity(0.9)
                memoDetails
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

        case .mood:
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Иконка слева
                    ZStack {
                        // Outer pulsing ring
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
                        let ringColor = iconRingColor(for: moodColor)
                        Circle()
                            .stroke(ringColor.opacity(outerPulseScale > 1.0 ? 0.6 : 0.3), lineWidth: 3)
                            .frame(width: 48, height: 48)
                            .scaleEffect(outerPulseScale)
                        
                        Circle()
                            .fill(iconFillColor(for: moodColor))
                            .frame(width: 40, height: 40)

                        // Кастомное изображение или системная иконка
                        if let imageData = moodCustomImageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: moodIconName)
                                .foregroundColor(iconColor(for: moodColor))
                                .font(.system(size: 20, weight: .semibold))
                                .symbolEffect(.pulse)
                        }
                    }

                    // Название
                    titleView

                    Spacer()

                    // Иконка сегодняшнего настроения справа в стиле Apple
                    if let data = memoItem.contentData,
                       let content = try? JSONDecoder().decode(MemoMoodContent.self, from: data),
                       let todayMood = content.entries.first(where: { Calendar.current.isDateInToday($0.date) }) {
                        // Показываем иконку в зависимости от значения настроения
                        Group {
                            switch todayMood.value {
                            case 1...3:
                                Text("😢")
                                    .font(.system(size: 24))
                            case 4...6:
                                Text("😐")
                                    .font(.system(size: 24))
                            case 7...9:
                                Text("😊")
                                    .font(.system(size: 24))
                            case 10:
                                Text("😄")
                                    .font(.system(size: 24))
                            default:
                                Text("😐")
                                    .font(.system(size: 24))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        // Дефолтная иконка, если настроение не внесено
                        Image(systemName: "circle.dashed")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(design == .rainbow ? .white.opacity(0.9) : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            if showDetails {
                Rectangle()
                    .fill(LinearGradient(colors: [Color.gray.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                    .opacity(0.9)
                memoDetails
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

        case .skill:
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Иконка слева
                    ZStack {
                        // Outer pulsing ring
                        let skillIconName: String = {
                            if let data = memoItem.contentData,
                               let content = try? JSONDecoder().decode(MemoSkillContent.self, from: data) {
                                return content.iconName
                            }
                            return memoItem.itemType.iconName
                        }()
                        let skillCustomImageData: Data? = {
                            if let data = memoItem.contentData,
                               let content = try? JSONDecoder().decode(MemoSkillContent.self, from: data) {
                                return content.customImageData
                            }
                            return nil
                        }()
                        let skillColor: Color = {
                            if let data = memoItem.contentData,
                               let content = try? JSONDecoder().decode(MemoSkillContent.self, from: data) {
                                return Color(hex: content.colorHex)
                            }
                            return memoItem.itemType.color
                        }()
                        let ringColor = iconRingColor(for: skillColor)
                        Circle()
                            .stroke(ringColor.opacity(outerPulseScale > 1.0 ? 0.6 : 0.3), lineWidth: 3)
                            .frame(width: 48, height: 48)
                            .scaleEffect(outerPulseScale)
                        
                        Circle()
                            .fill(iconFillColor(for: skillColor))
                            .frame(width: 40, height: 40)

                        // Кастомное изображение или системная иконка
                        if let imageData = skillCustomImageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: skillIconName)
                                .foregroundColor(iconColor(for: skillColor))
                                .font(.system(size: 20, weight: .semibold))
                                .symbolEffect(.pulse)
                        }
                    }

                    // Название
                    titleView

                    Spacer()

                    // Уровень первого навыка справа в стиле Apple
                    if let data = memoItem.contentData,
                       let content = try? JSONDecoder().decode(MemoSkillContent.self, from: data),
                       let firstSkill = content.skills.first {
                        if let target = firstSkill.targetLevel {
                            // С индикатором прогресса
                            HStack(spacing: 4) {
                                Text(String(format: "%.0f", firstSkill.currentLevel))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(design == .rainbow ? .white.opacity(0.9) : .primary)
                                
                                Text("/\(String(format: "%.0f", target))")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(design == .rainbow ? .white.opacity(0.9) : .primary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else {
                            // Без цели
                            Text(String(format: "%.1f", firstSkill.currentLevel))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(design == .rainbow ? .white.opacity(0.9) : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(UIColor.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    } else {
                        Text("0")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(design == .rainbow ? .white.opacity(0.9) : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            if showDetails {
                Rectangle()
                    .fill(LinearGradient(colors: [Color.gray.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                    .opacity(0.9)
                memoDetails
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

        case .budget:
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Иконка слева
                    ZStack {
                        // Outer pulsing ring
                        let budgetIconName: String = {
                            if let data = memoItem.contentData,
                               let content = try? JSONDecoder().decode(MemoBudgetContent.self, from: data) {
                                return content.iconName
                            }
                            return memoItem.itemType.iconName
                        }()
                        let budgetCustomImageData: Data? = {
                            if let data = memoItem.contentData,
                               let content = try? JSONDecoder().decode(MemoBudgetContent.self, from: data) {
                                return content.customImageData
                            }
                            return nil
                        }()
                        let budgetColor: Color = {
                            if let data = memoItem.contentData,
                               let content = try? JSONDecoder().decode(MemoBudgetContent.self, from: data) {
                                return Color(hex: content.colorHex)
                            }
                            return memoItem.itemType.color
                        }()
                        let ringColor = iconRingColor(for: budgetColor)
                        Circle()
                            .stroke(ringColor.opacity(outerPulseScale > 1.0 ? 0.6 : 0.3), lineWidth: 3)
                            .frame(width: 48, height: 48)
                            .scaleEffect(outerPulseScale)
                        
                        Circle()
                            .fill(iconFillColor(for: budgetColor))
                            .frame(width: 40, height: 40)

                        // Кастомное изображение или системная иконка
                        if let imageData = budgetCustomImageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: budgetIconName)
                                .foregroundColor(iconColor(for: budgetColor))
                                .font(.system(size: 20, weight: .semibold))
                                .symbolEffect(.pulse)
                        }
                    }

                    // Название
                    titleView

                    Spacer()

                    // Баланс первого бюджета справа в стиле Apple
                    if let data = memoItem.contentData,
                       let content = try? JSONDecoder().decode(MemoBudgetContent.self, from: data),
                       let firstBudget = content.budgets.first {
                        let balanceColor: Color = {
                            if design == .rainbow {
                                return firstBudget.currentBalance >= 0 ? .white.opacity(0.9) : Color(red: 1.0, green: 0.3, blue: 0.3)
                            } else {
                                return firstBudget.currentBalance >= 0 ? .green : .red
                            }
                        }()
                        Text(String(format: "%.0f ₽", firstBudget.currentBalance))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(balanceColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        Text("0 ₽")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(design == .rainbow ? .white.opacity(0.9) : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            if showDetails {
                Rectangle()
                    .fill(LinearGradient(colors: [Color.gray.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                    .opacity(0.9)
                memoDetails
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

        case .time:
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Иконка слева
                    ZStack {
                        // Outer pulsing ring
                        let timeIconName: String = {
                            if let data = memoItem.contentData,
                               let content = try? JSONDecoder().decode(MemoTimeContent.self, from: data) {
                                return content.iconName
                            }
                            return memoItem.itemType.iconName
                        }()
                        let timeCustomImageData: Data? = {
                            if let data = memoItem.contentData,
                               let content = try? JSONDecoder().decode(MemoTimeContent.self, from: data) {
                                return content.customImageData
                            }
                            return nil
                        }()
                        let timeColor: Color = {
                            if let data = memoItem.contentData,
                               let content = try? JSONDecoder().decode(MemoTimeContent.self, from: data) {
                                return Color(hex: content.colorHex)
                            }
                            return memoItem.itemType.color
                        }()
                        let ringColor = iconRingColor(for: timeColor)
                        Circle()
                            .stroke(ringColor.opacity(outerPulseScale > 1.0 ? 0.6 : 0.3), lineWidth: 3)
                            .frame(width: 48, height: 48)
                            .scaleEffect(outerPulseScale)
                        
                        Circle()
                            .fill(iconFillColor(for: timeColor))
                            .frame(width: 40, height: 40)

                        // Кастомное изображение или системная иконка
                        if let imageData = timeCustomImageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: timeIconName)
                                .foregroundColor(iconColor(for: timeColor))
                                .font(.system(size: 20, weight: .semibold))
                                .symbolEffect(.pulse)
                        }
                    }

                    // Название
                    titleView

                    Spacer()

                    // Время справа в стиле Apple
                    if let data = memoItem.contentData,
                       let content = try? JSONDecoder().decode(MemoTimeContent.self, from: data) {
                        let mins = Int(content.currentMinutes)
                        let hrs = mins / 60
                        let rem = mins % 60
                        Text(hrs > 0 ? String(format: "%dч %02dм", hrs, rem) : String(format: "%dм", rem))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(design == .rainbow ? .white.opacity(0.9) : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        Text("0м")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(design == .rainbow ? .white.opacity(0.9) : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            if showDetails {
                Rectangle()
                    .fill(LinearGradient(colors: [Color.gray.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                    .opacity(0.9)
                memoDetails
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

        case .health:
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Иконка слева
                    ZStack {
                        // Outer pulsing ring
                        let healthIconName: String = {
                            if let data = memoItem.contentData,
                               let content = try? JSONDecoder().decode(MemoHealthContent.self, from: data) {
                                return content.iconName
                            }
                            return memoItem.itemType.iconName
                        }()
                        let healthCustomImageData: Data? = {
                            if let data = memoItem.contentData,
                               let content = try? JSONDecoder().decode(MemoHealthContent.self, from: data) {
                                return content.customImageData
                            }
                            return nil
                        }()
                        let healthColor: Color = {
                            if let data = memoItem.contentData,
                               let content = try? JSONDecoder().decode(MemoHealthContent.self, from: data) {
                                return Color(hex: content.colorHex)
                            }
                            return memoItem.itemType.color
                        }()
                        let ringColor = iconRingColor(for: healthColor)
                        Circle()
                            .stroke(ringColor.opacity(outerPulseScale > 1.0 ? 0.6 : 0.3), lineWidth: 3)
                            .frame(width: 48, height: 48)
                            .scaleEffect(outerPulseScale)
                        
                        Circle()
                            .fill(iconFillColor(for: healthColor))
                            .frame(width: 40, height: 40)

                        // Кастомное изображение или системная иконка
                        if let imageData = healthCustomImageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: healthIconName)
                                .foregroundColor(iconColor(for: healthColor))
                                .font(.system(size: 20, weight: .semibold))
                                .symbolEffect(.pulse)
                        }
                    }

                    // Название
                    titleView

                    Spacer()

                    // Текущее значение справа в стиле Apple
                    if let data = memoItem.contentData,
                       let content = try? JSONDecoder().decode(MemoHealthContent.self, from: data) {
                        let unitText = content.unit.isEmpty ? "ед." : content.unit
                        Text(String(format: "%.1f %@", content.currentValue, unitText))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(design == .rainbow ? .white.opacity(0.9) : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        Text("0 ед.")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(design == .rainbow ? .white.opacity(0.9) : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            if showDetails {
                Rectangle()
                    .fill(LinearGradient(colors: [Color.gray.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                    .opacity(0.9)
                memoDetails
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

        case .tracker:
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Иконка слева
                    ZStack {
                        // Outer pulsing ring
                        let ringColor = iconRingColor(for: memoItem.itemType.color)
                        Circle()
                            .stroke(ringColor.opacity(outerPulseScale > 1.0 ? 0.6 : 0.3), lineWidth: 3)
                            .frame(width: 48, height: 48)
                            .scaleEffect(outerPulseScale)
                        
                        Circle()
                            .fill(iconFillColor(for: memoItem.itemType.color))
                            .frame(width: 40, height: 40)

                        Image(systemName: memoItem.itemType.iconName)
                            .foregroundColor(iconColor(for: memoItem.itemType.color))
                            .font(.system(size: 20, weight: .semibold))
                            .symbolEffect(.pulse)
                    }

                    // Название
                    titleView

                    Spacer()

                    // Дата справа в стиле Apple
                    Text(memoItem.creationDate, style: .date)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(design == .rainbow ? .white.opacity(0.9) : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            if showDetails {
                Rectangle()
                    .fill(LinearGradient(colors: [Color.gray.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                    .opacity(0.9)
                memoDetails
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var memoDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            // упрощённый блок подробностей: дата создания и список тегов
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(memoItem.creationDate, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if !memoItem.tags.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(memoItem.tags.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.top, 2)
    }
}
