# AGENTS.md

## Overview

Personal NixOS flake config for multiple machines. All code is Nix.

## Machines

Defined in `machines/` — each file is auto-discovered by `lib.nix`'s `load-modules` and becomes a `nixosConfigurations.<name>` output.

- **main** — primary desktop PC (AMD, Nvidia, ZFS, secure boot via lanzaboote, niri compositor)
- **flex** — laptop
- **home** — headless home server (deployed remotely via `deploy-rs`)
- **iso** — installer ISO

## Architecture

- **`modules/`** — NixOS feature modules, imported selectively per machine via `features` specialArg (e.g. `with features; [ nvidia niri borg ]`).
- **`modules/configuration.nix`** — shared base for desktop machines (main, flex). It is itself a feature that imports other features. The home server (`home.nix`) does **not** use it.
- **`home/profiles/`** — home-manager profile modules, composed via `home/roles.nix`. The `main` role imports all profiles; `headless` adds `{ headless = true; }`.
- **`home-manager`** is integrated as a NixOS module (not standalone), wired in `modules/home-manager.nix`.
- **`secrets/`** — agenix-encrypted secrets. Keys defined in `secrets/secrets.nix`. Edit secrets with the `agenix` CLI (available in devShell).

## Key specialArgs passed to machine modules

- `features` — attrset of all `modules/*.nix` paths
- `hm-profiles` — attrset of all `home/profiles/*` paths
- `pkgs-stable`, `pkgs-future` — pinned package sets from separate nixpkgs inputs
- `flake-inputs` — all flake inputs

## Commands

The repo uses `direnv` + `use flake` for the dev shell, which provides `agenix` and `deploy-rs`.

```bash
# Build and switch the current machine (requires sudo, runs locally)
sudo nixos-rebuild switch --flake .

# Deploy to the home server
deploy .#home

# Update flake inputs
nix flake update

# Pin nixpkgs-future to latest nixpkgs master
nix flake lock --override-input nixpkgs-future github:NixOS/nixpkgs/master
```

## Verification

After any cohesive/related set of changes to Nix files, verify the build and report the result:

```bash
nix build --no-link '.#nixosConfigurations.main.config.system.build.toplevel'
```

## Conventions

- `nixpkgs-future` exists as a separate input so it can be updated independently or pinned to nixpkgs master for bleeding-edge packages.
- Adding a new `.nix` file to `modules/` or `home/profiles/` auto-registers it — no import list to update at the directory level.
- Machine files are self-contained: they declare hardware, filesystem layout, and which features to import.
