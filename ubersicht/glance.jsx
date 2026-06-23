// homelab-glance — Übersicht desktop widget
// Polls the aggregator every 30 s and renders a full homelab status dashboard
// on the macOS desktop, styled to match the Homepage stone/dark theme.
//
// SETUP:
//   1. Install Übersicht: https://tracesof.net/uebersicht/
//   2. Drop this file into your Übersicht widgets folder
//   3. Create your secrets file (see below) — the widget will not load until
//      WIDGET_TOKEN and AGGREGATOR_URL are set there

// ── Configuration ─────────────────────────────────────────────────────────────
// Edit these values in your local copy before dropping the file into your
// Übersicht widgets folder. This file lives in the Übersicht folder, not in git,
// so there is no risk of accidentally committing real values.
const AGGREGATOR_URL = "http://YOUR_SERVER_IP:8765/api/dashboard"
const WIDGET_TOKEN   = "CHANGE_ME"

// ── Logo ──────────────────────────────────────────────────────────────────────
// Set SHOW_LOGO = false to hide the brand logo in the host-name row.
// LOGO_URI is the logo-dark SVG embedded as a base64 data URI so no external
// file is needed — it travels with the script.
const SHOW_LOGO = true
const LOGO_URI  = "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjQwMCIgdmlld0JveD0iMCAwIDQwMCA0MDAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CiAgPGRlZnM+CiAgICA8cmFkaWFsR3JhZGllbnQgaWQ9ImJnIiBjeD0iNDQlIiBjeT0iNDAlIiByPSI2OCUiPgogICAgICA8c3RvcCBvZmZzZXQ9IjAlIiBzdG9wLWNvbG9yPSIjMGQxNTI1Ii8+CiAgICAgIDxzdG9wIG9mZnNldD0iMTAwJSIgc3RvcC1jb2xvcj0iIzA2MGExMiIvPgogICAgPC9yYWRpYWxHcmFkaWVudD4KICAgIDxmaWx0ZXIgaWQ9Im5HbG93IiB4PSItNTAwJSIgeT0iLTUwMCUiIHdpZHRoPSIxMTAwJSIgaGVpZ2h0PSIxMTAwJSI+CiAgICAgIDxmZUdhdXNzaWFuQmx1ciBzdGREZXZpYXRpb249IjIuNSIgcmVzdWx0PSJiIi8+CiAgICAgIDxmZU1lcmdlPjxmZU1lcmdlTm9kZSBpbj0iYiIvPjxmZU1lcmdlTm9kZSBpbj0iU291cmNlR3JhcGhpYyIvPjwvZmVNZXJnZT4KICAgIDwvZmlsdGVyPgogICAgPGNsaXBQYXRoIGlkPSJjYyI+PGNpcmNsZSBjeD0iMjAwIiBjeT0iMjAwIiByPSIxODYiLz48L2NsaXBQYXRoPgogICAgCiAgPC9kZWZzPgogIDxjaXJjbGUgY3g9IjIwMCIgY3k9IjIwMCIgcj0iMTkyIiBmaWxsPSIjMDYwYTEyIi8+CiAgPGNpcmNsZSBjeD0iMjAwIiBjeT0iMjAwIiByPSIxOTIiIGZpbGw9InVybCgjYmcpIi8+CiAgPGNpcmNsZSBjeD0iMjAwIiBjeT0iMjAwIiByPSIxODkiIGZpbGw9Im5vbmUiIHN0cm9rZT0iI2Y1Yzg0MiIgc3Ryb2tlLXdpZHRoPSIwLjkiIG9wYWNpdHk9IjAuMiIvPgogIDxnIGNsaXAtcGF0aD0idXJsKCNjYykiPgogICAgPGcgc3Ryb2tlPSIjZjVjODQyIiBzdHJva2Utd2lkdGg9IjAuNyIgZmlsbD0ibm9uZSIgb3BhY2l0eT0iMC4xOCI+CiAgICAgIDxsaW5lIHgxPSIxNTcuMSIgeTE9IjEwOC44IiB4Mj0iMTQ1LjYiIHkyPSIxNjguMiIvPgogICAgICA8bGluZSB4MT0iMTU3LjEiIHkxPSIxMDguOCIgeDI9IjIxNy4yIiB5Mj0iOTAuMSIvPgogICAgICA8bGluZSB4MT0iMTU3LjEiIHkxPSIxMDguOCIgeDI9IjEyNS45IiB5Mj0iOTkuNyIvPgogICAgICA8bGluZSB4MT0iMTQ1LjYiIHkxPSIxNjguMiIgeDI9IjIwMi45IiB5Mj0iMjA5LjkiLz4KICAgICAgPGxpbmUgeDE9IjE0NS42IiB5MT0iMTY4LjIiIHgyPSIxMDAuMSIgeTI9IjIwOS4wIi8+CiAgICAgIDxsaW5lIHgxPSIyMTAuMyIgeTE9IjMyNi4wIiB4Mj0iMjI5LjgiIHkyPSIzMDYuNSIvPgogICAgICA8bGluZSB4MT0iMzI0LjIiIHkxPSIxODkuMyIgeDI9IjMwNS40IiB5Mj0iMTM0LjYiLz4KICAgICAgPGxpbmUgeDE9IjMyNC4yIiB5MT0iMTg5LjMiIHgyPSIzMDUuMSIgeTI9IjIyNC4zIi8+CiAgICAgIDxsaW5lIHgxPSIyMTEuNyIgeTE9Ijc0LjAiIHgyPSIyMTcuMiIgeTI9IjkwLjEiLz4KICAgICAgPGxpbmUgeDE9IjE4NS42IiB5MT0iMjc1LjIiIHgyPSIxMjMuOCIgeTI9IjI3MC42Ii8+CiAgICAgIDxsaW5lIHgxPSIxODUuNiIgeTE9IjI3NS4yIiB4Mj0iMjI5LjgiIHkyPSIzMDYuNSIvPgogICAgICA8bGluZSB4MT0iMTg1LjYiIHkxPSIyNzUuMiIgeDI9IjIwMi45IiB5Mj0iMjA5LjkiLz4KICAgICAgPGxpbmUgeDE9IjEyMy44IiB5MT0iMjcwLjYiIHgyPSIxMTcuNiIgeTI9IjI5NS4yIi8+CiAgICAgIDxsaW5lIHgxPSIxMjMuOCIgeTE9IjI3MC42IiB4Mj0iMTAwLjEiIHkyPSIyMDkuMCIvPgogICAgICA8bGluZSB4MT0iMjg4LjQiIHkxPSIyODkuNiIgeDI9IjI4NS4yIiB5Mj0iMjgxLjEiLz4KICAgICAgPGxpbmUgeDE9IjI4NS4yIiB5MT0iMjgxLjEiIHgyPSIyMjkuOCIgeTI9IjMwNi41Ii8+CiAgICAgIDxsaW5lIHgxPSIyODUuMiIgeTE9IjI4MS4xIiB4Mj0iMzA1LjEiIHkyPSIyMjQuMyIvPgogICAgICA8bGluZSB4MT0iMjcwLjUiIHkxPSIxMjQuOSIgeDI9IjI2Ny42IiB5Mj0iMTg0LjkiLz4KICAgICAgPGxpbmUgeDE9IjI3MC41IiB5MT0iMTI0LjkiIHgyPSIzMDUuNCIgeTI9IjEzNC42Ii8+CiAgICAgIDxsaW5lIHgxPSIyNzAuNSIgeTE9IjEyNC45IiB4Mj0iMjE3LjIiIHkyPSI5MC4xIi8+CiAgICAgIDxsaW5lIHgxPSIyNjcuNiIgeTE9IjE4NC45IiB4Mj0iMzA1LjEiIHkyPSIyMjQuMyIvPgogICAgICA8bGluZSB4MT0iMjY3LjYiIHkxPSIxODQuOSIgeDI9IjIwMi45IiB5Mj0iMjA5LjkiLz4KICAgICAgPGxpbmUgeDE9Ijg5LjQiIHkxPSIxMzcuMyIgeDI9Ijc1LjgiIHkyPSIxODcuNSIvPgogICAgICA8bGluZSB4MT0iODkuNCIgeTE9IjEzNy4zIiB4Mj0iMTI1LjkiIHkyPSI5OS43Ii8+CiAgICAgIDxsaW5lIHgxPSI3NS44IiB5MT0iMTg3LjUiIHgyPSIxMDAuMSIgeTI9IjIwOS4wIi8+CiAgICA8L2c+CiAgICA8ZyBzdHJva2U9IiNmNWM4NDIiIHN0cm9rZS13aWR0aD0iMC44NSIgZmlsbD0ibm9uZSIgb3BhY2l0eT0iMC4zMiI+CiAgICAgIDxsaW5lIHgxPSIyMzIuMyIgeTE9IjEwMi40IiB4Mj0iMjQ3LjQiIHkyPSI4Ny4zIi8+CiAgICAgIDxsaW5lIHgxPSIyMTAuMyIgeTE9IjMyNi4wIiB4Mj0iMTU5LjIiIHkyPSIzMTkuOCIvPgogICAgICA8bGluZSB4MT0iMjEwLjMiIHkxPSIzMjYuMCIgeDI9IjI0Ni42IiB5Mj0iMzE0LjIiLz4KICAgICAgPGxpbmUgeDE9IjE5MS4zIiB5MT0iMTA2LjEiIHgyPSIxNTYuNyIgeTI9Ijk2LjgiLz4KICAgICAgPGxpbmUgeDE9IjE1OS4yIiB5MT0iMzE5LjgiIHgyPSIxNTUuMCIgeTI9IjMwNC41Ii8+CiAgICAgIDxsaW5lIHgxPSIxNTkuMiIgeTE9IjMxOS44IiB4Mj0iMTE3LjYiIHkyPSIyOTUuMiIvPgogICAgICA8bGluZSB4MT0iMzIyLjEiIHkxPSIyMDkuNCIgeDI9IjMyNC4yIiB5Mj0iMTg5LjMiLz4KICAgICAgPGxpbmUgeDE9IjMyMi4xIiB5MT0iMjA5LjQiIHgyPSIzMDYuMSIgeTI9IjE4My4zIi8+CiAgICAgIDxsaW5lIHgxPSIzMjIuMSIgeTE9IjIwOS40IiB4Mj0iMzA1LjkiIHkyPSIyNTQuMyIvPgogICAgICA8bGluZSB4MT0iODcuMiIgeTE9IjE5MS41IiB4Mj0iOTQuOCIgeTI9IjE0Ni43Ii8+CiAgICAgIDxsaW5lIHgxPSI4Ny4yIiB5MT0iMTkxLjUiIHgyPSI3NS44IiB5Mj0iMjE5LjQiLz4KICAgICAgPGxpbmUgeDE9IjIxMS43IiB5MT0iNzQuMCIgeDI9IjE2MS4xIiB5Mj0iODAuMSIvPgogICAgICA8bGluZSB4MT0iMjExLjciIHkxPSI3NC4wIiB4Mj0iMjQ3LjQiIHkyPSI4Ny4zIi8+CiAgICAgIDxsaW5lIHgxPSIyMzEuNSIgeTE9IjMwMC4zIiB4Mj0iMjQ2LjYiIHkyPSIzMTQuMiIvPgogICAgICA8bGluZSB4MT0iMTYxLjEiIHkxPSI4MC4xIiB4Mj0iMTU2LjciIHkyPSI5Ni44Ii8+CiAgICAgIDxsaW5lIHgxPSIxNjEuMSIgeTE9IjgwLjEiIHgyPSIxMjUuOSIgeTI9Ijk5LjciLz4KICAgICAgPGxpbmUgeDE9IjE5MC4xIiB5MT0iMjk2LjQiIHgyPSIxNTUuMCIgeTI9IjMwNC41Ii8+CiAgICAgIDxsaW5lIHgxPSIyOTEuNSIgeTE9IjE0MS4xIiB4Mj0iMjg5LjIiIHkyPSIxMTQuMiIvPgogICAgICA8bGluZSB4MT0iMjkxLjUiIHkxPSIxNDEuMSIgeDI9IjMwNi4xIiB5Mj0iMTgzLjMiLz4KICAgICAgPGxpbmUgeDE9IjI4OS4yIiB5MT0iMTE0LjIiIHgyPSIyNDcuNCIgeTI9Ijg3LjMiLz4KICAgICAgPGxpbmUgeDE9IjI4OS4yIiB5MT0iMTE0LjIiIHgyPSIzMDUuNCIgeTI9IjEzNC42Ii8+CiAgICAgIDxsaW5lIHgxPSIyODguNCIgeTE9IjI4OS42IiB4Mj0iMjQ2LjYiIHkyPSIzMTQuMiIvPgogICAgICA8bGluZSB4MT0iMjg4LjQiIHkxPSIyODkuNiIgeDI9IjMwNS45IiB5Mj0iMjU0LjMiLz4KICAgICAgPGxpbmUgeDE9IjEyNi41IiB5MT0iMTI2LjYiIHgyPSIxNTYuNyIgeTI9Ijk2LjgiLz4KICAgICAgPGxpbmUgeDE9IjEyNi41IiB5MT0iMTI2LjYiIHgyPSI5NC44IiB5Mj0iMTQ2LjciLz4KICAgICAgPGxpbmUgeDE9IjExOS45IiB5MT0iMjc2LjEiIHgyPSI5NC41IiB5Mj0iMjY3LjIiLz4KICAgICAgPGxpbmUgeDE9IjExOS45IiB5MT0iMjc2LjEiIHgyPSIxNTUuMCIgeTI9IjMwNC41Ii8+CiAgICAgIDxsaW5lIHgxPSI5NC41IiB5MT0iMjY3LjIiIHgyPSIxMTcuNiIgeTI9IjI5NS4yIi8+CiAgICAgIDxsaW5lIHgxPSI5NC41IiB5MT0iMjY3LjIiIHgyPSI3NS44IiB5Mj0iMjE5LjQiLz4KICAgICAgPGxpbmUgeDE9IjI4NC4wIiB5MT0iMjQ4LjMiIHgyPSIzMDUuOSIgeTI9IjI1NC4zIi8+CiAgICAgIDxsaW5lIHgxPSI4OS40IiB5MT0iMTM3LjMiIHgyPSI5NC44IiB5Mj0iMTQ2LjciLz4KICAgICAgPGxpbmUgeDE9Ijc1LjgiIHkxPSIxODcuNSIgeDI9Ijc1LjgiIHkyPSIyMTkuNCIvPgogICAgPC9nPgogICAgPGcgc3Ryb2tlPSIjZjVjODQyIiBzdHJva2Utd2lkdGg9IjEuMSIgZmlsbD0ibm9uZSIgb3BhY2l0eT0iMC41MiI+CiAgICAgIDxsaW5lIHgxPSIyMjYuNSIgeTE9IjIxNi4xIiB4Mj0iMjIzLjIiIHkyPSIyNTEuMyIvPgogICAgICA8bGluZSB4MT0iMjI2LjUiIHkxPSIyMTYuMSIgeDI9IjI1NS4xIiB5Mj0iMTk1LjEiLz4KICAgICAgPGxpbmUgeDE9IjIyNi41IiB5MT0iMjE2LjEiIHgyPSIxOTcuOCIgeTI9IjE5NS4zIi8+CiAgICAgIDxsaW5lIHgxPSIyMjMuMiIgeTE9IjI1MS4zIiB4Mj0iMjUwLjUiIHkyPSIyNjkuOCIvPgogICAgICA8bGluZSB4MT0iMjIzLjIiIHkxPSIyNTEuMyIgeDI9IjE4OC44IiB5Mj0iMjY1LjgiLz4KICAgICAgPGxpbmUgeDE9IjIzMi4zIiB5MT0iMTAyLjQiIHgyPSIxOTEuMyIgeTI9IjEwNi4xIi8+CiAgICAgIDxsaW5lIHgxPSIyMzIuMyIgeTE9IjEwMi40IiB4Mj0iMjU4LjAiIHkyPSIxMzEuOSIvPgogICAgICA8bGluZSB4MT0iMTkxLjMiIHkxPSIxMDYuMSIgeDI9IjE4MS40IiB5Mj0iMTM2LjciLz4KICAgICAgPGxpbmUgeDE9IjExMS4wIiB5MT0iMjA3LjciIHgyPSI4Ny4yIiB5Mj0iMTkxLjUiLz4KICAgICAgPGxpbmUgeDE9IjExMS4wIiB5MT0iMjA3LjciIHgyPSIxMzcuNSIgeTI9IjE4NS44Ii8+CiAgICAgIDxsaW5lIHgxPSIxMTEuMCIgeTE9IjIwNy43IiB4Mj0iMTI1LjUiIHkyPSIyNDUuNyIvPgogICAgICA8bGluZSB4MT0iMjQyLjYiIHkxPSIxNTkuOCIgeDI9IjIwNi42IiB5Mj0iMTYxLjIiLz4KICAgICAgPGxpbmUgeDE9IjI0Mi42IiB5MT0iMTU5LjgiIHgyPSIyNTguMCIgeTI9IjEzMS45Ii8+CiAgICAgIDxsaW5lIHgxPSIyNDIuNiIgeTE9IjE1OS44IiB4Mj0iMjU1LjEiIHkyPSIxOTUuMSIvPgogICAgICA8bGluZSB4MT0iMjMxLjUiIHkxPSIzMDAuMyIgeDI9IjE5MC4xIiB5Mj0iMjk2LjQiLz4KICAgICAgPGxpbmUgeDE9IjIzMS41IiB5MT0iMzAwLjMiIHgyPSIyNTAuNSIgeTI9IjI2OS44Ii8+CiAgICAgIDxsaW5lIHgxPSIyMDYuNiIgeTE9IjE2MS4yIiB4Mj0iMTgxLjQiIHkyPSIxMzYuNyIvPgogICAgICA8bGluZSB4MT0iMjA2LjYiIHkxPSIxNjEuMiIgeDI9IjE5Ny44IiB5Mj0iMTk1LjMiLz4KICAgICAgPGxpbmUgeDE9IjE5MC4xIiB5MT0iMjk2LjQiIHgyPSIxODguOCIgeTI9IjI2NS44Ii8+CiAgICAgIDxsaW5lIHgxPSIyOTEuNSIgeTE9IjE0MS4xIiB4Mj0iMjU4LjAiIHkyPSIxMzEuOSIvPgogICAgICA8bGluZSB4MT0iMTQ1LjIiIHkxPSIxNDguOCIgeDI9IjEyNi41IiB5Mj0iMTI2LjYiLz4KICAgICAgPGxpbmUgeDE9IjE0NS4yIiB5MT0iMTQ4LjgiIHgyPSIxODEuNCIgeTI9IjEzNi43Ii8+CiAgICAgIDxsaW5lIHgxPSIxNDUuMiIgeTE9IjE0OC44IiB4Mj0iMTM3LjUiIHkyPSIxODUuOCIvPgogICAgICA8bGluZSB4MT0iMTE5LjkiIHkxPSIyNzYuMSIgeDI9IjEyNS41IiB5Mj0iMjQ1LjciLz4KICAgICAgPGxpbmUgeDE9IjI4NS4wIiB5MT0iMjA4LjciIHgyPSIyODQuMCIgeTI9IjI0OC4zIi8+CiAgICAgIDxsaW5lIHgxPSIyODUuMCIgeTE9IjIwOC43IiB4Mj0iMzA2LjEiIHkyPSIxODMuMyIvPgogICAgICA8bGluZSB4MT0iMjg1LjAiIHkxPSIyMDguNyIgeDI9IjI1NS4xIiB5Mj0iMTk1LjEiLz4KICAgICAgPGxpbmUgeDE9IjI4NC4wIiB5MT0iMjQ4LjMiIHgyPSIyNTAuNSIgeTI9IjI2OS44Ii8+CiAgICAgIDxsaW5lIHgxPSIxNjQuNyIgeTE9IjIwNy44IiB4Mj0iMTU5LjAiIHkyPSIyNDIuOSIvPgogICAgICA8bGluZSB4MT0iMTY0LjciIHkxPSIyMDcuOCIgeDI9IjEzNy41IiB5Mj0iMTg1LjgiLz4KICAgICAgPGxpbmUgeDE9IjE2NC43IiB5MT0iMjA3LjgiIHgyPSIxOTcuOCIgeTI9IjE5NS4zIi8+CiAgICAgIDxsaW5lIHgxPSIxNTkuMCIgeTE9IjI0Mi45IiB4Mj0iMTI1LjUiIHkyPSIyNDUuNyIvPgogICAgICA8bGluZSB4MT0iMTU5LjAiIHkxPSIyNDIuOSIgeDI9IjE4OC44IiB5Mj0iMjY1LjgiLz4KICAgIDwvZz4KICAgIDxnIGZpbGw9IiNmNWM4NDIiICBvcGFjaXR5PSIwLjIyIj4KICAgICAgPGNpcmNsZSBjeD0iMTU3LjEiIGN5PSIxMDguOCIgcj0iMi4yIi8+CiAgICAgIDxjaXJjbGUgY3g9IjE0NS42IiBjeT0iMTY4LjIiIHI9IjIuMiIvPgogICAgICA8Y2lyY2xlIGN4PSIyMTAuMyIgY3k9IjMyNi4wIiByPSIyLjIiLz4KICAgICAgPGNpcmNsZSBjeD0iMzI0LjIiIGN5PSIxODkuMyIgcj0iMi4yIi8+CiAgICAgIDxjaXJjbGUgY3g9IjE4NS42IiBjeT0iMjc1LjIiIHI9IjIuMiIvPgogICAgICA8Y2lyY2xlIGN4PSIxMjMuOCIgY3k9IjI3MC42IiByPSIyLjIiLz4KICAgICAgPGNpcmNsZSBjeD0iMjg1LjIiIGN5PSIyODEuMSIgcj0iMi4yIi8+CiAgICAgIDxjaXJjbGUgY3g9IjI3MC41IiBjeT0iMTI0LjkiIHI9IjIuMiIvPgogICAgICA8Y2lyY2xlIGN4PSIyNjcuNiIgY3k9IjE4NC45IiByPSIyLjIiLz4KICAgICAgPGNpcmNsZSBjeD0iNzUuOCIgY3k9IjE4Ny41IiByPSIyLjIiLz4KICAgICAgPGNpcmNsZSBjeD0iMjI5LjgiIGN5PSIzMDYuNSIgcj0iMi4yIi8+CiAgICAgIDxjaXJjbGUgY3g9IjExNy42IiBjeT0iMjk1LjIiIHI9IjIuMiIvPgogICAgICA8Y2lyY2xlIGN4PSIzMDUuNCIgY3k9IjEzNC42IiByPSIyLjIiLz4KICAgICAgPGNpcmNsZSBjeD0iMzA1LjEiIGN5PSIyMjQuMyIgcj0iMi4yIi8+CiAgICAgIDxjaXJjbGUgY3g9IjIxNy4yIiBjeT0iOTAuMSIgcj0iMi4yIi8+CiAgICAgIDxjaXJjbGUgY3g9IjIwMi45IiBjeT0iMjA5LjkiIHI9IjIuMiIvPgogICAgICA8Y2lyY2xlIGN4PSIxMjUuOSIgY3k9Ijk5LjciIHI9IjIuMiIvPgogICAgICA8Y2lyY2xlIGN4PSIxMDAuMSIgY3k9IjIwOS4wIiByPSIyLjIiLz4KICAgIDwvZz4KICAgIDxnIGZpbGw9IiNmNWM4NDIiICBvcGFjaXR5PSIwLjQyIj4KICAgICAgPGNpcmNsZSBjeD0iMjMyLjMiIGN5PSIxMDIuNCIgcj0iMi44IiBmaWx0ZXI9InVybCgjbkdsb3cpIi8+CiAgICAgIDxjaXJjbGUgY3g9IjE1OS4yIiBjeT0iMzE5LjgiIHI9IjIuOCIgZmlsdGVyPSJ1cmwoI25HbG93KSIvPgogICAgICA8Y2lyY2xlIGN4PSIzMjIuMSIgY3k9IjIwOS40IiByPSIyLjgiIGZpbHRlcj0idXJsKCNuR2xvdykiLz4KICAgICAgPGNpcmNsZSBjeD0iODcuMiIgY3k9IjE5MS41IiByPSIyLjgiIGZpbHRlcj0idXJsKCNuR2xvdykiLz4KICAgICAgPGNpcmNsZSBjeD0iMjExLjciIGN5PSI3NC4wIiByPSIyLjgiIGZpbHRlcj0idXJsKCNuR2xvdykiLz4KICAgICAgPGNpcmNsZSBjeD0iMjMxLjUiIGN5PSIzMDAuMyIgcj0iMi44IiBmaWx0ZXI9InVybCgjbkdsb3cpIi8+CiAgICAgIDxjaXJjbGUgY3g9IjE2MS4xIiBjeT0iODAuMSIgcj0iMi44IiBmaWx0ZXI9InVybCgjbkdsb3cpIi8+CiAgICAgIDxjaXJjbGUgY3g9IjI5MS41IiBjeT0iMTQxLjEiIHI9IjIuOCIgZmlsdGVyPSJ1cmwoI25HbG93KSIvPgogICAgICA8Y2lyY2xlIGN4PSIyODkuMiIgY3k9IjExNC4yIiByPSIyLjgiIGZpbHRlcj0idXJsKCNuR2xvdykiLz4KICAgICAgPGNpcmNsZSBjeD0iMjg4LjQiIGN5PSIyODkuNiIgcj0iMi44IiBmaWx0ZXI9InVybCgjbkdsb3cpIi8+CiAgICAgIDxjaXJjbGUgY3g9IjEyNi41IiBjeT0iMTI2LjYiIHI9IjIuOCIgZmlsdGVyPSJ1cmwoI25HbG93KSIvPgogICAgICA8Y2lyY2xlIGN4PSIxMTkuOSIgY3k9IjI3Ni4xIiByPSIyLjgiIGZpbHRlcj0idXJsKCNuR2xvdykiLz4KICAgICAgPGNpcmNsZSBjeD0iOTQuNSIgY3k9IjI2Ny4yIiByPSIyLjgiIGZpbHRlcj0idXJsKCNuR2xvdykiLz4KICAgICAgPGNpcmNsZSBjeD0iODkuNCIgY3k9IjEzNy4zIiByPSIyLjgiIGZpbHRlcj0idXJsKCNuR2xvdykiLz4KICAgICAgPGNpcmNsZSBjeD0iMjQ3LjQiIGN5PSI4Ny4zIiByPSIyLjgiIGZpbHRlcj0idXJsKCNuR2xvdykiLz4KICAgICAgPGNpcmNsZSBjeD0iMjQ2LjYiIGN5PSIzMTQuMiIgcj0iMi44IiBmaWx0ZXI9InVybCgjbkdsb3cpIi8+CiAgICAgIDxjaXJjbGUgY3g9IjE1Ni43IiBjeT0iOTYuOCIgcj0iMi44IiBmaWx0ZXI9InVybCgjbkdsb3cpIi8+CiAgICAgIDxjaXJjbGUgY3g9IjE1NS4wIiBjeT0iMzA0LjUiIHI9IjIuOCIgZmlsdGVyPSJ1cmwoI25HbG93KSIvPgogICAgICA8Y2lyY2xlIGN4PSIzMDYuMSIgY3k9IjE4My4zIiByPSIyLjgiIGZpbHRlcj0idXJsKCNuR2xvdykiLz4KICAgICAgPGNpcmNsZSBjeD0iMzA1LjkiIGN5PSIyNTQuMyIgcj0iMi44IiBmaWx0ZXI9InVybCgjbkdsb3cpIi8+CiAgICAgIDxjaXJjbGUgY3g9Ijk0LjgiIGN5PSIxNDYuNyIgcj0iMi44IiBmaWx0ZXI9InVybCgjbkdsb3cpIi8+CiAgICAgIDxjaXJjbGUgY3g9Ijc1LjgiIGN5PSIyMTkuNCIgcj0iMi44IiBmaWx0ZXI9InVybCgjbkdsb3cpIi8+CiAgICA8L2c+CiAgICA8ZyBmaWxsPSIjZjVjODQyIiAgb3BhY2l0eT0iMC43NSI+CiAgICAgIDxjaXJjbGUgY3g9IjIyNi41IiBjeT0iMjE2LjEiIHI9IjMuNCIgZmlsdGVyPSJ1cmwoI25HbG93KSIvPgogICAgICA8Y2lyY2xlIGN4PSIyMjMuMiIgY3k9IjI1MS4zIiByPSIzLjQiIGZpbHRlcj0idXJsKCNuR2xvdykiLz4KICAgICAgPGNpcmNsZSBjeD0iMTkxLjMiIGN5PSIxMDYuMSIgcj0iMy40IiBmaWx0ZXI9InVybCgjbkdsb3cpIi8+CiAgICAgIDxjaXJjbGUgY3g9IjExMS4wIiBjeT0iMjA3LjciIHI9IjMuNCIgZmlsdGVyPSJ1cmwoI25HbG93KSIvPgogICAgICA8Y2lyY2xlIGN4PSIyNDIuNiIgY3k9IjE1OS44IiByPSIzLjQiIGZpbHRlcj0idXJsKCNuR2xvdykiLz4KICAgICAgPGNpcmNsZSBjeD0iMjA2LjYiIGN5PSIxNjEuMiIgcj0iMy40IiBmaWx0ZXI9InVybCgjbkdsb3cpIi8+CiAgICAgIDxjaXJjbGUgY3g9IjE5MC4xIiBjeT0iMjk2LjQiIHI9IjMuNCIgZmlsdGVyPSJ1cmwoI25HbG93KSIvPgogICAgICA8Y2lyY2xlIGN4PSIxNDUuMiIgY3k9IjE0OC44IiByPSIzLjQiIGZpbHRlcj0idXJsKCNuR2xvdykiLz4KICAgICAgPGNpcmNsZSBjeD0iMjg1LjAiIGN5PSIyMDguNyIgcj0iMy40IiBmaWx0ZXI9InVybCgjbkdsb3cpIi8+CiAgICAgIDxjaXJjbGUgY3g9IjI4NC4wIiBjeT0iMjQ4LjMiIHI9IjMuNCIgZmlsdGVyPSJ1cmwoI25HbG93KSIvPgogICAgICA8Y2lyY2xlIGN4PSIxNjQuNyIgY3k9IjIwNy44IiByPSIzLjQiIGZpbHRlcj0idXJsKCNuR2xvdykiLz4KICAgICAgPGNpcmNsZSBjeD0iMTU5LjAiIGN5PSIyNDIuOSIgcj0iMy40IiBmaWx0ZXI9InVybCgjbkdsb3cpIi8+CiAgICAgIDxjaXJjbGUgY3g9IjI1OC4wIiBjeT0iMTMxLjkiIHI9IjMuNCIgZmlsdGVyPSJ1cmwoI25HbG93KSIvPgogICAgICA8Y2lyY2xlIGN4PSIxODEuNCIgY3k9IjEzNi43IiByPSIzLjQiIGZpbHRlcj0idXJsKCNuR2xvdykiLz4KICAgICAgPGNpcmNsZSBjeD0iMTM3LjUiIGN5PSIxODUuOCIgcj0iMy40IiBmaWx0ZXI9InVybCgjbkdsb3cpIi8+CiAgICAgIDxjaXJjbGUgY3g9IjEyNS41IiBjeT0iMjQ1LjciIHI9IjMuNCIgZmlsdGVyPSJ1cmwoI25HbG93KSIvPgogICAgICA8Y2lyY2xlIGN4PSIyNTUuMSIgY3k9IjE5NS4xIiByPSIzLjQiIGZpbHRlcj0idXJsKCNuR2xvdykiLz4KICAgICAgPGNpcmNsZSBjeD0iMjUwLjUiIGN5PSIyNjkuOCIgcj0iMy40IiBmaWx0ZXI9InVybCgjbkdsb3cpIi8+CiAgICAgIDxjaXJjbGUgY3g9IjE5Ny44IiBjeT0iMTk1LjMiIHI9IjMuNCIgZmlsdGVyPSJ1cmwoI25HbG93KSIvPgogICAgICA8Y2lyY2xlIGN4PSIxODguOCIgY3k9IjI2NS44IiByPSIzLjQiIGZpbHRlcj0idXJsKCNuR2xvdykiLz4KICAgIDwvZz4KICA8L2c+Cjwvc3ZnPg=="

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
export const command = `curl -sf -m 8 -H "Authorization: Bearer ${WIDGET_TOKEN}" "${AGGREGATOR_URL}"`
export const refreshFrequency = 30000   // 30 s

