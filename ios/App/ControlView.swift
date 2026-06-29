import SwiftUI
import GlanceKit

@MainActor
@Observable
final class ControlViewModel {
	enum LoadState { case loading, loaded, failed(String) }

	var state: LoadState = .loading
	var containers: [DockerContainer] = []
	var pending: PendingAction?
	var banner: String?

	struct PendingAction: Identifiable {
		let action: ContainerAction
		let container: DockerContainer
		var id: String { "\(action.rawValue)-\(container.name)" }
	}

	private let settings: AppSettings
	private var provider: any DockerControlProviding

	init(settings: AppSettings) {
		self.settings = settings
		self.provider = settings.makeControlProvider()
	}

	func load() async {
		provider = settings.makeControlProvider()
		state = .loading
		do {
			containers = try await provider.containers().sorted { $0.name < $1.name }
			state = .loaded
		} catch {
			state = .failed((error as? ControlError)?.errorDescription ?? error.localizedDescription)
		}
	}

	func request(_ action: ContainerAction, _ container: DockerContainer) {
		pending = PendingAction(action: action, container: container)
	}

	/// Takes the action explicitly — do NOT read `self.pending` here: the
	/// confirmationDialog's isPresented binding clears it on dismiss, which races
	/// this call.
	func confirm(_ p: PendingAction) async {
		pending = nil
		do {
			let entry = try await provider.perform(p.action, on: p.container.name)
			banner = "\(p.action.label) \(p.container.name) — \(entry.result)"
			await load()
		} catch {
			banner = (error as? ControlError)?.errorDescription ?? error.localizedDescription
		}
	}
}

struct ControlView: View {
	@Environment(\.colorScheme) private var scheme
	@Environment(\.dismiss) private var dismiss
	private let settings: AppSettings
	@State private var model: ControlViewModel

	init(settings: AppSettings) {
		self.settings = settings
		_model = State(initialValue: ControlViewModel(settings: settings))
	}

	var body: some View {
		let bp = BlueprintColors.resolve(scheme)
		List {
			switch model.state {
			case .loading:
				HStack { Spacer(); ProgressView().tint(bp.crease); Spacer() }
					.listRowBackground(Color.clear)
			case .failed(let message):
				VStack(spacing: 8) {
					Text(message).font(Typography.text(13)).foregroundStyle(bp.ink60)
						.multilineTextAlignment(.center)
				}
				.frame(maxWidth: .infinity)
				.listRowBackground(Color.clear)
			case .loaded:
				ForEach(model.containers) { container in
					ContainerRow(container: container, settings: settings) { action in
						model.request(action, container)
					}
					.listRowBackground(bp.card)
				}
			}
		}
		.scrollContentBackground(.hidden)
		.background(GraphPaperBackground())
		.environment(\.blueprint, bp)
		.navigationTitle("Containers")
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				NavigationLink { AuditView(settings: settings).environment(\.blueprint, bp) } label: {
					Image(systemName: "list.bullet.rectangle")
				}
			}
		}
		.refreshable { await model.load() }
		.task { await model.load() }
		.confirmationDialog(
			model.pending.map { "\($0.action.label) \($0.container.name)?" } ?? "",
			isPresented: Binding(get: { model.pending != nil }, set: { if !$0 { model.pending = nil } }),
			titleVisibility: .visible,
			presenting: model.pending
		) { p in
			Button("\(p.action.label) \(p.container.name)", role: p.action == .stop ? .destructive : nil) {
				Task { await model.confirm(p) }
			}
			Button("Cancel", role: .cancel) {}
		}
		.alert("Action", isPresented: Binding(get: { model.banner != nil }, set: { if !$0 { model.banner = nil } })) {
			Button("OK") { model.banner = nil }
		} message: {
			Text(model.banner ?? "")
		}
	}
}

private struct ContainerRow: View {
	@Environment(\.blueprint) private var bp
	let container: DockerContainer
	let settings: AppSettings
	let onAction: (ContainerAction) -> Void

	private var stateColor: Color {
		switch container.state {
		case "running": return bp.up
		case "exited", "dead": return bp.crane
		default: return bp.ink60
		}
	}

