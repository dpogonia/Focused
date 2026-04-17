import Foundation
import SwiftData

// MARK: - Реализация Vision AI (`Services/VisionAnalytics`)
//
// **Adapter** к HTTP API (OpenRouter-совместимый Chat Completions): реализует `VisionAnalyticsServicing`.
// Зависит только от `VisionAnalyticsConfiguration` (**DI**): URL, модель и ключ не зашиты в коде.
//
// Ответ API декодируется в `OpenRouterResponse` из `Features/Vision/View/Visions Model.swift` (**разделение DTO и сервиса**).

final class VisionAnalyticsService: VisionAnalyticsServicing {
    static let shared = VisionAnalyticsService(configuration: .loadDefault())

    private let configuration: VisionAnalyticsConfiguration

    /// Для тестов и кастомных endpoint’ов передайте свой `VisionAnalyticsConfiguration`.
    init(configuration: VisionAnalyticsConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Public API

    func generateLifetimeVision(
        for sphere: Sphere,
        goals: [Goal],
        tasks: [SuperTask],
        habits: [Habit]
    ) async -> String {
        let sphereHabits = habits.filter { $0.sphereID == sphere.id }.map { $0.title }.joined(separator: ", ")
        let sphereGoals = goals.filter { $0.sphereID == sphere.id }.map { $0.title }.joined(separator: ", ")
        let sphereTasks = tasks.filter { $0.sphereID == sphere.id }.map { $0.title }.joined(separator: ", ")

        let prompt = """
        Create a creative and motivating vision for lifetime vision for the life sphere "\(sphere.title)" with the current satisfaction level \(String(format: "%.0f", sphere.satisfaction))%.
        For context, here are the related goals: \(sphereGoals.isEmpty ? "not set" : sphereGoals).
        Related tasks: \(sphereTasks.isEmpty ? "not set" : sphereTasks).
        Related habits: \(sphereHabits.isEmpty ? "not set" : sphereHabits).
        Add emojis, possibly a short inspiring quote, and make the text vivid, as if it were a personal success plan.
        Important: Output ONLY the vision text, without any introductions, explanations, comments or Markdown. Do not use headings or bullet points. Start immediately with the vision as plain prose.
        Example: 🚀 You will conquer the peaks in Finance, reaching 90% satisfaction! With your goals... [vision text]. 'Quote'. 🌟
        """

        return await sendRequest(with: prompt)
    }

    func generateAnalyticsAdvice(
        for sphere: Sphere,
        goals: [Goal],
        tasks: [SuperTask],
        habits: [Habit],
        memoItems: [MemoItem]
    ) async -> String {
        let goalsSnapshot = goals.map { goal in
            let status = goal.status.rawValue
            let impact = goal.positiveImpact - goal.negativeImpact
            return "• \(goal.title) [\(status), impact: \(String(format: "%.1f", impact))]"
        }.joined(separator: "\n")

        let tasksSnapshot = tasks.map { task in
            let status = SuperTask.Status(rawValue: task.status) ?? .inProgress
            return "• \(task.title) [status: \(status.rawValue)]"
        }.joined(separator: "\n")

        let habitsSnapshot = habits.map { habit in
            let logic = HabitLogicService(habit: habit)
            let streak = logic.calculateStreak(upTo: Date())
            return "• \(habit.title) [required reps: \(habit.requiredRepetitions), current streak: \(streak) days]"
        }.joined(separator: "\n")

        let memoTypesCount = Dictionary(grouping: memoItems, by: { $0.itemType }).map { type, items in
            "• \(type.displayName): \(items.count)"
        }.sorted().joined(separator: "\n")

        let prompt = """
        You are an experienced productivity and personal growth coach. Analyze the ENTIRE system of the user in the Focused app and give concrete development recommendations.

        Current focus sphere: "\(sphere.title)" with satisfaction level \(String(format: "%.0f", sphere.satisfaction))%.

        IMPORTANT: below you have data about all goals, tasks, habits and memo entries of the user (not only for this sphere).

        Goals (total \(goals.count)):
        \(goalsSnapshot.isEmpty ? "• no goals" : goalsSnapshot)

        Tasks (total \(tasks.count)):
        \(tasksSnapshot.isEmpty ? "• no tasks" : tasksSnapshot)

        Habits (total \(habits.count)):
        \(habitsSnapshot.isEmpty ? "• no habits" : habitsSnapshot)

        Memo (notes and trackers):
        \(memoTypesCount.isEmpty ? "• no memo entries yet" : memoTypesCount)

        Based on all this data, write an analytical report and development plan for the user.
        Formatting rules:
        - Write in English, as continuous plain text, without Markdown, headings or lists.
        - You may use short paragraphs, but do not use characters like #, *, -, numbered lists or other markup symbols.
        - Do not repeat the raw lists above; instead, provide a human interpretation.

        Content structure (follow it, but do NOT explicitly number sections in the text):
        1) Briefly describe the current situation and main behavior patterns.
        2) Highlight the strengths of the system (what already works well).
        3) Show the main bottlenecks and risks (overload, missing links between goals, tasks, habits, etc.).
        4) Formulate several concrete recommendations for the next 30 days that will help build a coherent system (connecting goals, tasks, habits and memo usage).
        5) Finish with one inspiring sentence.
        """

        return await sendRequest(with: prompt)
    }

    // MARK: - Networking

    private func sendRequest(with prompt: String) async -> String {
        guard configuration.hasAPIKey else {
            return """
            Vision AI is not configured. Add your API key: set Info.plist key VisionAnalyticsAPIKey (via target Build Settings INFOPLIST_KEY_VisionAnalyticsAPIKey) or environment variable \(VisionAnalyticsConfiguration.environmentAPIKeyName). See VisionAnalyticsConfiguration.swift for details.
            """
        }

        var request = URLRequest(url: configuration.chatCompletionsURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(configuration.httpReferer, forHTTPHeaderField: "HTTP-Referer")

        let body: [String: Any] = [
            "model": configuration.modelName,
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.8,
            "max_tokens": 400
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            return "Error: Could not create request body."
        }
        request.httpBody = jsonData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                if let rawString = String(data: data, encoding: .utf8) {
                    print("Raw API Error Response: \(rawString)")
                }
                return "ERROR API: Code \(httpResponse.statusCode). Check console for more."
            }

            let apiResponse = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
            return apiResponse.choices.first?.message.content ?? "Try again"
        } catch {
            return "ERROR: \(error.localizedDescription). Check console for more."
        }
    }
}
