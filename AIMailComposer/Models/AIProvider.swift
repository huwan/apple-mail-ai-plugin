import Foundation

enum AIProvider: String, CaseIterable, Codable, Identifiable {
    case anthropic
    case openai
    case gemini
    case openrouter
    case vercel

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai: return "OpenAI"
        case .gemini: return "Google Gemini"
        case .openrouter: return "OpenRouter"
        case .vercel: return "Vercel AI Gateway"
        }
    }

    /// One-letter badge shown in the model picker.
    var badgeLetter: String {
        switch self {
        case .anthropic: return "A"
        case .openai: return "O"
        case .gemini: return "G"
        case .openrouter: return "R"
        case .vercel: return "V"
        }
    }

    /// Default API base URL (including the version segment). Endpoint paths
    /// like `/messages` or `/chat/completions` are appended to this.
    var defaultBaseURL: String {
        switch self {
        case .anthropic: return "https://api.anthropic.com/v1"
        case .openai: return "https://api.openai.com/v1"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta"
        case .openrouter: return "https://openrouter.ai/api/v1"
        case .vercel: return "https://ai-gateway.vercel.sh/v1"
        }
    }

    var baseURLDefaultsKey: String { "baseURL.\(rawValue)" }

    /// Base URL to actually use: the user's override from Settings when set,
    /// otherwise the provider default. Trailing slashes are stripped so
    /// endpoint paths can always be appended with a single "/".
    var effectiveBaseURL: String {
        let raw = UserDefaults.standard.string(forKey: baseURLDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var base = raw.isEmpty ? defaultBaseURL : raw
        while base.hasSuffix("/") { base.removeLast() }
        return base
    }
}