	var body: some View {
		HStack(spacing: 10) {
			Circle().fill(stateColor).frame(width: 8, height: 8)
			VStack(alignment: .leading, spacing: 2) {
				NavigationLink {
					LogsView(settings: settings, container: container.name)
						.environment(\.blueprint, bp)
				} label: {
					VStack(alignment: .leading, spacing: 2) {
						Text(container.name)
							.font(Typography.display(14, weight: .semibold))
							.foregroundStyle(bp.ink)
						Text(container.status ?? container.state ?? "—")
							.font(Typography.text(11))
							.foregroundStyle(bp.ink60)
					}
				}
			}
			Spacer()
			if container.controllable {
				Menu {
					ForEach(ContainerAction.allCases, id: \.self) { action in
						Button {
							onAction(action)
						} label: {
							Label(action.label, systemImage: action.systemImage)
						}
					}
				} label: {
					Image(systemName: "ellipsis.circle").foregroundStyle(bp.crease)
				}
			} else {
				Image(systemName: "lock.fill").font(.caption2).foregroundStyle(bp.ink60.opacity(0.6))
			}
		}
	}
}

struct LogsView: View {
	@Environment(\.blueprint) private var bp
	let settings: AppSettings
	let container: String
	@State private var logs = ""
	@State private var loading = true

	private let bottomID = "logs-bottom"

	var body: some View {
		ScrollViewReader { proxy in
			ScrollView {
				Text(logs.isEmpty ? "—" : logs)
					.font(.system(.caption2, design: .monospaced))
					.foregroundStyle(bp.ink)
					.frame(maxWidth: .infinity, alignment: .leading)
					.textSelection(.enabled)
					.padding()
				Color.clear.frame(height: 1).id(bottomID)   // scroll anchor (newest)
			}
			.background(GraphPaperBackground())
			.overlay(alignment: .bottomTrailing) { scrollToBottomButton(proxy) }
			.overlay { if loading { ProgressView().tint(bp.crease) } }
			// Jump to the newest line whenever logs load or refresh.
			.onChange(of: logs) { _, _ in proxy.scrollTo(bottomID, anchor: .bottom) }
		}
		.navigationTitle(container)
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
			}
		}
		.task { await load() }
	}

	/// Blueprint-themed floating control to jump to the newest log line.
	private func scrollToBottomButton(_ proxy: ScrollViewProxy) -> some View {
		Button {
			withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(bottomID, anchor: .bottom) }
		} label: {
			Image(systemName: "arrow.down.to.line")
				.font(.system(size: 14, weight: .semibold))
				.foregroundStyle(bp.graph)
				.frame(width: 36, height: 36)
				.background(bp.crease, in: Circle())
				.overlay(Circle().strokeBorder(bp.creaseLine, lineWidth: 1))
				.shadow(color: .black.opacity(0.35), radius: 3, y: 1)
		}
		.buttonStyle(.plain)
		.padding(16)
		.help("Scroll to newest")
	}

	private func load() async {
		loading = true
		do {
			logs = try await settings.makeControlProvider().logs(container: container, tail: 200)
		} catch {
			logs = "Error: " + ((error as? ControlError)?.errorDescription ?? error.localizedDescription)
		}
		loading = false
	}
}

struct AuditView: View {
	@Environment(\.blueprint) private var bp
	let settings: AppSettings
	@State private var entries: [AuditEntry] = []
	@State private var loaded = false

	var body: some View {
		List(entries) { entry in
			HStack {
				VStack(alignment: .leading, spacing: 2) {
					Text("\(entry.action) · \(entry.container)")
						.font(Typography.display(13, weight: .semibold))
						.foregroundStyle(bp.ink)
					Text(entry.date.formatted(date: .abbreviated, time: .standard))
						.font(Typography.text(10)).foregroundStyle(bp.ink60)
				}
				Spacer()
				Text(entry.result)
					.font(Typography.mono(11, weight: .semibold))
					.foregroundStyle(entry.succeeded ? bp.up : bp.crane)
			}
			.listRowBackground(bp.card)
		}
		.scrollContentBackground(.hidden)
		.background(GraphPaperBackground())
		.overlay {
			if loaded && entries.isEmpty {
				Text("No actions yet").font(Typography.text(13)).foregroundStyle(bp.ink60)
			}
		}
		.navigationTitle("Audit")
		.task {
			entries = (try? await settings.makeControlProvider().audit()) ?? []
			loaded = true
		}
	}
}
