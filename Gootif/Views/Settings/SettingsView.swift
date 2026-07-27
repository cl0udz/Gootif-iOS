import SwiftUI

struct SettingsView: View {
    @State private var apiKeyDraft: String = AppSettings.apiKeyOverride
    @State private var showSaved = false
    @State private var isTesting = false
    @State private var testResult: TestResult?

    enum TestResult: Equatable {
        case success
        case failure(String)
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    apiKeyCard
                    serverCard
                }
                .padding()
            }
        }
        .navigationTitle("Settings")
        .onChange(of: apiKeyDraft) { _, _ in testResult = nil }
    }

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("API Key", systemImage: "key.fill")
                .font(.headline)

            Text("Sent as the X-API-Key header. Leave blank to use the built-in default.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Paste new API key", text: $apiKeyDraft, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(2...4)
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 8) {
                Image(systemName: AppSettings.isUsingDefaultKey ? "shield.fill" : "shield.lefthalf.filled")
                    .foregroundStyle(AppSettings.isUsingDefaultKey ? AppColors.subtleText : AppColors.accent)
                Text(AppSettings.isUsingDefaultKey ? "Using built-in default key" : "Using custom key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let result = testResult {
                HStack(spacing: 8) {
                    switch result {
                    case .success:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppColors.positive)
                        Text("Connection succeeded")
                            .foregroundStyle(AppColors.positive)
                    case .failure(let message):
                        Image(systemName: "xmark.octagon.fill")
                            .foregroundStyle(AppColors.negative)
                        Text(message)
                            .foregroundStyle(AppColors.negative)
                    }
                }
                .font(.caption.weight(.medium))
            }

            HStack(spacing: 10) {
                Button {
                    Task { await testKey() }
                } label: {
                    HStack(spacing: 6) {
                        if isTesting {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "wifi")
                        }
                        Text("Test")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                }
                .disabled(isTesting)

                Button {
                    save()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "tray.and.arrow.down.fill")
                        Text("Save")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(AppColors.accent, in: Capsule())
                }
                .disabled(apiKeyDraft == AppSettings.apiKeyOverride)
            }
            .font(.subheadline.weight(.semibold))

            if !AppSettings.isUsingDefaultKey {
                Button(role: .destructive) {
                    apiKeyDraft = ""
                    save()
                } label: {
                    Label("Reset to default", systemImage: "arrow.counterclockwise")
                        .font(.footnote.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                }
            }

            if showSaved {
                Text("Saved")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.positive)
                    .transition(.opacity)
            }
        }
        .floatingCard()
    }

    private var serverCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Server", systemImage: "server.rack")
                .font(.headline)

            HStack {
                Text("Endpoint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(APIClient.baseURL)
                    .font(.caption.monospaced())
            }
        }
        .floatingCard()
    }

    private func save() {
        AppSettings.apiKeyOverride = apiKeyDraft
        apiKeyDraft = AppSettings.apiKeyOverride
        withAnimation { showSaved = true }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { showSaved = false }
        }
    }

    private func testKey() async {
        isTesting = true
        testResult = nil
        let trimmed = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let keyToTest = trimmed.isEmpty ? AppSettings.defaultAPIKey : trimmed
        do {
            try await APIClient.ping(apiKey: keyToTest)
            testResult = .success
        } catch {
            testResult = .failure(error.localizedDescription)
        }
        isTesting = false
    }
}
