import SwiftUI // work

// MARK: - Color Comparison Helper
func areColorsClose(_ color1: Color, _ color2: Color, tolerance: CGFloat = 0.01) -> Bool {
    let uiColor1 = UIColor(color1)
    let uiColor2 = UIColor(color2)
    var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
    var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
    uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
    uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
    return abs(r1 - r2) < tolerance && abs(g1 - g2) < tolerance && abs(b1 - b2) < tolerance && abs(a1 - a2) < tolerance
}

// MARK: - Color Selection View
struct ColorSelectionView: View {
    let availableColors: [String]
    @Binding var selectedColorHex: String
    @Binding var colorForPicker: Color
    var sphereColorHex: String? = nil // Цвет сферы для выделения
    private let hapticManager = HapticSoundManager.shared
    
    private var isCustomColorSelected: Bool {
        !availableColors.contains(where: { areColorsClose(Color(hex: $0), Color(hex: selectedColorHex)) })
    }
    
    private var isCustomColorSphereColor: Bool {
        sphereColorHex != nil && isCustomColorSelected && areColorsClose(Color(hex: selectedColorHex), Color(hex: sphereColorHex!))
    }
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 8), spacing: 12) {
            ForEach(availableColors, id: \.self) { hex in
                let presetColor = Color(hex: hex)
                let selectedColor = Color(hex: selectedColorHex)
                let isSelectedPresetColor = areColorsClose(presetColor, selectedColor)
                // Проверяем, совпадает ли цвет с цветом сферы
                let isSphereColor = sphereColorHex != nil && areColorsClose(presetColor, Color(hex: sphereColorHex!))
                
                Circle()
                    .fill(presetColor)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle().stroke(Color.accentColor, lineWidth: isSphereColor ? 3 : (isSelectedPresetColor ? 2 : 0))
                    )
                    .onTapGesture {
                        selectedColorHex = hex
                        hapticManager.selectionChanged()
                    }
            }
            
            ZStack {
                ColorPicker("", selection: $colorForPicker, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(Color.accentColor, lineWidth: isCustomColorSphereColor ? 3 : (isCustomColorSelected ? 2 : 0))
                    )
                
                if isCustomColorSelected {
                    Circle()
                        .stroke(Color.gray, lineWidth: 3)
                        .frame(width: 36, height: 36).opacity(0.5)
                }
            }
            .frame(width: 32, height: 32)
        }
        .padding(.vertical, 5)
    }
}

