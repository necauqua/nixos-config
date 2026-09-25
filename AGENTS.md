# AGENTS.md

## Overview

Personal NixOS flake config for multiple machines. All code is Nix.

## Machines

Each machine is `machines/<name>.nix` or a directory `machines/<name>/` with a `default.nix`, auto-discovered by `lib.nix`'s `load-modules` and turned into a `nixosConfigurations.<name>` output. A machine that needs modules of its own is a directory: `machines/<name>/default.nix` is the machine itself and every other file next to it is a module that only this machine can ever use, imported by relative path. A machine that needs none, such as `iso`, stays a single file.

- **main** — primary desktop PC (AMD, Nvidia, ZFS, secure boot via lanzaboote, niri compositor)
- **flex** — laptop
- **home** — headless home server on the LAN (NAS, ZFS, docker), deployed via `deploy-rs`
- **offsite** — the `necauq.ua` server: nginx, acme, postfix/rspamd, matrix, soju, murmur, ntfy, PDS, tangled knot, goatcounter, reposilite, and the restic repository (plus the frozen borg one it replaced)
- **micro** — the two Always Free Oracle Cloud boxes. It is one machine definition, and `flake.nix` makes the `micro1` and `micro2` configurations out of it, which differ by host name only
- **iso** — installer ISO

Only `home`, `offsite`, `micro1` and `micro2` are `deploy.nodes`; `main` and `flex` switch locally and `iso` is an image.

## Architecture

- **`modules/`** — shareable, machine-agnostic NixOS feature modules, imported selectively per machine via the `features` specialArg (e.g. `with features; [ nvidia niri samba ]`). A subdirectory with a `default.nix` is a feature too; a subdirectory without one is plain data and is skipped. Code that hardcodes one machine's identity — its domain, hardware, disks or wireguard peers — belongs in that machine's directory instead.
- **`modules/configuration.nix`** — shared base for desktop machines (main, flex). It is itself a feature that imports other features. The servers (`home`, `offsite`, the micros) do **not** use it.
- **`modules/secrets.nix`** — defines the `secrets` option and is imported globally from `flake.nix`, so it needs no `features` entry. `secrets.<name> = { }` maps to `secrets/<name>.age`, with optional `mode`/`owner`/`group`/`path`/`enable`, and expands to `age.secrets.<name>`.
- **`modules/ports.nix`** — same deal, imported globally. `ports.<name> = { }` claims a local port and `config.ports.<name>` is the number: the claims of a machine are sorted and numbered from 9000 up, so a new claim shifts the ones after it. Only for a port behind traefik or nginx; a port that a firewall rule, a peer or a client names stays a literal number.
- **`home/profiles/`** — home-manager profile modules, composed via `home/roles.nix`. The `main` role imports all profiles; `headless` adds `{ headless = true; }`.
- **`home-manager`** is integrated as a NixOS module (not standalone), wired in `modules/home-manager.nix`.
- **`secrets/`** — agenix-encrypted `.age` files. Recipients are defined in `secrets/secrets.nix`. Edit secrets with the `agenix` CLI (available in devShell).

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

# Deploy a remote machine (the devShell `deploy` skips deploy-rs's
# `nix flake check` of all machines; run that yourself when needed)
deploy .#home
deploy .#offsite

# Update flake inputs
nix flake update

# Pin nixpkgs-future to latest nixpkgs master
nix flake lock --override-input nixpkgs-future github:NixOS/nixpkgs/master
```

Secrets, from inside `secrets/`, with `~/.ssh/secrets_ed25519` as the identity (fish syntax, which is the shell here):

```fish
# Re-encrypt one secret after its recipient list changed, with a single
# passphrase prompt (EDITOR=: skips the editor and the no-change guard)
env EDITOR=: agenix -e <name>.age -i ~/.ssh/secrets_ed25519

# Re-encrypt everything. `age` cannot use ssh-agent, so an encrypted key
# prompts once per secret — strip the passphrase from a tmpfs copy first
set -l k $XDG_RUNTIME_DIR/agenix-key
install -m600 ~/.ssh/secrets_ed25519 $k
ssh-keygen -p -N '' -f $k
agenix -r -i $k
rm -f $k $k.pub
```

## Verification

After any cohesive/related set of changes to Nix files, verify the build and report the result:

```bash
nix build --no-link '.#nixosConfigurations.main.config.system.build.toplevel'
```

Build every machine that a change can reach, not just `main`. `nix flake check` also evaluates all of them plus the deploy schema.

## Conventions

- `nixpkgs-future` exists as a separate input so it can be updated independently or pinned to nixpkgs master for bleeding-edge packages.
- Adding a new `.nix` file to `modules/` or `home/profiles/` auto-registers it — no import list to update at the directory level. A file added to a machine directory `machines/<name>/` is *not* auto-imported; the machine has to list it.
- Machine files are self-contained: they declare hardware, filesystem layout, and which features to import. Configuration that only one machine can ever use belongs in its directory, either inline in `default.nix` when it is small or as a sibling module.
- Features are named by role, so the two ends of one system can coexist: `restic` is the backup job and `restic-server` holds the repository, `vpn` is the wireguard client peer and `vpn-server` is the listener.
- `deploy-rs`'s `fastConnection` means the link *from this machine to the node* is fast, so pushing the whole closure beats letting the node substitute. It is on for LAN nodes only; remote nodes get `--substitute-on-destination` and fetch the cacheable bulk themselves.
- A secret must be listed in `secrets/secrets.nix` for every machine that reads it, otherwise activation fails there. Machine host keys live at the top of that file.
