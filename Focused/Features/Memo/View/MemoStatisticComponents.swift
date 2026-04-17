import SwiftUI

// Presentation · Memo — общие куски сводной статистики (период + плитки метрик), чтобы не дублировать типы мемо.

// MARK: Сегментированный выбор периода (`MemoStatsPeriod`)
struct MemoStatsPeriodSegmentedPicker: View {
    @Binding var selection: MemoStatsPeriod

    var body: some View {
        Picker("Period", selection: $selection) {
            ForEach(MemoStatsPeriod.allCases) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selection) { _, _ in
            HapticSoundManager.shared.selectionChanged()
        }
    }
}

// MARK: Плитка одной метрики в блоке «Statistics»
struct MemoStatisticMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    /// Как у mood / health / time: длинное значение сжимается в одну строку.
    var valueScalesDown: Bool = false

    /// «Карточка» на `systemBackground` или лёгкий тинт (как старый `StatCard` в альбоме заметок).
    enum BackgroundStyle {
        case systemInset
        case tintWash
    }

    var backgroundStyle: BackgroundStyle = .systemInset

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3.bold())
                .lineLimit(valueScalesDown ? 1 : nil)
                .minimumScaleFactor(valueScalesDown ? 0.5 : 1.0)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .modifier(MetricCardBackground(style: backgroundStyle, tintColor: color))
    }
}

extension MemoStatisticMetricCard {
    /// Удобный порядок аргументов для экранов, где сначала задают масштабирование значения (как в старых `*StatisticCard`).
    init(
        valueScalesDown: Bool,
        title: String,
        value: String,
        icon: String,
        color: Color,
        backgroundStyle: BackgroundStyle = .systemInset
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.valueScalesDown = valueScalesDown
        self.backgroundStyle = backgroundStyle
    }
}

private struct MetricCardBackground: ViewModifier {
    let style: MemoStatisticMetricCard.BackgroundStyle
    let tintColor: Color

    func body(content: Content) -> some View {
        switch style {
        case .systemInset:
            content
                .padding()
                .background(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        case .tintWash:
            content
                .padding(.vertical, 12)
                .background(tintColor.opacity(0.1))
                .cornerRadius(10)
        }
    }
}
