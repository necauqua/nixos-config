
# The radicle half of the git mirror. radicle-node runs confined under its own
# user, so the git user reaches its storage and its key through sudo and this
# script. Every command here only reads the bare repository it is given, which
# leaves /storage/git to the git user alone.

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

tmp=$(mktemp -d)
# shellcheck disable=SC2064 # the path is fixed now, not at trap time
trap "rm -rf '$tmp'" EXIT

# the node id, which is the namespace this machine writes its refs under
nid() {
  rad self --nid 2>/dev/null
}

description() {
  rad inspect "$1" --payload \
    | jq -r '."xyz.radicle.project".description // empty'
}

# Declares a repository of the git user safe to open as the radicle user.
#
# radicle reads git through libgit2, which refuses a repository that another
# user owns, and every bare repository belongs to the git user. git itself only
# checks a path it had to discover, never one it is given, so the radicle half
# is the only half that needs this.
#
# libgit2 compares safe.directory literally, so neither the git root nor a
# pattern below it counts, and the alternative is the blanket `*`. The entry
# names the one repository the command was told to mirror instead.
trust() {
  printf '[safe]\n\tdirectory = %s\n' "$1" > "$tmp/gitconfig"
  export GIT_CONFIG_GLOBAL="$tmp/gitconfig"
}

case ${1:-} in
  nid)
    nid
    ;;

  # Creates the radicle repository and prints its rid. `rad init` writes a rad
  # remote and a remote tracking branch into the repository it is given, and
  # `git push --mirror` would then carry those to github and to the knot, so
  # it is given a throwaway clone instead. The clone shares the objects of the
  # original rather than copying them.
  init)
    [ $# -eq 4 ] || die "usage: rad-mirror init <repo> <name> <description>"
    trust "$2"

    git clone --bare --shared --quiet "$2" "$tmp/repo"
    rad init --name "$3" --description "$4" --no-confirm --public "$tmp/repo" \
      > "$tmp/log" 2>&1 || { cat "$tmp/log" >&2; die "rad init failed"; }

    rid=$(grep -oE 'rad:z[a-zA-Z0-9]+' "$tmp/log" | head -n1)
    [ -n "$rid" ] || { cat "$tmp/log" >&2; die "rad init printed no rid"; }
    printf '%s\n' "$rid"
    ;;

  # The description that the identity of a repository carries. Two arguments
  # read it, for a bare repository that is created around a rid and has none of
  # its own, and three write it. The identity is what the seed and every web
  # client show, so a write is a signed revision of it, and the node tells the
  # network about it.
  #
  # A revision needs an accept from the majority of the delegates, which is not
  # the `threshold` of the document: that one governs the canonical branch. A
  # repository with a second delegate therefore holds the revision until that
  # delegate accepts it, and the revision is printed for whoever asked.
  describe)
    case $# in
      2)
        description "$2"
        ;;

      3)
        if [ "$(description "$2")" = "$3" ]; then
          exit 0
        fi
        rad id update --repo "$2" \
          --title 'Update the description' \
          --description 'The description of the git server changed' \
          --payload xyz.radicle.project description "$(jq -n --arg d "$3" '$d')" \
          --no-confirm > "$tmp/log" 2>&1 \
          || { cat "$tmp/log" >&2; die "rad id update failed"; }
        rad sync --announce "$2" > /dev/null \
          || printf 'warning: %s could not be announced\n' "$2" >&2
        if [ "$(description "$2")" != "$3" ]; then
          sed -n 's/.*Revision \([0-9a-f]\{40\}\).*/\1/p' "$tmp/log" | head -n1
        fi
        ;;

      *)
        die "usage: rad-mirror describe <rid> [text]"
        ;;
    esac
    ;;

  # Seeds a repository that already exists on the network, so that the push
  # below has something to push into. The fetch only warns, because the node
  # may not have found a seed that carries it yet.
  link)
    [ $# -eq 2 ] || die "usage: rad-mirror link <rid>"
    rad seed "$2" --scope all
    rad sync --fetch "$2" \
      || printf 'warning: %s could not be fetched yet\n' "$2" >&2
    ;;

  unlink)
    [ $# -eq 2 ] || die "usage: rad-mirror unlink <rid>"
    rad unseed "$2"
    ;;

  # The mirror itself. Only branches and tags travel: refs/rad belongs to
  # radicle, and the url is spelled out because the bare repository holds no
  # rad remote, which is what keeps this side read only. A running node picks
  # the push up and announces it.
  push)
    [ $# -eq 3 ] || die "usage: rad-mirror push <repo> <rid>"
    trust "$2"

    git --git-dir="$2" push --force --prune "rad://${3#rad:}/$(nid)" \
      'refs/heads/*:refs/heads/*' 'refs/tags/*:refs/tags/*'
    ;;

  *)
    die "unknown command: ${1:-}"
    ;;
esac
