<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="logo-dark.png">
    <img src="logo-light.png" width="128" height="128" alt="Apple Mail AI Plugin logo">
  </picture>
</p>

<h1 align="center">Apple Mail AI Plugin</h1>

<p align="center">
  The Apple Mail AI Plugin is a native macOS menu bar app that uses AI (Claude, GPT, Gemini) to help you write email replies in Apple Mail.
</p>

<p align="center">
  <a href="#installation">Installation</a> &middot;
  <a href="#get-your-api-key">Get Your API Key</a> &middot;
  <a href="#usage">Usage</a> &middot;
  <a href="#building-from-source">Build from Source</a>
</p>

---

The **Apple Mail AI Plugin** lives in your menu bar and connects directly to Apple Mail. Select an email (or open a compose window) and press **Option + H** to open the composer panel. Type a few thoughts about what you want to say, pick an AI model, and the app writes your reply — matching the language and tone of the conversation.

**Bring your own API key.** No accounts, no subscriptions, no middleman. Your key is stored in macOS Keychain and calls go directly to the provider.

## Features

- **Menu bar app** — stays out of your way until you need it
- **Works with Apple Mail** — reads your email thread, recipients, subject, and current draft
- **No Reply needed** — just select an email in the list and hit the shortcut; the thread context comes along automatically
- **Multiple AI providers** — Anthropic (Claude), OpenAI (GPT), Google Gemini, OpenRouter, and Vercel AI Gateway
- **OpenAI Compatible endpoints** — bring any gateway that speaks the OpenAI protocol (DeepSeek, Groq, Ollama, vLLM, …) by entering its base URL, no code changes needed
- **Custom base URLs** — point any provider at a proxy or gateway from Settings
- **Thread summaries** — one click TL;DR of the selected email thread
- **Streaming responses** — see the reply as it's being written
- **Language matching** — automatically replies in the same language as the conversation
- **Keyboard shortcut** — **⌥H** (Option + H) to open from anywhere
- **Secure key storage** — API keys stored in macOS Keychain, never on disk

## Installation

**Requirements:** macOS 14 (Sonoma) or later

### Download

Grab the latest `.dmg` from [Releases](../../releases), open it, and drag **Apple Mail AI Plugin** to your Applications folder.

> **macOS Gatekeeper:** Since the app isn't signed with an Apple Developer certificate, macOS will block it on first launch. To open it:
> 1. Right-click (or Control-click) the app and select **Open**
> 2. Click **Open** in the dialog that appears
>
> You only need to do this once. Alternatively, run:
> ```
> xattr -cr /Applications/Apple\ Mail\ AI\ Plugin.app
> ```

## Get Your API Key

The Apple Mail AI Plugin calls AI providers directly — you'll need an API key from at least one provider. Pick whichever you prefer:

### Anthropic (Claude)

1. Go to [console.anthropic.com](https://console.anthropic.com/)
2. Sign up or log in
3. Navigate to **API Keys** in the sidebar
4. Click **Create Key**, give it a name, and copy the key

### OpenAI (GPT)

1. Go to [platform.openai.com](https://platform.openai.com/)
2. Sign up or log in
3. Navigate to **API Keys** in the sidebar
4. Click **Create new secret key**, name it, and copy the key

### Google Gemini

1. Go to [aistudio.google.com/apikey](https://aistudio.google.com/apikey)
2. Sign in with your Google account
3. Click **Create API Key**, select a project (or create one), and copy the key

### OpenRouter

1. Go to [openrouter.ai](https://openrouter.ai/)
2. Sign up or log in
3. Navigate to **Keys** in the sidebar
4. Click **Create Key**, name it, and copy the key

> **Tip:** OpenRouter gives you access to models from many providers through a single key. Great if you want to try different models without managing multiple accounts.

### Vercel AI Gateway

1. Go to [vercel.com](https://vercel.com/) and open the **AI Gateway** tab of your dashboard
2. Create an API key and copy it (starts with `vck_`)

> Like OpenRouter, one key covers models from many providers.

### Any OpenAI-Compatible Endpoint

Using DeepSeek, Groq, Ollama, vLLM, LiteLLM, or another gateway that speaks the OpenAI chat-completions protocol? Pick **OpenAI Compatible** in Settings, enter the endpoint's base URL (e.g. `https://api.deepseek.com/v1`), and paste its API key.

### Add Your Key to the App

1. Click the **Apple Mail AI Plugin** icon in your menu bar
2. Open **Settings** → **API Keys**
3. Pick your provider from the dropdown and paste its API key
4. Optionally set a custom base URL (leave empty for the provider default)
5. Hit **Save** — the app fetches the available models from that provider

## Usage

1. In **Apple Mail**, select the email you want to answer (or open a compose window)
2. Press **⌥H** (Option + H) to open the composer panel
3. Type a few words describing what you want to say (e.g. "sounds good, let's meet thursday")
4. Pick a model from the dropdown and hit **Generate**
5. Click **Copy message**, then paste the reply into your Mail draft (the panel closes and Mail comes forward — toggle this off in Settings → General)

The app reads the full email thread for context, so the generated reply stays relevant to the conversation. There's also a **Summarize** button for a quick TL;DR of the selected thread.

> **Why copy-paste?** Recent macOS versions broke the AppleScript APIs for writing into an existing Mail compose window, so the app puts the finished reply on your clipboard instead of inserting it directly.

## Building from Source

```bash
git clone https://github.com/huwan/apple-mail-ai-plugin.git
cd apple-mail-ai-plugin
make build
make run
```

No Xcode? `make build-spm` builds and bundles the app with Command Line Tools only, signing with your local Apple Development certificate when one exists (a stable signature keeps Keychain from re-prompting after every rebuild).

### Available Make Targets

| Command | Description |
|---------|-------------|
| `make build` | Debug build (requires Xcode) |
| `make build-spm` | Release build with Command Line Tools only |
| `make run` | Build and launch the app |
| `make release` | Optimized release build |
| `make sign` | Code sign (ad-hoc or with `SIGNING_IDENTITY`) |
| `make dmg` | Create a `.dmg` installer |
| `make install` | Install to `/Applications` |
| `make clean` | Remove build artifacts |

### Notarization (for distribution)

```bash
make notarize \
  SIGNING_IDENTITY="Developer ID Application: ..." \
  APPLE_ID=you@example.com \
  TEAM_ID=ABC123
```

## Privacy

- API keys are stored in macOS Keychain — never written to disk as plain text
- Email content is sent directly to your chosen AI provider and nowhere else
- No analytics, no telemetry, no data collection

## License

[MIT](LICENSE)
