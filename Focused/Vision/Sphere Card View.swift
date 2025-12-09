import SwiftUI
import SwiftData

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
                    ZStack {
                        Circle().fill(color)
                        Image(systemName: sphere.iconName)
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                            .foregroundColor(.white)
                    }
                    .frame(width: 36, height: 36)
                    
                    Text(sphere.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Spacer()
                }
                
                // PROGRESS REPRESENTATION
                VStack(alignment: .leading, spacing: 8) {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 10)
                        GeometryReader { geo in
                            let width = geo.size.width * CGFloat(max(0, min(100, sphere.satisfaction))) / 100.0
                            Capsule()
                                .fill(LinearGradient(colors: [color.opacity(0.95), color.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                                .frame(width: width, height: 10)
                                .overlay(
                                    Capsule().stroke(color.opacity(0.35), lineWidth: 1)
                                )
                                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: sphere.satisfaction)
                        }
                        .frame(height: 10)
                    }
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
            ZStack {
                Circle().fill(Color(hex: sphere.colorHex))
                Image(systemName: sphere.iconName)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .foregroundColor(.white)
            }
            .frame(width: 34, height: 34)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(sphere.title).font(.headline)
                    Spacer()
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.15)).frame(height: 8)
                    GeometryReader { geo in
                        let w = geo.size.width * CGFloat(max(0, min(100, sphere.satisfaction)))/100
                        Capsule()
                            .fill(LinearGradient(colors: [Color(hex: sphere.colorHex).opacity(0.95), Color(hex: sphere.colorHex).opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: w, height: 8)
                            .overlay(Capsule().stroke(Color(hex: sphere.colorHex).opacity(0.35), lineWidth: 1))
                    }
                }
                .frame(height: 8)
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
