---
sidebar_position: 1
title: Hyprland
sidebar_label: Hyprland
slug: /configure/compositors/hyprland
---

# Hyprland

Configuration is stored in `~/.config/hypr`. The main file is `hyprland.lua`, which loads modules from the `config/` directory:

- `variables.lua` - modifier keys and default applications
- `env.lua` - environment variables
- `autostart.lua` - startup processes
- `monitors.lua` - display and resolution setup
- `settings.lua` - window decorations, blur, animations, and input
- `keybinds.lua` - keybindings for compositor actions and shell controls

## Autostart

The shell daemon, clipboard history, and audio effects are launched from `config/autostart.lua`:

```lua
hl.on("hyprland.start", function()
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  hl.exec_cmd("systemctl --user enable --now easyeffects")
  hl.exec_cmd("kizashid start")
end)
```

## Keybindings

Shell overlays and controls are bound in `config/keybinds.lua` using `kizashi msg toggle <module>`:

- `launcher` - application launcher
- `system` - system control panel
- `clipboard` - clipboard history
- `music` - media player
- `wallpaper` - wallpaper selector
- `calendar` - calendar popout
- `network` - wi-fi and network connections
- `volume` - audio output and input slider
- `guide` - cheat sheet for keybindings
- `autohide` - toggle status bar autohide

Workspace switching is routed through the shell to update bar indicators:

```lua
for i = 1, 10 do
  hl.bind("SUPER + " .. (i % 10), hl.dsp.exec_cmd("kizashi msg workspace " .. i))
  hl.bind("SUPER + SHIFT + " .. (i % 10), hl.dsp.exec_cmd("kizashi msg workspace " .. i .. " move"))
end
```

Quick utility actions:
- Lock screen: `kizashi lock`
- Reload shell: `kizashi reload`
- Screenshots: `kizashi screenshot` (add `--edit`, `--full`, or `--full --edit`)
- Brightness: `kizashi brightness lower` and `kizashi brightness raise`
- Volume: `kizashi volume lower`, `kizashi volume raise`, and `kizashi volume mute-toggle`
