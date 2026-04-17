import SwiftUI

/// Draws text along an arc by placing each character on the circle tangent.
/// Widths are measured using SwiftUI layout (no UIKit).
struct CurvedTextOnArcSwiftUI: View {
    let text: String
    let center: CGPoint
    let radius: CGFloat
    /// Angle pointing to the center of the string (radial direction).
    let centerAngle: Angle
    let font: Font
    let color: Color
    /// When true, rotates glyphs 180° (upside down) on the bottom half.
    let upsideDown: Bool

    @State private var widths: [Int: CGFloat] = [:]

    var body: some View {
        let chars = Array(text)
        let measured = chars.indices.compactMap { widths[$0] }
        let isReady = measured.count == chars.count
        let total: CGFloat = isReady ? measured.reduce(0, +) : 0
        let totalAngle = Double(total / max(1, radius)) // radians
        // For bottom half (upsideDown) we layout along the arc in reverse direction
        // to avoid mirrored reading order.
        let start = upsideDown
            ? (centerAngle.radians + totalAngle / 2.0)
            : (centerAngle.radians - totalAngle / 2.0)

        return ZStack {
            // Hidden measurer: collects widths for each character.
            HStack(spacing: 0) {
                ForEach(chars.indices, id: \.self) { idx in
                    Text(String(chars[idx]))
                        .font(font)
                        .fixedSize()
                        .background(WidthMeasurer(idx: idx))
                        .hidden()
                }
            }
            .onPreferenceChange(CharWidthPreferenceKey.self) { prefs in
                if prefs.count == chars.count {
                    widths = prefs
                }
            }

            // Draw curved characters only after measurement.
            if isReady {
                ZStack {
                    ForEach(chars.indices, id: \.self) { idx in
                        let prefix = chars.indices.prefix(idx).compactMap { widths[$0] }.reduce(0, +)
                        let w = widths[idx] ?? 0
                        let mid = Double((prefix + w / 2.0) / max(1, radius))
                        let a = upsideDown ? (start - mid) : (start + mid)
                        let tangent = a + Double.pi / 2.0 + (upsideDown ? Double.pi : 0)
                        Text(String(chars[idx]))
                            .font(font)
                            .foregroundStyle(color)
                            .rotationEffect(.radians(tangent))
                            .position(
                                x: center.x + cos(a) * radius,
                                y: center.y + sin(a) * radius
                            )
                    }
                }
            }
        }
    }
}

/// Draws an SF Symbol + text as ONE continuous curved label.
/// This prevents overlaps that happen when icon/text are positioned independently.
struct CurvedIconTextOnArcSwiftUI: View {
    let iconSystemName: String
    let iconColor: Color
    let text: String
    let textColor: Color
    let center: CGPoint
    let radius: CGFloat
    /// Angle pointing to the center of the whole label (icon + space + text).
    let centerAngle: Angle
    let font: Font
    let upsideDown: Bool

    @State private var widths: [Int: CGFloat] = [:]

    private enum Token: Equatable {
        case icon
        case char(Character)
    }

    var body: some View {
        let tokens: [Token] = [.icon, .char(" ")] + text.map { .char($0) }
        let measured = tokens.indices.compactMap { widths[$0] }
        let isReady = measured.count == tokens.count
        let total: CGFloat = isReady ? measured.reduce(0, +) : 0
        let totalAngle = Double(total / max(1, radius)) // radians

        let start = upsideDown
            ? (centerAngle.radians + totalAngle / 2.0)
            : (centerAngle.radians - totalAngle / 2.0)

        return ZStack {
            // Hidden measurer: collect widths for each token (icon + chars).
            HStack(spacing: 0) {
                ForEach(tokens.indices, id: \.self) { idx in
                    tokenView(tokens[idx])
                        .font(font)
                        .fixedSize()
                        .background(WidthMeasurer(idx: idx))
                        .hidden()
                }
            }
            .onPreferenceChange(CharWidthPreferenceKey.self) { prefs in
                if prefs.count == tokens.count {
                    widths = prefs
                }
            }

            if isReady {
                ZStack {
                    ForEach(tokens.indices, id: \.self) { idx in
                        let prefix = tokens.indices.prefix(idx).compactMap { widths[$0] }.reduce(0, +)
                        let w = widths[idx] ?? 0
                        let mid = Double((prefix + w / 2.0) / max(1, radius))
                        let a = upsideDown ? (start - mid) : (start + mid)
                        let tangent = a + Double.pi / 2.0 + (upsideDown ? Double.pi : 0)

                        tokenView(tokens[idx])
                            .font(font)
                            .rotationEffect(.radians(tangent))
                            .position(
                                x: center.x + cos(a) * radius,
                                y: center.y + sin(a) * radius
                            )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tokenView(_ token: Token) -> some View {
        switch token {
        case .icon:
            Image(systemName: iconSystemName)
                .foregroundStyle(iconColor)
        case .char(let c):
            Text(String(c))
                .foregroundStyle(textColor)
        }
    }
}

private struct WidthMeasurer: View {
    let idx: Int
    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: CharWidthPreferenceKey.self, value: [idx: proxy.size.width])
        }
    }
}

private struct CharWidthPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

