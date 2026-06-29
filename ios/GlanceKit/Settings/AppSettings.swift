import Foundation
import Observation

/// Observable app configuration, shared between the app and (later) the widgets.
///
/// Non-secret prefs (base URL, mock toggle, theme) live in the App Group
/// `UserDefaults` so widgets can read them; the token lives in the shared
/// Keychain group. Defaults to **mock mode** so the app renders with no server.
@MainActor
@Observable
public final class AppSettings {
	public nonisolated static let appGroup = "group.dev.ponderance.homelabglance"
	// Use the App Group as the Keychain access group: app-group identifiers work
	// as keychain groups WITHOUT the team prefix, so the app and widget (both in
	// this group) share the token. (A bare bundle-style group would need the
	// $(AppIdentifierPrefix) and wouldn't match across the two targets.)
	public nonisolated static let keychainGroup = appGroup

	public static let shared = AppSettings()

	private typealias Keys = SettingsKeys

	private let defaults: UserDefaults
	private let keychain: KeychainStore

	public var baseURLString: String {
		didSet { defaults.set(baseURLString, forKey: Keys.baseURL) }
	}

	/// When true, the app renders bundled sample data instead of hitting a server.
	public var useMockData: Bool {
		didSet { defaults.set(useMockData, forKey: Keys.useMock) }
	}

	/// WIDGET_TOKEN; persisted to the Keychain (not observed externally).
	public var token: String {
		didSet { keychain.set(token, for: Keys.token) }
	}

	/// CONTROL_TOKEN for Docker writes; persisted to the Keychain.
	public var controlToken: String {
		didSet { keychain.set(controlToken, for: Keys.controlToken) }
	}

	/// macOS: hide the Dock icon and run as a menu-bar-only (accessory) app.
	public var hideDockIcon: Bool {
		didSet { defaults.set(hideDockIcon, forKey: Keys.hideDockIcon) }
	}

	public init(
		defaults: UserDefaults = AppSettings.defaultStore(),
		keychain: KeychainStore = KeychainStore(accessGroup: AppSettings.keychainGroup)
	) {
		self.defaults = defaults
		self.keychain = keychain
		// `useMockData` defaults to true the first time (no key present yet).
		self.useMockData = (defaults.object(forKey: Keys.useMock) as? Bool) ?? true
		self.baseURLString = defaults.string(forKey: Keys.baseURL) ?? ""
		self.token = keychain.string(for: Keys.token) ?? ""
		self.controlToken = keychain.string(for: Keys.controlToken) ?? ""
		self.hideDockIcon = defaults.bool(forKey: Keys.hideDockIcon)
	}

	/// App Group store when available, else the standard store (unsigned builds).
	public nonisolated static func defaultStore() -> UserDefaults {
		UserDefaults(suiteName: appGroup) ?? .standard
	}

	/// The provider implied by the current settings.
	public func makeProvider() -> any DashboardProviding {
		if useMockData { return MockDashboardClient() }
		if let live = LiveDashboardClient(baseURLString: baseURLString, token: token) {
			return live
		}
		return MockDashboardClient()
	}

	/// The Docker control provider implied by the current settings.
	public func makeControlProvider() -> any DockerControlProviding {
		if useMockData { return MockDockerControlClient() }
		return LiveDockerControlClient(baseURLString: baseURLString, token: token, controlToken: controlToken)
			?? MockDockerControlClient()
	}
}
