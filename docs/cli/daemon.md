---
sidebar_position: 2
title: Kizashi daemon
sidebar_label: Kizashi daemon
slug: /cli/daemon
---

# Kizashi daemon

`kizashid` is the background service daemon for the desktop shell.

## Options

- `-v, --verbose`: Enable verbose logging output.
- `-V, --version`: Print installed version and exit.
- `-h, --help`: Show usage help and exit.

## Commands

### `start`

- `kizashid start`: Start the desktop shell and background services (default command).

### `stop`

- `kizashid stop`: Stop the running daemon and all background shell processes (`focus_daemon.py`, `quickshell`).

### `status`

- `kizashid status`: Check whether the daemon is currently running (exit code 0 if running, 1 if stopped).

## Autostart

Compositor autostart examples:

- Hyprland (`config/autostart.lua`): `hl.exec_cmd("kizashid start")`
- Niri (`config/autostart.kdl`): `spawn-at-startup "kizashid" "start"`
- Sway (`configDir/autostart`): `exec kizashid start`
