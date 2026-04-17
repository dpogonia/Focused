import SwiftUI

// Presentation · Vision — общие примитивы иконки сферы и полосы satisfaction (карточки / сегменты).

enum VisionSphereChrome {
    static let satisfactionBarHeightLarge: CGFloat = 10
    static let satisfactionBarHeightCompact: CGFloat = 8
}

struct VisionSphereIconDisc: View {
    let color: Color
    let iconName: String
    var diameter: CGFloat = 36
    var iconInset: CGFloat = 8

    var body: some View {
        ZStack {
            Circle().fill(color)
            Image(systemName: iconName)
                .resizable()
                .scaledToFit()
                .padding(iconInset)
                .foregroundColor(.white)
        }
        .frame(width: diameter, height: diameter)
    }
}

struct VisionSatisfactionCapsuleBar: View {
    let tint: Color
    var satisfaction: Double
    var height: CGFloat = VisionSphereChrome.satisfactionBarHeightLarge
    var showFillStroke: Bool = true

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.gray.opacity(0.15))
                .frame(height: height)
            GeometryReader { geo in
                let width = geo.size.width * CGFloat(max(0, min(100, satisfaction))) / 100.0
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.95), tint.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width, height: height)
                    .overlay(
                        Group {
                            if showFillStroke {
                                Capsule().stroke(tint.opacity(0.35), lineWidth: 1)
                            }
                        }
                    )
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: satisfaction)
            }
            .frame(height: height)
        }
    }
}

// MARK: - Процент в капсуле (Linear / Bars)

struct VisionTintedPercentCapsule: View {
    let text: String
    let tint: Color
    var style: Style
    var foreground: Color

    enum Style {
        case linearHeader
        case barsFooter
    }

    var body: some View {
        Text(text)
            .font(style == .linearHeader ? .subheadline.weight(.bold) : .system(size: 10, weight: .medium))
            .padding(.horizontal, style == .linearHeader ? 8 : 6)
            .padding(.vertical, style == .linearHeader ? 4 : 2)
            .background(tint.opacity(0.12))
            .overlay(Capsule().stroke(tint.opacity(0.25), lineWidth: 1))
            .clipShape(Capsule())
            .foregroundColor(foreground)
    }
}

// MARK: - Всплывающий процент при drag (Radar / Circle)

struct VisionDragPreviewCalloutBadge: View {
    let text: String
    var isAligned: Bool

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color(UIColor.systemBackground)))
            .overlay(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 0.5))
            .foregroundColor(isAligned ? .primary : .orange)
    }
}

// MARK: - Горизонтальный трек Linear (сетка 10% + заливка / проекция)

struct VisionLinearStyleHorizontalBar: View {
    let tint: Color
    var satisfaction: Double
    var potentialIncrease: Double
    var barHeight: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            GeometryReader { geo in
                let fullWidth = geo.size.width
                let trackH = geo.size.height
                let lineVerticalInset: CGFloat = 6
                let lineH = max(0, trackH - lineVerticalInset * 2)
                let gridLineColor = Color.gray.opacity(0.26)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(UIColor.secondarySystemBackground))
                    ForEach(1..<10, id: \.self) { step in
                        Rectangle()
                            .fill(gridLineColor)
                            .frame(width: 1, height: lineH)
                            .position(x: fullWidth * CGFloat(step) / 10.0, y: trackH / 2)
                    }
                }
            }
            .frame(height: barHeight)

            GeometryReader { geo in
                let satisfactionValue = satisfaction
                let currentRatio = max(0, min(1, satisfactionValue / 100.0))
                let projectedRatio = max(currentRatio, min(1, (satisfactionValue + potentialIncrease) / 100.0))
                let currentWidth = geo.size.width * currentRatio
                let projectedWidth = geo.size.width * projectedRatio

                if projectedWidth > currentWidth + 2 {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.22), tint.opacity(0.08)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: projectedWidth, height: barHeight)
                }

                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.95), tint.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: currentWidth, height: barHeight)
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: satisfaction)
            }
            .frame(height: barHeight)
        }
        .frame(height: barHeight)
    }
}
