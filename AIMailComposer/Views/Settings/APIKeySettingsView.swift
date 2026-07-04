import SwiftUI

struct APIKeySettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    /// Provider being edited. Persisted so the page reopens on the one the
    /// user actually uses. Keys for other providers stay saved regardless.
    @AppStorage("settingsProviderTab") private var selectedProviderRaw: String = AIProvider.anthropic.rawValue
    @State private var currentKey: String = ""
    @State private var currentBaseURL: String = ""
    @State private var configuredProviders: Set<AIProvider> = []
    @State private var statusMessage: String = ""
    @State private var isError: Bool = false
    @State private var modelSearchText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            apiKeyFields
            Divider()
            modelSection
        }
    }

    // MARK: - API Keys

    private var selectedProvider: AIProvider {
        AIProvider(rawValue: selectedProviderRaw) ?? .anthropic
    }

    private var apiKeyFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Provider")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Picker("", selection: $selectedProviderRaw) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.displayName + (configuredProviders.contains(provider) ? "  ✓" : ""))
                            .tag(provider.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 220, alignment: .leading)
                Spacer()
            }

            KeyField(label: "API Key", placeholder: keyPlaceholder, text: $currentKey)

            VStack(alignment: .leading, spacing: 3) {
                Text("Base URL")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField(baseURLPlaceholder, text: $currentBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                Text(selectedProvider == .openaiCompatible
                     ? "Any endpoint that speaks the OpenAI chat-completions protocol (DeepSeek, Groq, Ollama, …)."
                     : "Leave empty for the default. Useful for proxies and gateways.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 2)
            }

            HStack(spacing: 8) {
                Button("Save") { saveCurrent() }
                    .controlSize(.small)
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(isError ? .red : .green)
                        .lineLimit(1)
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear {
            loadProviderFields()
            refreshConfiguredProviders()
        }
        .onChange(of: selectedProviderRaw) { _ in
            statusMessage = ""
            loadProviderFields()
        }
    }

    private var keyPlaceholder: String {
        switch selectedProvider {
        case .anthropic: return "sk-ant-api03-…"
        case .openai: return "sk-…"
        case .gemini: return "AIza…"
        case .openrouter: return "sk-or-v1-…"
        case .vercel: return "vck_…"
        case .openaiCompatible: return "API key for your endpoint"
        }
    }

    private var baseURLPlaceholder: String {
        let defaultURL = selectedProvider.defaultBaseURL
        return defaultURL.isEmpty ? "https://your-gateway.example.com/v1 (required)" : defaultURL
    }

    private func loadProviderFields() {
        currentKey = settingsStore.getAPIKey(for: selectedProvider) ?? ""
        currentBaseURL = settingsStore.baseURLOverride(for: selectedProvider)
    }

    private func refreshConfiguredProviders() {
        configuredProviders = Set(AIProvider.allCases.filter {
            !(settingsStore.getAPIKey(for: $0) ?? "").isEmpty
        })
    }

    // MARK: - Model Selection

    private var isFetching: Bool {
        settingsStore.isFetchingAnthropic
            || settingsStore.isFetchingOpenAI
            || settingsStore.isFetchingGemini
            || settingsStore.isFetchingOpenRouter
            || settingsStore.isFetchingVercel
            || settingsStore.isFetchingCompatible
    }

    @ViewBuilder
    private var modelSection: some View {
        if settingsStore.allModels.isEmpty && !isFetching {
            modelEmptyState
        } else {
            modelList
        }
    }

    private var modelEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cpu")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No models available")
                .font(.subheadline)
                .fontWeight(.medium)
            Text("Save an API key above, then models will be fetched from the provider.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            fetchErrorLines
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private var modelList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Model")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if isFetching {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Refresh") {
                    Task { await settingsStore.fetchAllModels() }
                }
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                TextField("Search models…", text: $modelSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !modelSearchText.isEmpty {
                    Button {
                        modelSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .padding(.horizontal)
            .padding(.bottom, 8)

            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 0) {
                    if let selected = settingsStore.selectedModel {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 11))
                            Text(selected.displayName)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                            Text("· \(selected.provider.displayName)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Button("Show in list") { revealSelected(proxy) }
                                .controlSize(.small)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }

                    List(selection: $settingsStore.selectedModelID) {
                        ForEach(filteredGroupedModels, id: \.0) { provider, models in
                            Section(provider.displayName) {
                                ForEach(models) { model in
                                    modelRow(model)
                                        .tag(model.id)
                                        .id(model.id)
                                }
                            }
                        }
                    }
                    .listStyle(.bordered)
                }
                .onAppear {
                    // Give the list a beat to lay out before jumping to the
                    // selected model, or scrollTo silently no-ops.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        proxy.scrollTo(settingsStore.selectedModelID, anchor: .center)
                    }
                }
            }

            fetchErrorLines
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
    }

    /// Clear any active search (the selected model may be filtered out),
    /// then scroll the list to the selected model.
    private func revealSelected(_ proxy: ScrollViewProxy) {
        modelSearchText = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation {
                proxy.scrollTo(settingsStore.selectedModelID, anchor: .center)
            }
        }
    }

    private var filteredGroupedModels: [(AIProvider, [AIModel])] {
        guard !modelSearchText.isEmpty else {
            return settingsStore.sortedGroupedModels
        }
        let query = modelSearchText.lowercased()
        return settingsStore.sortedGroupedModels.compactMap { provider, models in
            let filtered = models.filter {
                $0.displayName.lowercased().contains(query)
                    || $0.id.lowercased().contains(query)
            }
            guard !filtered.isEmpty else { return nil }
            return (provider, filtered)
        }
    }

    private func modelRow(_ model: AIModel) -> some View {
        HStack {
            Text(model.displayName)
            Spacer()
            if model.id == settingsStore.selectedModelID {
                Image(systemName: "checkmark")
                    .foregroundStyle(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            settingsStore.selectedModelID = model.id
        }
    }

    @ViewBuilder
    private var fetchErrorLines: some View {
        VStack(spacing: 2) {
            if let err = settingsStore.anthropicFetchError {
                Text("Anthropic: \(err)").font(.caption2).foregroundStyle(.red)
            }
            if let err = settingsStore.openaiFetchError {
                Text("OpenAI: \(err)").font(.caption2).foregroundStyle(.red)
            }
            if let err = settingsStore.geminiFetchError {
                Text("Gemini: \(err)").font(.caption2).foregroundStyle(.red)
            }
            if let err = settingsStore.openrouterFetchError {
                Text("OpenRouter: \(err)").font(.caption2).foregroundStyle(.red)
            }
            if let err = settingsStore.vercelFetchError {
                Text("Vercel AI Gateway: \(err)").font(.caption2).foregroundStyle(.red)
            }
            if let err = settingsStore.compatibleFetchError {
                Text("OpenAI Compatible: \(err)").font(.caption2).foregroundStyle(.red)
            }
        }
    }

    // MARK: - Save

    /// Save the key + base URL of the provider currently shown, then
    /// re-fetch that provider's models so the new settings are verified
    /// immediately. Other providers' saved keys are untouched.
    private func saveCurrent() {
        let provider = selectedProvider
        let trimmedKey = currentKey.trimmingCharacters(in: .whitespacesAndNewlines)
        currentKey = trimmedKey

        settingsStore.setBaseURLOverride(currentBaseURL, for: provider)
        currentBaseURL = settingsStore.baseURLOverride(for: provider)

        do {
            if trimmedKey.isEmpty {
                settingsStore.deleteAPIKey(for: provider)
                clearModels(for: provider)
                refreshConfiguredProviders()
                isError = false
                statusMessage = "Key removed."
                return
            }
            try settingsStore.setAPIKey(trimmedKey, for: provider)
            refreshConfiguredProviders()

            isError = false
            statusMessage = "Saved. Fetching models…"
            Task {
                await settingsStore.fetchModels(for: provider)
                if let err = fetchError(for: provider) {
                    statusMessage = err
                    isError = true
                } else {
                    statusMessage = "Saved. \(modelCount(for: provider)) models loaded."
                    isError = false
                }
            }
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }
    }

    private func clearModels(for provider: AIProvider) {
        switch provider {
        case .anthropic: settingsStore.anthropicModels = []
        case .openai: settingsStore.openaiModels = []
        case .gemini: settingsStore.geminiModels = []
        case .openrouter: settingsStore.openrouterModels = []
        case .vercel: settingsStore.vercelModels = []
        case .openaiCompatible: settingsStore.compatibleModels = []
        }
    }

    private func fetchError(for provider: AIProvider) -> String? {
        switch provider {
        case .anthropic: return settingsStore.anthropicFetchError
        case .openai: return settingsStore.openaiFetchError
        case .gemini: return settingsStore.geminiFetchError
        case .openrouter: return settingsStore.openrouterFetchError
        case .vercel: return settingsStore.vercelFetchError
        case .openaiCompatible: return settingsStore.compatibleFetchError
        }
    }

    private func modelCount(for provider: AIProvider) -> Int {
        switch provider {
        case .anthropic: return settingsStore.anthropicModels.count
        case .openai: return settingsStore.openaiModels.count
        case .gemini: return settingsStore.geminiModels.count
        case .openrouter: return settingsStore.openrouterModels.count
        case .vercel: return settingsStore.vercelModels.count
        case .openaiCompatible: return settingsStore.compatibleModels.count
        }
    }
}

/// API key input, masked by default with an eye toggle to reveal.
private struct KeyField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Group {
                    if isRevealed {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))

                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(isRevealed ? "Hide key" : "Show key")
            }
        }
    }
}
