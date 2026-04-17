import SwiftUI
import SwiftData

// MARK: - Единые заголовки и отступы секций Edit (Goals / Tasks / Habits / Memo)

enum AppEditFormChrome {
    static let areaSectionTitle = "Area"
    static let basicSectionTitle = "Basic"
    static let detailsSectionTitle = "Details"
    static let tagsSectionTitle = "Tags"
    static let subTasksSectionTitle = "Sub-Tasks"
    static let subtaskDetailsSectionTitle = "Subtask Details"
    static let habitDetailsSectionTitle = "Basic"
    static let repetitionFrequencySectionTitle = "Repetition"
    
    // Memo — форма создания/редактирования
    static let streakSectionTitle = "Streak"
    static let titleSectionTitle = "Basic"
    static let notesSectionTitle = "Notes"
    static let noteSectionTitle = "Note"
    static let counterSectionTitle = "Counter"
    static let settingsSectionTitle = "Settings"
    static let budgetSectionTitle = "Budget"
    static let timeSectionTitle = "Time"
    static let healthSectionTitle = "Health"
    
    // Memo — листы настроек контента (типовые секции)
    static let appearanceSectionTitle = "Appearance"
    static let mainSectionTitle = "Main"
    static let generalSectionTitle = "General"
    static let additionalSectionTitle = "Additional"
    static let goalAndNotesSectionTitle = "Goal and notes"
    static let itemMediaSectionTitle = "Item media"
    static let valueSectionTitle = "Value"
    static let amountSectionTitle = "Amount"
    static let minutesSectionTitle = "Minutes"
    static let levelSectionTitle = "Level"
    static let moodSectionTitle = "Mood"
    
    // Vision
    static let visionSphereDetailsSectionTitle = "DETAILS"
    
    /// Вертикальный интервал между строками внутри блока Area (сфера, слайдеры, цвет).
    static let areaBlockSpacing: CGFloat = 8
    /// Отступ вокруг блока выбора цвета — как в прежних формах Memo.
    static let colorSelectionVerticalPadding: CGFloat = 5
    
    static func impactSectionTitle(areaName: String) -> String {
        "Impact on \(areaName)"
    }
}

/// Сфера + палитра (без слайдеров impact) — тот же layout, что и в `AreaImpactSection`, но для Memo до отдельной секции Impact.
struct AreaSphereAndColorFormContent: View {
    @Binding var selectedSphereID: UUID?
    @Binding var selectedColorHex: String
    @Binding var colorForPicker: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppEditFormChrome.areaBlockSpacing) {
            SpherePickerView(selectedSphereID: $selectedSphereID)
            ColorSelectionView(
                availableColors: AppConstants.Colors.palette,
                selectedColorHex: $selectedColorHex,
                colorForPicker: $colorForPicker
            )
            .padding(.vertical, AppEditFormChrome.colorSelectionVerticalPadding)
        }
    }
}

/// **Переиспользуемая секция формы (DRY)** для экранов Edit: один и тот же UI блока «Area».
/// Доменная логика (уменьшение satisfaction) не зашита внутрь — приходит через `onApplyMissDecrease`,
/// чтобы соблюсти **разделение Presentation / Domain**: View знает только «вызвать замыкание с (Sphere, amount)».
struct AreaImpactSection: View {
    let title: String
    
    @Binding var selectedSphereID: UUID?
    @Binding var positiveImpact: Double
    @Binding var negativeImpact: Double
    @Binding var colorHex: String
    @Binding var colorForPicker: Color
    
    let onApplyMissDecrease: (Sphere, Double) -> Void
    
    @Query private var spheres: [Sphere]
    
    init(
        title: String = AppEditFormChrome.areaSectionTitle,
        selectedSphereID: Binding<UUID?>,
        positiveImpact: Binding<Double>,
        negativeImpact: Binding<Double>,
        colorHex: Binding<String>,
        colorForPicker: Binding<Color>,
        onApplyMissDecrease: @escaping (Sphere, Double) -> Void
    ) {
        self.title = title
        self._selectedSphereID = selectedSphereID
        self._positiveImpact = positiveImpact
        self._negativeImpact = negativeImpact
        self._colorHex = colorHex
        self._colorForPicker = colorForPicker
        self.onApplyMissDecrease = onApplyMissDecrease
    }
    
    private var selectedSphere: Sphere? {
        guard let sid = selectedSphereID else { return nil }
        return spheres.first(where: { $0.id == sid })
    }
    
    var body: some View {
        Section(header: Text(title)) {
            VStack(alignment: .leading, spacing: AppEditFormChrome.areaBlockSpacing) {
                SpherePickerView(selectedSphereID: $selectedSphereID)
                
                if let sphere = selectedSphere {
                    ImpactSliderView(
                        positiveImpact: $positiveImpact,
                        negativeImpact: $negativeImpact,
                        range: 0...100,
                        step: 0.5,
                        unit: "%",
                        onApplyMissDecrease: { amount in
                            onApplyMissDecrease(sphere, amount)
                        }
                    )
                }
                
                ColorSelectionView(
                    availableColors: AppConstants.Colors.palette,
                    selectedColorHex: $colorHex,
                    colorForPicker: $colorForPicker
                )
                .padding(.vertical, AppEditFormChrome.colorSelectionVerticalPadding)
            }
        }
    }
}

