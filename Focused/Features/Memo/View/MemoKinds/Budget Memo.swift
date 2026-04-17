import SwiftUI
import SwiftData

// Presentation · Memo — тип «бюджет»: модель контента, экран, графики и редакторы транзакций.
// Данные хранятся внутри `MemoItem` (кодирование в `MemoModels` / content structs); impact сферы учитывается в `ImpactEngine` при пересчёте.
// Оглавление: валюта → модель `MemoBudgetContent` → основной `BudgetContentView` → карточка статистики → sheet’ы редактирования.

// MARK: Валюта и формат отображения сумм
enum BudgetCurrency: String, CaseIterable {
    case none = ""
    case dollar = "$"
    case euro = "€"
    case ruble = "₽"
    case yuan = "¥"
    
    var displayTitle: String {
        switch self {
        case .none: return "—"
        case .dollar: return "$ (dollar)"
        case .euro: return "€ (euro)"
        case .ruble: return "₽ (ruble)"
        case .yuan: return "¥ (yuan)"
        }
    }
}

// MARK: Модель данных бюджета (Codable внутри `MemoItem`)
struct MemoBudgetContent: Codable, Hashable {
    var budgets: [BudgetItem] = []
    var iconName: String = "dollarsign.circle"
    var customImageData: Data? = nil
    var colorHex: String = "#00C7BE" // default mint
    var sphereID: UUID? = nil
    var notes: String = ""
    var initialBalance: Double = 0.0
    var stepValue: Double = 100.0
    var targetValue: Double? = nil
    var currency: String = ""
    var positiveImpact: Double = 0.0
    var negativeImpact: Double = 0.0
    var additionalImpacts: [SphereImpact] = []
    
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

// MARK: Главный экран бюджета (баланс, кнопки, история, мини-статистика)
struct BudgetContentView: View {
    let item: MemoItem
    @Binding var showBudgetStatistics: Bool
    
    @Environment(\.modelContext) private var modelContext
    @State private var budgetContent: MemoBudgetContent = MemoBudgetContent()
    @State private var showEditSheet = false
    @State private var pendingDelta: Double = 0
    @State private var selectedStatsPeriod: MemoStatsPeriod = .month
    @State private var transactionToDelete: MemoBudgetContent.BudgetItem.BudgetTransaction? = nil
    @State private var transactionToEdit: MemoBudgetContent.BudgetItem.BudgetTransaction? = nil
    @State private var circlePulseScale: CGFloat = 1.0
    @State private var showValueEditor = false
    @State private var iconPulseTrigger = UUID()
    @State private var repeatTimer: Timer? = nil
    
    private let hapticManager = HapticSoundManager.shared
    
    private func filteredTransactions(for budget: MemoBudgetContent.BudgetItem) -> [MemoBudgetContent.BudgetItem.BudgetTransaction] {
        guard let start = selectedStatsPeriod.startDate() else {
            return budget.transactions
        }
        return budget.transactions.filter { $0.date >= start }
    }
    
    private var budget: MemoBudgetContent.BudgetItem? {
        return budgetContent.budgets.first
    }
    
    private var displayedBalance: Double {
        guard let b = budget else { return 0 }
        return b.currentBalance + pendingDelta
    }
    
