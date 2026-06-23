// homelab-glance — Übersicht desktop widget
// Polls the aggregator every 30 s and renders a full homelab status dashboard
// on the macOS desktop, styled to match the Homepage stone/dark theme.
//
// SETUP:
//   1. Install Übersicht: https://tracesof.net/uebersicht/
//   2. Drop this file into your Übersicht widgets folder
//   3. Create your secrets file (see below) — the widget will not load until
//      WIDGET_TOKEN and AGGREGATOR_URL are set there

// ── Secrets ───────────────────────────────────────────────────────────────────
// Secrets are sourced from ~/.config/homelab-glance/secrets.env at shell time.
// Never edit this file to add secrets — use the secrets file instead.
//
// One-time setup:
//   mkdir -p ~/.config/homelab-glance
//   cp glance.secrets.env.example ~/.config/homelab-glance/secrets.env
//   # then edit secrets.env and set WIDGET_TOKEN and AGGREGATOR_URL

// ── Aesthetic tokens (Homepage stone/dark) ────────────────────────────────────
const T = {
  bg:          "#1c1a17",
  card:        "#26231f",
  border:      "#34302a",
  text:        "#ececec",
  label:       "#8a847c",
  value:       "#ffffff",
  green:       "#5bbf7b",
  red:         "#e05252",
  amber:       "#d4a044",
  muted:       "#5a554e",
  radius:      "10px",
  fontMono:    "'SF Mono', 'Fira Code', monospace",
  fontSans:    "-apple-system, 'SF Pro Display', sans-serif",
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET_TOKEN and AGGREGATOR_URL are read from the secrets file at shell time.
export const command = '. "$HOME/.config/homelab-glance/secrets.env" 2>/dev/null && curl -sf -m 8 -H "Authorization: Bearer $WIDGET_TOKEN" "$AGGREGATOR_URL"'
export const refreshFrequency = 30000   // 30 s

// Position widget in top-right corner; adjust to taste
export const className = `
  top: 20px;
  right: 20px;
  width: 680px;
  max-height: 95vh;
  overflow: hidden;
  font-family: ${T.fontSans};
  font-size: 13px;
  color: ${T.text};
  -webkit-font-smoothing: antialiased;
  pointer-events: none;

  .wrap {
    background: ${T.bg};
    border: 1px solid ${T.border};
    border-radius: ${T.radius};
    padding: 14px 16px;
    overflow: hidden;
  }

  /* ── Host header ── */
  .host-row {
    display: flex;
    align-items: center;
    gap: 18px;
    padding-bottom: 10px;
    margin-bottom: 12px;
    border-bottom: 1px solid ${T.border};
  }
  .host-name {
    font-weight: 700;
    font-size: 15px;
    color: ${T.value};
    margin-right: auto;
  }
  .host-stat {
    display: flex;
    flex-direction: column;
    align-items: center;
  }
  .host-stat .lbl { font-size: 10px; text-transform: uppercase; letter-spacing: .06em; color: ${T.label}; }
  .host-stat .val { font-size: 14px; font-weight: 700; color: ${T.value}; }

  /* ── Status pill ── */
  .pill {
    display: inline-block;
    padding: 1px 7px;
    border-radius: 20px;
    font-size: 10px;
    font-weight: 600;
    letter-spacing: .04em;
    text-transform: uppercase;
  }
  .pill-up    { background: rgba(91,191,123,.18); color: ${T.green}; }
  .pill-down  { background: rgba(224,82,82,.18);  color: ${T.red}; }
  .pill-stale { background: rgba(212,160,68,.18); color: ${T.amber}; }

  /* ── Group ── */
  .group { margin-bottom: 10px; }
  .group-label {
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: .08em;
    color: ${T.label};
    margin-bottom: 6px;
    padding-left: 2px;
  }
  .cards { display: flex; flex-wrap: wrap; gap: 8px; }

  /* ── Card ── */
  .card {
    background: ${T.card};
    border: 1px solid ${T.border};
    border-radius: ${T.radius};
    padding: 8px 11px;
    min-width: 148px;
    flex: 1;
    transition: opacity .3s;
  }
  .card.down  { opacity: .55; border-color: rgba(224,82,82,.35); }
  .card.stale { border-color: rgba(212,160,68,.4); }

  .card-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 6px;
  }
  .card-title {
    font-weight: 600;
    font-size: 12px;
    color: ${T.value};
  }

  /* ── Container micro-stats row ── */
  .cstats {
    display: flex;
    gap: 10px;
    margin-bottom: 5px;
    font-family: ${T.fontMono};
    font-size: 10px;
    color: ${T.label};
  }
  .cstats span { white-space: nowrap; }

  /* ── Service data rows ── */
  .kv-row {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    margin-top: 3px;
  }
  .kv-row .k {
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: .05em;
    color: ${T.label};
  }
  .kv-row .v {
    font-size: 12px;
    font-weight: 700;
    color: ${T.value};
    font-family: ${T.fontMono};
  }

  /* ── Footer timestamp ── */
  .footer {
    margin-top: 10px;
    font-size: 10px;
    color: ${T.muted};
    text-align: right;
  }

  /* ── Error/loading states ── */
  .state-msg {
    padding: 12px;
    color: ${T.label};
    font-size: 12px;
    text-align: center;
  }
`

// ─────────────────────────────────────────────────────────────────────────────
// Helpers

function pill(status, stale) {
  if (stale)         return <span className="pill pill-stale">stale</span>
  if (status === "up") return <span className="pill pill-up">up</span>
  if (status === "down") return <span className="pill pill-down">down</span>
  return <span className="pill pill-stale">{status}</span>
}

function fmt(val, unit = "", decimals = 1) {
  if (val == null) return "—"
  return Number(val).toFixed(decimals) + unit
}

function uptime(secs) {
  if (!secs) return "—"
  const d = Math.floor(secs / 86400)
  const h = Math.floor((secs % 86400) / 3600)
  return d > 0 ? `${d}d ${h}h` : `${h}h`
}

function ContainerStats({ card }) {
  if (!card.container_running && card.cpu_pct == null) return null
  return (
    <div className="cstats">
      {card.cpu_pct != null && <span>CPU {fmt(card.cpu_pct, "%")}</span>}
      {card.mem_mb  != null && <span>MEM {fmt(card.mem_mb / 1024, " GB", 2)}</span>}
    </div>
  )
}

// ─────────────────────────────────────────────────────────────────────────────
// Card renderers per service type

function JellyfinCard({ card }) {
  const d = card.data || {}
  const np = (d.now_playing || []).slice(0, 1)[0]
  return (
    <div className={`card ${card.status === "down" ? "down" : ""} ${card.stale ? "stale" : ""}`}>
      <div className="card-header">
        <span className="card-title">{card.title}</span>
        {pill(card.status, card.stale)}
      </div>
      <ContainerStats card={card} />
      <div className="kv-row">
        <span className="k">Streams</span>
        <span className="v">{d.streams ?? "—"}</span>
      </div>
      {np && (
        <div className="kv-row">
          <span className="k">Playing</span>
          <span className="v" style={{fontSize:"10px", maxWidth:"110px", overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap"}}>
            {np.title}
          </span>
        </div>
      )}
    </div>
  )
}

function QBitCard({ card }) {
  const d = card.data || {}
  return (
    <div className={`card ${card.status === "down" ? "down" : ""} ${card.stale ? "stale" : ""}`}>
      <div className="card-header">
        <span className="card-title">{card.title}</span>
        {pill(card.status, card.stale)}
      </div>
      <ContainerStats card={card} />
      <div className="kv-row">
        <span className="k">↓ MiB/s</span>
        <span className="v">{fmt(d.dl_mibps)}</span>
      </div>
      <div className="kv-row">
        <span className="k">↑ MiB/s</span>
        <span className="v">{fmt(d.ul_mibps)}</span>
      </div>
      <div className="kv-row">
        <span className="k">Active / Seed</span>
        <span className="v">{d.active ?? "—"} / {d.seeding ?? "—"}</span>
      </div>
    </div>
  )
}

function ArrCard({ card }) {
  const d = card.data || {}
  const countKey = d.wanted != null ? "wanted" : d.missing != null ? "missing" : "grabs"
  return (
    <div className={`card ${card.status === "down" ? "down" : ""} ${card.stale ? "stale" : ""}`}>
      <div className="card-header">
        <span className="card-title">{card.title}</span>
        {pill(card.status, card.stale)}
      </div>
      <ContainerStats card={card} />
      <div className="kv-row">
        <span className="k">Queue</span>
        <span className="v">{d.queue ?? "—"}</span>
      </div>
      <div className="kv-row">
        <span className="k">{countKey}</span>
        <span className="v">{d[countKey] ?? "—"}</span>
      </div>
    </div>
  )
}

function PiholeCard({ card }) {
  const d = card.data || {}
  return (
    <div className={`card ${card.status === "down" ? "down" : ""} ${card.stale ? "stale" : ""}`}>
      <div className="card-header">
        <span className="card-title">{card.title}</span>
        {pill(card.status, card.stale)}
      </div>
      <ContainerStats card={card} />
      <div className="kv-row">
        <span className="k">Blocked</span>
        <span className="v">{d.blocked_pct != null ? fmt(d.blocked_pct, "%") : "—"}</span>
      </div>
      <div className="kv-row">
        <span className="k">Queries</span>
        <span className="v">{d.queries != null ? d.queries.toLocaleString() : "—"}</span>
      </div>
      <div className="kv-row">
        <span className="k">Gravity</span>
        <span className="v">{d.gravity != null ? (d.gravity/1e6).toFixed(2)+"M" : "—"}</span>
      </div>
    </div>
  )
}

function HomeCard({ card }) {
  return (
    <div className={`card ${card.status === "down" ? "down" : ""}`}>
      <div className="card-header">
        <span className="card-title">{card.title}</span>
        {pill(card.status, card.stale)}
      </div>
      <ContainerStats card={card} />
    </div>
  )
}

function renderCard(card) {
  switch (card.id) {
    case "jellyfin":    return <JellyfinCard key={card.id} card={card} />
    case "qbittorrent": return <QBitCard     key={card.id} card={card} />
    case "pihole":      return <PiholeCard   key={card.id} card={card} />
    case "sonarr":
    case "radarr":
    case "prowlarr":    return <ArrCard      key={card.id} card={card} />
    default:            return <HomeCard     key={card.id} card={card} />
  }
}

// ─────────────────────────────────────────────────────────────────────────────
const GROUP_ORDER = ["Media", "Acquisition", "Infrastructure", "Home"]

export const render = ({ output, error }) => {
  if (error) {
    return (
      <div className="wrap">
        <div className="state-msg">⚠ fetch error — {String(error).slice(0, 80)}</div>
      </div>
    )
  }

  if (!output || !output.trim()) {
    return (
      <div className="wrap">
        <div className="state-msg">connecting…</div>
      </div>
    )
  }

  let data
  try {
    data = JSON.parse(output)
  } catch (e) {
    return (
      <div className="wrap">
        <div className="state-msg">⚠ parse error: {String(e)}</div>
      </div>
    )
  }

  const host   = data.host  || {}
  const cards  = data.cards || []
  const genAt  = data.generated_at ? new Date(data.generated_at * 1000) : null
  const timeStr = genAt
    ? genAt.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" })
    : "—"

  // Group cards
  const groups = {}
  for (const c of cards) {
    const g = c.group || "Other"
    if (!groups[g]) groups[g] = []
    groups[g].push(c)
  }

  return (
    <div className="wrap">
      {/* ── Host header ── */}
      <div className="host-row">
        <span className="host-name">⚡ {host.name || "homelab"}</span>
        {pill(host.status, host.stale)}
        <div className="host-stat">
          <span className="lbl">CPU</span>
          <span className="val">{fmt(host.cpu_pct, "%")}</span>
        </div>
        <div className="host-stat">
          <span className="lbl">RAM</span>
          <span className="val">{fmt(host.ram_used_gb, "", 1)} / {fmt(host.ram_total_gb, " GB", 0)}</span>
        </div>
        <div className="host-stat">
          <span className="lbl">Disk</span>
          <span className="val">{fmt(host.disk_used_tb, "", 1)} / {fmt(host.disk_total_tb, " TB", 1)}</span>
        </div>
        <div className="host-stat">
          <span className="lbl">Uptime</span>
          <span className="val">{uptime(host.uptime)}</span>
        </div>
      </div>

      {/* ── Service groups ── */}
      {GROUP_ORDER.filter(g => groups[g]).map(g => (
        <div key={g} className="group">
          <div className="group-label">{g}</div>
          <div className="cards">
            {groups[g].map(renderCard)}
          </div>
        </div>
      ))}

      <div className="footer">updated {timeStr}</div>
    </div>
  )
}