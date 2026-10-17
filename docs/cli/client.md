---
sidebar_position: 1
title: Kizashi client
sidebar_label: Kizashi client
slug: /cli/client
---

# Kizashi client

`kizashi` is the command-line client for the desktop shell.

## Options

- `-v, --verbose`: Enable verbose logging output.
- `-V, --version`: Print installed version and exit.
- `-h, --help`: Show usage help and exit.

## Commands

### `msg`

Dispatches layout, workspace, and overlay actions to the shell:

- `kizashi msg workspace <number>`: Switch to workspace `<number>`.
- `kizashi msg workspace <number> move`: Move active window to workspace `<number>`.
- `kizashi msg <number>`: Shorthand to switch to workspace `<number>`.
- `kizashi msg <number> move`: Shorthand to move active window to workspace `<number>`.
- `kizashi msg open <target> [subtarget]`: Open a panel or activate a subtab.
- `kizashi msg toggle <target> [subtarget]`: Toggle panel visibility.
- `kizashi msg close`: Close any open overlay.

#### Targets

- `launcher`: Application search and launcher overlay.
- `clipboard` (alias: `clip`): Clipboard history manager.
- `network`: Network manager popup.
  - `network wifi`: Open directly on WiFi tab.
  - `network ethernet`: Open directly on Ethernet tab.
- `volume`: Audio mixer and device picker.
- `guide`: Settings and documentation hub.
  - `guide keybinds`: Open shortcut cheat sheet tab.
  - `guide appearance`: Open appearance and styling tab.
- `calendar`: Calendar, clock, and schedule panel.
- `music`: Media player controls and track artwork.
- `wallpaper`: Wallpaper picker and live preview.
- `notifications`: Notification history center.
- `system`: System resource monitor and power controls.
- `autohide`: Toggle bar autohide setting live.
- `airplane` (alias: `flight`): Toggle airplane mode (WiFi and Bluetooth).
- `clearNotifications` (aliases: `clear_notifications`, `clearNotifs`): Clear all notifications.

### `launch`

Runs standalone interface components in runner mode:

- `kizashi launch start [args...]`: Launch first-time setup and onboarding wizard.
- `kizashi launch widgetredactor [args...]`: Launch desktop widget editor.

### `ipc`

Sends raw IPC calls directly to the running shell:

- `kizashi ipc call <target> <method> [args...]`: Forward call to target object.
  - `ipc call main handleCommand <cmd> <target> <arg>`: Dispatch generic UI command.
  - `ipc call main forceReload`: Force reload shell components.
  - `ipc call main clearNotifications`: Purge all notification popups and history.
  - `ipc call lock activate`: Trigger lock screen immediately.
  - `ipc call screenshotOverlay toggle [args...]`: Toggle interactive screenshot overlay.

### `kill`

Stops the daemon and terminates all background shell workers (`focus_daemon.py`, `quickshell`, `kizashid`).

## Script shortcuts

### `screenshot`

Captures screen images, records video, or decodes QR codes:

- `kizashi screenshot`: Open interactive selection and recording overlay.
- `kizashi screenshot --full`: Capture focused monitor immediately.
- `kizashi screenshot --edit`: Open screenshot in Satty image editor.
- `kizashi screenshot --record`: Toggle screen video recording (start or stop).
- `kizashi screenshot --scan-qr`: Scan selected region for QR codes.
- `kizashi screenshot --geometry <X,Y WxH>`: Set capture crop region.
- `kizashi screenshot --monitor <name>`: Set target monitor output.
- `kizashi screenshot --backend <gpu-screen-recorder|wf-recorder>`: Set recording backend.
- `kizashi screenshot --desk-vol <0.0-1.0>`: Set desktop audio volume multiplier.
- `kizashi screenshot --desk-mute <true|false>`: Mute desktop audio in recording.
- `kizashi screenshot --mic-vol <0.0-1.0>`: Set microphone audio volume multiplier.
- `kizashi screenshot --mic-mute <true|false>`: Mute microphone audio in recording.
- `kizashi screenshot --mic-dev <name>`: Set microphone input device name.

