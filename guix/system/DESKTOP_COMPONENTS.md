# SociOS desktop — components, protocols, and default-config validation

The reference look/feel (from the running SociOS laptop) and the checklist that
the **default** Guix desktop profile (`desktop.scm` + `guix/home/socios-desktop.scm`)
must include the *whole thing* — not a bare GNOME. Status: ✅ in default ·
⚙️ needs dconf/home config · 🟠 needs Guix packaging (Workstream F) · ☐ TODO.

## Aesthetic / theme
- **Wallpaper set:** "ancient monument + sky" — Stonehenge/Avebury **standing
  stones** at sunset (pink/purple), dawn (frosty blue), and a **Matrix code-rain**
  variant (green digital rain over the stones at dusk). Signature look. 🟠 (ship a
  `socios-wallpapers` package) + ⚙️ (set as default).
- **Shell:** dark top panel; light/Adwaita app windows; **window buttons on the
  LEFT** (`✕ – □`); custom cursor; ArcMenu "Override Menu Theme" + **Custom color
  theme**. ⚙️ (dconf).
- **Two editions seen:** GNOME (primary, SociOS-branded) and an **XFCE** variant
  with a docklike bottom panel + Matrix wallpaper.

## Shell / panel components (GNOME primary)
| Component | What it is | Status |
|---|---|---|
| SociOS branding + app menu | branded activities/app button | ⚙️ |
| **Places** menu | Places Status Indicator extension | 🟠 |
| **ArcMenu** + **tognee** layout | Windows-start-style app menu (category tree + search + shortcut strip: Home/Downloads/Docs/keyring/Settings/terminal/logout/lock/power) | 🟠 (ArcMenu + tognee layout not in Guix) |
| **Extensions** dropdown | extension manager/list in the bar | 🟠 |
| **Public-IP** indicator | shows WAN IP (VPN egress watch) | 🟠 |
| **Workspace thumbnails** | window/workspace preview | 🟠 |
| **System monitor** | CPU %, mem/disk, **net speed KB/s** (Vitals / system-monitor / Net-Speed) | 🟠 |
| **Docker** indicator | container status in the bar | 🟠 |
| **Night light** | redshift/blue-light (moon icon) | ✅ (`redshift`/`gammastep`) + ⚙️ |
| WiFi / Volume / Mic / Battery / Clock / Power | standard quick settings | ✅ |
| App tray indicators | WhatsApp/@ etc. (AppIndicator) | 🟠 (appindicator ext) |

## Terminals
| Component | What it is | Status |
|---|---|---|
| **Tilix — Quake / drop-down drawer** | top-edge drop-down terminal (F12-style) | ✅ `tilix` + ⚙️ (quake keybind/geometry) |
| Xfce Terminal | XFCE-edition terminal | ✅ |
| TurtleTerm / sourceos-shell | the SourceOS agentic terminals | (estate) |

## Launcher / search
| Component | What it is | Status |
|---|---|---|
| **Web-search launcher** | popup with Google/YouTube/Amazon/Ebay/GitHub/Wolfram/DuckDuckGo → "start search in browser" | 🟠 (search provider) — **enhancement: route through `sherlock-search` + E1 consent** |

## Dock / taskbar (XFCE edition)
| Component | Status |
|---|---|
| **Docklike bottom panel** (Plank / xfce4-panel docklike) with app launchers | 🟠 / ✅ (plank in Guix) + ⚙️ |

## Applications seen (default set)
Browsers **Chromium + Firefox/IceCat** (+ **Chrome Apps**/PWAs), **LibreOffice**,
**GIMP**, media, **WhatsApp + Telegram** (proprietary — *enhancement target:
**Matrix**/Element for sovereign messaging*), file manager, settings. Mostly ✅ in
Guix (chromium 🟡 via nonguix for codecs).

## Protocols observed (what you're actually using)
| Protocol | Evidence | Sovereign enhancement |
|---|---|---|
| **Docker / OCI** | whale indicator; container workflow | route images through **zot** (E5) |
| **SSH** | Tilix/Xfce terminals, remote hosts (`hellbook`), IPs | consent-plane on remote exec (E1) |
| **VPN / WAN-IP watch** | public IP `103.101.171.161` shown top-bar | fold into the **mesh** (E3) egress posture |
| **LAN / mDNS (Avahi)** | `192.168.100.x`, `hellbook.local` | Continuity/AirDrop via mesh (E3) |
| **HTTP(S) web search** | the engine launcher → browser | via `sherlock-search`, purpose-gated (E1) |
| **Chrome Apps / PWA** | ArcMenu "Chrome Apps" category | signed app plane (E5) |
| **Messaging (WhatsApp/Telegram)** | dock + tray | **Matrix** (E1/E3) sovereign replacement |
| **Redshift / DDC** | night-light | ✅ |

## Enhancement mapping (this desktop carries the program)
- The **terminals + shell + ArcMenu actions** are the primary **E1 consent-plane**
  surface and the home of the missing **E11 consent/receipts UX** (the Privacy pane).
- The **public-IP/VPN + LAN/mDNS** indicators are the seed of **E3 mesh federation**.
- The **web-search launcher** must route through `sherlock-search` under **E1**.
- **Docker** images flow through **zot** under **E5**; the whole profile is **E8**
  (reproducible Guix) — this file's ☐/🟠 rows are the Workstream-F packaging queue.

## Validation result (before this PR)
The default `desktop.scm` was **bare GNOME** (gdm + openssh). It included **none**
of ArcMenu/tognee, Tilix-quake, the monitors, Docker, the dock, the web-search
launcher, the theme, or the wallpaper set → **FAIL**. This PR moves the ✅/⚙️ rows
into the default and enumerates the 🟠 rows as the packaging queue so the default
converges on the whole thing.
