import AppIntents
import GlanceKit

/// Widget layout: adaptive grid (today's look) or a single-column list.
enum WidgetLayoutOption: String, AppEnum {
	case grid
	case list

	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Layout"
	static let caseDisplayRepresentations: [WidgetLayoutOption: DisplayRepresentation] = [
		.grid: "Grid",
		.list: "List",
	]
}

/// How much each tile shows.
enum WidgetDensity: String, AppEnum {
	case regular
	case compact

	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Density"
	static let caseDisplayRepresentations: [WidgetDensity: DisplayRepresentation] = [
		.regular: "Regular",
		.compact: "Compact",
	]
}

/// Per-instance configuration for the dashboard widget (long-press → Edit
/// Widget). Every parameter is optional/defaulted so widgets placed before the
/// StaticConfiguration→AppIntentConfiguration migration keep today's behavior.
struct GlanceConfigurationIntent: WidgetConfigurationIntent {
	static let title: LocalizedStringResource = "Dashboard Options"
	static let description = IntentDescription("Choose which containers this widget shows and how.")

	@Parameter(title: "Containers", description: "Empty shows your default selection.")
	var containers: [ContainerAppEntity]?

	@Parameter(title: "Layout", default: .grid)
	var layout: WidgetLayoutOption

	@Parameter(title: "Density", default: .regular)
	var density: WidgetDensity
}
