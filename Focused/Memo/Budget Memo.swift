import SwiftUI
import SwiftData

// MARK: - Budget Content Model
struct MemoBudgetContent: Codable, Hashable {
    var budgets: [BudgetItem] = []
    var iconName: String = "dollarsign.circle"
    var customImageData: Data? = nil
    var colorHex: String = "#00C7BE" // default mint
    var sphereID: UUID? = nil
    var notes: String = ""
    var initialBalance: Double = 0.0 // Начальный баланс для нового бюджета
    
    struct BudgetItem: Codable, Hashable, Identifiable {
        var id: UUID = UUID()
        var name: String = ""
        var currentBalance: Double = 0.0
        var iconName: String = "creditcard.fill"
        var customImageData: Data? = nil
        var colorHex: String = "#34C759" // default green
        var notes: String = ""
        var transactions: [BudgetTransaction] = []
        
        struct BudgetTransaction: Codable, Hashable, Identifiable {
            var id: UUID = UUID()
            var date: Date
            var amount: Double // положительное = доход, отрицательное = расход
            var note: String = ""
        }
        
        var isPositive: Bool {
            currentBalance >= 0
        }
        
        var color: Color {
            isPositive ? .green : .red
        }
    }
    
    var color: Color { Color(hex: colorHex) }
}

// MARK: - Budget Content View
struct BudgetContentView: View {
    let item: MemoItem
    @Binding var showBudgetStatistics: Bool
    
    @Environment(\.modelContext) private var modelContext
    @State private var budgetContent: MemoBudgetContent = MemoBudgetContent()
    @State private var editingBudget: MemoBudgetContent.BudgetItem? = nil
    @State private var addingTransaction: MemoBudgetContent.BudgetItem? = nil
    @State private var deltaAmount: Double = 0.0
    @State private var amountText: String = "0"
    @State private var balanceNote: String = ""
    @FocusState private var isAmountTextFieldFocused: Bool
    
    private let hapticManager = HapticSoundManager.shared
    
    // Computed property to get the single budget
    private var budget: MemoBudgetContent.BudgetItem? {
        return budgetContent.budgets.first
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Statistics View
            if showBudgetStatistics, let budget = budget, !budget.transactions.isEmpty {
                statisticsView(budget: budget)
                    .padding()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            ScrollView {
                if let budget = budget {
                    budgetDetailView(budget: budget)
                    .padding()
                }
            }
        }
        .onAppear {
            loadBudgets()
            // If no budget exists, create one with the card's title
            if budgetContent.budgets.isEmpty {
                createInitialBudget()
            }
        }
        .sheet(item: $editingBudget) { budget in
            BudgetEditorSheet(
                budget: budget,
                onSave: { updatedBudget in
                    updateBudget(updatedBudget)
                }
            )
        }
        .sheet(item: $addingTransaction) { budget in
            TransactionAddSheet(
                budget: budget,
                onSave: { amount, note in
                    addTransaction(budget: budget, amount: amount, note: note)
                }
            )
        }
    }
    
    // MARK: - Budget Detail View
    @ViewBuilder
    private func budgetDetailView(budget: MemoBudgetContent.BudgetItem) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(budget.color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    if let imageData = budget.customImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: budget.iconName)
                            .font(.title2)
                            .foregroundColor(budget.color)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(budget.name)
                        .font(.title2.bold())
                    
