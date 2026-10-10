# ShivTrix Core - Tech OS, Assisted Remote Control & Power Toys

OLED-black, pro-look in-browser Tech OS with hardware telemetry, network Power Toys, and an
AnyDesk-style **Remote Resolve** studio (screen share + real mouse/keyboard control + tools on the host).

## Quick start (Windows)
1. Install Python 3 (python.org). Unzip this folder.
2. Double-click **`companion.bat`**. It installs `psutil`, starts the companion on `http://127.0.0.1:9871` and opens the app.
3. For remote support over the internet host the folder on GitHub Pages (below) or just share the **room link / QR**.

> The companion listens on **127.0.0.1 only** (not your LAN). Set `SHIVTRIX_LAN=1` before starting it if you really want LAN access.

## Remote Resolve - how a support session works
| Role | What they do |
| --- | --- |
| **Host** (the PC to be fixed) | Opens the app via `companion.bat`, clicks **Capture & Share Screen** (choose **Entire Screen**), shares the room link/QR, picks an access level. |
| **Technician** (up to **10** at once) | Opens the link / scans the QR / enters the Room ID and clicks **Join**. |

Access levels (set by the host only; technicians cannot change them):
* **View Only** - watch the screen.
* **Laser Pointer** - point at things on the host screen.
* **Assisted Control** - mouse, touch, keyboard **and** diagnostic tools run on the host.

### Assisted Control (like AnyDesk)
* Selecting it makes Windows show a **native "Allow remote control?" dialog on the host PC**. Nothing is injected until the person at that PC clicks **Yes**. A web page cannot click it.
* Control auto-expires if the page stops sending its heartbeat, and the host can revoke it at any time (**View Only**, **Revoke Access**, or closing the page). All held keys/buttons are released.
* Only one technician controls at a time (others see "busy"); the host can remove any peer.
* Real input is injected by `companion.py` through Windows `SendInput` (no extra packages). Choose which **display** is controlled in the host panel.
* Windows apps running **as administrator** (or the lock screen / UAC) ignore normal input - start `companion.bat` as administrator if you need to control those. `Ctrl+Alt+Del` cannot be sent by any web app.

**Technician controls**
| Device | Action |
| --- | --- |
| Mouse / pen | move, click, drag, right-click, middle-click, wheel scroll |
| Keyboard | click the screen, then type; shortcuts like Ctrl+C work. The **Keys** menu sends Win, Alt+Tab, Alt+F4, Win+D, Task Manager, Ctrl+C/V/X/A/Z and arrows |
| Touch - **Direct touch** | tap = click, long-press = right-click, one-finger drag = drag, two-finger drag = scroll, two-finger tap = right-click |
| Touch - **Touchpad** | drag = move cursor, tap = click, two-finger tap = right-click, double-tap + drag = drag, two-finger drag = scroll |
| Phone keyboard | **Keyboard** button opens the on-screen keyboard; text (including non-English) and backspace are sent to the host |

### Tools run on the HOST system
In **Advanced Power Toys**, a technician in Assisted Control can switch **Run tools on -> Host system**. Ping, continuous ping,
traceroute, NSLookup, port check and network adapters then execute on the host PC (through the host's companion) and the live results stream back.
Only a fixed allow-list of tools and strictly validated arguments are accepted, and every request is written to the host's audit log.

### Limits
* Max **10** technicians per room; extra people are told the room is full.
* Needs a shared **Entire Screen** for accurate click positions (tab/window sharing cannot be mapped to the desktop).
* Quick Trigger buttons "Flush DNS" and "Defender Scan" only log an action; they do not execute anything yet.

## Deploy on GitHub Pages
Upload everything in this folder to the repository root, then **Settings -> Pages -> GitHub Actions**. Open
`https://<you>.github.io/<repo>/` (hard-refresh once). Browsers allow an https page to talk to `http://127.0.0.1:9871`,
so a host can use the Pages site together with a locally running `companion.bat` (required for control and tools).
The companion only accepts control requests from `localhost` and `*.github.io` origins.

## Files
`index.html + style.css + script.js` (modular app), `shivtrix_core.html` (single file, served by the companion),
`sw.js` (network-first service worker), `manifest.json`, `companion.py` / `companion.bat` (bridge, control engine, web server),
`helper.ps1` / `run_helper.bat` (PowerShell tools-only bridge: no remote control, no streaming tools), `.nojekyll`, `.github/workflows/deploy.yml`.

## Themes
**OLED Pro** (default, pure black), Cyber Neon, Matrix Emerald, Solar Flare, Deep Void, Light Clean - switch with the Theme button.
