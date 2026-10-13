---
sidebar_position: 2
title: NixOS
sidebar_label: NixOS
slug: /installation/nixos
---

# NixOS

Kizashi provides flake outputs, a NixOS module for system dependencies, and a Home Manager module for user configuration and service management.

## 1. Add flake input

Add Kizashi to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    kizashi.url = "github:ilyamiro/serpantinum";
  };

  outputs = { self, nixpkgs, kizashi, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit kizashi; };
      modules = [
        ./configuration.nix
        kizashi.nixosModules.default
      ];
    };
  };
}
```

## 2. configuration.nix

Enable the NixOS module to configure system prerequisites:

```nix
{
  programs.kizashi.enable = true;
}
```

If you prefer installing the package directly without the system module:

```nix
{ pkgs, kizashi, ... }:

{
  environment.systemPackages = [
    kizashi.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
```

## 3. Home Manager configuration

```nix
{ kizashi, ... }:

{
  imports = [
    kizashi.homeManagerModules.default
  ];

  programs.kizashi = {
    enable = true;
    systemd.enable = true;

    settings = {
      wallpaperDir = "/home/username/Pictures/Wallpapers";

      general = {
        language = "en";
        weatherUnit = "metric";
        weatherInterval = 30;
      };

      bar = {
        position = "top";
        style = "solid";
        width = 40;
        workspaceCount = 10;
        modules = {
          left = [ "workspaces" ];
          center = [ "time" ];
          right = [ "tray" [ "kb" "wifi" "bt" "vol" "bat" ] ];
        };
      };

      theme = {
        fontFamily = "Adwaita Mono";
        borderRadius = 12;
        matugen = true;
      };

      notifications = {
        dnd = false;
        position = "top right";
        sound = true;
      };
    };
  };
}
```

## 4. Updating

Update the flake lockfile and rebuild your system:

```bash
nix flake update kizashi
sudo nixos-rebuild switch --flake .
```
