import Foundation

enum OpenAIServiceError: LocalizedError {
    case missingAPIKey
    case invalidResponse(status: Int, detail: String?)
    case emptyReply
    case underlying(URLError)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add OPENAI_API_KEY to .env (no spaces around =), save, Clean Build Folder, then run. Or set it in the Run scheme’s Environment Variables."
        case let .invalidResponse(status, detail):
            if let detail, !detail.isEmpty { return "OpenAI error (\(status)): \(detail)" }
            return "OpenAI returned an error (code \(status))."
        case .emptyReply:
            return "Buddy did not get a reply from the AI. Try again?"
        case let .underlying(urlError):
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost:
                return "No internet connection. Check Wi‑Fi or cellular and try again."
            case .timedOut, .dnsLookupFailed:
                return "The request timed out. Try again in a moment."
            case .cancelled:
                return "Request was cancelled."
            default:
                return urlError.localizedDescription
            }
        }
    }
}

private enum OpenAISecrets {
    /// 1) Xcode Scheme → Run → Environment `OPENAI_API_KEY` (good for quick tests)
    /// 2) `OpenAISecrets.plist` produced by **Sync OpenAI .env** build phase from `.env`
    static var apiKey: String {
        if let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            let k = env.trimmingCharacters(in: .whitespacesAndNewlines)
            if !k.isEmpty { return k }
        }

