#!/bin/bash
# Fixture tests. They never point sweep at the real home folder.

set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SWEEP="$ROOT/sweep"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
  printf 'fail: %s\n' "$*" >&2
  exit 1
}

export SWEEP_TEST=1
export SWEEP_HOME="$tmp/home"
mkdir -p "$SWEEP_HOME/Library/Caches/com.example.app"
mkdir -p "$SWEEP_HOME/Library/Caches/CloudKit"
mkdir -p "$SWEEP_HOME/Library/Caches/com.apple.Safari"
mkdir -p "$SWEEP_HOME/Documents"
mkdir -p "$SWEEP_HOME/Library/Logs/DiagnosticReports"
mkdir -p "$SWEEP_HOME/Library/Application Support/MobileSync/Backup/iphone"
mkdir -p "$SWEEP_HOME/src/app/node_modules/pkg"
mkdir -p "$SWEEP_HOME/src/loose/node_modules/pkg"
mkdir -p "$SWEEP_HOME/src/rs/target"
mkdir -p "$SWEEP_HOME/.Trash"

printf 'keep' > "$SWEEP_HOME/Documents/keep.txt"
printf 'secret' > "$SWEEP_HOME/Library/Caches/CloudKit/state"
printf 'page' > "$SWEEP_HOME/Library/Caches/com.apple.Safari/page"
printf 'junk' > "$SWEEP_HOME/Library/Caches/com.example.app/junk"
printf 'trash' > "$SWEEP_HOME/.Trash/trash"
printf 'backup' > "$SWEEP_HOME/Library/Application Support/MobileSync/Backup/iphone/info"
printf '{}' > "$SWEEP_HOME/src/app/package.json"
printf 'mod' > "$SWEEP_HOME/src/app/node_modules/pkg/index.js"
printf 'loose' > "$SWEEP_HOME/src/loose/node_modules/pkg/index.js"
printf '[package]\nname = "x"\nversion = "0.0.0"\n' > "$SWEEP_HOME/src/rs/Cargo.toml"
printf 'bin' > "$SWEEP_HOME/src/rs/target/bin"
printf 'old' > "$SWEEP_HOME/Library/Logs/old.log"
printf 'crash' > "$SWEEP_HOME/Library/Logs/DiagnosticReports/crash.ips"
touch -t 202001010000 "$SWEEP_HOME/Library/Logs/old.log"
touch -t 202001010000 "$SWEEP_HOME/Library/Logs/DiagnosticReports/crash.ips"

outside="$tmp/outside"
mkdir -p "$outside"
printf 'safe' > "$outside/safe"
ln -s "$outside" "$SWEEP_HOME/Library/Caches/evil"

items="$("$SWEEP" items caches)"
printf '%s\n' "$items" | grep -q 'com.example.app' || fail 'items missed a cache'
printf '%s\n' "$items" | grep -q 'CloudKit' && fail 'CloudKit was offered for deletion' || true
printf '%s\n' "$items" | grep -q 'com.apple.Safari' && fail 'browser cache was listed under caches' || true
if "$SWEEP" clean --yes caches --only CloudKit >/dev/null 2>&1; then
  fail 'CloudKit matched a folder name'
fi
test -f "$SWEEP_HOME/Library/Caches/CloudKit/state" || fail 'CloudKit was removed by --only'

out="$("$SWEEP" scan)"
printf '%s\n' "$out" | grep -q 'caches' || fail 'scan missed caches'
printf '%s\n' "$out" | grep -q 'browsers' || fail 'scan missed browsers'
printf '%s\n' "$out" | grep -q 'backups' || fail 'scan missed backups'
printf '%s\n' "$out" | grep -q 'Nothing was deleted' || fail 'scan claimed a delete'

"$SWEEP" clean caches >/dev/null
test -f "$SWEEP_HOME/Library/Caches/com.example.app/junk" || fail 'dry run deleted a cache'

