import SwiftUI
import SwiftData

// Вынесены из `EditMemoView` — модификаторы onChange для цвета/сферы по типам мемо.

// MARK: Вспомогательные модификаторы UI (стили полей)
struct NoteAlbumColorModifiers: ViewModifier {
    @ObservedObject var viewModel: EditMemoViewModel
    let modelContext: ModelContext
        
    func body(content: Content) -> some View {
        content
            .modifier(NoteAlbumColorHandlers(viewModel: viewModel, modelContext: modelContext))
            .modifier(ListColorHandlers(viewModel: viewModel, modelContext: modelContext))
            .modifier(CounterColorHandlers(viewModel: viewModel, modelContext: modelContext))
            .modifier(StreakColorHandlers(viewModel: viewModel, modelContext: modelContext))
            .modifier(MoodColorHandlers(viewModel: viewModel, modelContext: modelContext))
            .modifier(SkillColorHandlers(viewModel: viewModel, modelContext: modelContext))
            .modifier(TimeColorHandlers(viewModel: viewModel, modelContext: modelContext))
            .modifier(HealthColorHandlers(viewModel: viewModel, modelContext: modelContext))
            .modifier(BudgetColorHandlers(viewModel: viewModel, modelContext: modelContext))
            .modifier(CalendarColorHandlers(viewModel: viewModel, modelContext: modelContext))
    }
}
    
struct CalendarColorHandlers: ViewModifier {
    @ObservedObject var viewModel: EditMemoViewModel
    let modelContext: ModelContext
        
    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.calendarColorForPicker) { old, newColor in
                if let newHex = newColor.toHex() {
                    if !viewModel.isUpdatingCalendarColorFromSphere {
                        viewModel.calendarColorManuallyChanged = true
                    }
                    viewModel.calendarColorHex = newHex
                }
            }
            .onChange(of: viewModel.calendarColorHex) { old, newHex in
                if !viewModel.isUpdatingCalendarColorFromSphere {
                    viewModel.calendarColorManuallyChanged = true
                }
                viewModel.calendarColorForPicker = Color(hex: newHex)
            }
            .onChange(of: viewModel.calendarContent.sphereID) { oldSphereID, newSphereID in
                if oldSphereID != newSphereID {
                    viewModel.calendarContent.positiveImpact = 0.0
                    viewModel.calendarContent.negativeImpact = 0.0
                    viewModel.calendarContent.additionalImpacts = []
                }
                if let newSphereID = newSphereID {
                    let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == newSphereID })
                    if let sphere = try? modelContext.fetch(fetchDescriptor).first {
                        if !viewModel.calendarColorManuallyChanged {
                            viewModel.isUpdatingCalendarColorFromSphere = true
                            viewModel.calendarColorHex = sphere.colorHex
                            viewModel.calendarColorForPicker = Color(hex: sphere.colorHex)
                            DispatchQueue.main.async {
                                viewModel.isUpdatingCalendarColorFromSphere = false
                            }
                        }
                    }
                }
            }
    }
}
    
struct NoteAlbumColorHandlers: ViewModifier {
    @ObservedObject var viewModel: EditMemoViewModel
    let modelContext: ModelContext
        
    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.noteAlbumColorForPicker) { old, newColor in
                if let newHex = newColor.toHex() {
                    if !viewModel.isUpdatingColorFromSphere {
                        viewModel.noteAlbumColorManuallyChanged = true
                    }
                    viewModel.noteAlbumColorHex = newHex
                }
            }
            .onChange(of: viewModel.noteAlbumColorHex) { old, newHex in
                if !viewModel.isUpdatingColorFromSphere {
                    viewModel.noteAlbumColorManuallyChanged = true
                }
                viewModel.noteAlbumColorForPicker = Color(hex: newHex)
            }
            .onChange(of: viewModel.noteAlbumSphereID) { oldSphereID, newSphereID in
                if let newSphereID = newSphereID {
                    let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == newSphereID })
                    if let sphere = try? modelContext.fetch(fetchDescriptor).first {
                        if !viewModel.noteAlbumColorManuallyChanged {
                            viewModel.isUpdatingColorFromSphere = true
                            viewModel.noteAlbumColorHex = sphere.colorHex
                            viewModel.noteAlbumColorForPicker = Color(hex: sphere.colorHex)
                            DispatchQueue.main.async {
                                viewModel.isUpdatingColorFromSphere = false
                            }
                        }
                    }
                }
            }
    }
}
    
