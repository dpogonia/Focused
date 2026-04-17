import SwiftUI
import SwiftData

// Карточка мемо в сетке — свойства, инициализатор и `body`.

// MARK: Карточка мемо в сетке
struct MemoCardView: View {
    let memoItem: MemoItem
    let design: AppDesign
    /// День календаря для streak: бейдж с огнём серый, если в этот день нет отметки (вкладка Memo / сфера Vision).
    var streakReferenceDate: Date? = nil
    var onDoubleTap: (() -> Void)? = nil
    var onLongPress: (() -> Void)? = nil
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Query(sort: \Sphere.orderIndex) var spheres: [Sphere]
    @State var showDetails: Bool = false
    @State var outerPulse = false
    @State var animationTask: Task<Void, Never>?
    @State var tapWorkItem: DispatchWorkItem?
    @State var tapCount = 0
    let hapticManager = HapticSoundManager.shared

    init(
        memoItem: MemoItem,
        design: AppDesign = .basic,
        streakReferenceDate: Date? = nil,
        onDoubleTap: (() -> Void)? = nil,
        onLongPress: (() -> Void)? = nil
    ) {
        self.memoItem = memoItem
        self.design = design
        self.streakReferenceDate = streakReferenceDate
        self.onDoubleTap = onDoubleTap
        self.onLongPress = onLongPress
    }

    private var memoCardFill: AnyShapeStyle {
        let isArchived = memoItem.status == .archived
        if design == .rainbow {
            if isArchived {
                return AnyShapeStyle(Color(UIColor.systemGray4))
            }
            return AnyShapeStyle(memoItem.itemType.gradient)
        }
        return AnyShapeStyle(Color(UIColor.systemBackground))
    }

    private var memoCardStroke: Color {
        let isArchived = memoItem.status == .archived
        if design == .rainbow {
            return isArchived ? Color.gray.opacity(0.35) : memoItem.itemType.color.opacity(0.35)
        }
        return Color(UIColor.systemGray5)
    }

    // MARK: Каркас, фон, жесты появления
    var body: some View {
        contentPreview
        .contentTransition(.opacity)
        .frame(minHeight: 72, alignment: .center)
        .mainListCardChrome(
            fill: memoCardFill,
            stroke: memoCardStroke
        )
        .onTapGesture {
            handleTap()
        }
        .onAppear {
            updateOuterPulse()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }
}
