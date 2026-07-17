import SwiftUI
import GlanceKit

/// Sheet wrapper: sheets get a fresh environment, so resolve the blueprint
/// palette from the system scheme before showing the onboarding content.
struct OnboardingSheet: View {
	@Environment(\.colorScheme) private var scheme
	@Bindable var settings: AppSettings

	var body: some View {
		OnboardingView(settings: settings)
			.environment(\.blueprint, BlueprintColors.resolve(scheme))
	}
}

/// First-run onboarding: explains that Homelab Glance is a client for the
/// open-source glance aggregator running on the user's own server, collects the
/// base URL + tokens, and offers an "explore with sample data" path that stays
/// in mock mode. The first network call happens on "Test & connect" — that's
/// what triggers the iOS local-network permission prompt, never at launch.
struct OnboardingView: View {
	@Environment(\.blueprint) private var bp
	@Environment(\.dismiss) private var dismiss
	@Bindable var settings: AppSettings

	@State private var testing = false
	@State private var testResult: String?
	@State private var testFailed = false

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				header

				BlueprintFormSection(
					"What you need",
					footer: "Homelab Glance is a client for the open-source glance aggregator on your own server. Nothing leaves your device except calls to the server you configure."
				) {
					Label {
						Text("The glance aggregator running on your server (a small Docker container)")
							.font(Typography.text(14))
							.foregroundStyle(bp.ink)
							.fixedSize(horizontal: false, vertical: true)
					} icon: {
						Image(systemName: "server.rack").foregroundStyle(bp.crease)
					}
					Label {
						Text("Its WIDGET_TOKEN — plus CONTROL_TOKEN if you want start/stop/restart")
							.font(Typography.text(14))
							.foregroundStyle(bp.ink)
							.fixedSize(horizontal: false, vertical: true)
					} icon: {
						Image(systemName: "key.fill").foregroundStyle(bp.crease)
					}
					Link(destination: URL(string: "https://github.com/AnmolS1/homelab-glance/blob/main/aggregator/README.md")!) {
						Text("Aggregator setup guide ↗")
							.font(Typography.text(13, weight: .semibold))
							.foregroundStyle(bp.crease)
					}
				}

				BlueprintFormSection(
					"Connect",
					footer: "Use HTTPS, or connect over your local network. Cleartext HTTP works only for Tailscale (*.ts.net) hosts."
				) {
					BlueprintField("Base URL", text: $settings.baseURLString, kind: .mono,
					               prompt: "https://glance.example.com", isURL: true)
					BlueprintField("Widget token", text: $settings.token, kind: .monoSecure)
					BlueprintField("Control token (optional)", text: $settings.controlToken, kind: .monoSecure)
					BlueprintActionRow(
						title: "Test & connect",
						busy: testing,
						result: testResult,
						isError: testFailed,
						disabled: settings.baseURLString.isEmpty
					) {
						connect()
					}
				}

				Button {
					settings.hasCompletedOnboarding = true
					dismiss()
				} label: {
					Text("Explore with sample data")
						.font(Typography.text(15, weight: .semibold))
						.foregroundStyle(bp.crease)
						.frame(maxWidth: .infinity, minHeight: 44)
				}
				.buttonStyle(.plain)
				.background(bp.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
				.overlay {
					RoundedRectangle(cornerRadius: 12, style: .continuous)
						.strokeBorder(bp.creaseLine, lineWidth: 1)
				}
			}
			.padding(20)
			.frame(maxWidth: 520)
			.frame(maxWidth: .infinity)
		}
		.background(GraphPaperBackground().ignoresSafeArea())
		.interactiveDismissDisabled()
			.onChange(of: testResult) { _, r in if let r { AccessibilityNotification.Announcement(r).post() } }
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text("Welcome to Homelab Glance")
				.font(Typography.display(26, weight: .bold))
				.foregroundStyle(bp.ink)
			Text("Your homelab, at a glance — dashboard, widgets, and Docker controls.")
				.font(Typography.text(15))
				.foregroundStyle(bp.ink60)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(.top, 12)
	}

	private func connect() {
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
			if ok {
				settings.useMockData = false
				settings.hasCompletedOnboarding = true
				testing = false
				dismiss()
			} else {
				testResult = "Not reachable — check URL and connectivity. You can also explore with sample data below."
				testFailed = true
				testing = false
			}
		}
	}
}
