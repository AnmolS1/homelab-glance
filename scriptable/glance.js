// homelab-glance — Scriptable iOS widget (Large)
// Fetches the aggregator dashboard and renders a compact homelab status widget
// on your iOS home screen.
//
// SETUP:
//   1. Run setup-keychain.js (in this repo) once inside Scriptable to store your
//      WIDGET_TOKEN and AGGREGATOR_URL in the iOS Keychain
//   2. Make sure your iPhone can reach the aggregator (e.g. via Tailscale)
//   3. Paste this entire script into a new Scriptable script
//   4. Add a Large Scriptable widget to your home screen and select this script
//
// REFRESH CAVEAT:
//   widget.refreshAfterDate is set to 5 minutes below, but iOS throttles widget
//   refresh at its own discretion — actual cadence may be 15–60 minutes depending
//   on battery level, Background App Refresh settings, and iOS heuristics. This is
//   a hint, not a guarantee. For real-time data use the Übersicht widget on macOS.

// ── Secrets ───────────────────────────────────────────────────────────────────
// WIDGET_TOKEN and AGGREGATOR_URL are stored in the iOS Keychain via setup-keychain.js.
// Never hardcode secrets in this file.

const AGGREGATOR_URL = Keychain.contains("homelab_glance_url")
	? Keychain.get("homelab_glance_url")
	: ""

const WIDGET_TOKEN = Keychain.contains("homelab_glance_token")
	? Keychain.get("homelab_glance_token")
	: ""

// ── Logo ──────────────────────────────────────────────────────────────────────
// Set SHOW_LOGO = false to hide the brand logo next to the host name.
// LOGO_PNG_B64 is logo-amber downscaled to 120 px, embedded as base64 so the
// script is self-contained (no external files or network requests needed).
// To regenerate with a different variant:
//   sips -Z 120 logo-amber.png --out /tmp/logo-120.png && base64 -i /tmp/logo-120.png
const SHOW_LOGO = true
const LOGO_PNG_B64 = "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"

// ── Stone/dark palette ────────────────────────────────────────────────────────
const C = {
	bg: new Color("#1c1a17"),
	card: new Color("#26231f"),
	border: new Color("#34302a"),
	text: new Color("#ececec"),
	label: new Color("#8a847c"),
	value: new Color("#ffffff"),
	green: new Color("#5bbf7b"),
	red: new Color("#e05252"),
	amber: new Color("#d4a044"),
	muted: new Color("#5a554e"),
}

// ── Fetch data ────────────────────────────────────────────────────────────────
async function fetchDashboard() {
	const req = new Request(AGGREGATOR_URL)
	req.headers = { "Authorization": `Bearer ${WIDGET_TOKEN}` }
	req.timeoutInterval = 8
	try {
		const json = await req.loadJSON()
		return { ok: true, data: json }
	} catch (e) {
		return { ok: false, error: String(e) }
	}
}

// ── Formatting helpers ────────────────────────────────────────────────────────
function fmt(val, unit = "", decimals = 1) {
	if (val == null || val === undefined) return "—"
	return Number(val).toFixed(decimals) + unit
}

function uptimeStr(secs) {
	if (!secs) return "—"
	const d = Math.floor(secs / 86400)
	const h = Math.floor((secs % 86400) / 3600)
	return d > 0 ? `${d}d ${h}h` : `${h}h`
}

function fmtNum(n) {
	if (n == null) return "—"
	if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + "M"
	if (n >= 1_000) return (n / 1_000).toFixed(1) + "k"
	return String(n)
}

function statusColor(status, stale) {
	if (stale) return C.amber
	if (status === "up") return C.green
	if (status === "down") return C.red
	return C.label
}

// ── Widget helpers ────────────────────────────────────────────────────────────
function addLabel(stack, text, size = 9, color = C.label) {
	const t = stack.addText(text.toUpperCase())
	t.font = Font.systemFont(size)
	t.textColor = color
	t.lineLimit = 1
	return t
}

function addValue(stack, text, size = 12, color = C.value) {
	const t = stack.addText(String(text))
	t.font = Font.boldSystemFont(size)
	t.textColor = color
	t.lineLimit = 1
	return t
}

// A labelled stat pair (vertical: label on top, value below)
function addStat(parent, label, value, valueColor = C.value) {
	const col = parent.addStack()
	col.layoutVertically()
	col.spacing = 1
	addLabel(col, label, 9)
	addValue(col, value, 12, valueColor)
	return col
}

