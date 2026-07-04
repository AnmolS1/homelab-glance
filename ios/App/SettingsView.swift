import SwiftUI
import GlanceKit

/// Connection settings: mock toggle, aggregator base URL + tokens (Keychain),
/// and a "Test connection" button that hits `/healthz`. Blueprint-styled —
/// labels above full-width fields on graph paper, never a stock `Form`.
struct SettingsView: View {
	@Environment(\.blueprint) private var bp
	@Environment(\.dismiss) private var dismiss
	@Bindable var settings: AppSettings

	@State private var testing = false
	@State private var testResult: String?
	@State private var testFailed = false

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				BlueprintFormSection(
					"Connection",
					footer: "Render bundled sample data with no server. Turn off to connect to your aggregator."
				) {
					BlueprintToggleRow("Use mock data", isOn: $settings.useMockData)
				}

				BlueprintFormSection(
					"Aggregator",
					footer: "The control token is needed only for start/stop/restart."
				) {
					BlueprintField("Base URL", text: $settings.baseURLString, kind: .mono,
					               prompt: "https://glance.example.com", isURL: true)
					BlueprintField("Widget token", text: $settings.token, kind: .monoSecure)
					BlueprintField("Control token", text: $settings.controlToken, kind: .monoSecure)
					BlueprintActionRow(
						title: "Test connection",
						busy: testing,
						result: testResult,
						isError: testFailed,
						disabled: settings.baseURLString.isEmpty
					) {
						runTest()
					}
				}
				.disabled(settings.useMockData)
				.opacity(settings.useMockData ? 0.5 : 1)

				#if os(macOS)
				BlueprintFormSection(
					"App",
					footer: "Run from the menu bar without a Dock icon. The menu-bar panel stays available."
				) {
					BlueprintToggleRow("Hide Dock icon (menu-bar only)", isOn: $settings.hideDockIcon)
				}
				#endif
			}
			.padding(16)
			.frame(maxWidth: 520)
			.frame(maxWidth: .infinity)
		}
		.scrollContentBackground(.hidden)
		.background(GraphPaperBackground())
		.navigationTitle("Settings")
		.toolbar {
			ToolbarItem(placement: .confirmationAction) {
				Button("Done") { dismiss() }
			}
		}
	}

	private func runTest() {
		testing = true
		testResult = nil
		testFailed = false
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
			testFailed = !ok
			testing = false
		}
	}
}
