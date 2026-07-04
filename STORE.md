# Homelab Glance — App Store readiness checklist

What's needed to ship the iOS/macOS client. The aggregator stays open-source
(see [aggregator/README.md](aggregator/README.md)) — only the app goes to the
App Store.

## Metadata (fill in on App Store Connect)

| Field | Value / TODO |
|---|---|
| App name | Homelab Glance *(confirm availability on ASC)* |
| Subtitle (30 chars) | e.g. "Your homelab, at a glance" |
| Category | Utilities |
| Description | TODO — cover: native dashboard for your self-hosted homelab; auto-detected Docker containers (rich cards for Jellyfin/Sonarr/…, generic cards for everything else); home-screen + menu-bar widgets; start/stop/restart with a separate control token; works with the open-source aggregator you run on your own server; demo mode needs no server. |
| Keywords (100 chars) | homelab,docker,server,dashboard,self-hosted,jellyfin,sonarr,widget,monitor |
| Support URL | TODO (e.g. the GitHub repo) |
| Marketing URL | optional |
| Privacy-policy URL | **TODO — required.** Must state: no data collected; the app talks only to the user's own server; tokens stay in the device Keychain. |

## Privacy (App Privacy section on ASC)

- Data collection: **None**. (Matches `PrivacyInfo.xcprivacy`: no tracking, no
  collected data types, UserDefaults accessed with reason CA92.1.)
- `ITSAppUsesNonExemptEncryption = false` is already set — no export docs needed.

## App Review notes (paste into the Review Notes field)

> Homelab Glance is a client for the open-source "glance" aggregator the user
> runs on their own server (https://github.com/AnmolS1/homelab-glance). No
> account or server is needed to review: **Mock Data is ON by default** — every
> screen and widget is fully explorable with bundled sample data (dashboard,
> container list, logs, start/stop/restart against the mock control plane, the
> card manager, and the configurable widget).
>
> Network use: the app connects only to the server URL the user enters. ATS is
> restrictive (HTTPS by default) with NSAllowsLocalNetworking for LAN servers
> and a scoped exception for Tailscale MagicDNS (*.ts.net) hosts, whose traffic
> is end-to-end encrypted by WireGuard. NSLocalNetworkUsageDescription is set;
> the local-network prompt appears on first connect, not at launch.

## Screenshots (generate from mock mode — no server needed)

Matrix: light + dark per device class.

- iPhone 6.9" (iPhone 17 Pro Max sim): dashboard (rich + generic cards), container list + logs, Settings, widget gallery/Edit Widget.
- iPad 13": dashboard grid, extra-large widget.
- Mac: main window, menu-bar panel, narrow-window Settings.

Suggested flow per screenshot run: fresh install → onboarding → "Explore with
sample data" → screenshots.

## Human-only steps (cannot be automated from this repo)

1. Create the App Store Connect app record (bundle id `dev.ponderance.homelabglance`, team `G2KBQH7KWT`).
2. Host the privacy policy and set its URL.
3. Archive + upload from Xcode 26 (Product → Archive → Distribute), both iOS and macOS.
4. Verify the App Group / Keychain entitlements are on the distribution provisioning profiles.
5. Make the GHCR package public (or document `docker login ghcr.io`) after the first publish-workflow run, so the aggregator quickstart works for reviewers/users.
6. Complete the App Privacy questionnaire ("Data Not Collected").