    private func effectiveStep() -> Double {
        let raw = budgetContent.stepValue
        let positive = raw > 0 ? raw : 100
        return max(0.01, (positive * 100).rounded() / 100)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                if let budget = budget {
                    VStack(spacing: 16) {
                        budgetCircleView(budget: budget)
                        
                        budgetControlButtonsView(budget: budget)
                        
                        if let target = budgetContent.targetValue, target > 0 {
                            budgetProgressView(budget: budget, target: target)
                        }
                        
                        if !budget.transactions.isEmpty {
                            budgetHistorySection(budget: budget)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
            }
        }
        .onAppear {
            loadBudgets()
            iconPulseTrigger = UUID()
            // If no budget exists, create one with the card's title
            if budgetContent.budgets.isEmpty {
                createInitialBudget()
            }
        }
        .onDisappear {
            stopRepeatTimer()
        }
        .sheet(isPresented: $showEditSheet) {
            BudgetEditorSheet(
                budgetContent: $budgetContent,
                onSave: {
                    saveBudgets()
                }
            )
        }
        .fullScreenCover(isPresented: $showBudgetStatistics) {
            Group {
                if let budget = budget {
                    let filtered = filteredTransactions(for: budget)
                    NavigationStack {
                    ScrollView {
                        VStack(spacing: 16) {
                            statisticsView(budget: budget)
                            if !filtered.isEmpty {
                                let chartData = filtered
                                    .sorted(by: { $0.date < $1.date })
                                    .map { ChartDataPoint(date: $0.date, value: $0.amount) }
                                ChartView(
                                    data: chartData,
                                    title: "Balance changes",
                                    color: Color(hex: budgetContent.colorHex),
                                    unit: budgetContent.currency
                                )
                                .frame(height: 200)
                            }
                        }
                        .padding()
                    }
                    .background(Color(UIColor.systemGroupedBackground))
                    .navigationTitle("Statistics")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showBudgetStatistics = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                } else {
                    EmptyView()
                }
            }
        }
        .frostedDeleteConfirmation(
            isPresented: Binding(
                get: { transactionToDelete != nil },
                set: { if !$0 { transactionToDelete = nil } }
            ),
            title: "Delete transaction?",
            message: "This action cannot be undone.",
            onConfirm: {
                if let transaction = transactionToDelete,
                   !budgetContent.budgets.isEmpty {
                    deleteTransaction(budget: budgetContent.budgets[0], transaction: transaction)
                    transactionToDelete = nil
                }
            }
        )
        .sheet(item: $transactionToEdit) { transaction in
            BudgetTransactionEditSheet(
                transaction: transaction,
                currency: budgetContent.currency,
                colorHex: budgetContent.colorHex,
                onSave: { updated in
                    guard !budgetContent.budgets.isEmpty,
                          let idx = budgetContent.budgets[0].transactions.firstIndex(where: { $0.id == updated.id }) else {
                        transactionToEdit = nil
                        return
                    }
                    let oldAmount = budgetContent.budgets[0].transactions[idx].amount
                    budgetContent.budgets[0].transactions[idx] = updated
                    budgetContent.budgets[0].currentBalance += (updated.amount - oldAmount)
                    budgetContent.initialBalance = budgetContent.budgets[0].currentBalance
                    saveBudgets()
                    transactionToEdit = nil
                },
                onCancel: {
                    transactionToEdit = nil
                }
            )
        }
        .fullScreenCover(isPresented: $showValueEditor) {
            if let b = budget {
                BudgetValueEditorSheet(
                    currentBalance: b.currentBalance,
                    color: Color(hex: budgetContent.colorHex),
                    currency: budgetContent.currency,
                    onSave: { newBalance, note in
                        guard !budgetContent.budgets.isEmpty else { return }
                        let delta = newBalance - budgetContent.budgets[0].currentBalance
                        modifyBalance(budget: budgetContent.budgets[0], delta: delta, note: note)
                        showValueEditor = false
                    },
                    onCancel: {
                        showValueEditor = false
                    }
                )
            }
        }
    }
    
    // MARK: Шапка — название, баланс, валюта
    private func budgetCircleView(budget: MemoBudgetContent.BudgetItem) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let imageData = budgetContent.customImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                        .iconPulseOnceOnAppear()
                } else {
                    Image(systemName: budgetContent.iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color(hex: budgetContent.colorHex))
                        .symbolEffect(.pulse, options: .nonRepeating, value: iconPulseTrigger)
                }
                
                Text(formattedHeaderValue(budget: budget))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: budgetContent.colorHex))
                    .onTapGesture(count: 2) {
                        showValueEditor = true
                    }
                
