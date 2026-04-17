import Foundation

// MARK: - Конфигурация Vision AI (вне кода / без секретов в репозитории)
//
// **Этап 3:** endpoint, модель и ключ читаются из **Info.plist** (сгенерированного через
// `INFOPLIST_KEY_*` в настройках таргета) или из **переменной окружения** — секрет не хранится в Swift-файлах.
//
// **Порядок разрешения API-ключа:**
// 1. `VisionAnalyticsAPIKey` в Info (см. Build Settings → `INFOPLIST_KEY_VisionAnalyticsAPIKey` или свой plist);
// 2. переменная окружения `VISION_ANALYTICS_API_KEY` (удобно в Xcode: Scheme → Run → Arguments → Environment);
// 3. пусто → `VisionAnalyticsService` вернёт понятное сообщение вместо сетевого вызова.
//
// **Паттерн:** **Dependency Injection** конфигурации в сервис (через `init`) и **Single Source of Truth** для URL/модели.

/// Параметры доступа к HTTP Chat Completions (OpenRouter и совместимые API).
struct VisionAnalyticsConfiguration: Sendable {
    /// Bearer-токен; пустой, если не задан ни plist, ни env.
    let apiKey: String
    /// POST URL (например `.../chat/completions`).
    let chatCompletionsURL: URL
    /// Идентификатор модели в формате провайдера.
    let modelName: String
    /// Заголовок `HTTP-Referer`, если требуется провайдером.
    let httpReferer: String

    var hasAPIKey: Bool {
        !apiKey.isEmpty
    }

    /// Имя env-переменной для локальной разработки (без коммита ключа в git).
    static let environmentAPIKeyName = "VISION_ANALYTICS_API_KEY"

    /// Загружает значения из `Bundle.main.infoDictionary` с безопасными значениями по умолчанию.
    static func loadDefault() -> VisionAnalyticsConfiguration {
        let info = Bundle.main.infoDictionary ?? [:]

        let fromPlist = (info["VisionAnalyticsAPIKey"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fromEnv = ProcessInfo.processInfo.environment[Self.environmentAPIKeyName]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let apiKey = !fromPlist.isEmpty ? fromPlist : fromEnv

        let endpointString = (info["VisionAnalyticsEndpointURL"] as? String)
            ?? "https://openrouter.ai/api/v1/chat/completions"
        let model = (info["VisionAnalyticsModelName"] as? String) ?? "deepseek/deepseek-chat"
        let referer = (info["VisionAnalyticsHTTPReferer"] as? String) ?? "https://dev.example.com"

        let url = URL(string: endpointString) ?? URL(string: "https://openrouter.ai/api/v1/chat/completions")!

        return VisionAnalyticsConfiguration(
            apiKey: apiKey,
            chatCompletionsURL: url,
            modelName: model,
            httpReferer: referer
        )
    }
}
