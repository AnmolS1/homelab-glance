import SwiftUI
import GlanceKit

/// Connection settings: mock toggle, aggregator base URL + token (Keychain),
/// and a "Test connection" button that hits `/healthz`.
struct SettingsView: View {
	@Environment(\.blueprint) private var bp
	@Environment(\.dismiss) private var dismiss
	@Bindable var settings: AppSettings

	@State private var testing = false
	@State private var testResult: String?

	var body: some View {
		NavigationStack {
			Form {
				Section {
					Toggle("Use mock data", isOn: $settings.useMockData)
				} footer: {
					Text("Render bundled sample data with no server. Turn off to connect to your aggregator.")
				}

				Section("Aggregator") {
					TextField("Base URL", text: $settings.baseURLString)
						.textContentType(.URL)
						.disableAutocorrection(true)
						#if os(iOS)
						.textInputAutocapitalization(.never)
						.keyboardType(.URL)
						#endif
					SecureField("WIDGET_TOKEN", text: $settings.token)
					SecureField("CONTROL_TOKEN (for start/stop/restart)", text: $settings.controlToken)

					Button {
						runTest()
					} label: {
						HStack {
							Text("Test connection")
							if testing { Spacer(); ProgressView() }
						}
					}
					.disabled(testing || settings.baseURLString.isEmpty)

					if let testResult {
						Text(testResult).foregroundStyle(bp.ink60)
					}
				}
				.disabled(settings.useMockData)
			}
			.navigationTitle("Settings")
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") { dismiss() }
				}
			}
		}
	}

	private func runTest() {
		testing = true
		testResult = nil
		let urlString = settings.baseURLString
		let token = settings.token
		Task {
			let ok: Bool
			if let client = LiveDashboardClient(baseURLString: urlString, token: token) {
				ok = await client.testConnection()
			} else {
				ok = false
			}
			testResult = ok ? "Reachable ✓" : "Not reachable — check URL and connectivity."
			testing = false
		}
	}
}
