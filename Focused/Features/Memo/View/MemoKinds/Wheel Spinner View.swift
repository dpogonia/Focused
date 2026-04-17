import SwiftUI

// Presentation · Memo — игровой «колесо» выбора пункта из списка (UI над данными List-мемо).
// Оглавление: полноэкранное колесо → треугольник-указатель → компактная кнопка в списке.

// MARK: Полноэкранное колесо и анимация
struct WheelSpinnerView: View {
    let items: [MemoListItem]
    @State private var isSpinning = false
    @State private var selectedItem: MemoListItem?
    @State private var rotationAngle: Double = 0
    @State private var showResult = false
    
    private let hapticManager = HapticSoundManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            if items.isEmpty {
                Text("List is empty")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                // Wheel visualization
                ZStack {
                    // Background circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.green.opacity(0.1), .green.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 200, height: 200)
                        .overlay(
                            Circle()
                                .stroke(Color.green, lineWidth: 3)
                        )
                    
                    // Items arranged in circle
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        let angle = (Double(index) / Double(items.count)) * 360
                        let adjustedAngle = angle - 90 // Start from top
                        
                        Text(item.text)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                            .multilineTextAlignment(.center)
                            .frame(width: 60)
                            .offset(y: -70)
                            .rotationEffect(.degrees(adjustedAngle))
                    }
                    
                    // Center pointer
                    VStack {
                        Triangle()
                            .fill(Color.red)
                            .frame(width: 20, height: 15)
                            .offset(y: -85)
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                    }
                }
                .rotationEffect(.degrees(rotationAngle))
                .animation(.easeOut(duration: 2.0), value: rotationAngle)
                
                // Spin button
                Button(action: spinWheel) {
                    HStack(spacing: 8) {
                        Image(systemName: "shuffle")
                            .font(.title2)
                        Text("Spin the wheel")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .scaleEffect(isSpinning ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isSpinning)
                }
                .disabled(isSpinning)
                
                // Result display
                if let selectedItem = selectedItem, showResult {
                    VStack(spacing: 12) {
                        Text("Result:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(selectedItem.text)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.green, lineWidth: 2)
                            )
                    }
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showResult)
                }
            }
        }
        .padding()
    }
    
    private func spinWheel() {
        guard !items.isEmpty && !isSpinning else { return }
        
        hapticManager.selectionChanged()
        
        isSpinning = true
        showResult = false
        selectedItem = nil
        
        // Calculate random rotation (multiple full rotations + random angle)
        let baseRotations = Double.random(in: 5...8) * 360
        let randomAngle = Double.random(in: 0...360)
        let finalAngle = baseRotations + randomAngle
        
        rotationAngle += finalAngle
        
        // Calculate which item will be selected
        let normalizedAngle = (360 - (finalAngle.truncatingRemainder(dividingBy: 360))) + 90
        let itemIndex = Int((normalizedAngle / 360) * Double(items.count)) % items.count
        
        // Show result after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            selectedItem = items[itemIndex]
            showResult = true
            isSpinning = false
            hapticManager.completionSuccess()
        }
    }
}

// MARK: Форма треугольника для указателя
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: Компактная кнопка открытия колеса (для list-мемо)
struct WheelSpinnerButton: View {
    let items: [MemoListItem]
    @State private var showWheel = false
    
    var body: some View {
        Button(action: {
            showWheel = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "shuffle")
                    .font(.title3)
                Text("Wheel")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [.green, .green.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
        }
        .sheet(isPresented: $showWheel) {
            NavigationView {
                WheelSpinnerView(items: items)
                    .navigationTitle("Wheel")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showWheel = false
                            }
                        }
                    }
            }
        }
    }
}
