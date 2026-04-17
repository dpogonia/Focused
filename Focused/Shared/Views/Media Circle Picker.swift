import SwiftUI
import ImageIO
import PhotosUI

struct MediaCirclePickerConfiguration: Equatable {
    var dialogTitle: String
    var tintHex: String
    var size: CGFloat
    var fallbackIconName: String
    var ringLineWidth: CGFloat = 4
    var innerFillOpacity: Double = 0.15
    var ringOpacity: Double = 0.95
}

/// **Компонент с состоянием + биндинги к модели** (`@Binding imageData/iconName`):
/// визуальная оболочка живёт здесь, а родитель (например `EditGoalView`) остаётся тонким — только передаёт данные.
/// Взаимное исключение фото/иконки — **инвариант UI**, поэтому сброс делается в одном месте при выборе.
///
/// Reusable block for picking either an SF Symbol icon or a photo, shown inside a circular preview.
/// - Tap on the circle to choose: icon / photo / reset.
/// - Icon and photo are mutually exclusive: picking one clears the other.
struct MediaCirclePicker: View {
    let config: MediaCirclePickerConfiguration
    
    @Binding var imageData: Data?
    @Binding var iconName: String?
    
    /// If true, always show the picker options even when empty.
    var allowReset: Bool = true
    
    @State private var showIconPicker: Bool = false
    @State private var showMediaChoice: Bool = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showPhotoPicker: Bool = false
    
    private let hapticManager = HapticSoundManager.shared
    
    init(
        dialogTitle: String,
        tintHex: String,
        size: CGFloat,
        fallbackIconName: String,
        imageData: Binding<Data?>,
        iconName: Binding<String?>,
        allowReset: Bool = true
    ) {
        self.config = MediaCirclePickerConfiguration(
            dialogTitle: dialogTitle,
            tintHex: tintHex,
            size: size,
            fallbackIconName: fallbackIconName
        )
        self._imageData = imageData
        self._iconName = iconName
        self.allowReset = allowReset
    }
    
    init(
        config: MediaCirclePickerConfiguration,
        imageData: Binding<Data?>,
        iconName: Binding<String?>,
        allowReset: Bool = true
    ) {
        self.config = config
        self._imageData = imageData
        self._iconName = iconName
        self.allowReset = allowReset
    }
    
    var body: some View {
        Button {
            hapticManager.selectionChanged()
            showMediaChoice = true
        } label: {
            ZStack {
                let tint = Color(hex: config.tintHex)
                
                // Outer colored ring.
                Circle()
                    .stroke(tint.opacity(config.ringOpacity), lineWidth: config.ringLineWidth)
                    .frame(width: config.size + 10, height: config.size + 10)
                
                // Inner background.
                Circle()
                    .fill(tint.opacity(config.innerFillOpacity))
                    .frame(width: config.size, height: config.size)
                
                if let imageData {
                    CircularImageDataView(data: imageData)
                        .frame(width: config.size, height: config.size)
                        .clipShape(Circle())
                } else {
                    Image(systemName: iconName ?? config.fallbackIconName)
                        .font(.system(size: config.size * 0.44, weight: .semibold))
                        .foregroundColor(tint)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 6)
        .confirmationDialog(config.dialogTitle, isPresented: $showMediaChoice, titleVisibility: .visible) {
            Button("Choose icon") {
                hapticManager.selectionChanged()
                showIconPicker = true
            }
            Button("Choose photo") {
                hapticManager.selectionChanged()
                showPhotoPicker = true
            }
            if allowReset {
                Button("Reset", role: .destructive) {
                    hapticManager.selectionChanged()
                    resetToDefault()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showIconPicker) {
            IconCatalogPickerView(
                title: "Choose icon",
                tintColor: Color(hex: config.tintHex),
                selectedIconName: $iconName,
                onPick: {
                // When selecting an icon, remove photo.
                imageData = nil
                selectedPhoto = nil
                }
            )
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        // When selecting a photo, clear any custom icon.
                        imageData = data
                        iconName = nil
                    }
                }
            }
        }
    }
    
    private func resetToDefault() {
        imageData = nil
        selectedPhoto = nil
        // Reset should restore the configured default symbol (not leave nil),
        // so callers can enforce a specific default like "trophy".
        iconName = config.fallbackIconName
    }
}

private struct CircularImageDataView: View {
    let data: Data
    var body: some View {
        if let cg = decodeCGImage(data) {
            Image(decorative: cg, scale: 1)
                .resizable()
                .scaledToFill()
        } else {
            // If decoding fails, keep layout stable with an empty placeholder.
            Color.clear
        }
    }
    
    private func decodeCGImage(_ data: Data) -> CGImage? {
        let cfData = data as CFData
        guard let source = CGImageSourceCreateWithData(cfData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

