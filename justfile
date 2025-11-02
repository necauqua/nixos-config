
@_default:
    just -ul

deploy flake="local":
    #!/usr/bin/env bash
    impure=""
    if [[ "{{flake}}" = "local" ]]; then
        impure=--impure
    fi
    ulimit -n 65535 # well this is a thing
    sudo nixos-rebuild switch --flake "{{flake}}" $impure