                    Text(formatCurrency(budget.currentBalance))
                        .font(.title3.bold())
                        .foregroundColor(budget.color)
                }
                
                Spacer()
                
                    Button {
                        editingBudget = budget
                } label: {
                    Image(systemName: "pencil")
                        .font(.title3)
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            // Balance Control
            VStack(spacing: 16) {
                // Current balance display
                VStack(spacing: 8) {
                    Text("Текущий баланс")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(formatCurrency(budget.currentBalance))
                        .font(.title.bold())
                        .foregroundColor(budget.color)
                    
                    if deltaAmount != 0 {
                        Text("→ \(formatCurrency(budget.currentBalance + deltaAmount))")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Кнопки - и + с полем суммы
            HStack(spacing: 20) {
                Button {
                        deltaAmount -= 100
                        updateAmountText()
                        hapticManager.playHaptic(style: .light)
                } label: {
                    Image(systemName: "minus.circle.fill")
                            .font(.system(size: 50))
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                    TextField("0", text: $amountText)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(deltaAmount < 0 ? .red : budget.color)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numbersAndPunctuation)
                        .focused($isAmountTextFieldFocused)
                        .onChange(of: amountText) { oldValue, newValue in
                            deltaAmount = parseAmountInput(newValue)
                }
                        .frame(width: 140)
                
                Spacer()
                
                Button {
                        deltaAmount += 100
                        updateAmountText()
                        hapticManager.playHaptic(style: .light)
                } label: {
                    Image(systemName: "plus.circle.fill")
                            .font(.system(size: 50))
                        .foregroundColor(.green)
                    }
                }
                .padding(.horizontal, 20)
                
                // Note field
                if deltaAmount != 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Заметка (опционально)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Введите заметку", text: $balanceNote)
                            .textFieldStyle(.roundedBorder)
                    }
                    .transition(.opacity)
                }
                
                // Кнопки Принять/Отмена
                if deltaAmount != 0 {
                    HStack(spacing: 20) {
                        Button("Отмена") {
                            resetBalanceDelta()
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Button("Сохранить") {
                            modifyBalance(budget: budget, delta: deltaAmount, note: balanceNote)
                            resetBalanceDelta()
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(budget.color)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .transition(.opacity)
                }
            }
            
            // Notes
            if !budget.notes.isEmpty {
                Text(budget.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Full Transactions History
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("История транзакций")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button {
                        addingTransaction = budget
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                }
                
                if budget.transactions.isEmpty {
                    Text("История транзакций пока пуста")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    ForEach(budget.transactions.sorted(by: { $0.date > $1.date })) { transaction in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                            Text(transaction.date, style: .date)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                if !transaction.note.isEmpty {
                                    Text(transaction.note)
                                        .font(.caption)
                                .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Text(formatCurrency(transaction.amount))
                                .font(.headline)
                                .foregroundColor(transaction.amount >= 0 ? .green : .red)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background((transaction.amount >= 0 ? Color.green : Color.red).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteTransaction(budget: budget, transaction: transaction)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Statistics View
    @ViewBuilder
    private func statisticsView(budget: MemoBudgetContent.BudgetItem) -> some View {
        VStack(spacing: 16) {
            Text("Статистика")
                .font(.headline)
            
            // Income/Expense cards
            let (income, expense) = calculateIncomeExpense(budget.transactions)
                    
                    HStack(spacing: 16) {
                        VStack {
                            Text(formatCurrency(income))
                                .font(.title2.bold())
                                .foregroundColor(.green)
                            Text("Доходы")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        VStack {
                            Text(formatCurrency(-expense))
                                .font(.title2.bold())
                                .foregroundColor(.red)
                            Text("Расходы")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
            // Chart
            let chartData = budget.transactions
                        .sorted(by: { $0.date < $1.date })
                .map { transaction in
                            ChartDataPoint(date: transaction.date, value: transaction.amount)
                        }
                    
                    ChartView(
                        data: chartData,
                title: budget.name,
                color: budget.color,
                        unit: ""
                    )
                    .frame(height: 200)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func calculateIncomeExpense(_ transactions: [MemoBudgetContent.BudgetItem.BudgetTransaction]) -> (Double, Double) {
        var income = 0.0
        var expense = 0.0
        
        for transaction in transactions {
            if transaction.amount >= 0 {
                income += transaction.amount
            } else {
                expense += transaction.amount
            }
        }
        
        return (income, expense)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = ""
        formatter.maximumFractionDigits = 0
        let sign = amount >= 0 ? "+" : "-"
        return "\(sign)\(formatter.string(from: NSNumber(value: abs(amount))) ?? "\(Int(abs(amount)))")"
    }
    
    // MARK: - Helper Methods
    private func loadBudgets() {
        if let data = item.contentData,
           let content = try? JSONDecoder().decode(MemoBudgetContent.self, from: data) {
            budgetContent = content
        }
    }
    
    private func saveBudgets() {
        if let data = try? JSONEncoder().encode(budgetContent) {
            item.contentData = data
            try? modelContext.save()
        }
    }
    
    private func createInitialBudget() {
        let newBudget = MemoBudgetContent.BudgetItem(
            name: item.title,
            currentBalance: budgetContent.initialBalance,
            iconName: budgetContent.iconName,
            customImageData: budgetContent.customImageData,
            colorHex: budgetContent.colorHex,
            notes: budgetContent.notes,
            transactions: []
        )
        budgetContent.budgets = [newBudget]
        saveBudgets()
    }
    
    private func resetBalanceDelta() {
        deltaAmount = 0.0
        amountText = "0"
        balanceNote = ""
        isAmountTextFieldFocused = false
    }
    
    private func updateAmountText() {
        if deltaAmount == 0.0 {
            amountText = "0"
        } else {
            amountText = String(format: "%.0f", deltaAmount)
        }
    }
    
    private func parseAmountInput(_ input: String) -> Double {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return 0.0
        }
        
        // Проверяем наличие знака минус
        let isNegative = trimmed.hasPrefix("-")
        let cleanInput = isNegative ? String(trimmed.dropFirst()) : trimmed
        
        if let amount = Double(cleanInput) {
            return isNegative ? -amount : amount
        }
        
        return 0.0
    }
    
    private func updateBudget(_ budget: MemoBudgetContent.BudgetItem) {
        if budgetContent.budgets.isEmpty {
            budgetContent.budgets = [budget]
        } else {
            budgetContent.budgets[0] = budget
        }
        // Update card title and content properties to match budget
        item.title = budget.name
        budgetContent.initialBalance = budget.currentBalance
        budgetContent.colorHex = budget.colorHex
        budgetContent.iconName = budget.iconName
        budgetContent.customImageData = budget.customImageData
        budgetContent.notes = budget.notes
        hapticManager.playHaptic(style: .light)
        saveBudgets()
    }
    
    private func modifyBalance(budget: MemoBudgetContent.BudgetItem, delta: Double, note: String = "") {
        guard !budgetContent.budgets.isEmpty else { return }
            withAnimation {
            budgetContent.budgets[0].currentBalance += delta
            budgetContent.initialBalance = budgetContent.budgets[0].currentBalance
                
                // Add transaction
                let transaction = MemoBudgetContent.BudgetItem.BudgetTransaction(
                    date: Date(),
                    amount: delta,
                note: note.isEmpty ? (delta > 0 ? "Добавлено" : "Списано") : note
                )
            budgetContent.budgets[0].transactions.append(transaction)
            }
            hapticManager.playHaptic(style: .light)
            saveBudgets()
    }
    
    private func addTransaction(budget: MemoBudgetContent.BudgetItem, amount: Double, note: String) {
        guard !budgetContent.budgets.isEmpty else { return }
            withAnimation {
            budgetContent.budgets[0].currentBalance += amount
            budgetContent.initialBalance = budgetContent.budgets[0].currentBalance
                
                let transaction = MemoBudgetContent.BudgetItem.BudgetTransaction(
                    date: Date(),
                    amount: amount,
                    note: note
                )
            budgetContent.budgets[0].transactions.append(transaction)
            }
            hapticManager.playHaptic(style: .light)
            saveBudgets()
    }
    
    private func deleteTransaction(budget: MemoBudgetContent.BudgetItem, transaction: MemoBudgetContent.BudgetItem.BudgetTransaction) {
        guard !budgetContent.budgets.isEmpty else { return }
            withAnimation {
                // Remove transaction
            budgetContent.budgets[0].transactions.removeAll { $0.id == transaction.id }
                
                // Adjust balance
            budgetContent.budgets[0].currentBalance -= transaction.amount
            budgetContent.initialBalance = budgetContent.budgets[0].currentBalance
            }
            hapticManager.playHaptic(style: .medium)
            saveBudgets()
    }
}

// MARK: - Budget Editor Sheet
struct BudgetEditorSheet: View {
    let budget: MemoBudgetContent.BudgetItem?
    let onSave: (MemoBudgetContent.BudgetItem) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var initialBalance: Double
    @State private var iconName: String
    @State private var customImageData: Data?
    @State private var colorHex: String
    @State private var notes: String
    @State private var showIconPicker = false
    
    init(budget: MemoBudgetContent.BudgetItem?, onSave: @escaping (MemoBudgetContent.BudgetItem) -> Void) {
        self.budget = budget
        self.onSave = onSave
        
        _name = State(initialValue: budget?.name ?? "")
        _initialBalance = State(initialValue: budget?.currentBalance ?? 0.0)
        _iconName = State(initialValue: budget?.iconName ?? "creditcard.fill")
        _customImageData = State(initialValue: budget?.customImageData)
        _colorHex = State(initialValue: budget?.colorHex ?? "#34C759")
        _notes = State(initialValue: budget?.notes ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Основное") {
                    TextField("Название бюджета", text: $name)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Начальный баланс")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Slider(value: $initialBalance, in: -10000...100000, step: 100)
                            Text(String(format: "%.0f", initialBalance))
                                .font(.headline)
                                .frame(width: 100)
                        }
                    }
                }
                
                Section("Дополнительно") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Заметки")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                    }
                }
                
                Section("Внешний вид") {
                    Button {
                        showIconPicker = true
                    } label: {
                        HStack {
                            Text("Иконка")
                            Spacer()
                            if let imageData = customImageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: iconName)
                                    .foregroundColor(Color(hex: colorHex))
                            }
                        }
                    }
                    
                    ColorPicker("Цвет", selection: Binding(
                        get: { Color(hex: colorHex) },
                        set: { colorHex = $0.toHex() ?? "#34C759" }
                    ))
                }
            }
            .navigationTitle(budget == nil ? "Новый бюджет" : "Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveBudget()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(
                    selectedIcon: $iconName,
                    isPresented: $showIconPicker
                )
            }
        }
    }
    
    private func saveBudget() {
        var newBudget = budget ?? MemoBudgetContent.BudgetItem()
        newBudget.name = name
        newBudget.currentBalance = initialBalance
        newBudget.iconName = iconName
        newBudget.customImageData = customImageData
        newBudget.colorHex = colorHex
        newBudget.notes = notes
        
        onSave(newBudget)
        dismiss()
    }
}

// MARK: - Transaction Add Sheet
struct TransactionAddSheet: View {
    let budget: MemoBudgetContent.BudgetItem
    let onSave: (Double, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var deltaAmount: Double = 0.0
    @State private var amountText: String = "0"
    @State private var note: String = ""
    @State private var isIncome: Bool = true
    @FocusState private var isTextFieldFocused: Bool
    
    private let stepAmount: Double = 100.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Picker for income/expense
                    Picker("Тип", selection: $isIncome) {
                        Text("Доход").tag(true)
                        Text("Расход").tag(false)
            }
            .pickerStyle(.segmented)
            .padding()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Кнопки - и + с полем суммы
                    HStack(spacing: 20) {
                        Button {
                            deltaAmount -= stepAmount
                            updateAmountText()
                            hapticManager.playHaptic(style: .light)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        TextField("0", text: $amountText)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(deltaAmount < 0 ? .red : budget.color)
                            .multilineTextAlignment(.center)
                            .keyboardType(.numbersAndPunctuation)
                            .focused($isTextFieldFocused)
                            .onChange(of: amountText) { oldValue, newValue in
                                deltaAmount = parseAmountInput(newValue)
                            }
                            .frame(width: 140)
                        
                        Spacer()
                        
                        Button {
                            deltaAmount += stepAmount
                            updateAmountText()
                            hapticManager.playHaptic(style: .light)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Note field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Заметка (опционально)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        TextField("Введите заметку", text: $note)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 20)
                    }
                    
                    // Кнопки Принять/Отмена
                    HStack(spacing: 20) {
                        Button("Отмена") {
                            resetDelta()
                            dismiss()
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Button("Сохранить") {
                            let finalAmount = isIncome ? abs(deltaAmount) : -abs(deltaAmount)
                            onSave(finalAmount, note)
                            dismiss()
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(budget.color)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(deltaAmount == 0.0)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            resetDelta()
        }
    }
    
    private let hapticManager = HapticSoundManager.shared
    
    private func resetDelta() {
        deltaAmount = 0.0
        amountText = "0"
        note = ""
        isTextFieldFocused = false
    }
    
    private func updateAmountText() {
        if deltaAmount == 0.0 {
            amountText = "0"
        } else {
            amountText = String(format: "%.0f", deltaAmount)
        }
    }
    
    private func parseAmountInput(_ input: String) -> Double {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return 0.0
        }
        
        // Проверяем наличие знака минус
        let isNegative = trimmed.hasPrefix("-")
        let cleanInput = isNegative ? String(trimmed.dropFirst()) : trimmed
        
        if let amount = Double(cleanInput) {
            return isNegative ? -amount : amount
        }
        
        return 0.0
    }
}

