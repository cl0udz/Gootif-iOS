import Foundation

enum AppSettings {
    static let defaultAPIKey = Secrets.defaultAPIKey

    private static let apiKeyOverrideKey = "GootifAPIKeyOverride"

    static var apiKey: String {
        let override = UserDefaults.standard.string(forKey: apiKeyOverrideKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return override.isEmpty ? defaultAPIKey : override
    }

    static var apiKeyOverride: String {
        get { UserDefaults.standard.string(forKey: apiKeyOverrideKey) ?? "" }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: apiKeyOverrideKey)
            } else {
                UserDefaults.standard.set(trimmed, forKey: apiKeyOverrideKey)
            }
        }
    }

    static var isUsingDefaultKey: Bool {
        apiKeyOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
