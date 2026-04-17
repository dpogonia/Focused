import SwiftUI

/// Reusable centered frosted confirmation dialog with optional "apply negative impact" action.
struct ImpactActionDialog: View {
    @Binding var isPresented: Bool
    
    let iconName: String?
    let iconTint: Color?
    
    let title: String
    let message: String
    
    let primaryTitle: String
    let primaryTint: Color
    let onPrimary: () -> Void
    
    let secondaryTitle: String?
    let secondaryTint: Color?
    let onSecondary: (() -> Void)?
    
    let onCancel: () -> Void
    
    private let hapticManager = HapticSoundManager.shared
    
    var body: some View {
        if isPresented {
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        hapticManager.selectionChanged()
                        isPresented = false
                        onCancel()
                    }
                
                VStack(spacing: 14) {
                    VStack(spacing: 10) {
                        if let iconName, let iconTint {
                            ZStack {
                                Circle()
                                    .fill(iconTint.opacity(0.15))
                                Image(systemName: iconName)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(iconTint)
                            }
                            .frame(width: 44, height: 44)
                        }
                        
                        Text(title)
                            .glassDialogTitleTextStyle()
                        
                        Text(message)
                            .glassDialogMessageTextStyle()
                    }
                    
                    VStack(spacing: 10) {
                        Button(primaryTitle) {
                            isPresented = false
                            onPrimary()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(primaryTint)
                        
                        if let secondaryTitle, let onSecondary {
                            Button(secondaryTitle) {
                                isPresented = false
                                onSecondary()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(secondaryTint ?? primaryTint)
                        }
                        
                        Button("Cancel", role: .cancel) {
                            hapticManager.selectionChanged()
                            isPresented = false
                            onCancel()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(22)
                .frame(width: 300)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                .transition(.scale.combined(with: .opacity))
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPresented)
        }
    }
}

