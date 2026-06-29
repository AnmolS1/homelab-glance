import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Nudges WidgetKit to refresh timelines — called by the app after it caches a
/// fresh dashboard, so widgets pick up new data promptly (still subject to the
/// system's widget refresh budget).
public enum WidgetReload {
	public static func requestAll() {
		#if canImport(WidgetKit)
		WidgetCenter.shared.reloadAllTimelines()
		#endif
	}
}
