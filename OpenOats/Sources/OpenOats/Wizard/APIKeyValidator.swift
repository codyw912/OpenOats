import Foundation

/// Validates API keys with lightweight authenticated requests.
/// These checks are read-only and only exist to catch broken credentials early.
enum APIKeyValidator {
    enum ValidationResult: Equatable, Sendable {
        /// Key is valid and authenticated.
        case valid
        /// Key failed authentication.
        case invalid(message: String)
        /// Network error or non-auth issue. The key might still work later.
        case networkError(message: String)
    }

    /// Validate an ElevenLabs API key by hitting the voices endpoint.
    static func validateElevenLabsKey(_ key: String) async -> ValidationResult {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .invalid(message: "API key is empty")
        }

        guard let url = URL(string: "https://api.elevenlabs.io/v1/voices") else {
            return .networkError(message: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(trimmed, forHTTPHeaderField: "xi-api-key")
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return validationResult(
                for: response,
                authFailureMessage: "This key didn't work - double-check it on elevenlabs.io"
            )
        } catch {
            return .networkError(message: "Could not verify - will test when you go online")
        }
    }

    /// Validate an OpenRouter API key by hitting the models list endpoint.
    static func validateOpenRouterKey(_ key: String) async -> ValidationResult {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .invalid(message: "API key is empty")
        }

        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else {
            return .networkError(message: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return validationResult(
                for: response,
                authFailureMessage: "This key didn't work - double-check it on openrouter.ai"
            )
        } catch {
            return .networkError(message: "Could not verify - will test when you go online")
        }
    }

    /// Validate a Voyage AI API key with a minimal embeddings request.
    static func validateVoyageKey(_ key: String) async -> ValidationResult {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .invalid(message: "API key is empty")
        }

        guard let url = URL(string: "https://api.voyageai.com/v1/embeddings") else {
            return .networkError(message: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: [
                "input": ["test"],
                "model": "voyage-3-lite",
            ]
        )

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return validationResult(
                for: response,
                authFailureMessage: "This key didn't work - double-check it on dash.voyageai.com"
            )
        } catch {
            return .networkError(message: "Could not verify - will test when you go online")
        }
    }

    /// Validate a custom OpenAI-compatible endpoint by hitting `/v1/models`.
    /// Empty key is allowed — many local servers (LM Studio, llama.cpp) accept unauthenticated requests.
    static func validateOpenAICompatibleEndpoint(baseURL: String, apiKey: String) async -> ValidationResult {
        var trimmedBase = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard !trimmedBase.isEmpty else {
            return .invalid(message: "Endpoint URL is empty")
        }

        for suffix in ["/v1/models", "/v1"] {
            if trimmedBase.hasSuffix(suffix) {
                trimmedBase = String(trimmedBase.dropLast(suffix.count))
            }
        }

        guard let url = URL(string: trimmedBase + "/v1/models") else {
            return .invalid(message: "Endpoint URL is not valid")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return validationResult(
                for: response,
                authFailureMessage: "The endpoint rejected the API key. Double-check the key and that this server requires one."
            )
        } catch {
            return .networkError(message: "Couldn't reach \(trimmedBase). Check the URL and that the server is running.")
        }
    }

    static func validationResult(
        for response: URLResponse,
        authFailureMessage: String
    ) -> ValidationResult {
        guard let http = response as? HTTPURLResponse else {
            return .networkError(message: "Unexpected response type")
        }

        if (200...299).contains(http.statusCode) {
            return .valid
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            return .invalid(message: authFailureMessage)
        }
        return .networkError(message: "Unexpected status: \(http.statusCode)")
    }
}
