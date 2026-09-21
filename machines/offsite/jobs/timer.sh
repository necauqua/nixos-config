
# The bridge between the `jobs` user and everything that belongs to root: the
# timers, the key file and the sandbox that a deploy runs in. It is the one
# program that user may run through sudo, so every argument it takes is a name
# that it validates itself, and never a unit or a path.
#
# Only the gateway and the hook ever reach it: the code of a job runs under
# NoNewPrivileges, which takes sudo away from it.

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

# the same rule as the names in jobs-ssh, so a name can never reach out of the
# namespace of its user, in the units or on the disk
valid() {
  case $1 in
    '' | .* | *[!A-Za-z0-9._-]*) die "invalid name: ${1:-<empty>}" ;;
  esac
}

# a user and a job to the paths and the unit they own. The instance holds the
# escaped path, so "%I" gives "<user>/<job>" back to the unit
job_vars() {
  user=$1
  name=$2
  valid "$user"
  valid "$name"
  tree="$WORK/$user/$name"
  cache="$WORK/$user/.npm"
  unit="job@$(systemd-escape "$user/$name")"
  dropin="/run/systemd/system/$unit.timer.d"
}

file="$KEYS/jobs"

action=${1:-}

case $action in
  # stop the job before a deploy touches its worktree
  disarm)
    job_vars "${2:-}" "${3:-}"
    systemctl stop "$unit.timer" "$unit.service" || true
    ;;

  # Install the dependencies and build the package. This runs the code of the
  # package itself, both the lifecycle scripts of npm and the build script, so
  # it goes into a transient unit that only sees the worktree of the job and
  # the cache of its user. That is what keeps one user away from another. The
  # network stays open, because the install fetches from the registry
  deploy)
    job_vars "${2:-}" "${3:-}"
    [ -d "$tree" ] || die "$user/$name has no worktree"
    [ -d "$cache" ] || die "$user/$name has no cache directory"

    exec systemd-run \
      --quiet --pipe --wait --collect --service-type=exec \
      --uid=jobs --gid=jobs \
      --setenv=HOME="$cache" \
      --property=WorkingDirectory="$tree" \
      --property=ReadWritePaths="$tree $cache" \
      --property=ProtectSystem=strict \
      --property=ProtectHome=yes \
      --property=PrivateTmp=yes \
      --property=PrivateDevices=yes \
      --property=NoNewPrivileges=yes \
      --property=RestrictSUIDSGID=yes \
      --property=RuntimeMaxSec=900 \
      --property=InaccessiblePaths="$ROOT $KEYS" \
      --property=TemporaryFileSystem="$WORK:ro" \
      --property=BindPaths="$tree $cache" \
      --property=RestrictAddressFamilies="AF_UNIX AF_INET AF_INET6 AF_NETLINK" \
      -- "$INSTALL"
    ;;

  # read the schedule of the deployed package and put the timer on it. The
  # drop-in lives in /run, so a reboot forgets it and jobs-arm.service writes
  # it again from the same package.json
  arm)
    job_vars "${2:-}" "${3:-}"
    package="$tree/package.json"
    [ -f "$package" ] || die "$user/$name is not deployed"

    schedule=$(jq -r '.onCalendar // empty' "$package")

    if [ -z "$schedule" ]; then
      rm -rf "$dropin"
      systemctl daemon-reload
      systemctl stop "$unit.timer" || true
      printf 'warning: package.json carries no "onCalendar" field, %s stays disarmed\n' \
        "$name" >&2
      exit 0
    fi

    systemd-analyze calendar "$schedule" > /dev/null 2>&1 \
      || die "package.json carries an invalid OnCalendar expression: $schedule"

    mkdir -p "$dropin"
    # the empty assignment drops the placeholder of the template unit, which
    # exists only because a timer without a trigger refuses to load
    printf '[Timer]\nOnCalendar=\nOnCalendar=%s\n' "$schedule" > "$dropin/schedule.conf"

    systemctl daemon-reload
    systemctl restart "$unit.timer"
    printf 'armed %s: %s\n' "$name" "$schedule" >&2
    ;;

  # run the job now, next to whatever the timer does
  run)
    job_vars "${2:-}" "${3:-}"
    [ -f "$tree/package.json" ] || die "$user/$name is not deployed"
    systemctl start --wait "$unit.service"
    ;;

  # The key file is root's alone. Nothing that runs as `jobs` may write it, so
  # a key that the admin hands out can never grant another one
  key-add)
    user=${2:-}
    type=${3:-}
    blob=${4:-}
    comment=${*:5}
    valid "$user"
    [ "$user" != root ] || die "root is the namespace of the admin keys"
    [ -n "$blob" ] || die "usage: jobs-timer key-add <user> <ssh-key>"

    # the line is quoted, and the comment is the one part a client chooses
    comment=${comment//[^A-Za-z0-9@._-]/_}
    key="$type $blob${comment:+ $comment}"

    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT
    printf '%s\n' "$key" > "$tmp"
    ssh-keygen -l -f "$tmp" > /dev/null 2>&1 || die "that is not an ssh public key"

    mkdir -p "$KEYS"
    touch "$file"
    chmod 0644 "$file"
    ! grep -qF " $blob" "$file" || die "that key is already registered"

    printf 'command="%s %s",restrict %s\n' "$GATEWAY" "$user" "$key" >> "$file"
    printf 'registered a key for %s\n' "$user" >&2
    ;;

  # a key by its blob or its comment, or every key of the user
  key-rm)
    user=${2:-}
    pattern=${3:-}
    valid "$user"
    [ -f "$file" ] || die "no key is registered"

    prefix="command=\"$GATEWAY $user\","
    removed=0
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT

    while IFS= read -r line || [ -n "$line" ]; do
      if [ "${line#"$prefix"}" != "$line" ] \
        && { [ -z "$pattern" ] || [ "${line#*"$pattern"}" != "$line" ]; }; then
        removed=$((removed + 1))
        continue
      fi
      printf '%s\n' "$line" >> "$tmp"
    done < "$file"

    [ "$removed" -gt 0 ] || die "no key of $user matches"
    install -m 0644 -o root -g root "$tmp" "$file"
    printf 'took back %s key(s) of %s\n' "$removed" "$user" >&2
    ;;

  *) die "usage: jobs-timer arm|disarm|deploy|run <user> <job>" ;;
esac
