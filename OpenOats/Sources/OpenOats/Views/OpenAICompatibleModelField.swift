import SwiftUI

/// A text field with a dropdown listing models from an OpenAI-compatible `/v1/models` endpoint.
struct OpenAICompatibleModelField: View {
    @Binding var modelName: String
    let baseURL: String
    let apiKey: String
    let placeholder: String

    @State private var availableModels: [String] = []
    @State private var isLoading = false
    @State private var lastError: OpenAICompatibleModelFetcher.FetchError?

    var body: some View {
        HStack(spacing: 4) {
            TextField("Model", text: $modelName, prompt: Text(placeholder))
                .font(.system(size: 12, design: .monospaced))

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
            } else {
                Menu {
                    if availableModels.isEmpty {
                        Button(emptyLabel) {}
                            .disabled(true)
                    } else {
                        ForEach(availableModels, id: \.self) { model in
                            Button(model) {
                                modelName = model
                            }
                        }
                    }
                    Divider()
                    Button("Refresh") {
                        Task { await fetchModels() }
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .frame(width: 16, height: 16)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .task(id: "\(baseURL)|\(apiKey.isEmpty ? "" : "k")") {
            await fetchModels()
        }
    }

    private var emptyLabel: String {
        switch lastError {
        case .unauthorized: "API key required"
        case .invalidURL: "Invalid endpoint URL"
        case .networkError: "Endpoint unreachable"
        case .decodingError: "Unexpected response"
        case .none: "No models found"
        }
    }

    private func fetchModels() async {
        guard !baseURL.trimmingCharacters(in: .whitespaces).isEmpty else {
            availableModels = []
            return
        }
        isLoading = true
        let result = await OpenAICompatibleModelFetcher.fetchModels(baseURL: baseURL, apiKey: apiKey)
        switch result {
        case .success(let models):
            availableModels = models
            lastError = nil
        case .failure(let error):
            availableModels = []
            lastError = error
        }
        isLoading = false
    }
}
