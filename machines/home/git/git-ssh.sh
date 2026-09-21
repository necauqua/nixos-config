
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
  create <repo> [text]      create a repository, with its description
  describe <repo> <text>    set the description of a repository
  mirror list <repo>        show the mirrors of a repository
  mirror add <repo> <url>   add a mirror
  mirror rm <repo> <url>    remove a mirror
  mirror sync <repo>        look the knot url of a repository up again
  rad list                  show the radicle id of every repository
  rad nid                   show the node id of this machine
  rad init <repo>           create the radicle repository
  rad link <repo> <rid>     adopt a radicle repository that exists already,
                            and create the repository if the name is free
  rad unlink <repo>         stop mirroring a repository to radicle
  rad sync <repo>           push a repository to radicle now

A push to a name that does not exist creates the repository, and its first
push puts it on radicle. The description that radicle is given comes from
create, which saves describe a revision of the radicle identity. Such a
revision needs an accept from every delegate of the repository.
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

# A rid makes the repository a mirror of a radicle repository that exists
# already. Without one, radicle needs a branch, which only the push that
# follows brings, so the hook creates the radicle repository and clears the
# marker that this leaves behind
create_repo() {
  local repo=$1 name=$2 rid=${3:-} description=${4:-}
  git init --bare --quiet --initial-branch=main "$repo"
  git -C "$repo" config core.hooksPath "$GIT_HOOKS"
  printf '%s\n' "${description:-$name}" > "$repo/description"
  if [ -n "$rid" ]; then
    set_rad_id "$repo" "$rid"
  else
    git -C "$repo" config rad.auto true
  fi
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
      create_repo "$repo" "$name"
    fi

    exec git "${argv[0]#git-}" "$repo"
    ;;

  list)
    for repo in "$GIT_ROOT"/*; do
      [ -d "$repo/objects" ] || continue
      basename "$repo"
    done
    ;;

  # the repository is created here and not by the first push, so that radicle
  # is given the description of the repository from the start
  create)
    [ ${#argv[@]} -ge 2 ] || usage
    repo=$(resolve "${argv[1]}")
    name=$(basename "$repo")
    [ ! -d "$repo" ] || die "$name exists already"
    create_repo "$repo" "$name" "" "${argv[*]:2}"
    ;;

  describe)
    [ ${#argv[@]} -ge 3 ] || usage
    repo=$(existing "${argv[1]}")
    text=${argv[*]:2}
    printf '%s\n' "$text" > "$repo/description"
    # the identity of the repository is what the seed and every web client
    # show, and the description of a repository that is not on radicle yet
    # travels there with `rad init`
    rid=$(rad_id "$repo")
    if [ -n "$rid" ]; then
      # a revision that a second delegate has to accept comes back named, and
      # what the network shows stays as it was until then
      rev=$(rad_mirror describe "$rid" "$text")
      if [ -n "$rev" ]; then
        cat >&2 <<EOF
the description of $rid is a revision of its identity now, and a second
delegate has to accept it before the network shows it. On that machine:

  rad id accept $rev --repo $rid
EOF
      fi
    fi
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
      # delegate, which `rad id update` on that other machine decides.
      #
      # A name that no repository holds yet gets one here, because the other
      # road to a bare repository is the first push, and that one puts the
      # repository on radicle itself
      link)
        [ ${#argv[@]} -eq 4 ] || usage
        repo=$(resolve "${argv[2]}")
        rid=${argv[3]}
        # before the repository, so that a rid the node refuses leaves nothing
        rad_mirror link "$rid"
        if [ -d "$repo" ]; then
          set_rad_id "$repo" "$rid"
        else
          # the identity of the repository already says what it is
          create_repo "$repo" "$(basename "$repo")" "$rid" \
            "$(rad_mirror describe "$rid" || true)"
        fi
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
