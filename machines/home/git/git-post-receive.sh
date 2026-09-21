
# post-receive hook of every repository under the git root. It pushes the whole
# repository to each configured mirror, and a mirror that is out of reach only
# warns, it never fails the push that triggered it.

# the ref list is not needed, but it has to be read
cat > /dev/null

# a fresh repository points HEAD at a branch that the push may not carry, which
# leaves the mirrors with nothing to show
if ! git rev-parse --verify --quiet HEAD > /dev/null; then
  for candidate in refs/heads/main refs/heads/master \
    "$(git for-each-ref --count=1 --format='%(refname)' refs/heads/)"; do
    if [ -n "$candidate" ] && git rev-parse --verify --quiet "$candidate" > /dev/null; then
      git symbolic-ref HEAD "$candidate"
      printf 'HEAD now points at %s\n' "${candidate#refs/heads/}" >&2
      break
    fi
  done
fi

urls=$(git config --get-all mirror.url || true)

printf '%s\n' "$urls" | while read -r url; do
  [ -n "$url" ] || continue
  printf 'mirroring to %s\n' "$url" >&2
  git push --mirror --quiet "$url" >&2 \
    || printf 'warning: the push to %s failed\n' "$url" >&2
done

# radicle is not a git url, so it is not one of the mirrors above. The
# repository carries its rid, and rad-mirror does the radicle half as the
# radicle user, see git.nix
repo=$(git rev-parse --absolute-git-dir)
rid=$(git config --get rad.id || true)

# a repository that the gateway created is put on radicle here and not there,
# because only now does it hold a branch to publish
if [ -z "$rid" ] && [ "$(git config --get rad.auto || true)" = true ]; then
  name=$(basename "$repo")
  description=$(head -n1 "$repo/description" 2> /dev/null || true)
  if rid=$("$SUDO" -u radicle "$RAD_MIRROR" init "$repo" "$name" "${description:-$name}"); then
    git config rad.id "$rid"
    git config --unset-all rad.auto || true
    # the web gateway reads the alias of every repository at start only
    "$SUDO" "$SYSTEMCTL" try-restart radicle-httpd.service \
      || printf 'warning: radicle-httpd did not restart\n' >&2
    printf 'radicle repository %s created\n' "$rid" >&2
  else
    rid=
    printf 'warning: the radicle repository could not be created\n' >&2
  fi
fi

if [ -n "$rid" ]; then
  printf 'mirroring to %s\n' "$rid" >&2
  "$SUDO" -u radicle "$RAD_MIRROR" push "$repo" "$rid" >&2 \
    || printf 'warning: the push to %s failed\n' "$rid" >&2
fi

exit 0
