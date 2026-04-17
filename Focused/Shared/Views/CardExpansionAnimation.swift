import SwiftUI

/// Shared motion for expanding/collapsing list cards (Goals, Tasks, Habits, Memo).
enum CardExpansionAnimation {
    /// Soft settle: high damping avoids overshoot; fewer “ghost” frames than bouncier springs.
    static let spring = Animation.spring(response: 0.68, dampingFraction: 0.96)
}