        guard let url = Bundle.main.url(forResource: "OpenAISecrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = obj as? [String: Any],
              let raw = dict["OPENAI_API_KEY"] as? String
        else { return "" }

        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

final class OpenAIService {
    private let session: URLSession

    /// Whisper transcription + GPT replies need this. Set `OPENAI_API_KEY` in the Xcode scheme or `.env` → `OpenAISecrets.plist`.
    static var isAPIKeyConfigured: Bool {
        !OpenAISecrets.apiKey.isEmpty
    }

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
    }

    /// Streams chat completion deltas; calls `onAccumulated` with the full text-so-far on the main actor. Returns the final trimmed reply for TTS / history.
    func streamCompletion(
        messages: [Message],
        displayName: String,
        responseLength: BuddyResponseLength,
        onAccumulated: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        let key = OpenAISecrets.apiKey
        guard !key.isEmpty else { throw OpenAIServiceError.missingAPIKey }

        var request = URLRequest(url: Constants.openAIChatURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let payload = ChatCompletionRequest(
            model: Constants.openAIModel,
            stream: true,
            max_tokens: responseLength.maxTokens,
            temperature: 0.7,
            messages: buildOpenAIMessages(history: messages, displayName: displayName, responseLength: responseLength)
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch let urlError as URLError {
            throw OpenAIServiceError.underlying(urlError)
        }

        guard let http = response as? HTTPURLResponse else {
            throw OpenAIServiceError.invalidResponse(status: -1, detail: nil)
        }

        if !(200 ... 299).contains(http.statusCode) {
            let detail = await drainAsyncBytesAsString(bytes)
            throw OpenAIServiceError.invalidResponse(status: http.statusCode, detail: detail)
        }

        var accumulated = ""

        try await forEachSSELine(bytes: bytes) { rawLine in
            guard rawLine.hasPrefix("data: ") else { return }
            let payload = String(rawLine.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
            if payload == "[DONE]" { return }

            guard let data = payload.data(using: .utf8) else { return }

            if let errEnvelope = try? JSONDecoder().decode(OpenAIErrorEnvelope.self, from: data),
               let msg = errEnvelope.error?.message
            {
                throw OpenAIServiceError.invalidResponse(status: http.statusCode, detail: msg)
            }

            guard let chunk = try? JSONDecoder().decode(ChatCompletionChunk.self, from: data),
                  let piece = chunk.choices?.first?.delta?.content,
                  !piece.isEmpty
            else { return }

            accumulated.append(piece)
            let snapshot = accumulated
            await MainActor.run {
                onAccumulated(snapshot)
            }
        }

        let trimmed = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw OpenAIServiceError.emptyReply
        }
        return trimmed
    }

    /// Sends a recorded WAV (16‑bit PCM) to OpenAI Whisper — used when `SFSpeechRecognizer` yields no text.
    func transcribeSpeechWAV(fileURL: URL) async throws -> String {
        let key = OpenAISecrets.apiKey
        guard !key.isEmpty else { throw OpenAIServiceError.missingAPIKey }

        let audioData: Data
        do {
            audioData = try Data(contentsOf: fileURL)
        } catch {
            throw OpenAIServiceError.underlying(URLError(.cannotOpenFile))
        }
        guard audioData.count > 1000 else { throw OpenAIServiceError.emptyReply }

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        func appendString(_ s: String) { body.append(contentsOf: Data(s.utf8)) }

        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        appendString("\(Constants.openAIWhisperModel)\r\n")
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"file\"; filename=\"speech.wav\"\r\n")
        appendString("Content-Type: audio/wav\r\n\r\n")
        body.append(audioData)
        appendString("\r\n")
        appendString("--\(boundary)--\r\n")

        var request = URLRequest(url: Constants.openAITranscriptionsURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw OpenAIServiceError.underlying(urlError)
        }

        guard let http = response as? HTTPURLResponse else {
            throw OpenAIServiceError.invalidResponse(status: -1, detail: nil)
        }

        if !(200 ... 299).contains(http.statusCode) {
            let detail = String(data: data, encoding: .utf8)
            throw OpenAIServiceError.invalidResponse(status: http.statusCode, detail: detail)
        }

        guard let decoded = try? JSONDecoder().decode(WhisperTranscriptionResponse.self, from: data) else {
            throw OpenAIServiceError.invalidResponse(status: http.statusCode, detail: "Bad transcription JSON")
        }

        let text = decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            throw OpenAIServiceError.emptyReply
        }
        return text
    }

    private func buildOpenAIMessages(history: [Message], displayName: String, responseLength: BuddyResponseLength) -> [ChatCompletionRequest.APIMessage] {
        var out: [ChatCompletionRequest.APIMessage] = [
            .init(role: "system", content: Constants.systemPrompt(displayName: displayName, length: responseLength))
        ]
        for m in history {
            let role = m.isUser ? "user" : "assistant"
            out.append(.init(role: role, content: m.text))
        }
        return out
    }

    private func drainAsyncBytesAsString(_ bytes: URLSession.AsyncBytes) async -> String? {
        var data = Data()
        do {
            for try await b in bytes {
                data.append(b)
            }
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    /// Decodes SSE lines as UTF-8 (byte-at-a time decoding breaks emoji / non-ASCII in JSON).
    private func forEachSSELine(
        bytes: URLSession.AsyncBytes,
        onLine: (String) async throws -> Void
    ) async throws {
        var lineBuffer = Data()
        do {
            for try await byte in bytes {
                if byte == 10 {
                    let trimmed = flushUTF8Line(&lineBuffer)
                    if let trimmed, !trimmed.isEmpty {
                        try await onLine(trimmed)
                    }
                } else if byte != 13 {
                    lineBuffer.append(byte)
                }
            }
            if let trimmed = flushUTF8Line(&lineBuffer), !trimmed.isEmpty {
                try await onLine(trimmed)
            }
        } catch let urlError as URLError {
            throw OpenAIServiceError.underlying(urlError)
        }
    }

    private func flushUTF8Line(_ buffer: inout Data) -> String? {
        defer { buffer.removeAll(keepingCapacity: true) }
        guard !buffer.isEmpty else { return nil }
        let s = String(data: buffer, encoding: .utf8)
        return s?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Request / stream payloads

private struct ChatCompletionRequest: Encodable {
    struct APIMessage: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let stream: Bool
    let max_tokens: Int
    let temperature: Double
    let messages: [APIMessage]
}

private struct ChatCompletionChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let content: String?
            let role: String?
        }

        let delta: Delta?
        let finish_reason: String?
    }

    let choices: [Choice]?
}

private struct OpenAIErrorEnvelope: Decodable {
    struct Err: Decodable {
        let message: String?
        let type: String?
    }

    let error: Err?
}

private struct WhisperTranscriptionResponse: Decodable {
    let text: String
}
