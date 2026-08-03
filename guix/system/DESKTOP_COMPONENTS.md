# SociOS desktop — components, protocols, and default-config validation

**Principle — OWN THE SHELL (first-class absorption).** The screenshots are the
**design target, not a parts list.** SociOS does **not** implement its desktop by
bolting on third-party gnome-look extensions (ArcMenu, Vitals, dash-to-dock,
tognee, appindicator) or proprietary apps (WhatsApp, Telegram, Element) — that
ecosystem is a balkanized graveyard that breaks every GNOME release. The menu,
dock, monitors, drop-down terminal, search, **consent/receipts UX (E11)**, and
**messaging** are built as ONE **owned, version-locked, first-class SociOS shell**
(home: `sourceos-shell`), native and coherent. Messaging is our own capability on
the sovereign **mesh/Matrix substrate**, first-class in the shell — never a
WhatsApp/Telegram bolt-on.

The checklist below is what the **default** profile (`desktop.scm` +
`guix/home/socios-desktop.dconf`) must include. Status: ✅ in default · ⚙️ dconf ·
🔷 **build as a first-class owned SociOS shell component (`sourceos-shell`), not a
third-party extension** · ☐ TODO.

## Aesthetic / theme
- **Wallpaper set:** "ancient monument + sky" — Stonehenge/Avebury **standing
  stones** at sunset (pink/purple), dawn (frosty blue), and a **Matrix code-rain**
  variant (green digital rain over the stones at dusk). Signature look. 🔷 (ship a
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
| **Places** menu | Places Status Indicator extension | 🔷 |
| **ArcMenu** + **tognee** layout | Windows-start-style app menu (category tree + search + shortcut strip: Home/Downloads/Docs/keyring/Settings/terminal/logout/lock/power) | 🔷 (ArcMenu + tognee layout not in Guix) |
| **Extensions** dropdown | extension manager/list in the bar | 🔷 |
| **Public-IP** indicator | shows WAN IP (VPN egress watch) | 🔷 |
| **Workspace thumbnails** | window/workspace preview | 🔷 |
| **System monitor** | CPU %, mem/disk, **net speed KB/s** (Vitals / system-monitor / Net-Speed) | 🔷 |
| **Docker** indicator | container status in the bar | 🔷 |
| **Night light** | redshift/blue-light (moon icon) | ✅ (`redshift`/`gammastep`) + ⚙️ |
| WiFi / Volume / Mic / Battery / Clock / Power | standard quick settings | ✅ |
| App tray indicators | WhatsApp/@ etc. (AppIndicator) | 🔷 (appindicator ext) |

## Terminals
| Component | What it is | Status |
|---|---|---|
| **Tilix — Quake / drop-down drawer** | top-edge drop-down terminal (F12-style) | ✅ `tilix` + ⚙️ (quake keybind/geometry) |
| Xfce Terminal | XFCE-edition terminal | ✅ |
| TurtleTerm / sourceos-shell | the SourceOS agentic terminals | (estate) |

## Launcher / search
| Component | What it is | Status |
|---|---|---|
| **Web-search launcher** | popup with Google/YouTube/Amazon/Ebay/GitHub/Wolfram/DuckDuckGo → "start search in browser" | 🔷 (search provider) — **enhancement: route through `sherlock-search` + E1 consent** |

## Dock / taskbar (XFCE edition)
| Component | Status |
|---|---|
| **Docklike bottom panel** (Plank / xfce4-panel docklike) with app launchers | 🔷 / ✅ (plank in Guix) + ⚙️ |

## Applications (default set)
Browser **Firefox/IceCat** (+ a signed app/PWA plane, E5), **LibreOffice**,
**GIMP**, media, file manager, settings — free software, ✅ in Guix.
**Messaging is NOT WhatsApp/Telegram/Element** — it is a **first-class SociOS
messaging capability** on the sovereign mesh/Matrix substrate, native to the shell
(owned, integrated, stable). 🔷 (`sourceos-shell` + mesh).

## Protocols observed (what you're actually using)
| Protocol | Evidence | Sovereign enhancement |
|---|---|---|
| **Docker / OCI** | whale indicator; container workflow | route images through **zot** (E5) |
| **SSH** | Tilix/Xfce terminals, remote hosts (`hellbook`), IPs | consent-plane on remote exec (E1) |
| **VPN / WAN-IP watch** | public IP `103.101.171.161` shown top-bar | fold into the **mesh** (E3) egress posture |
| **LAN / mDNS (Avahi)** | `192.168.100.x`, `hellbook.local` | Continuity/AirDrop via mesh (E3) |
| **HTTP(S) web search** | the engine launcher → browser | via `sherlock-search`, purpose-gated (E1) |
| **Chrome Apps / PWA** | ArcMenu "Chrome Apps" category | signed app plane (E5) |
| **Messaging — OWN first-class capability** | native SociOS messaging in the shell | mesh/Matrix substrate, integrated + stable (E1/E3) — never WhatsApp/Telegram |
| **Redshift / DDC** | night-light | ✅ |

## Enhancement mapping (this desktop carries the program)
- The **terminals + shell + ArcMenu actions** are the primary **E1 consent-plane**
  surface and the home of the missing **E11 consent/receipts UX** (the Privacy pane).
- The **public-IP/VPN + LAN/mDNS** indicators are the seed of **E3 mesh federation**.
- The **web-search launcher** must route through `sherlock-search` under **E1**.
- **Docker** images flow through **zot** under **E5**; the whole profile is **E8**
  (reproducible Guix) — this file's ☐/🔷 rows are the Workstream-F packaging queue.

## Validation result (before this PR)
The default `desktop.scm` was **bare GNOME** (gdm + openssh). It included **none**
of the menu/tognee, Tilix-quake, the monitors, Docker, the dock, the web-search
launcher, the theme, or the wallpaper set → **FAIL**. This PR moves the ✅/⚙️ rows
into the default now, and enumerates the 🔷 rows as the **owned-shell build queue**
(`sourceos-shell`) — built as first-class, version-locked, coherent SociOS shell
components, **not** third-party gnome-look extensions — so the default converges on
the whole thing *and stays stable across GNOME releases*.
