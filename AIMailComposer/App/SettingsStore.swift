import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    private let keychainService = KeychainService()

    @AppStorage("selectedModelID") var selectedModelID: String = ""
    @AppStorage("customWritingInstructions") var customWritingInstructions: String = ""
    /// Close the composer panel (and bring Mail forward) after the primary
    /// copy action. Off = keep the panel open, like the small Copy chip.
    @AppStorage("autoCloseAfterCopy") var autoCloseAfterCopy: Bool = true
    @AppStorage("hotkeyKeyCode") var hotkeyKeyCode: Int = 0x04    // kVK_ANSI_H
    @AppStorage("hotkeyModifiers") var hotkeyModifiers: Int = 0x0800 // optionKey

    static let hotkeyDidChange = Notification.Name("hotkeyDidChange")

    func setHotkey(keyCode: Int, modifiers: Int) {
        hotkeyKeyCode = keyCode
        hotkeyModifiers = modifiers
        NotificationCenter.default.post(name: Self.hotkeyDidChange, object: nil)
    }

    // MARK: - Launch at Login

    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Failed to update launch at login: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    @Published var anthropicModels: [AIModel] = []
    @Published var openaiModels: [AIModel] = []
    @Published var geminiModels: [AIModel] = []
    @Published var openrouterModels: [AIModel] = []
    @Published var vercelModels: [AIModel] = []
    @Published var compatibleModels: [AIModel] = []
    @Published var isFetchingAnthropic = false
    @Published var isFetchingOpenAI = false
    @Published var isFetchingGemini = false
    @Published var isFetchingOpenRouter = false
    @Published var isFetchingVercel = false
    @Published var isFetchingCompatible = false
    @Published var anthropicFetchError: String?
    @Published var openaiFetchError: String?
    @Published var geminiFetchError: String?
    @Published var openrouterFetchError: String?
    @Published var vercelFetchError: String?
    @Published var compatibleFetchError: String?
    @Published var trendingModels: [TrendingModel] = []

    var allModels: [AIModel] {
        anthropicModels + openaiModels + geminiModels + openrouterModels + vercelModels + compatibleModels
    }

    /// Models grouped by provider. Within each group, sorted by release date
    /// descending (most recently released first), then by `tiebreakScore`.
    /// New flagship models land at the top without any hand-maintained list.
    var sortedGroupedModels: [(AIProvider, [AIModel])] {
        AIProvider.allCases.compactMap { provider in
            let models: [AIModel]
            switch provider {
            case .anthropic: models = anthropicModels
            case .openai: models = openaiModels
            case .gemini: models = geminiModels
            case .openrouter: models = openrouterModels
            case .vercel: models = vercelModels
            case .openaiCompatible: models = compatibleModels
            }
            guard !models.isEmpty else { return nil }
            let sorted = models.sorted { lhs, rhs in
                let lk = lhs.sortKey
                let rk = rhs.sortKey
                if lk.0 != rk.0 { return lk.0 > rk.0 }
                return lk.1 > rk.1
            }
            return (provider, sorted)
        }
    }

    /// The most popular models across all providers. Uses trending data from
    /// OpenRouter's public API so the list stays current without hardcoded
    /// model names. Falls back to a recency-based heuristic when trending
    /// data isn't available.
    var popularModels: [AIModel] {
        if !trendingModels.isEmpty {
            var popular: [AIModel] = []
            for entry in trendingModels {
                var match: AIModel?

                // Try direct-API models for the entry's provider first
                if let provider = entry.provider {
                    let providerModels: [AIModel]
                    switch provider {
                    case .anthropic:  providerModels = anthropicModels
                    case .openai:     providerModels = openaiModels
                    case .gemini:     providerModels = geminiModels
                    case .openrouter: providerModels = openrouterModels
                    case .vercel: providerModels = vercelModels
                    case .openaiCompatible: providerModels = compatibleModels
                    }
                    match = providerModels.first {
                        ModelFetcher.modelIDMatchesSlug($0.id, slug: entry.slug)
                    }
                }

                // Fall back to OpenRouter/Vercel models by full ID (both use
                // the same `provider/model` slug format).
                if match == nil {
                    match = (openrouterModels + vercelModels).first {
                        $0.id.lowercased() == entry.openRouterId.lowercased()
                    }
                }

                if let match, !popular.contains(match) {
                    popular.append(match)
                }
                if popular.count >= 5 { break }
            }
            if !popular.isEmpty { return popular }
        }

        // Fallback: top 3 newest from each provider, re-sorted.
        var candidates: [AIModel] = []
        for (_, provider) in sortedGroupedModels.enumerated() {
            candidates.append(contentsOf: provider.1.prefix(3))
        }
        return candidates
            .sorted { lhs, rhs in
                let lk = lhs.sortKey
                let rk = rhs.sortKey
                if lk.0 != rk.0 { return lk.0 > rk.0 }
                return lk.1 > rk.1
            }
            .prefix(5)
            .map { $0 }
    }

    var selectedModel: AIModel? {
        allModels.first { $0.id == selectedModelID }
    }

    /// Pick a sensible default model when none is set or the stored one
    /// disappeared from the latest fetch.
    func ensureDefaultSelection() {
        if let current = selectedModel, allModels.contains(current) {
            return
        }
        if let best = popularModels.first {
            selectedModelID = best.id
        }
    }

    func setAPIKey(_ key: String, for provider: AIProvider) throws {
        try keychainService.setKey(key, for: provider)
    }

    func getAPIKey(for provider: AIProvider) -> String? {
        keychainService.getKey(for: provider)
    }

    func deleteAPIKey(for provider: AIProvider) {
        keychainService.deleteKey(for: provider)
    }

    // MARK: - Base URL overrides

    /// The stored override only — empty string when the default is in use.
    func baseURLOverride(for provider: AIProvider) -> String {
        UserDefaults.standard.string(forKey: provider.baseURLDefaultsKey) ?? ""
    }

    func setBaseURLOverride(_ url: String, for provider: AIProvider) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: provider.baseURLDefaultsKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: provider.baseURLDefaultsKey)
        }
    }

    func makeAIClient() throws -> AIClient {
        guard let model = selectedModel else {
            throw AIClientError.requestFailed("No model selected. Open Settings and pick a model.")
        }
        return try AIClientFactory.client(for: model, keychainService: keychainService)
    }

    func fetchModels(for provider: AIProvider) async {
        guard let apiKey = getAPIKey(for: provider), !apiKey.isEmpty else { return }

        switch provider {
        case .anthropic:
            isFetchingAnthropic = true
            anthropicFetchError = nil
            do {
                anthropicModels = try await ModelFetcher.fetchAnthropicModels(apiKey: apiKey)
                ensureDefaultSelection()
            } catch {
                anthropicFetchError = error.localizedDescription
            }
            isFetchingAnthropic = false

        case .openai:
            isFetchingOpenAI = true
            openaiFetchError = nil
            do {
                openaiModels = try await ModelFetcher.fetchOpenAIModels(apiKey: apiKey)
                ensureDefaultSelection()
            } catch {
                openaiFetchError = error.localizedDescription
            }
            isFetchingOpenAI = false

        case .gemini:
            isFetchingGemini = true
            geminiFetchError = nil
            do {
                geminiModels = try await ModelFetcher.fetchGeminiModels(apiKey: apiKey)
                ensureDefaultSelection()
            } catch {
                geminiFetchError = error.localizedDescription
            }
            isFetchingGemini = false

        case .openrouter:
            isFetchingOpenRouter = true
            openrouterFetchError = nil
            do {
                openrouterModels = try await ModelFetcher.fetchOpenRouterModels(apiKey: apiKey)
                ensureDefaultSelection()
            } catch {
                openrouterFetchError = error.localizedDescription
            }
            isFetchingOpenRouter = false

        case .vercel:
            isFetchingVercel = true
            vercelFetchError = nil
            do {
                vercelModels = try await ModelFetcher.fetchVercelModels(apiKey: apiKey)
                ensureDefaultSelection()
            } catch {
                vercelFetchError = error.localizedDescription
            }
            isFetchingVercel = false

        case .openaiCompatible:
            isFetchingCompatible = true
            compatibleFetchError = nil
            do {
                compatibleModels = try await ModelFetcher.fetchOpenAICompatibleModels(apiKey: apiKey)
                ensureDefaultSelection()
            } catch {
                compatibleFetchError = error.localizedDescription
            }
            isFetchingCompatible = false
        }
    }

    func fetchAllModels() async {
        // Fetch trending/popular rankings from OpenRouter (public, no auth)
        // in parallel with provider model lists.
        async let trending = ModelFetcher.fetchTrendingModels()

        await withTaskGroup(of: Void.self) { group in
            for provider in AIProvider.allCases {
                if let key = getAPIKey(for: provider), !key.isEmpty {
                    group.addTask { await self.fetchModels(for: provider) }
                }
            }
        }

        trendingModels = await trending
    }
}
