#!/usr/bin/env bash
# Re-encrypt every secret for the recipients in secrets.nix.
#
# age cannot use ssh-agent, so with an encrypted identity agenix asks for the
# passphrase once per secret. This script removes the passphrase from a copy of
# the identity on tmpfs, so that you type it once, and deletes the copy at the end.
#
# Usage: ./rekey.sh [identity]   (default: ~/.ssh/secrets_ed25519)
set -euo pipefail

identity=${1:-$HOME/.ssh/secrets_ed25519}

cd "$(dirname "$0")"

key=$(mktemp -p "${XDG_RUNTIME_DIR:?must be a tmpfs}" agenix-key.XXXXXX)
trap 'rm -f "$key" "$key.pub"' EXIT

install -m600 "$identity" "$key"
ssh-keygen -q -p -N '' -f "$key"
agenix -r -i "$key"