// Position widget in top-right corner; adjust to taste
export const className = `
  top: 20px;
  left: 20px;
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
	gap: 12px;
	padding-bottom: 10px;
	margin-bottom: 12px;
	border-bottom: 1px solid ${T.border};
  }
  .host-logo {
	width: 45px;
	height: 45px;
	border-radius: 50%;
	flex-shrink: 0;
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
	margin-left: 10px;
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

  /* ── Sensors section ── */
  .sensors { margin-top: 10px; }
  .sensor-rows { display: flex; flex-direction: column; gap: 5px; }
  .sensor-row { display: flex; align-items: center; gap: 8px; }
  .sensor-lbl {
	font-size: 10px;
	text-transform: uppercase;
	letter-spacing: .06em;
	color: ${T.label};
	width: 44px;
	flex-shrink: 0;
  }
  .sensor-val {
	font-size: 13px;
	font-weight: 700;
	color: ${T.value};
	width: 36px;
	flex-shrink: 0;
	font-family: ${T.fontMono};
  }
  .sensor-spark {
	flex: 1;
	min-width: 0;
	display: flex;
	align-items: center;
  }
  .sensor-gpu {
	display: flex;
	gap: 14px;
	font-size: 10px;
	padding-left: 2px;
	margin-top: 3px;
  }
  .sensor-gpu .k { color: ${T.label}; text-transform: uppercase; letter-spacing: .04em; margin-right: 3px; }
  .sensor-gpu .v { font-weight: 700; color: ${T.value}; font-family: ${T.fontMono}; }

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
// Sparkline — renders a mini SVG line chart scaled to the data range

// Sparkline is rendered into a fixed coordinate space (width × height) but
// displayed at 100% container width via viewBox + preserveAspectRatio so it
// fills the available space. vectorEffect="non-scaling-stroke" keeps the
// 1.5px line crisp regardless of how the SVG is stretched.
function Sparkline({ data, width = 90, height = 24, color }) {
  if (!data || data.length < 2) return null
  const min = Math.min(...data), max = Math.max(...data)
  const range = max - min || 1
  const pts = data.map((v, i) => {
	const x = (i / (data.length - 1)) * (width - 2) + 1
	const y = (height - 2) - ((v - min) / range) * (height - 4)
	return `${x.toFixed(1)},${y.toFixed(1)}`
  }).join(" ")
  return (
	<svg viewBox={`0 0 ${width} ${height}`} preserveAspectRatio="none"
		 style={{width:"100%", height:`${height}px`, overflow:"visible", display:"block"}}>
	  <polyline points={pts} fill="none" stroke={color} strokeWidth="1.5"
				strokeLinejoin="round" strokeLinecap="round"
				vectorEffect="non-scaling-stroke" />
	</svg>
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
// Sensors section — NVMe + GPU temperature sparklines and GPU load/power/VRAM

function SensorsSection({ sensors }) {
  if (!sensors) return null
  const {
	nvme_temp, gpu_temp, nvme_temp_history, gpu_temp_history,
	gpu_load_pct, gpu_power_w, gpu_vram_used_mb, gpu_vram_total_mb,
  } = sensors
  if (nvme_temp == null && gpu_temp == null) return null
  return (
	<div className="sensors">
	  <div className="group-label">Sensors</div>
	  <div className="sensor-rows">
		{nvme_temp != null && (
		  <div className="sensor-row">
			<span className="sensor-lbl">NVMe</span>
			<span className="sensor-val">{fmt(nvme_temp, "°", 0)}</span>
			<div className="sensor-spark">
			  <Sparkline data={nvme_temp_history} color={T.amber} />
			</div>
		  </div>
		)}
		{gpu_temp != null && (
		  <div className="sensor-row">
			<span className="sensor-lbl">GPU</span>
			<span className="sensor-val">{fmt(gpu_temp, "°", 0)}</span>
			<div className="sensor-spark">
			  <Sparkline data={gpu_temp_history} color={T.green} />
			</div>
		  </div>
		)}
		{(gpu_load_pct != null || gpu_power_w != null || gpu_vram_used_mb != null) && (
		  <div className="sensor-gpu">
			{gpu_load_pct != null && (
			  <span><span className="k">Load</span><span className="v">{fmt(gpu_load_pct, "%", 0)}</span></span>
			)}
			{gpu_power_w != null && (
			  <span><span className="k">Power</span><span className="v">{fmt(gpu_power_w, "W", 0)}</span></span>
			)}
			{gpu_vram_used_mb != null && gpu_vram_total_mb != null && (
			  <span>
				<span className="k">VRAM</span>
				<span className="v">
				  {fmt(gpu_vram_used_mb / 1024, "", 1)}/{fmt(gpu_vram_total_mb / 1024, " GB", 0)}
				</span>
			  </span>
			)}
		  </div>
		)}
	  </div>
	</div>
  )
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
		{SHOW_LOGO && <img className="host-logo" src={LOGO_URI} alt="" />}
		<span className="host-name">{host.name || "homelab"}</span>
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

	  {/* ── Sensors ── */}
	  {host.sensors && <SensorsSection sensors={host.sensors} />}

	  <div className="footer">updated {timeStr}</div>
	</div>
  )
}
