# Omarchy Dev Services

Docker containers and local dev servers in the [Omarchy](https://omarchy.org) bar, built as an Omarchy shell (Quickshell) plugin. You can see what's running, open a port in the browser, follow logs, and stop things without opening a terminal.

## Bar widget

A docker icon with the number of running containers plus listening dev servers. When nothing is running, the icon is dimmed and has no number.

| Mouse | Action |
|---|---|
| Left click | Open the popup |
| Right click | Refresh now |
| Middle click | Stop all running containers |

## Popup

**Docker**

- Each container has a status dot, its name, its compose project, image and status, and its published host ports
- Click a port chip (`:8080`) to open `http://localhost:8080`
- Buttons: **Follow logs** and **Shell** (each opens in a terminal), **Restart**, **Start / Stop**
- In the header: **Stop all running containers** and **Stop the Docker daemon**
- When Docker isn't usable, the popup says why and offers the fix:
  - *daemon stopped*: **Start Docker** (`systemctl start docker`, through polkit)
  - *permission denied*: **Copy fix command** (`sudo usermod -aG docker $USER`; log out and back in after running it)
  - *not installed*: points to `omarchy install docker`

**Dev servers**

The popup lists every TCP port your own user is listening on, with one row per process. A Vite server on 5173 and its HMR socket appear as one row. Each row shows:

- the project, which is the name of the process's working directory
- the process name, PID and path, plus *all interfaces* if it listens beyond localhost
- port chips that open in the browser
- **Open a terminal** in the project folder
- **Stop**, which sends SIGTERM. If the process is still listening, the button turns red and the next click sends SIGKILL

System daemons such as cups and systemd-resolved don't appear: without root, `ss` only reports the owner of your own sockets.

## Keys

| Key | Action |
|---|---|
| SUPER+ALT+D | Toggle the popup |

## Command line

The plugin registers a `bsadik.devservices` IPC target:

```bash
omarchy-shell bsadik.devservices status    # JSON: docker state, containers, servers
omarchy-shell bsadik.devservices refresh
omarchy-shell bsadik.devservices stopAll   # stop every running container
omarchy-shell bsadik.devservices panel     # toggle the popup
```

## Install

```bash
cd ~/Work/omarchy-devservices-plugin
./install.sh
```

`install.sh` is safe to re-run. It:

1. copies `bsadik.devservices/` to `~/.config/omarchy/plugins/bsadik.devservices/`
2. adds the widget to the bar's right section, just before the system tray
3. adds a marked SUPER+ALT+D block to `~/.config/hypr/bindings.lua` and reloads Hyprland
4. restarts the Omarchy shell, which caches plugin code that is already loaded

After editing anything in this repo, run `./install.sh` again to apply it. Omarchy rejects symlinked plugin folders, so the plugin is copied rather than linked.

To move the widget: `omarchy bar move bsadik.devservices --section center`. To remove it: `./install.sh --uninstall`.

## How it works

The **service** runs `collect.sh` every 20 seconds, or every 3 seconds while a popup is open. The script prints one JSON object: Docker's state and `docker ps -a`, plus `ss -ltnp` enriched with each process's name, command line and working directory from `/proc`. It takes about 70 ms. Bar widgets (one per monitor) read from the service, so the polling only happens once.

| File | Purpose |
|---|---|
| `bsadik.devservices/manifest.json` | Plugin manifest (service and bar widget) |
| `bsadik.devservices/collect.sh` | Collects Docker and listening-port data as JSON |
| `bsadik.devservices/Service.qml` | Polling, container and process actions, IPC |
| `bsadik.devservices/BarWidget.qml` | Bar icon and count, popup host |
| `bsadik.devservices/DevPanel.qml` | Popup contents |
| `bsadik.devservices/PortChip.qml` | Clickable `:port` pill |
| `bsadik.devservices/Dev.js` | Icons, parsing, grouping and sorting helpers |

## Requirements

- Omarchy with the Quickshell-based `omarchy-shell` and Lua Hyprland config
- `JetBrainsMono Nerd Font` (Omarchy default) for the icons
- `ss` (iproute2), `jq`; `docker` for the Docker section
- `rsync` (for `install.sh`)