                Spacer()
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: budgetContent.colorHex).opacity(0.16))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(circlePulseScale)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contextMenu {
            Button {
                showEditSheet = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        .onLongPressGesture(minimumDuration: 1.5, maximumDistance: 50) {
            acceptBudgetDelta(effectiveStep())
        } onPressingChanged: { isPressing in
            if isPressing {
                withAnimation(.easeInOut(duration: 1.5)) {
                    circlePulseScale = 1.05
                }
            } else {
                withAnimation(.easeOut(duration: 0.25)) {
                    circlePulseScale = 1.0
                }
            }
        }
    }
    
    private func formattedHeaderValue(budget: MemoBudgetContent.BudgetItem) -> String {
        let number = formatBudgetNumber(displayedBalance)
        let curr = budgetContent.currency.trimmingCharacters(in: .whitespaces)
        if curr.isEmpty {
            return number
        }
        return "\(number) \(curr)"
    }
    
    private func formatBudgetNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    /// Число для плиток статистики: добавляет валюту, если задана (как у старого `BudgetStatisticCard`).
    private func budgetMetricDisplayValue(_ numericFormatted: String) -> String {
        let curr = budgetContent.currency.trimmingCharacters(in: .whitespaces)
        return curr.isEmpty ? numericFormatted : "\(numericFormatted) \(curr)"
    }
    
    private func acceptBudgetDelta(_ delta: Double) {
        guard let b = budget else { return }
        modifyBalance(budget: b, delta: delta)
    }
    
    // MARK: Кнопки доход / расход / корректировка
    private func budgetControlButtonsView(budget: MemoBudgetContent.BudgetItem) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                Button {
                    addPendingDelta(-effectiveStep())
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: budgetContent.colorHex))
                }
                .onLongPressGesture(minimumDuration: 0.4, pressing: { pressing in
                    if pressing {
                        startRepeatTimer(delta: -effectiveStep())
                    } else {
                        stopRepeatTimer()
                    }
                }, perform: {})
                
                Spacer()
                
                Button {
                    addPendingDelta(effectiveStep())
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: budgetContent.colorHex))
                }
                .onLongPressGesture(minimumDuration: 0.4, pressing: { pressing in
                    if pressing {
                        startRepeatTimer(delta: effectiveStep())
                    } else {
                        stopRepeatTimer()
                    }
                }, perform: {})
            }
            .padding(.horizontal, 40)
            
            if pendingDelta != 0 {
                HStack(spacing: 20) {
                    Button("Cancel") {
                        pendingDelta = 0
                        hapticManager.playHaptic(style: .light)
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Button("Accept") {
                        acceptPendingDelta(budget: budget)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: budgetContent.colorHex))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)
                .transition(.opacity)
            }
        }
    }
    
    private func addPendingDelta(_ delta: Double) {
        withAnimation {
            pendingDelta += delta
        }
        hapticManager.playHaptic(style: .light)
    }
    
    private func startRepeatTimer(delta: Double) {
        stopRepeatTimer()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            addPendingDelta(delta)
        }
        RunLoop.main.add(repeatTimer!, forMode: .common)
    }
    
    private func stopRepeatTimer() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
    
    private func acceptPendingDelta(budget: MemoBudgetContent.BudgetItem) {
        guard pendingDelta != 0 else { return }
        withAnimation {
            modifyBalance(budget: budget, delta: pendingDelta)
            pendingDelta = 0
        }
        hapticManager.playHaptic(style: .light)
        saveBudgets()
    }
    
    // MARK: Прогресс к цели (если задан target)
    private func budgetProgressView(budget: MemoBudgetContent.BudgetItem, target: Double) -> some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(Color(hex: budgetContent.colorHex))
                        .font(.subheadline)
                    Text("Progress to target")
                        .font(.headline)
                }
                Spacer()
                Text("\(formatBudgetNumber(displayedBalance)) / \(formatBudgetNumber(target))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: budgetContent.colorHex))
                        .frame(
                            width: geometry.size.width * min(max(CGFloat(displayedBalance / max(target, 0.0001)), 0), 1.0),
                            height: 12
                        )
                }
            }
            .frame(height: 12)
            
            let percent = target > 0 ? Int(displayedBalance / max(target, 0.0001) * 100) : 0
            Text("\(percent)%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: История транзакций (скролл, свайпы)
    private func budgetHistorySection(budget: MemoBudgetContent.BudgetItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(Color(hex: budgetContent.colorHex))
                    Text("History")
                        .font(.headline)
                    Spacer()
                    Text("\(budget.transactions.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 12) {
                    ForEach(budget.transactions.sorted(by: { $0.date > $1.date }).prefix(10)) { transaction in
                        HStack(spacing: 12) {
                            Button {
                                hapticManager.selectionChanged()
                                transactionToEdit = transaction
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(budgetContent.currency.trimmingCharacters(in: .whitespaces).isEmpty
                                            ? formatBudgetTransactionAmount(transaction.amount)
                                            : "\(formatBudgetTransactionAmount(transaction.amount)) \(budgetContent.currency.trimmingCharacters(in: .whitespaces))")
                                            .font(.subheadline.bold())
                                        Text(transaction.date, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if !transaction.note.isEmpty {
                                        Text(transaction.note)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                    
                                    Image(systemName: "pencil")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                hapticManager.playNotificationHaptic(type: .warning)
                                transactionToDelete = transaction
                            } label: {
                                Image(systemName: "trash")
                                    .font(.body)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contextMenu {
                            Button {
                                transactionToEdit = transaction
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                transactionToDelete = transaction
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func formatBudgetTransactionAmount(_ amount: Double) -> String {
        let sign = amount >= 0 ? "+" : "-"
        return "\(sign)\(formatBudgetNumber(abs(amount)))"
    }
    
    // MARK: Компактная статистика по периодам
    @ViewBuilder
    private func statisticsView(budget: MemoBudgetContent.BudgetItem) -> some View {
        let filtered = filteredTransactions(for: budget)
        VStack(spacing: 16) {
            MemoStatsPeriodSegmentedPicker(selection: $selectedStatsPeriod)
            
            Text("Statistics")
                .font(.headline)
            
            HStack(spacing: 16) {
                MemoStatisticMetricCard(
                    valueScalesDown: true,
                    title: "Current",
                    value: budgetMetricDisplayValue(formatBudgetNumber(budget.currentBalance)),
                    icon: "dollarsign.circle",
                    color: Color(hex: budgetContent.colorHex)
                )
                
                if let target = budgetContent.targetValue {
                    MemoStatisticMetricCard(
                        valueScalesDown: true,
                        title: "Target",
                        value: budgetMetricDisplayValue(formatBudgetNumber(target)),
                        icon: "target",
                        color: .green
                    )
                }
            }
            
            HStack(spacing: 16) {
                let (income, expense) = calculateIncomeExpense(filtered)
                
                MemoStatisticMetricCard(
                    valueScalesDown: true,
                    title: "Income",
                    value: budgetMetricDisplayValue(formatBudgetNumber(income)),
                    icon: "arrow.down.circle",
                    color: .green
                )
                
                MemoStatisticMetricCard(
                    valueScalesDown: true,
                    title: "Expenses",
                    value: budgetMetricDisplayValue(formatBudgetNumber(-expense)),
                    icon: "arrow.up.circle",
                    color: .red
                )
            }
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
    
    // MARK: Хелперы — сохранение, пересчёт, форматирование
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
                note: note
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

// MARK: Sheet — редактирование одной записи истории
struct BudgetTransactionEditSheet: View {
    let transaction: MemoBudgetContent.BudgetItem.BudgetTransaction
    let currency: String
    let colorHex: String
    let onSave: (MemoBudgetContent.BudgetItem.BudgetTransaction) -> Void
    let onCancel: () -> Void
    
    @State private var editableAmount: Double
    @State private var editableNote: String
    
    init(transaction: MemoBudgetContent.BudgetItem.BudgetTransaction, currency: String, colorHex: String, onSave: @escaping (MemoBudgetContent.BudgetItem.BudgetTransaction) -> Void, onCancel: @escaping () -> Void) {
        self.transaction = transaction
        self.currency = currency
        self.colorHex = colorHex
        self.onSave = onSave
        self.onCancel = onCancel
        _editableAmount = State(initialValue: transaction.amount)
        _editableNote = State(initialValue: transaction.note)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(AppEditFormChrome.amountSectionTitle) {
                    TextField("Amount", value: $editableAmount, format: .number)
                        .keyboardType(.decimalPad)
                    if !currency.isEmpty {
                        Text(currency)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(AppEditFormChrome.noteSectionTitle) {
                    TextEditor(text: $editableNote)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updated = MemoBudgetContent.BudgetItem.BudgetTransaction(
                            id: transaction.id,
                            date: transaction.date,
                            amount: editableAmount,
                            note: editableNote
                        )
                        onSave(updated)
                    }
                }
            }
        }
    }
}

// MARK: Sheet — настройки бюджета (лимиты, цели)
struct BudgetEditorSheet: View {
    @Binding var budgetContent: MemoBudgetContent
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(AppEditFormChrome.mainSectionTitle) {
                    HStack {
                        Text("Step")
                        Spacer()
                        TextField("100", value: $budgetContent.stepValue, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Target value")
                        Spacer()
                        TextField("None", value: Binding(
                            get: { budgetContent.targetValue },
                            set: { newValue in
                                if let v = newValue, v > 0 {
                                    budgetContent.targetValue = v
                                } else {
                                    budgetContent.targetValue = nil
                                }
                            }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    }
                    
                    Picker("Currency", selection: Binding(
                        get: { BudgetCurrency(rawValue: budgetContent.currency) ?? .none },
                        set: { budgetContent.currency = $0.rawValue }
                    )) {
                        ForEach(BudgetCurrency.allCases, id: \.rawValue) { currency in
                            Text(currency.displayTitle).tag(currency)
                        }
                    }
                }
                
                Section(AppEditFormChrome.notesSectionTitle) {
                    TextEditor(text: $budgetContent.notes)
                        .frame(minHeight: 80)
                }
                
                Section(AppEditFormChrome.appearanceSectionTitle) {
                    MediaCirclePicker(
                        config: MediaCirclePickerConfiguration(
                            dialogTitle: "Budget media",
                            tintHex: budgetContent.colorHex,
                            size: 72,
                            fallbackIconName: "dollarsign.circle"
                        ),
                        imageData: $budgetContent.customImageData,
                        iconName: Binding(
                            get: { Optional(budgetContent.iconName) },
                            set: { newValue in
                                if let newValue { budgetContent.iconName = newValue }
                            }
                        )
                    )
                    
                    ColorPicker("Color", selection: Binding(
                        get: { Color(hex: budgetContent.colorHex) },
                        set: { budgetContent.colorHex = $0.toHex() ?? "#00C7BE" }
                    ))
                }
            }
            .navigationTitle("Edit budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: Sheet — быстрый ввод числового значения
struct BudgetValueEditorSheet: View {
    let currentBalance: Double
    let color: Color
    let currency: String
    let onSave: (Double, String) -> Void
    let onCancel: () -> Void
    
    @State private var balanceText: String = "0"
    @State private var note: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    private let hapticManager = HapticSoundManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    TextField("0", text: $balanceText)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(color)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numbersAndPunctuation)
                        .focused($isTextFieldFocused)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    if !currency.isEmpty {
                        Text(currency)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note (optional)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        TextField("enter note", text: $note)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 20)
                    }
                    
                    HStack(spacing: 20) {
                        Button("Cancel") {
                            onCancel()
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Button("Save") {
                            let trimmed = balanceText.replacingOccurrences(of: ",", with: ".")
                            let newBalance = Double(trimmed) ?? currentBalance
                            onSave(newBalance, note)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(color)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            balanceText = formatBalanceForEdit(currentBalance)
        }
    }
    
    private func formatBalanceForEdit(_ value: Double) -> String {
        if value == Double(Int(value)) {
            return "\(Int(value))"
        }
        return String(format: "%.2f", value)
    }
}

// MARK: Sheet — добавление транзакции (legacy, не в новом потоке)
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
            Picker("Type", selection: $isIncome) {
                Text("Income").tag(true)
                Text("Expense").tag(false)
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
                        Text("Note (optional)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        TextField("enter note", text: $note)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 20)
                    }
                    
                    // Кнопки Принять/Отмена
                    HStack(spacing: 20) {
                        Button("Cancel") {
                            resetDelta()
                            dismiss()
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Button("Save") {
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