struct ListColorHandlers: ViewModifier {
    @ObservedObject var viewModel: EditMemoViewModel
    let modelContext: ModelContext
        
    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.listColorForPicker) { old, newColor in
                if let newHex = newColor.toHex() {
                    if !viewModel.isUpdatingListColorFromSphere {
                        viewModel.listColorManuallyChanged = true
                    }
                    viewModel.listColorHex = newHex
                }
            }
            .onChange(of: viewModel.listColorHex) { old, newHex in
                if !viewModel.isUpdatingListColorFromSphere {
                    viewModel.listColorManuallyChanged = true
                }
                viewModel.listColorForPicker = Color(hex: newHex)
            }
            .onChange(of: viewModel.listContent.sphereID) { oldSphereID, newSphereID in
                if oldSphereID != newSphereID {
                    viewModel.listContent.positiveImpact = 0.0
                    viewModel.listContent.negativeImpact = 0.0
                    viewModel.listContent.additionalImpacts = []
                }
                if let newSphereID = newSphereID {
                    let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == newSphereID })
                    if let sphere = try? modelContext.fetch(fetchDescriptor).first {
                        if !viewModel.listColorManuallyChanged {
                            viewModel.isUpdatingListColorFromSphere = true
                            viewModel.listColorHex = sphere.colorHex
                            viewModel.listColorForPicker = Color(hex: sphere.colorHex)
                            DispatchQueue.main.async {
                                viewModel.isUpdatingListColorFromSphere = false
                            }
                        }
                    }
                }
            }
    }
}
    
struct CounterColorHandlers: ViewModifier {
    @ObservedObject var viewModel: EditMemoViewModel
    let modelContext: ModelContext
        
    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.counterColorForPicker) { old, newColor in
                if let newHex = newColor.toHex() {
                    if !viewModel.isUpdatingCounterColorFromSphere {
                        viewModel.counterColorManuallyChanged = true
                    }
                    viewModel.counterColorHex = newHex
                }
            }
            .onChange(of: viewModel.counterColorHex) { old, newHex in
                if !viewModel.isUpdatingCounterColorFromSphere {
                    viewModel.counterColorManuallyChanged = true
                }
                viewModel.counterColorForPicker = Color(hex: newHex)
            }
            .onChange(of: viewModel.counterContent.sphereID) { oldSphereID, newSphereID in
                if oldSphereID != newSphereID {
                    viewModel.counterContent.positiveImpact = 0.0
                    viewModel.counterContent.negativeImpact = 0.0
                    viewModel.counterContent.additionalImpacts = []
                }
                if let newSphereID = newSphereID {
                    let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == newSphereID })
                    if let sphere = try? modelContext.fetch(fetchDescriptor).first {
                        if !viewModel.counterColorManuallyChanged {
                            viewModel.isUpdatingCounterColorFromSphere = true
                            viewModel.counterColorHex = sphere.colorHex
                            viewModel.counterColorForPicker = Color(hex: sphere.colorHex)
                            DispatchQueue.main.async {
                                viewModel.isUpdatingCounterColorFromSphere = false
                            }
                        }
                    }
                }
            }
    }
}
    
struct StreakColorHandlers: ViewModifier {
    @ObservedObject var viewModel: EditMemoViewModel
    let modelContext: ModelContext
        
    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.streakColorForPicker) { old, newColor in
                if let newHex = newColor.toHex() {
                    if !viewModel.isUpdatingStreakColorFromSphere {
                        viewModel.streakColorManuallyChanged = true
                    }
                    viewModel.streakColorHex = newHex
                }
            }
            .onChange(of: viewModel.streakColorHex) { old, newHex in
                if !viewModel.isUpdatingStreakColorFromSphere {
                    viewModel.streakColorManuallyChanged = true
                }
                viewModel.streakColorForPicker = Color(hex: newHex)
            }
            .onChange(of: viewModel.streakContent.sphereID) { oldSphereID, newSphereID in
                if oldSphereID != newSphereID {
                    viewModel.streakContent.positiveImpact = 0.0
                    viewModel.streakContent.negativeImpact = 0.0
                    viewModel.streakContent.additionalImpacts = []
                }
                if let newSphereID = newSphereID {
                    let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == newSphereID })
                    if let sphere = try? modelContext.fetch(fetchDescriptor).first {
                        if !viewModel.streakColorManuallyChanged {
                            viewModel.isUpdatingStreakColorFromSphere = true
                            viewModel.streakColorHex = sphere.colorHex
                            viewModel.streakColorForPicker = Color(hex: sphere.colorHex)
                            DispatchQueue.main.async {
                                viewModel.isUpdatingStreakColorFromSphere = false
                            }
                        }
                    }
                }
            }
    }
}
    
