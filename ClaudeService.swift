import Foundation

final class ClaudeService {
    private struct ClaudeRequest: Encodable {
        struct APIMessage: Encodable {
            struct ContentBlock: Encodable {
                let type: String
                let text: String
            }

            let role: String
            let content: [ContentBlock]
        }

        let model: String
        let max_tokens: Int
        let system: String
        let messages: [APIMessage]
    }

    private struct ClaudeResponse: Decodable {
        struct ContentBlock: Decodable {
            let type: String
            let text: String?
        }

        let content: [ContentBlock]
    }

    func send(messages: [Message], kidName: String) async throws -> String {
        var request = URLRequest(url: Constants.anthropicURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Constants.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let apiMessages = messages.map { message in
            ClaudeRequest.APIMessage(
                role: message.isUser ? "user" : "assistant",
                content: [.init(type: "text", text: message.text)]
            )
        }

        let payload = ClaudeRequest(
            model: Constants.model,
            max_tokens: BuddyResponseLength.short.maxTokens,
            system: Constants.systemPrompt(displayName: kidName, length: .short),
            messages: apiMessages
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard
            let statusCode = (response as? HTTPURLResponse)?.statusCode,
            (200...299).contains(statusCode)
        else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        return decoded.content
            .first(where: { $0.type == "text" })?
            .text?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "Oops, my circuits got a little confused! Try again?"
    }
}
