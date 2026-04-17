import SwiftUI

/// **Facade над `ImpactActionDialog`**: одна точка, где решается, показывать ли вторую кнопку
/// (negative impact), какие иконку/цвет area подставить и какой текст процента вставить.
/// Это тот же идеологический приём, что и `MainTabHeaderRow` в `MainTabChrome.swift`:
/// **composition** — родитель передаёт данные и коллбеки, общий слой не содержит доменных `switch` по экранам.
enum ImpactActionPresenter {
    @ViewBuilder
    static func dialog(
        isPresented: Binding<Bool>,
        spheres: [Sphere],
        sphereID: UUID?,
        negativeImpact: Double,
        allowSecondaryAction: Bool = true,
        title: String,
        message: String,
        messageWithImpact: String,
        primaryTitle: String,
        primaryTint: Color,
        secondaryTitleFormat: String,
        secondaryTint: Color? = nil,
        onPrimary: @escaping () -> Void,
        onSecondary: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> some View {
        let sphere = sphereID.flatMap { sid in spheres.first(where: { $0.id == sid }) }
        let iconName = sphere?.iconName
        let iconTint = sphere.map { Color(hex: $0.colorHex) }
        let pct = String(format: "%.0f", negativeImpact)
        let hasSecondary = allowSecondaryAction && negativeImpact > 0 && sphere != nil
        let resolvedMessage = hasSecondary ? messageWithImpact : message

        ImpactActionDialog(
            isPresented: isPresented,
            iconName: iconName,
            iconTint: iconTint,
            title: title,
            message: resolvedMessage,
            primaryTitle: primaryTitle,
            primaryTint: primaryTint,
            onPrimary: onPrimary,
            secondaryTitle: hasSecondary ? String(format: secondaryTitleFormat, pct) : nil,
            secondaryTint: secondaryTint ?? primaryTint,
            onSecondary: hasSecondary ? onSecondary : nil,
            onCancel: onCancel
        )
    }
}