### `volume`

Controls audio sink and source levels via WirePlumber:

- `kizashi volume raise`: Increase output volume by 5%.
- `kizashi volume lower`: Decrease output volume by 5%.
- `kizashi volume mute-toggle`: Toggle output mute.
- `kizashi volume mic-toggle`: Toggle microphone mute.
- `kizashi volume mic-raise`: Increase microphone volume by 5%.
- `kizashi volume mic-lower`: Decrease microphone volume by 5%.

### `brightness`

Controls display backlight and external monitor brightness:

- `kizashi brightness get`: Print current brightness percentage (default).
- `kizashi brightness set <0-100>`: Set brightness to percentage.
- `kizashi brightness raise`: Increase brightness by 5%.
- `kizashi brightness lower`: Decrease brightness by 5%.
- `kizashi brightness backend`: Print active backend (`backlight`, `ddc`, or `none`).
- `kizashi brightness watch`: Watch backlight changes with inotify.

### `weather`

Queries weather data and manages forecast cache:

- `kizashi weather --current-temp`: Print current temperature.
- `kizashi weather --current-icon`: Print current weather icon glyph.
- `kizashi weather --current-hex`: Print current weather condition accent hex.
- `kizashi weather --temp`: Print today forecasted maximum temperature.
- `kizashi weather --icon`: Print today forecast icon glyph.
- `kizashi weather --hex`: Print today forecast accent hex.
- `kizashi weather --json`: Print complete structured forecast JSON.
- `kizashi weather --getdata`: Force fresh fetch from Open-Meteo API.
- `kizashi weather --nav next`: Advance 5-day forecast view to next day.
- `kizashi weather --nav prev`: Move 5-day forecast view to previous day.
- `kizashi weather --view-listener`: Stream active forecast view index.
- `kizashi weather --unit <metric|imperial|standard>`: Set temperature unit profile.
- `kizashi weather --location '<json>'`: Pass custom coordinates JSON.
- `kizashi weather --verbose` (`-v`): Print verbose debug output.

### `location`

Retrieves and updates geographic coordinates:

- `kizashi location`: Print cached or retrieved location JSON.
- `kizashi location --refresh` (`-r`): Force fresh lookup from IP geolocation providers.
- `kizashi location --verbose` (`-v`): Print debug diagnostics to stderr.

### `location_manual`

Sets geographic coordinates manually:

- `kizashi location_manual <latitude> <longitude>`: Set coordinates, reverse-geocode city and country, resolve timezone, and save to settings.

### `blue_light_filter`

Controls color temperature and day/night schedule via DBus:

- `kizashi blue_light_filter set <temperature> [output] [mode] [latitude] [longitude]`: Set temperature (1000-10000K) manually (`mode=manual`) or automatically with solar schedule (`mode=auto`).
- `kizashi blue_light_filter reset [output]`: Reset color temperature to 6500K daylight neutral and stop auto loop.
- `kizashi blue_light_filter status [output]`: Print status (`running` or `stopped`).
- `kizashi blue_light_filter --verbose` (`-v`): Print verbose output with current Kelvin and brightness levels.

### `monitors_detect`

Queries active display outputs:

- `kizashi monitors_detect`: List connected display names line-by-line.
- `kizashi monitors_detect --verbose`: Output display specifications (`<name>|<resolution>|<refresh_rate>`).

### `current_focus`

Runs active window focus tracking daemon:

- `kizashi current_focus`: Monitor and log window focus changes across compositors to JSONL.

### `lock`

Activates lock screen:

- `kizashi lock`: Trigger lock screen interface immediately.

### `reload`

Reloads shell:

- `kizashi reload`: Force reload QuickShell desktop elements without restarting the daemon.

### `exit`

Terminates desktop session:

- `kizashi exit`: Cleanly terminate graphical session and exit active compositor.
