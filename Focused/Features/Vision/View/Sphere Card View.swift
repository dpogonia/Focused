import SwiftUI
import SwiftData

// Presentation · Vision — компактная карточка сферы (выбор, цвет, иконка).
// Не содержит расчёта impact — только отображение полей `Sphere`.

struct SphereCardView: View {
    let sphere: Sphere
    let isSelected: Bool
    
    private var color: Color { Color(hex: sphere.colorHex) }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(UIColor.systemBackground), Color(UIColor.secondarySystemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
                //.shadow(color: .black.opacity(isSelected ? 0.15 : 0.08), radius: isSelected ? 10 : 6, x: 0, y: isSelected ? 4 : 2)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    VisionSphereIconDisc(color: color, iconName: sphere.iconName, diameter: 36, iconInset: 8)
                    
                    Text(sphere.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Spacer()
                }
                
                // PROGRESS REPRESENTATION
                VStack(alignment: .leading, spacing: 8) {
                    VisionSatisfactionCapsuleBar(
                        tint: color,
                        satisfaction: sphere.satisfaction,
                        height: VisionSphereChrome.satisfactionBarHeightLarge,
                        showFillStroke: true
                    )
                    HStack(spacing: 8) {
                        Text(String(format: "%.0f%%", sphere.satisfaction))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.12))
                            .overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 1))
                            .clipShape(Capsule())
                        Spacer()
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 240, height: 160)
    }
}

// MARK: - SELECTED SPHERE DETAILS CARD
struct SelectedSpereCard: View {
    let sphere: Sphere
    let onEdit: (Sphere) -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VisionSphereIconDisc(
                color: Color(hex: sphere.colorHex),
                iconName: sphere.iconName,
                diameter: 34,
                iconInset: 8
            )
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(sphere.title).font(.headline)
                    Spacer()
                }
                VisionSatisfactionCapsuleBar(
                    tint: Color(hex: sphere.colorHex),
                    satisfaction: sphere.satisfaction,
                    height: VisionSphereChrome.satisfactionBarHeightCompact,
                    showFillStroke: true
                )
            }
            Text(String(format: "%.0f%%", sphere.satisfaction))
                .font(.subheadline).bold()
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color(hex: sphere.colorHex).opacity(0.12))
                .overlay(Capsule().stroke(Color(hex: sphere.colorHex).opacity(0.25), lineWidth: 1))
                .clipShape(Capsule())
        }
        //.padding(12)
//        .background(
//            RoundedRectangle(cornerRadius: 12)
//                .fill(Color(UIColor.secondarySystemBackground))
                //.overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.06), lineWidth: 1))
        //)
        //.padding(.horizontal, 16)
        .onTapGesture {
            onEdit(sphere)
        }
    }
}