struct MoodColorHandlers: ViewModifier {
    @ObservedObject var viewModel: EditMemoViewModel
    let modelContext: ModelContext
        
    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.moodColorForPicker) { old, newColor in
                if let newHex = newColor.toHex() {
                    if !viewModel.isUpdatingMoodColorFromSphere {
                        viewModel.moodColorManuallyChanged = true
                    }
                    viewModel.moodColorHex = newHex
                }
            }
            .onChange(of: viewModel.moodColorHex) { old, newHex in
                if !viewModel.isUpdatingMoodColorFromSphere {
                    viewModel.moodColorManuallyChanged = true
                }
                viewModel.moodColorForPicker = Color(hex: newHex)
            }
            .onChange(of: viewModel.moodContent.sphereID) { oldSphereID, newSphereID in
                if oldSphereID != newSphereID {
                    viewModel.moodContent.positiveImpact = 0.0
                    viewModel.moodContent.negativeImpact = 0.0
                    viewModel.moodContent.additionalImpacts = []
                }
                if let newSphereID = newSphereID {
                    let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == newSphereID })
                    if let sphere = try? modelContext.fetch(fetchDescriptor).first {
                        if !viewModel.moodColorManuallyChanged {
                            viewModel.isUpdatingMoodColorFromSphere = true
                            viewModel.moodColorHex = sphere.colorHex
                            viewModel.moodColorForPicker = Color(hex: sphere.colorHex)
                            DispatchQueue.main.async {
                                viewModel.isUpdatingMoodColorFromSphere = false
                            }
                        }
                    }
                }
            }
    }
}
    
struct SkillColorHandlers: ViewModifier {
    @ObservedObject var viewModel: EditMemoViewModel
    let modelContext: ModelContext
        
    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.skillColorForPicker) { old, newColor in
                if let newHex = newColor.toHex() {
                    if !viewModel.isUpdatingSkillColorFromSphere {
                        viewModel.skillColorManuallyChanged = true
                    }
                    viewModel.skillColorHex = newHex
                }
            }
            .onChange(of: viewModel.skillColorHex) { old, newHex in
                if !viewModel.isUpdatingSkillColorFromSphere {
                    viewModel.skillColorManuallyChanged = true
                }
                viewModel.skillColorForPicker = Color(hex: newHex)
            }
            .onChange(of: viewModel.skillContent.sphereID) { oldSphereID, newSphereID in
                if oldSphereID != newSphereID {
                    viewModel.skillContent.positiveImpact = 0.0
                    viewModel.skillContent.negativeImpact = 0.0
                    viewModel.skillContent.additionalImpacts = []
                }
                if let newSphereID = newSphereID {
                    let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == newSphereID })
                    if let sphere = try? modelContext.fetch(fetchDescriptor).first {
                        if !viewModel.skillColorManuallyChanged {
                            viewModel.isUpdatingSkillColorFromSphere = true
                            viewModel.skillColorHex = sphere.colorHex
                            viewModel.skillColorForPicker = Color(hex: sphere.colorHex)
                            DispatchQueue.main.async {
                                viewModel.isUpdatingSkillColorFromSphere = false
                            }
                        }
                    }
                }
            }
    }
}
    
