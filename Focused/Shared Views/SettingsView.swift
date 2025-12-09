import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var appDesignSettings: [AppDesignSettings]
    @Query private var appCalendarSettings: [AppCalendarSettings]
    
    @State private var selectedDesign: AppDesign = .basic
    @State private var calendarVisible: Bool = true
    
    private let hapticManager = HapticSoundManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Appearance Section
                Section {
                    designPicker
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose the visual style for your app")
                }
                
                // MARK: - Calendar Section
                Section {
                    calendarToggle
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                } header: {
                    Text("Calendar")
                } footer: {
                    Text("Show or hide the calendar in all tabs")
                }
                
                // MARK: - About Section
                Section {
                    aboutRow
                    versionRow
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        hapticManager.selectionChanged()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    // MARK: - Design Picker
    @ViewBuilder
    private var designPicker: some View {
        ZStack {
            // Light yellow gradient background for the entire section
            if selectedDesign == .rainbow {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 1.0, blue: 0.8),      // Light yellow
                                Color(red: 1.0, green: 0.95, blue: 0.6),     // Warm yellow
                                Color(red: 1.0, green: 0.9, blue: 0.4)       // Golden yellow
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(selectedDesign == .rainbow ? 1 : 0)
                    .animation(.easeInOut(duration: 0.4), value: selectedDesign)
            }
            
            HStack {
                Image(systemName: "paintbrush.fill")
                    .foregroundColor(selectedDesign == .rainbow ? .orange : .blue)
                    .frame(width: 24, height: 24)
                    .animation(.easeInOut(duration: 0.3), value: selectedDesign)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("App Style")
                        .font(.body)
                    Text(selectedDesign == .basic ? "Clean and minimal" : "Colorful and vibrant")
                        .font(.caption)
                        .foregroundColor(selectedDesign == .rainbow ? .orange : .secondary)
                        .animation(.easeInOut(duration: 0.3), value: selectedDesign)
                }
                
                Spacer()
                
                Picker("Design", selection: $selectedDesign) {
                    Text("Basic")
                        .font(.system(size: 12, weight: .medium))
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                        .tag(AppDesign.basic)
                    Text("Rainbow")
                        .font(.system(size: 12, weight: .medium))
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                        .tag(AppDesign.rainbow)
                }
                .pickerStyle(.segmented)
                .tint(selectedDesign == .rainbow ? Color(red: 1.0, green: 0.9, blue: 0.4) : .blue)
                .animation(.easeInOut(duration: 0.3), value: selectedDesign)
                .frame(width: 140)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .background(
            // Invisible background to ensure proper sizing
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
        )
        .onChange(of: selectedDesign) { _, newValue in
            updateDesignSetting(newValue)
        }
    }
    
    
    // MARK: - Calendar Toggle
    @ViewBuilder
    private var calendarToggle: some View {
        ZStack {
            // Light mint gradient background when calendar is visible
            if calendarVisible {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.8, green: 1.0, blue: 0.9),      // Light mint
                                Color(red: 0.7, green: 0.95, blue: 0.85),    // Soft mint
                                Color(red: 0.6, green: 0.9, blue: 0.8)       // Mint green
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(calendarVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.4), value: calendarVisible)
            }
            
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(calendarVisible ? .mint : .green)
                    .frame(width: 24, height: 24)
                    .animation(.easeInOut(duration: 0.3), value: calendarVisible)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Calendar")
                        .font(.body)
                    Text(calendarVisible ? "Calendar is visible in all tabs" : "Calendar is hidden in all tabs")
                        .font(.caption)
                        .foregroundColor(calendarVisible ? .mint : .secondary)
                        .animation(.easeInOut(duration: 0.3), value: calendarVisible)
                }
                
                Spacer()
                
                Toggle("", isOn: $calendarVisible)
                    .tint(calendarVisible ? .mint : .green)
                    .animation(.easeInOut(duration: 0.3), value: calendarVisible)
                    .onChange(of: calendarVisible) { _, newValue in
                        updateCalendarSetting(newValue)
                    }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .background(
            // Invisible background to ensure proper sizing
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
        )
    }
    
    // MARK: - About Rows
    @ViewBuilder
    private var aboutRow: some View {
        HStack {
            Image(systemName: "info.circle")
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            Text("Focused")
                .font(.body)
            
            Spacer()
            
            Text("Productivity App")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var versionRow: some View {
        HStack {
            Image(systemName: "app.badge")
                .foregroundColor(.purple)
                .frame(width: 24, height: 24)
            
            Text("Version")
                .font(.body)
            
            Spacer()
            
            Text("1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Functions
    private func loadCurrentSettings() {
        selectedDesign = appDesignSettings.first?.design ?? .basic
        calendarVisible = appCalendarSettings.first?.isVisible ?? true
    }
    
    private func updateDesignSetting(_ newDesign: AppDesign) {
        hapticManager.selectionChanged()
        let global = appDesignSettings.first ?? {
            let s = AppDesignSettings()
            modelContext.insert(s)
            return s
        }()
        
        withAnimation(.easeInOut(duration: 0.25)) {
            global.design = newDesign
            try? modelContext.save()
        }
        NotificationCenter.default.post(name: .appDesignDidChange, object: nil)
    }
    
    private func updateCalendarSetting(_ isVisible: Bool) {
        hapticManager.selectionChanged()
        let global = appCalendarSettings.first ?? {
            let s = AppCalendarSettings()
            modelContext.insert(s)
            return s
        }()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            global.isVisible = isVisible
            try? modelContext.save()
        }
        NotificationCenter.default.post(name: .appCalendarVisibilityDidChange, object: nil)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [AppDesignSettings.self, AppCalendarSettings.self])
}
