# Buddy

**Buddy** is a native **iOS** voice companion app built with **SwiftUI**. Children talk with a friendly robot character through **press-and-hold voice input**; replies stream from **OpenAI** and are read aloud with **system speech synthesis**, with an animated mascot that reacts to listening, thinking, and speaking.

## What it does

- **Voice-first chat:** hold an on-screen “orb” to speak; **Apple on-device speech recognition** is merged with **OpenAI Whisper** when needed for clearer transcripts, including heuristics to drop junk one-word noise.
- **Streaming AI replies:** **GPT‑4o** via **Chat Completions (SSE)** so answers appear progressively; conversation **short-term memory** keeps recent turns in context.
- **Kid-oriented tone:** system prompts encourage short, plain-language, age-appropriate answers (no emoji in spoken replies; safety-oriented boundaries in copy).
- **Polished UX:** onboarding, settings (**display name**, **short vs detailed** reply length, **TTS voice**, **haptics**), suggestion chips, optional transcript sheet, and a custom **Buddy robot** animation layer.

## Stack

| Layer | Technology |
|--------|------------|
| UI | SwiftUI (iOS), custom layouts & gradients |
| Speech in | `Speech` framework + OpenAI **Whisper** (`audio/transcriptions`) |
| Language model | OpenAI **GPT‑4o**, streaming HTTP + SSE parsing |
| Speech out | `AVFoundation` **AVSpeechSynthesizer**, localized voice catalog |
| Settings | `UserDefaults`, `@ObservableObject` settings store |
| Tooling | Xcode project; `.env` → `OpenAISecrets.plist` sync script for local API keys |

The codebase also includes a **Claude (Anthropic)** request helper for experiments; the shipped chat path uses **OpenAI** end-to-end.

## Requirements

- Xcode + iOS SDK  
- Configure `OPENAI_API_KEY` (scheme environment variable or `.env` processed into `OpenAISecrets.plist` per project scripts)

---

### Portfolio summary (e.g. Upwork)

Native **Swift / SwiftUI** iOS app: voice-driven AI companion with **speech-to-text** (Apple + Whisper), **streaming GPT‑4o** chat, **text-to-speech**, animated character UI, onboarding, and settings. Emphasis on responsive UX, transcript quality, and child-friendly conversational guardrails.
