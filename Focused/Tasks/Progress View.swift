import SwiftUI
import SwiftData

struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            // Фоновый круг
            Circle()
                .stroke(Color(UIColor.systemGray4), lineWidth: 2)
                .opacity(0.3)
            
            // Прогресс круг
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: progressGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            
            // Центральная иконка для завершенных тасков
            if progress >= 1.0 {
                Image(systemName: "checkmark")
                    .font(.caption2)
                    .foregroundColor(.green)
                    .scaleEffect(progress >= 1.0 ? 1.0 : 0.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: progress)
            }
        }
        .scaleEffect(progress > 0 ? 1.0 : 0.8)
        .opacity(progress > 0 ? 1.0 : 0.6)
        .animation(.easeInOut(duration: 0.3), value: progress)
    }
    
    private var progressGradientColors: [Color] {
        if progress >= 1.0 {
            return [.green, .mint]
        } else if progress >= 0.7 {
            return [.blue, .green]
        } else if progress >= 0.4 {
            return [.orange, .yellow]
        } else {
            return [.red, .orange]
        }
    }
}