// A horizontal divider line
function addDivider(parent) {
	parent.addSpacer(6)
	const sep = parent.addStack()
	sep.size = new Size(0, 1)
	sep.backgroundColor = C.border
	sep.addSpacer()
	parent.addSpacer(6)
}

// Compact one-line service row: [icon] Title · key val · key val   [● status]
function addCompactRow(parent, icon, title, pairs, status, stale) {
	const row = parent.addStack()
	row.layoutHorizontally()
	row.centerAlignContent()
	row.spacing = 5

	// SF Symbol icon
	try {
		const sym = SFSymbol.named(icon)
		sym.applyFont(Font.systemFont(12))
		const img = row.addImage(sym.image)
		img.imageSize = new Size(13, 13)
		img.tintColor = C.label
	} catch (_) { }

	// Title
	const titleTxt = row.addText(title)
	titleTxt.font = Font.semiboldSystemFont(11)
	titleTxt.textColor = C.text
	titleTxt.lineLimit = 1

	row.addSpacer()

	// Key-value pairs
	for (const [k, v] of pairs) {
		const lbl = row.addText(k + " ")
		lbl.font = Font.systemFont(9)
		lbl.textColor = C.label
		const val = row.addText(v + "  ")
		val.font = Font.boldSystemFont(11)
		val.textColor = C.value
	}

	// Status dot
	const dot = row.addText("●")
	dot.font = Font.systemFont(10)
	dot.textColor = statusColor(status, stale)
}

// Full service card (2-row: container stats row + data row)
function addFullCard(parent, icon, title, status, stale, cStats, dataRows) {
	const card = parent.addStack()
	card.layoutVertically()
	card.spacing = 2
	card.backgroundColor = C.card
	card.cornerRadius = 8
	card.setPadding(7, 10, 7, 10)

	// Header row
	const hdr = card.addStack()
	hdr.layoutHorizontally()
	hdr.centerAlignContent()
	hdr.spacing = 5

	try {
		const sym = SFSymbol.named(icon)
		sym.applyFont(Font.systemFont(13))
		const img = hdr.addImage(sym.image)
		img.imageSize = new Size(14, 14)
		img.tintColor = statusColor(status, stale)
	} catch (_) { }

	const tTxt = hdr.addText(title)
	tTxt.font = Font.boldSystemFont(13)
	tTxt.textColor = C.value

	hdr.addSpacer()

	// Container cpu/mem in header
	if (cStats.cpu != null) {
		const cpu = hdr.addText(`CPU ${fmt(cStats.cpu, "%")}`)
		cpu.font = Font.systemFont(10)
		cpu.textColor = C.label
		hdr.addSpacer(6)
	}
	if (cStats.mem != null) {
		const mem = hdr.addText(`MEM ${fmt(cStats.mem / 1024, " GB", 2)}`)
		mem.font = Font.systemFont(10)
		mem.textColor = C.label
	}

	// Data rows
	const dataStack = card.addStack()
	dataStack.layoutHorizontally()
	dataStack.spacing = 14
	dataStack.topAlignContent()

	for (const [k, v, col] of dataRows) {
		addStat(dataStack, k, v, col || C.value)
	}
}

// ── Sparkline helper ──────────────────────────────────────────────────────────
// Draws a line chart into a DrawContext and returns it as an Image.
function sparklineImage(data, w, h, color) {
	if (!data || data.length < 2) return null
	const dc = new DrawContext()
	dc.size = new Size(w, h)
	dc.opaque = false
	dc.respectScreenScale = true
	const min = Math.min(...data), max = Math.max(...data)
	const range = max - min || 1
	const path = new Path()
	data.forEach((v, i) => {
		const x = (i / (data.length - 1)) * (w - 2) + 1
		const y = (h - 2) - ((v - min) / range) * (h - 4)
		if (i === 0) path.move(new Point(x, y))
		else path.addLine(new Point(x, y))
	})
	dc.addPath(path)
	dc.setStrokeColor(color)
	dc.setLineWidth(1.5)
	dc.strokePath()
	return dc.getImage()
}

