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

// ── Stone/dark palette ────────────────────────────────────────────────────────
const C = {
  bg:          new Color("#1c1a17"),
  card:        new Color("#26231f"),
  border:      new Color("#34302a"),
  text:        new Color("#ececec"),
  label:       new Color("#8a847c"),
  value:       new Color("#ffffff"),
  green:       new Color("#5bbf7b"),
  red:         new Color("#e05252"),
  amber:       new Color("#d4a044"),
  muted:       new Color("#5a554e"),
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
  if (n >= 1_000)     return (n / 1_000).toFixed(1) + "k"
  return String(n)
}

function statusColor(status, stale) {
  if (stale)           return C.amber
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
  parent.addSpacer(3)
  const sep = parent.addStack()
  sep.size = new Size(0, 1)
  sep.backgroundColor = C.border
  sep.addSpacer()
  parent.addSpacer(3)
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
  } catch(_) {}

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
  } catch(_) {}

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

  const data  = result.data
  const host  = data.host  || {}
  const cards = data.cards || []

  const cardMap = {}
  for (const c of cards) cardMap[c.id] = c

  // ── Host header (slim) ──────────────────────────────────────────────────────
  const hostRow = w.addStack()
  hostRow.layoutHorizontally()
  hostRow.centerAlignContent()
  hostRow.spacing = 10

  const hostnameText = hostRow.addText("⚡ " + (host.name || "homelab"))
  hostnameText.font = Font.boldSystemFont(13)
  hostnameText.textColor = C.value

  hostRow.addSpacer()
  addStat(hostRow, "CPU",    fmt(host.cpu_pct, "%"))
  addStat(hostRow, "RAM",    fmt(host.ram_used_gb, "", 1) + "/" + fmt(host.ram_total_gb, "G", 0))
  addStat(hostRow, "Disk",   fmt(host.disk_used_tb, "", 1) + "/" + fmt(host.disk_total_tb, "T", 1))
  addStat(hostRow, "Uptime", uptimeStr(host.uptime))

  addDivider(w)

  // ── Jellyfin (full card) ────────────────────────────────────────────────────
  const jf = cardMap["jellyfin"] || {}
  const jfd = jf.data || {}
  const np  = (jfd.now_playing || [])[0]
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
      ["Active",  String(qbd.active  ?? "—")],
      ["Seeding", String(qbd.seeding ?? "—")],
    ]
  )

  addDivider(w)

  // ── Compact rows ────────────────────────────────────────────────────────────
  const ph = cardMap["pihole"]  || {}
  const phd = ph.data || {}
  addCompactRow(
    w,
    "shield.fill",
    "Pi-hole",
    [
      ["blk",  phd.blocked_pct != null ? fmt(phd.blocked_pct, "%") : "—"],
      ["q",    fmtNum(phd.queries)],
    ],
    ph.status,
    ph.stale,
  )

  w.addSpacer(4)

  const sn = cardMap["sonarr"] || {}
  const snd = sn.data || {}
  addCompactRow(
    w,
    "tv",
    "Sonarr",
    [
      ["queue",   String(snd.queue   ?? "—")],
      ["wanted",  String(snd.wanted  ?? "—")],
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
      ["queue",   String(rdd.queue   ?? "—")],
      ["missing", String(rdd.missing ?? "—")],
    ],
    rd.status,
    rd.stale,
  )

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
