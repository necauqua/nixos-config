
# post-receive hook of every job repository. It puts the pushed revision in the
# worktree of the job, has the dependencies installed and the package built,
# and puts the timer back on the schedule that the package declares.
#
# git runs it inside the bare repository, whose path carries both names, with
# the updated refs on stdin.

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

name=$(basename "$PWD")
user=$(basename "$(dirname "$PWD")")
tree="$WORK/$user/$name"
cache="$WORK/$user/.npm"

# One branch deploys and every other ref is only stored, so the repository
# stays a plain git host with the whole history in it and a push says on its
# own whether it also promotes a revision
branch=refs/heads/deploy

rev=
while read -r _old new ref; do
  [ "$ref" = "$branch" ] && rev=$new
done

if [ -z "$rev" ]; then
  printf 'note: stored, nothing deployed. Push to "deploy" to deploy:\n' >&2
  printf '      git push <remote> HEAD:deploy\n' >&2
  exit 0
fi

# a delete of the branch leaves the job on its last deploy
case $rev in
  *[!0]*) ;;
  *)
    printf 'note: "deploy" was deleted, %s keeps its last deploy\n' "$name" >&2
    exit 0
    ;;
esac

printf 'deploying %s\n' "$name" >&2

# nothing may read the worktree while it changes
"$SUDO" "$JOBS_TIMER" disarm "$user" "$name"

# the sandbox of the deploy takes both paths as they are, so they exist first
mkdir -p "$tree" "$cache"
# the worktree only ever holds one revision, so the detached head it lands on
# is the point and not a thing to warn about
GIT_WORK_TREE=$tree git -c advice.detachedHead=false checkout -f "$rev"
# drop the files that the push removed. Without -x it leaves node_modules and
# every other ignored path alone, which is also how a job keeps state across a
# deploy: what .gitignore holds stays, everything untracked goes
GIT_WORK_TREE=$tree git clean -fdq

[ -f "$tree/package.json" ] || die "the package carries no package.json"

"$SUDO" "$JOBS_TIMER" deploy "$user" "$name"
"$SUDO" "$JOBS_TIMER" arm "$user" "$name"
