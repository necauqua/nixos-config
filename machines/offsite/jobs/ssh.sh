
# Forced command of the `jobs` user. It serves the git protocol over ssh and
# creates the bare repository on the first push to a name that is free.
#
# Every key names the user it belongs to, and the admin keys carry "admin" as
# well. A user only ever reaches the namespace of its own name.

user=${1:-}
admin=${2:-}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

[ -n "$user" ] || die "the gateway was called without a user"
case $admin in
  '' | admin) ;;
  *) die "the gateway was called with an unknown mode: $admin" ;;
esac

usage() {
  cat >&2 <<EOF
jobs@$DOMAIN, as $user. It understands:

  list              list the jobs and their schedules
  status <job>      show the timer of a job and its last run
  log <job>         show the journal of a job
  run <job>         run a job now and wait for it
  drop <job>        stop a job and forget its worktree

A push to a name that does not exist creates the job:

  git remote add offsite ssh://jobs@$DOMAIN:$SSH_PORT/<job>
  git push offsite main

That stores the history and no more, the same as any other git host. The
"deploy" branch is the one that deploys, so a revision runs once you
promote it:

  git push offsite main:deploy

The schedule comes from the package itself: put an "onCalendar" field in
package.json, in the systemd OnCalendar format, for example "hourly",
"daily" or "Mon *-*-* 04:30:00". A package without one is deployed but
stays disarmed. "main" of package.json names the entry point, which node
runs with the worktree as its working directory. The job may reach the
network, which is the point of it: an api call on a schedule.

A deploy installs the dependencies from the lock file. A package with a
"build" script also gets its devDependencies, runs that script and is
then pruned back to the production tree, so a job may bundle itself into
one file. That is worth doing: a job that imports a few packages out of
node_modules spends about a second on the walk over them, and one
bundled file starts in a tenth of that.

The worktree is the only path a job may write, and it is also the path a
deploy rewrites: every untracked file goes, and only the ignored ones
stay. So a job that keeps state must write it to a path that .gitignore
holds, and "drop" takes that state with the worktree.
EOF

  [ -n "$admin" ] && cat >&2 <<EOF

As an admin key you reach the jobs of every user, named <user>/<job>,
and you hand out the keys:

  key list                       list the users and their keys
  key add <user> <ssh-key>       let a key deploy as <user>
  key rm <user> [<key or name>]  take one key back, or all of them

A registered key reaches its own namespace and nothing else, neither on
the disk nor in the units, and its deploys are built in a sandbox of
their own.
EOF

  exit 1
}

# the same rule as the names in jobs-timer, so a name can never reach out of
# the namespace of its user
valid() {
  case $1 in
    '' | .* | *[!A-Za-z0-9._-]*) die "invalid name: $1" ;;
  esac
}

# A job path to its user and its name. A user may leave its own namespace out,
# an admin names the namespace to reach another one
resolve() {
  local path=$1
  path=${path#/}
  path=${path#\~/}
  path=${path%/}
  path=${path%.git}
  case $path in
    */*/*) die "invalid job: $1" ;;
    */*)
      job_user=${path%%/*}
      job_name=${path#*/}
      ;;
    *)
      job_user=$user
      job_name=$path
      ;;
  esac
  valid "$job_user"
  valid "$job_name"
  [ -n "$admin" ] || [ "$job_user" = "$user" ] \
    || die "you only reach the jobs of $user"

  repo="$ROOT/$job_user/$job_name"
  tree="$WORK/$job_user/$job_name"
  unit="job@$(systemd-escape "$job_user/$job_name")"
  # an admin sees whose job it is, a user has the one namespace
  if [ -n "$admin" ]; then
    label="$job_user/$job_name"
  else
    label=$job_name
  fi
}

existing() {
  resolve "$1"
  [ -d "$repo/objects" ] || die "no such job: $1"
}

schedule_of() {
  local package="$1/package.json"
  if [ ! -f "$package" ]; then
    printf 'not deployed'
  else
    jq -r '.onCalendar // "disarmed"' "$package"
  fi
}

create() {
  mkdir -p "$ROOT/$job_user"
  git init --bare --quiet --initial-branch=main "$repo"
  git -C "$repo" config core.hooksPath "$HOOKS"
  printf 'scheduled job %s\n' "$label" > "$repo/description"
  printf 'created %s\n' "$label" >&2
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

    resolve "$path"

    if [ ! -d "$repo/objects" ]; then
      [ "${argv[0]}" = git-receive-pack ] || die "no such job: $label"
      create
    fi

    exec git "${argv[0]#git-}" "$repo"
    ;;

  list)
    if [ -n "$admin" ]; then
      namespaces=("$ROOT"/*)
    else
      namespaces=("$ROOT/$user")
    fi
    for namespace in "${namespaces[@]}"; do
      [ -d "$namespace" ] || continue
      owner=$(basename "$namespace")
      for repo in "$namespace"/*; do
        [ -d "$repo/objects" ] || continue
        name=$(basename "$repo")
        if [ -n "$admin" ]; then
          printf '%-32s %s\n' "$owner/$name" "$(schedule_of "$WORK/$owner/$name")"
        else
          printf '%-24s %s\n' "$name" "$(schedule_of "$WORK/$owner/$name")"
        fi
      done
    done
    ;;

  status)
    [ ${#argv[@]} -eq 2 ] || usage
    existing "${argv[1]}"
    printf 'schedule: %s\n' "$(schedule_of "$tree")"
    systemctl list-timers --all --no-pager "$unit.timer"
    systemctl status --no-pager --lines=0 "$unit.service" || true
    ;;

  log)
    [ ${#argv[@]} -eq 2 ] || usage
    existing "${argv[1]}"
    journalctl --no-pager --lines=100 --unit="$unit.service"
    ;;

  run)
    [ ${#argv[@]} -eq 2 ] || usage
    existing "${argv[1]}"
    "$SUDO" "$JOBS_TIMER" run "$job_user" "$job_name"
    ;;

  # the repository stays, so a later push deploys the job again
  drop)
    [ ${#argv[@]} -eq 2 ] || usage
    existing "${argv[1]}"
    "$SUDO" "$JOBS_TIMER" disarm "$job_user" "$job_name"
    rm -rf "${tree:?}"
    printf 'dropped %s\n' "$label" >&2
    ;;

  # the key file is root's, so every write goes through the sudo bridge
  key)
    [ -n "$admin" ] || usage
    file="$KEYS/jobs"
    case ${argv[1]:-} in
      list)
        [ -f "$file" ] || die "no key is registered"
        # command="<gateway> <user>",restrict <type> <blob> <comment>
        while IFS= read -r line || [ -n "$line" ]; do
          [ -n "$line" ] || continue
          rest=${line#command=\"}
          rest=${rest#* }
          owner=${rest%%\"*}
          key=${rest#*\",}
          key=${key#* }
          printf '%-16s %s\n' "$owner" "$key"
        done < "$file"
        ;;
      add)
        [ ${#argv[@]} -ge 5 ] || die "usage: key add <user> <ssh-key>"
        "$SUDO" "$JOBS_TIMER" key-add "${argv[@]:2}"
        ;;
      rm)
        [ ${#argv[@]} -ge 3 ] || die "usage: key rm <user> [<key or name>]"
        "$SUDO" "$JOBS_TIMER" key-rm "${argv[@]:2}"
        ;;
      *) usage ;;
    esac
    ;;

  *) usage ;;
esac