struct TimeColorHandlers: ViewModifier {
    @ObservedObject var viewModel: EditMemoViewModel
    let modelContext: ModelContext
        
    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.timeColorForPicker) { old, newColor in
                if let newHex = newColor.toHex() {
                    if !viewModel.isUpdatingTimeColorFromSphere {
                        viewModel.timeColorManuallyChanged = true
                    }
                    viewModel.timeColorHex = newHex
                }
            }
            .onChange(of: viewModel.timeColorHex) { old, newHex in
                if !viewModel.isUpdatingTimeColorFromSphere {
                    viewModel.timeColorManuallyChanged = true
                }
                viewModel.timeColorForPicker = Color(hex: newHex)
            }
            .onChange(of: viewModel.timeContent.sphereID) { oldSphereID, newSphereID in
                if oldSphereID != newSphereID {
                    viewModel.timeContent.positiveImpact = 0.0
                    viewModel.timeContent.negativeImpact = 0.0
                    viewModel.timeContent.additionalImpacts = []
                }
                if let newSphereID = newSphereID {
                    let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == newSphereID })
                    if let sphere = try? modelContext.fetch(fetchDescriptor).first {
                        if !viewModel.timeColorManuallyChanged {
                            viewModel.isUpdatingTimeColorFromSphere = true
                            viewModel.timeColorHex = sphere.colorHex
                            viewModel.timeColorForPicker = Color(hex: sphere.colorHex)
                            DispatchQueue.main.async {
                                viewModel.isUpdatingTimeColorFromSphere = false
                            }
                        }
                    }
                }
            }
    }
}
    
struct HealthColorHandlers: ViewModifier {
    @ObservedObject var viewModel: EditMemoViewModel
    let modelContext: ModelContext
        
    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.healthColorForPicker) { old, newColor in
                if let newHex = newColor.toHex() {
                    if !viewModel.isUpdatingHealthColorFromSphere {
                        viewModel.healthColorManuallyChanged = true
                    }
                    viewModel.healthColorHex = newHex
                }
            }
            .onChange(of: viewModel.healthColorHex) { old, newHex in
                if !viewModel.isUpdatingHealthColorFromSphere {
                    viewModel.healthColorManuallyChanged = true
                }
                viewModel.healthColorForPicker = Color(hex: newHex)
            }
            .onChange(of: viewModel.healthContent.sphereID) { oldSphereID, newSphereID in
                if oldSphereID != newSphereID {
                    viewModel.healthContent.positiveImpact = 0.0
                    viewModel.healthContent.negativeImpact = 0.0
                    viewModel.healthContent.additionalImpacts = []
                }
                if let newSphereID = newSphereID {
                    let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == newSphereID })
                    if let sphere = try? modelContext.fetch(fetchDescriptor).first {
                        if !viewModel.healthColorManuallyChanged {
                            viewModel.isUpdatingHealthColorFromSphere = true
                            viewModel.healthColorHex = sphere.colorHex
                            viewModel.healthColorForPicker = Color(hex: sphere.colorHex)
                            DispatchQueue.main.async {
                                viewModel.isUpdatingHealthColorFromSphere = false
                            }
                        }
                    }
                }
            }
    }
}
    
struct BudgetColorHandlers: ViewModifier {
    @ObservedObject var viewModel: EditMemoViewModel
    let modelContext: ModelContext
        
    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.budgetColorForPicker) { old, newColor in
                if let newHex = newColor.toHex() {
                    if !viewModel.isUpdatingBudgetColorFromSphere {
                        viewModel.budgetColorManuallyChanged = true
                    }
                    viewModel.budgetColorHex = newHex
                }
            }
            .onChange(of: viewModel.budgetColorHex) { old, newHex in
                if !viewModel.isUpdatingBudgetColorFromSphere {
                    viewModel.budgetColorManuallyChanged = true
                }
                viewModel.budgetColorForPicker = Color(hex: newHex)
            }
            .onChange(of: viewModel.budgetContent.sphereID) { oldSphereID, newSphereID in
                if oldSphereID != newSphereID {
                    viewModel.budgetContent.positiveImpact = 0.0
                    viewModel.budgetContent.negativeImpact = 0.0
                    viewModel.budgetContent.additionalImpacts = []
                }
                if let newSphereID = newSphereID {
                    let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == newSphereID })
                    if let sphere = try? modelContext.fetch(fetchDescriptor).first {
                        if !viewModel.budgetColorManuallyChanged {
                            viewModel.isUpdatingBudgetColorFromSphere = true
                            viewModel.budgetColorHex = sphere.colorHex
                            viewModel.budgetColorForPicker = Color(hex: sphere.colorHex)
                            DispatchQueue.main.async {
                                viewModel.isUpdatingBudgetColorFromSphere = false
                            }
                        }
                    }
                }
            }
    }
}
