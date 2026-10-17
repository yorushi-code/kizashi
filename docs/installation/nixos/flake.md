---
sidebar_position: 1
title: Flake input
sidebar_label: Flake input
slug: /installation/nixos
---

# NixOS: Flake input

Kizashi provides flake outputs, a NixOS module for system dependencies, and a Home Manager module for user configuration and service management. This page covers the flake and the system module; see [Home Manager](/installation/nixos/home-manager) for the user configuration.

## Add the flake input

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

## Enable the system module

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

## Updating

Update the flake lockfile and rebuild your system:

```bash
nix flake update kizashi
sudo nixos-rebuild switch --flake .
```
