import Foundation

/// Fetches the list of models from an OpenAI-compatible `/v1/models` endpoint.
enum OpenAICompatibleModelFetcher {
    private struct ModelInfo: Decodable {
        let id: String
    }

    private struct ModelsResponse: Decodable {
        let data: [ModelInfo]
    }

    enum FetchError: Error, Equatable, Sendable {
        case invalidURL
        case unauthorized
        case networkError(String)
        case decodingError
    }

    /// Returns model IDs sorted alphabetically, or an error explaining the failure.
    /// Strips trailing `/v1` or `/v1/models` from the user-supplied base URL so a
    /// pasted full path doesn't double-up.
    static func fetchModels(baseURL: String, apiKey: String? = nil) async -> Result<[String], FetchError> {
        var trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        for suffix in ["/v1/models", "/v1"] {
            if trimmed.hasSuffix(suffix) {
                trimmed = String(trimmed.dropLast(suffix.count))
            }
        }
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed + "/v1/models") else {
            return .failure(.invalidURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        if let apiKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else {
            return .failure(.networkError("Endpoint not reachable at \(trimmed)"))
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            return .failure(.unauthorized)
        }
        guard (200...299).contains(http.statusCode) else {
            return .failure(.networkError("Unexpected status \(http.statusCode) from \(trimmed)"))
        }

        guard let decoded = try? JSONDecoder().decode(ModelsResponse.self, from: data) else {
            return .failure(.decodingError)
        }

        return .success(decoded.data.map(\.id).sorted())
    }
}
