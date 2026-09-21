
# The dependency install and the build of a deploy, started by jobs-timer in a
# transient unit with the worktree as its working directory. It runs the code
# of the package, so the unit around it may only write that worktree and the
# npm cache of its user. The network stays open, because the install fetches
# from the registry.

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

[ -f package.json ] || die "the package carries no package.json"

# HOME is the cache directory of the user, the one path outside the worktree
# that this may write
export npm_config_cache="$HOME/cache"
export npm_config_update_notifier=false
export npm_config_fund=false
export npm_config_audit=false

# A package that builds needs its devDependencies for that and none of them
# afterwards, so it takes the whole tree and is pruned back down once the
# build is over. A package without a build step never sees them at all.
if jq -e '.scripts.build // empty' package.json > /dev/null; then
  build=1
  omit=()
else
  build=
  omit=(--omit=dev)
fi

if [ -f package-lock.json ]; then
  npm ci "${omit[@]}"
else
  printf 'warning: no package-lock.json, falling back to npm install\n' >&2
  npm install --no-package-lock "${omit[@]}"
fi

# The start of a job is dominated by the walk over node_modules, so a package
# that bundles itself into one file starts about ten times faster. This is the
# place to do it: the run itself only reads what the build leaves behind.
if [ -n "$build" ]; then
  npm run build
  npm prune --omit=dev
fi
