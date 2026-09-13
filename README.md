# NixOS configuration

This is my NixOS configuration so that I can easily and quickly bootstrap
NixOS from a flake anytime I need.

It holds every machine I run:

| Machine           | What it is                                    |
| ----------------- | ----------------------------------------------|
| `main`            | desktop PC                                    |
| `flex`            | laptop, which I sometimes use                 |
| `home`            | the home server on the LAN - NAS, ZFS, docker |
| `offsite`         | the `necauq.ua` server                        |
| `micro1`/`micro2` | Always Free Oracle Cloud boxes                |
| `iso`             | an installer image                            |

Build and switch at `main` or `flex`:

```bash
sudo nixos-rebuild switch --flake .
```

Deploy a remote machine with [deploy-rs](https://github.com/serokell/deploy-rs):

```bash
deploy .#offsite
```