"$SWEEP" clean --yes caches >/dev/null
test ! -e "$SWEEP_HOME/Library/Caches/com.example.app" || fail 'cache survived'
test -f "$SWEEP_HOME/Library/Caches/CloudKit/state" || fail 'CloudKit was removed'
test -f "$SWEEP_HOME/Documents/keep.txt" || fail 'a document was removed'
test -f "$SWEEP_HOME/Library/Caches/com.apple.Safari/page" || fail 'browser cache removed with caches'
test -f "$outside/safe" || fail 'a symlink target outside Caches was removed'
test -f "$SWEEP_HOME/Library/Application Support/MobileSync/Backup/iphone/info" || fail 'backup removed with caches'

"$SWEEP" clean --yes browsers >/dev/null
test ! -e "$SWEEP_HOME/Library/Caches/com.apple.Safari/page" || fail 'browser cache survived'

"$SWEEP" clean --yes logs >/dev/null
test ! -e "$SWEEP_HOME/Library/Logs/old.log" || fail 'old log survived'
test -f "$SWEEP_HOME/Library/Logs/DiagnosticReports/crash.ips" || fail 'crash report was removed'

"$SWEEP" clean --yes backups >/dev/null
test ! -e "$SWEEP_HOME/Library/Application Support/MobileSync/Backup/iphone" || fail 'backup survived an explicit clean'

proj="$("$SWEEP" projects)"
printf '%s\n' "$proj" | grep -q 'projects' || fail 'projects were not reported'
test -d "$SWEEP_HOME/src/app/node_modules" || fail 'projects deleted during a report'
"$SWEEP" clean --yes projects >/dev/null
test ! -d "$SWEEP_HOME/src/app/node_modules" || fail 'node_modules survived'
test -d "$SWEEP_HOME/src/loose/node_modules" || fail 'node_modules without package.json was removed'
test ! -d "$SWEEP_HOME/src/rs/target" || fail 'Cargo target survived'
test -f "$SWEEP_HOME/src/app/package.json" || fail 'package.json was removed'

large="$("$SWEEP" large)"
printf '%s\n' "$large" | grep -q 'Home' || fail 'large did not report the home folder'
"$SWEEP" --version | grep -q '0.2.0'

if "$SWEEP" nope >/dev/null 2>&1; then
  fail 'unknown group should fail'
fi

bindir="$tmp/bin"
mkdir -p "$bindir" "$SWEEP_HOME/Library/Caches/Homebrew"
printf 'pkg' > "$SWEEP_HOME/Library/Caches/Homebrew/pkg"
cat > "$bindir/brew" <<'EOF'
#!/bin/bash
if [[ "$1" == "--cache" ]]; then
  printf '%s\n' "$SWEEP_HOME/Library/Caches/Homebrew"
  exit 0
fi
if [[ "$1" == "cleanup" ]]; then
  printf '%s\n' "$*" >> "$SWEEP_HOME/brew.called"
  exit 0
fi
exit 0
EOF
chmod +x "$bindir/brew"
PATH="$bindir:$PATH" "$SWEEP" clean --yes homebrew >/dev/null
test -s "$SWEEP_HOME/brew.called" || fail 'brew cleanup was not used'
test ! -e "$SWEEP_HOME/Library/Caches/Homebrew/pkg" || fail 'brew download survived'

mkdir -p "$SWEEP_HOME/Library/Caches/keep.me" "$SWEEP_HOME/Library/Caches/drop.me"
printf 'stay' > "$SWEEP_HOME/Library/Caches/keep.me/file"
printf 'go' > "$SWEEP_HOME/Library/Caches/drop.me/file"
printf '%s\n' caches drop.me clean no quit | "$SWEEP" menu >/dev/null
test -f "$SWEEP_HOME/Library/Caches/drop.me/file" || fail 'no did not cancel'
printf '%s\n' caches drop.me clean yes quit | "$SWEEP" menu >/dev/null
test -f "$SWEEP_HOME/Library/Caches/keep.me/file" || fail 'an unticked folder was deleted'
test ! -e "$SWEEP_HOME/Library/Caches/drop.me" || fail 'a ticked folder survived'
"$SWEEP" clean --yes caches --only keep.me >/dev/null
test ! -e "$SWEEP_HOME/Library/Caches/keep.me" || fail '--only left the named folder'
test -f "$SWEEP_HOME/Documents/keep.txt" || fail 'a document was removed'

printf 'ok\n'
