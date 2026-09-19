
# Forced command of the `git` user. It serves the git protocol over ssh and
# creates the bare repository on the first push to a name that is free.

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat >&2 <<EOF
git@$GIT_DOMAIN understands:

  list                      list the repositories
  describe <repo> <text>    set the description of a repository
  mirror list <repo>        show the mirrors of a repository
  mirror add <repo> <url>   add a mirror
  mirror rm <repo> <url>    remove a mirror
  mirror sync <repo>        look the knot url of a repository up again
  rad list                  show the radicle id of every repository
  rad nid                   show the node id of this machine
  rad init <repo>           create the radicle repository
  rad link <repo> <rid>     adopt a radicle repository that exists already
  rad unlink <repo>         stop mirroring a repository to radicle
  rad sync <repo>           push a repository to radicle now

A push to a name that does not exist creates the repository, and its first
push puts it on radicle.
EOF
  exit 1
}

# repository name to absolute path, flat plain names only. The repositories are
# bare but carry no .git suffix, which keeps one name for the directory, for
# the alias on the seed and for every clone url
resolve() {
  local name=$1
  name=${name#/}
  name=${name#\~/}
  name=${name%/}
  name=${name%.git}
  case $name in
    '' | .* | *[!A-Za-z0-9._-]*) die "invalid repository name: $1" ;;
  esac
  printf '%s/%s' "$GIT_ROOT" "$name"
}

mirrors() {
  git -C "$1" config --get-all mirror.url || true
}

rad_mirror() {
  "$SUDO" -u radicle "$RAD_MIRROR" "$@"
}

rad_id() {
  git -C "$1" config --get rad.id || true
}

# the rid is recorded here, and the repository stops asking for one of its own,
# whether it was created by `rad init` or adopted by `rad link`
set_rad_id() {
  git -C "$1" config rad.id "$2"
  git -C "$1" config --unset-all rad.auto || true
}

# the web gateway reads the alias of every repository at start only, so it
# learns a new rid from a restart
rad_reload() {
  "$SUDO" "$SYSTEMCTL" try-restart radicle-httpd.service \
    || printf 'warning: radicle-httpd did not restart\n' >&2
}

add_mirror() {
  local repo=$1 url=$2
  if mirrors "$repo" | grep -qxF "$url"; then
    return 0
  fi
  git -C "$repo" config --add mirror.url "$url"
  printf 'mirror %s added\n' "$url" >&2
}

# the knot gives every repository a did of its own and serves it under that
# did, so the url can only be looked up, never built from the name
add_knot_mirror() {
  local repo=$1 name=$2 url current

  if ! url=$(git-knot-url "$name"); then
    printf 'warning: %s is not on %s yet; create it there, then run "mirror sync %s"\n' \
      "$name" "$GIT_KNOT" "$name" >&2
    return 0
  fi

  # a repository that was made again on the knot carries a new did, so any
  # other url of the knot is stale
  while read -r current; do
    case $current in
      "$url" | *"$GIT_KNOT"*)
        [ "$current" = "$url" ] && continue
        git -C "$repo" config --unset-all --fixed-value mirror.url "$current"
        printf 'mirror %s dropped\n' "$current" >&2
        ;;
    esac
  done < <(mirrors "$repo")

  add_mirror "$repo" "$url"
}

create() {
  local repo=$1 name=$2
  git init --bare --quiet --initial-branch=main "$repo"
  git -C "$repo" config core.hooksPath "$GIT_HOOKS"
  printf '%s\n' "$name" > "$repo/description"
  # radicle needs a branch, which only the push that follows brings, so the
  # hook creates the radicle repository and clears this marker
  git -C "$repo" config rad.auto true
  printf 'created %s\n' "$name" >&2
  add_mirror "$repo" "git@github.com:$GITHUB_USER/$name.git"
  add_knot_mirror "$repo" "$name"
}

existing() {
  local repo
  repo=$(resolve "$1")
  [ -d "$repo" ] || die "no such repository: $1"
  printf '%s' "$repo"
}