// ── Widget builder ────────────────────────────────────────────────────────────
async function buildWidget(result) {
	const w = new ListWidget()
	w.backgroundColor = C.bg
	w.setPadding(14, 14, 10, 14)
	w.spacing = 0

	// Refresh hint — iOS throttles actual cadence regardless of this value
	w.refreshAfterDate = new Date(Date.now() + 5 * 60 * 1000)

	if (!result.ok) {
		const errTxt = w.addText("⚠ " + (result.error || "fetch failed"))
		errTxt.font = Font.systemFont(12)
		errTxt.textColor = C.red
		errTxt.minimumScaleFactor = 0.7
		return w
	}

	const data = result.data
	const host = data.host || {}
	const cards = data.cards || []

	const cardMap = {}
	for (const c of cards) cardMap[c.id] = c

	// ── Host header (slim) ──────────────────────────────────────────────────────
	const hostRow = w.addStack()
	hostRow.layoutHorizontally()
	hostRow.centerAlignContent()
	hostRow.spacing = 10

	if (SHOW_LOGO) {
		try {
			const logoImg = Image.fromData(Data.fromBase64String(LOGO_PNG_B64))
			const logoCell = hostRow.addStack()
			logoCell.size = new Size(20, 20)
			logoCell.cornerRadius = 10
			const logoView = logoCell.addImage(logoImg)
			logoView.imageSize = new Size(20, 20)
		} catch (_) { }
	}
	const hostnameText = hostRow.addText(host.name || "homelab")
	hostnameText.font = Font.boldSystemFont(13)
	hostnameText.textColor = C.value
	hostnameText.lineLimit = 1
	hostnameText.minimumScaleFactor = 0.6

	hostRow.addSpacer()
	addStat(hostRow, "CPU", fmt(host.cpu_pct, "%"))
	addStat(hostRow, "RAM", fmt(host.ram_used_gb, "", 1) + "/" + fmt(host.ram_total_gb, "G", 0))
	addStat(hostRow, "Disk", fmt(host.disk_used_tb, "", 1) + "/" + fmt(host.disk_total_tb, "T", 1))
	addStat(hostRow, "Uptime", uptimeStr(host.uptime))

	addDivider(w)

	// ── Jellyfin (full card) ────────────────────────────────────────────────────
	const jf = cardMap["jellyfin"] || {}
	const jfd = jf.data || {}
	const np = (jfd.now_playing || [])[0]
	addFullCard(
		w,
		"play.tv.fill",
		"Jellyfin",
		jf.status,
		jf.stale,
		{ cpu: jf.cpu_pct, mem: jf.mem_mb },
		[
			["Streams", String(jfd.streams ?? "—")],
			["Playing", np ? np.title.slice(0, 20) : "nothing", C.label],
		]
	)

	w.addSpacer(6)

	// ── qBittorrent (full card) ─────────────────────────────────────────────────
	const qb = cardMap["qbittorrent"] || {}
	const qbd = qb.data || {}
	addFullCard(
		w,
		"arrow.down.circle.fill",
		"qBittorrent",
		qb.status,
		qb.stale,
		{ cpu: qb.cpu_pct, mem: qb.mem_mb },
		[
			["↓ MiB/s", fmt(qbd.dl_mibps)],
			["↑ MiB/s", fmt(qbd.ul_mibps)],
			["Active", String(qbd.active ?? "—")],
			["Seeding", String(qbd.seeding ?? "—")],
		]
	)

	addDivider(w)

	// ── Pi-hole (full card) ─────────────────────────────────────────────────────
	const ph = cardMap["pihole"] || {}
	const phd = ph.data || {}
	addFullCard(
		w,
		"shield.fill",
		"Pi-hole",
		ph.status,
		ph.stale,
		{ cpu: ph.cpu_pct, mem: ph.mem_mb },
		[
			["Blocked", phd.blocked_pct != null ? fmt(phd.blocked_pct, "%") : "—"],
			["Queries", fmtNum(phd.queries)],
			["Gravity", phd.gravity != null ? (phd.gravity / 1e6).toFixed(2) + "M" : "—"],
		]
	)

	addDivider(w)

	// ── Compact rows ────────────────────────────────────────────────────────────
	const sn = cardMap["sonarr"] || {}
	const snd = sn.data || {}
	addCompactRow(
		w,
		"tv",
		"Sonarr",
		[
			["queue", String(snd.queue ?? "—")],
			["wanted", String(snd.wanted ?? "—")],
		],
		sn.status,
		sn.stale,
	)

	w.addSpacer(4)

	const rd = cardMap["radarr"] || {}
	const rdd = rd.data || {}
	addCompactRow(
		w,
		"film",
		"Radarr",
		[
			["queue", String(rdd.queue ?? "—")],
			["missing", String(rdd.missing ?? "—")],
		],
		rd.status,
		rd.stale,
	)

	// ── Sensors ──────────────────────────────────────────────────────────────────
	const sensors = host.sensors || {}
	const hasSensors = sensors.nvme_temp != null || sensors.gpu_temp != null

	if (hasSensors) {
		addDivider(w)

		const sensLbl = w.addText("SENSORS")
		sensLbl.font = Font.systemFont(8)
		sensLbl.textColor = C.label

		w.addSpacer(4)

		// NVMe and GPU temperature on one horizontal row (label + °C value + sparkline)
		const sparkRow = w.addStack()
		sparkRow.layoutHorizontally()
		sparkRow.spacing = 8

		if (sensors.nvme_temp != null) {
			const nvRow = sparkRow.addStack()
			nvRow.layoutHorizontally()
			nvRow.spacing = 5
			nvRow.centerAlignContent()
			const nvLbl = nvRow.addText("NVMe")
			nvLbl.font = Font.systemFont(9)
			nvLbl.textColor = C.label
			const nvVal = nvRow.addText(fmt(sensors.nvme_temp, "°", 0))
			nvVal.font = Font.boldSystemFont(11)
			nvVal.textColor = C.amber
			const nvImg = sparklineImage(sensors.nvme_temp_history, 115, 28, C.amber)
			if (nvImg) {
				const nvSpark = nvRow.addImage(nvImg)
				nvSpark.imageSize = new Size(115, 28)
			}
		}

		// sparkRow.addSpacer()

		if (sensors.gpu_temp != null) {
			const gpRow = sparkRow.addStack()
			gpRow.layoutHorizontally()
			gpRow.spacing = 5
			gpRow.centerAlignContent()
			const gpLbl = gpRow.addText("GPU")
			gpLbl.font = Font.systemFont(9)
			gpLbl.textColor = C.label
			const gpVal = gpRow.addText(fmt(sensors.gpu_temp, "°", 0))
			gpVal.font = Font.boldSystemFont(11)
			gpVal.textColor = C.green
			const gpImg = sparklineImage(sensors.gpu_temp_history, 115, 28, C.green)
			if (gpImg) {
				const gpSpark = gpRow.addImage(gpImg)
				gpSpark.imageSize = new Size(115, 28)
			}
		}

		// GPU details line: load / power / VRAM
		if (sensors.gpu_load_pct != null || sensors.gpu_power_w != null || sensors.gpu_vram_used_mb != null) {
			w.addSpacer(3)
			const gpuDet = w.addStack()
			gpuDet.layoutHorizontally()
			gpuDet.spacing = 10

			if (sensors.gpu_load_pct != null) {
				const ld = gpuDet.addText("load " + fmt(sensors.gpu_load_pct, "%", 0))
				ld.font = Font.systemFont(9)
				ld.textColor = C.muted
			}
			if (sensors.gpu_power_w != null) {
				const pw = gpuDet.addText(fmt(sensors.gpu_power_w, "W", 0))
				pw.font = Font.systemFont(9)
				pw.textColor = C.muted
			}
			if (sensors.gpu_vram_used_mb != null && sensors.gpu_vram_total_mb != null) {
				const vr = gpuDet.addText(
					fmt(sensors.gpu_vram_used_mb / 1024, "", 1) + "/" +
					fmt(sensors.gpu_vram_total_mb / 1024, "G", 0) + " vram"
				)
				vr.font = Font.systemFont(9)
				vr.textColor = C.muted
			}
		}
	}

	// ── Timestamp ────────────────────────────────────────────────────────────────
	w.addSpacer()
	const genAt = data.generated_at ? new Date(data.generated_at * 1000) : new Date()
	const tsLine = w.addText("updated " + genAt.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }))
	tsLine.font = Font.systemFont(9)
	tsLine.textColor = C.muted
	tsLine.rightAlignText()

	return w
}

// ── Entry point ───────────────────────────────────────────────────────────────
const result = await fetchDashboard()
const widget = await buildWidget(result)

if (config.runsInWidget) {
	Script.setWidget(widget)
} else {
	// Preview in app
	widget.presentLarge()
}
Script.complete()
