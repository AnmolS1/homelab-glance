import SwiftUI
import GlanceKit

/// Settings → "Widget & cards": every auto-detected container, with visibility
/// toggles, drag-to-reorder, rename and group overrides, and the default widget
/// selection. Persists to the App Group (`CardConfigStore`) so the dashboard,
/// widgets, and the widget Edit screen all read one config.
struct CardManagerView: View {
	@Environment(\.blueprint) private var bp
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	let settings: AppSettings

	enum LoadState {
		case loading
		case failed(String)
		case loaded([DockerContainer])
	}

	@State private var state: LoadState = .loading
	@State private var config = CardConfigStore.shared.load()
	@State private var renameTarget: DockerContainer?
	@State private var renameText = ""

	private static let groupChoices = ["Containers", "Media", "Acquisition", "Infrastructure", "Home"]

	var body: some View {
		Group {
			switch state {
			case .loading:
				VStack(spacing: 10) {
					ProgressView().tint(bp.crease)
					Text("Detecting containers…")
						.font(Typography.text(13))
						.foregroundStyle(bp.ink60)
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			case .failed(let message):
				VStack(spacing: 12) {
					Image(systemName: "exclamationmark.triangle")
						.font(.title)
						.foregroundStyle(bp.crane)
					Text(message)
						.font(Typography.text(13))
						.foregroundStyle(bp.ink60)
						.multilineTextAlignment(.center)
					Button("Retry") { Task { await load() } }
						.buttonStyle(.borderedProminent)
						.tint(bp.crease)
				}
				.padding(32)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			case .loaded(let containers) where containers.isEmpty:
				VStack(spacing: 8) {
					Image(systemName: "shippingbox")
						.font(.system(size: 28, weight: .semibold))
						.foregroundStyle(bp.ink60)
					Text("No containers detected")
						.font(Typography.text(15, weight: .semibold))
						.foregroundStyle(bp.ink)
					Text("Point the aggregator at a Docker socket-proxy to auto-detect containers.")
						.font(Typography.text(13))
						.foregroundStyle(bp.ink60)
						.multilineTextAlignment(.center)
				}
				.padding(24)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			case .loaded(let containers):
				list(orderedContainers(containers))
			}
		}
		.background(GraphPaperBackground())
		.navigationTitle("Widget & cards")
		.task { await load() }
		.alert("Rename card", isPresented: Binding(
			get: { renameTarget != nil },
			set: { if !$0 { renameTarget = nil } }
		)) {
			TextField("Display name", text: $renameText)
			Button("Save") {
				if let target = renameTarget {
					var updated = config
					let trimmed = renameText.trimmingCharacters(in: .whitespaces)
					updated.renames[target.name] = trimmed.isEmpty || trimmed == target.name ? nil : trimmed
					apply(updated)
				}
				renameTarget = nil
			}
			Button("Cancel", role: .cancel) { renameTarget = nil }
		}
	}

	private func list(_ containers: [DockerContainer]) -> some View {
		List {
			Section {
				ForEach(containers) { container in
					row(container)
						.listRowBackground(bp.card)
				}
				.onMove { from, to in
					var names = containers.map(\.name)
					names.move(fromOffsets: from, toOffset: to)
					var updated = config
					updated.order = names
					apply(updated)
				}
			} header: {
				Text("Cards".uppercased())
					.font(Typography.text(12, weight: .semibold))
					.foregroundStyle(bp.ink60)
			} footer: {
				Text("Toggle which containers appear; drag to reorder. Long-press a row to rename, change its group, or mark it as a widget default. Known services render their rich card automatically.")
					.font(Typography.text(12))
					.foregroundStyle(bp.ink60)
			}

			Section {
				Toggle(isOn: Binding(
					get: { config.widgetDefaults.isEmpty },
					set: { all in
						var updated = config
						updated.widgetDefaults = all ? [] : visibleNames(containers)
						apply(updated)
					}
				)) {
					Text("Widgets show all visible cards")
						.font(Typography.text(15))
						.foregroundStyle(bp.ink)
				}
				.tint(bp.crease)
				.listRowBackground(bp.card)
			} footer: {
				Text("Off: widgets show only the cards marked as widget defaults (long-press a row above). Each placed widget can still override this via Edit Widget.")
					.font(Typography.text(12))
					.foregroundStyle(bp.ink60)
			}
		}
		.scrollContentBackground(.hidden)
		#if os(iOS)
		.environment(\.editMode, .constant(.active))
		#endif
	}

	private func row(_ container: DockerContainer) -> some View {
		let type = ServiceType.detect(image: container.image, name: container.name)
		return HStack(spacing: 10) {
			Toggle(isOn: Binding(
				get: { !config.hidden.contains(container.name) },
				set: { visible in
					var updated = config
					if visible { updated.hidden.remove(container.name) } else { updated.hidden.insert(container.name) }
					apply(updated)
				}
			)) {
				VStack(alignment: .leading, spacing: 2) {
					HStack(spacing: 6) {
						Circle()
							.fill(container.isRunning ? bp.up : bp.crane)
							.frame(width: 7, height: 7).accessibilityLabel(container.isRunning ? "running" : "stopped")
						Text(config.displayName(for: container.name))
							.font(Typography.text(15, weight: .semibold))
							.foregroundStyle(bp.ink)
							.lineLimit(1)
						if let type, !dynamicTypeSize.isAccessibilitySize {
							Text(type.rawValue.uppercased())
								.font(Typography.mono(9, weight: .semibold))
								.foregroundStyle(bp.crease)
								.padding(.horizontal, 5)
								.padding(.vertical, 1)
								.background(bp.crease.opacity(0.12), in: Capsule())
						}
						if config.widgetDefaults.contains(container.name) {
							Image(systemName: "star.fill")
								.font(.system(size: 9))
								.foregroundStyle(bp.sax)
								.accessibilityLabel("Widget default")
						}
					}
					if let image = container.image {
						Text(image)
							.font(Typography.mono(10))
							.foregroundStyle(bp.ink60)
							.lineLimit(1)
							.truncationMode(.middle)
					}
				}
			}
			.tint(bp.crease)
			.toggleStyle(.switch)
			.accessibilityHint("Shows this card on the dashboard and in widgets")
		}
		.contextMenu {
			Button {
				renameText = config.displayName(for: container.name)
				renameTarget = container
			} label: {
				Label("Rename…", systemImage: "pencil")
			}
			Menu {
				ForEach(Self.groupChoices, id: \.self) { group in
					Button {
						var updated = config
						updated.groups[container.name] = group == "Containers" ? nil : group
						apply(updated)
					} label: {
						if (config.groups[container.name] ?? "Containers") == group {
							Label(group, systemImage: "checkmark")
						} else {
							Text(group)
						}
					}
				}
			} label: {
				Label("Group", systemImage: "square.grid.2x2")
			}
			Button {
				var updated = config
				if let i = updated.widgetDefaults.firstIndex(of: container.name) {
					updated.widgetDefaults.remove(at: i)
				} else {
					updated.widgetDefaults.append(container.name)
				}
				apply(updated)
			} label: {
				if config.widgetDefaults.contains(container.name) {
					Label("Remove from widget defaults", systemImage: "star.slash")
				} else {
					Label("Add to widget defaults", systemImage: "star")
				}
			}
		}
	}

	private func orderedContainers(_ containers: [DockerContainer]) -> [DockerContainer] {
		let rank = Dictionary(uniqueKeysWithValues: config.order.enumerated().map { ($1, $0) })
		return containers.sorted { a, b in
			let ra = rank[a.name] ?? Int.max
			let rb = rank[b.name] ?? Int.max
			return ra == rb ? a.name < b.name : ra < rb
		}
	}

	private func visibleNames(_ containers: [DockerContainer]) -> [String] {
		orderedContainers(containers).map(\.name).filter { !config.hidden.contains($0) }
	}

	private func apply(_ updated: CardConfig) {
		config = updated
		CardConfigStore.shared.save(updated)
		WidgetReload.requestAll()
	}

	private func load() async {
		state = .loading
		let provider = settings.makeControlProvider()
		do {
			state = .loaded(try await provider.containers())
		} catch {
			state = .failed(error.localizedDescription)
		}
	}
}