read -ra argv <<< "${SSH_ORIGINAL_COMMAND:-}"
[ ${#argv[@]} -gt 0 ] || usage

case ${argv[0]} in
  git-receive-pack | git-upload-pack | git-upload-archive)
    [ ${#argv[@]} -eq 2 ] || die "expected exactly one repository"

    # git quotes the path it sends
    path=${argv[1]}
    path=${path#[\'\"]}
    path=${path%[\'\"]}

    repo=$(resolve "$path")
    name=$(basename "$repo")

    if [ ! -d "$repo" ]; then
      [ "${argv[0]}" = git-receive-pack ] || die "no such repository: $name"
      create "$repo" "$name"
    fi

    exec git "${argv[0]#git-}" "$repo"
    ;;

  list)
    for repo in "$GIT_ROOT"/*; do
      [ -d "$repo/objects" ] || continue
      basename "$repo"
    done
    ;;

  describe)
    [ ${#argv[@]} -ge 3 ] || usage
    repo=$(existing "${argv[1]}")
    printf '%s\n' "${argv[*]:2}" > "$repo/description"
    ;;

  mirror)
    [ ${#argv[@]} -ge 3 ] || usage
    repo=$(existing "${argv[2]}")
    name=$(basename "$repo")
    case ${argv[1]} in
      list) mirrors "$repo" ;;
      add)
        [ ${#argv[@]} -eq 4 ] || usage
        add_mirror "$repo" "${argv[3]}"
        ;;
      rm)
        [ ${#argv[@]} -eq 4 ] || usage
        git -C "$repo" config --unset-all --fixed-value mirror.url "${argv[3]}"
        ;;
      sync) add_knot_mirror "$repo" "$name" ;;
      *) usage ;;
    esac
    ;;

  rad)
    [ ${#argv[@]} -ge 2 ] || usage
    case ${argv[1]} in
      list)
        for repo in "$GIT_ROOT"/*; do
          [ -d "$repo/objects" ] || continue
          printf '%-24s %s\n' "$(basename "$repo")" "$(rad_id "$repo")"
        done
        ;;

      nid) rad_mirror nid ;;

      init)
        [ ${#argv[@]} -eq 3 ] || usage
        repo=$(existing "${argv[2]}")
        name=$(basename "$repo")
        [ -z "$(rad_id "$repo")" ] || die "$name is on radicle already"
        description=$(head -n1 "$repo/description" 2> /dev/null || true)
        rid=$(rad_mirror init "$repo" "$name" "${description:-$name}")
        set_rad_id "$repo" "$rid"
        rad_mirror push "$repo" "$rid"
        rad_reload
        printf 'created %s\n' "$rid" >&2
        ;;

      # the repository was made on another machine, so this one only starts to
      # replicate it. It can write the canonical branch once its node is a
      # delegate, which `rad id update` on that other machine decides
      link)
        [ ${#argv[@]} -eq 4 ] || usage
        repo=$(existing "${argv[2]}")
        rid=${argv[3]}
        rad_mirror link "$rid"
        set_rad_id "$repo" "$rid"
        rad_reload
        printf 'linked %s\n' "$rid" >&2
        ;;

      unlink)
        [ ${#argv[@]} -eq 3 ] || usage
        repo=$(existing "${argv[2]}")
        rid=$(rad_id "$repo")
        [ -n "$rid" ] || die "${argv[2]} is not on radicle"
        git -C "$repo" config --unset-all rad.id || true
        rad_mirror unlink "$rid"
        rad_reload
        printf 'unlinked %s\n' "$rid" >&2
        ;;

      sync)
        [ ${#argv[@]} -eq 3 ] || usage
        repo=$(existing "${argv[2]}")
        rid=$(rad_id "$repo")
        [ -n "$rid" ] || die "${argv[2]} is not on radicle"
        rad_mirror push "$repo" "$rid"
        ;;

      *) usage ;;
    esac
    ;;

  *) usage ;;
esac
