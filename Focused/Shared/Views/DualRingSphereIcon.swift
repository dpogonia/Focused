import SwiftUI

// Presentation · Shared — иконка сферы с кольцами (Vision, дашборд). Без доменной логики.

/// Reusable icon badge with two concentric rings and optional pulse animation.
struct DualRingSphereIcon: View {
    let iconName: String?
    let color: Color
    var size: CGFloat = 30
    var isSelected: Bool = false
    var forcePulse: Bool = false
    
    @State private var pulse = false
    
    private var outerRingWidth: CGFloat { size * 0.12 }
    private var innerRingSize: CGFloat { size * 0.68 }
    private var coreSize: CGFloat { size * 0.46 }
    private var iconSize: CGFloat { size * 0.42 }
    
    var body: some View {
        ZStack {
            // Background mask to fully cover underlying radar lines
            Circle()
                .fill(Color(UIColor.systemBackground))
                .frame(width: size + 8, height: size + 8)
            
            // Outer, soft ring
            Circle()
                .stroke(color.opacity(1.0), lineWidth: outerRingWidth)
                .frame(width: size, height: size)
                .scaleEffect(pulseScale)
            
            // Inner crisp ring
            Circle()
                .stroke(color.opacity(0.3), lineWidth: outerRingWidth * 0.95)
                .frame(width: innerRingSize, height: innerRingSize)
                .scaleEffect(innerPulseScale)
            
            // Core fill
            Circle()
                .fill(color.opacity(0.0))
                .frame(width: coreSize, height: coreSize)
            
            if let symbol = iconSymbol {
                Image(systemName: symbol)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(color)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .shadow(color: color.opacity(isSelected ? 0.32 : 0.0), radius: isSelected ? 8 : 0, x: 0, y: 2)
        .onAppear { updatePulse() }
        .onChange(of: isSelected) { updatePulse() }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isSelected)
    }
    
    private var pulseScale: CGFloat {
        guard shouldPulse else { return 1.0 }
        return pulse ? 1.08 : 0.96
    }
    
    private var innerPulseScale: CGFloat {
        guard shouldPulse else { return 1.0 }
        return pulse ? 1.03 : 0.98
    }
    
    private func updatePulse() {
        guard shouldPulse else {
            pulse = false
            return
        }
        pulse = false
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
    
    private var shouldPulse: Bool { forcePulse || isSelected }
    
    private var iconSymbol: String? {
        guard let iconName = iconName, !iconName.isEmpty else { return nil }
        return iconName 
    }
}

