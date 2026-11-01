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

mkdir -p "$SWEEP_HOME/Library/Caches/zz.big" "$SWEEP_HOME/Library/Caches/com.spotify.client"
dd if=/dev/zero of="$SWEEP_HOME/Library/Caches/zz.big/file" bs=1024 count=64 >/dev/null 2>&1
printf 'song' > "$SWEEP_HOME/Library/Caches/com.spotify.client/file"

items="$("$SWEEP" items caches)"
printf '%s\n' "$items" | head -n 1 | grep -q 'zz.big' || fail 'largest folder was not listed first'
printf '%s\n' "$items" | grep -q 'Spotify' || fail 'Spotify was not given a plain name'
printf '%s\n' "$items" | grep -q 'com.example.app' || fail 'items missed a cache'
"$SWEEP" clean --yes caches --only Spotify >/dev/null
test ! -e "$SWEEP_HOME/Library/Caches/com.spotify.client" || fail 'Spotify cache survived --only'
last="$("$SWEEP" last)"
case "$last" in
  *Spotify*) ;;
  *) fail 'last did not remember Spotify' ;;
esac
test -d "$SWEEP_HOME/Library/Caches/zz.big" || fail '--only Spotify removed another folder'
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
"$SWEEP" --version | grep -q '0.10.0'

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

mkdir -p "$SWEEP_HOME/Library/Caches/com.spotify.client"
printf 'song' > "$SWEEP_HOME/Library/Caches/com.spotify.client/file"
printf '%s\n' Spotify clean yes quit | "$SWEEP" menu >/dev/null
test ! -e "$SWEEP_HOME/Library/Caches/com.spotify.client" || fail 'ticking Spotify did not delete it'
test -f "$SWEEP_HOME/Documents/keep.txt" || fail 'a document was removed from the menu'

mkdir -p "$SWEEP_HOME/Library/Caches/walk.big" "$SWEEP_HOME/Library/Caches/walk.small"
dd if=/dev/zero of="$SWEEP_HOME/Library/Caches/walk.big/file" bs=1024 count=80 >/dev/null 2>&1
printf 'small' > "$SWEEP_HOME/Library/Caches/walk.small/file"
printf '%s\n' walk no quit | "$SWEEP" menu >/dev/null
test -f "$SWEEP_HOME/Library/Caches/walk.big/file" || fail 'no during a walk deleted the folder'
printf '%s\n' walk yes quit | "$SWEEP" menu >/dev/null
test ! -e "$SWEEP_HOME/Library/Caches/walk.big" || fail 'yes during a walk left the folder'
test -f "$SWEEP_HOME/Library/Caches/walk.small/file" || fail 'walk deleted the next folder after quit'
test -f "$SWEEP_HOME/Documents/keep.txt" || fail 'a document was removed during a walk'

mkdir -p "$SWEEP_HOME/Library/Caches/big.visible" "$SWEEP_HOME/Library/Caches/tiny.hidden"
mkdir -p "$SWEEP_HOME/Library/Application Support/MobileSync/Backup/keep-phone"
dd if=/dev/zero of="$SWEEP_HOME/Library/Caches/big.visible/file" bs=1024 count=2048 >/dev/null 2>&1
printf 'dust' > "$SWEEP_HOME/Library/Caches/tiny.hidden/file"
printf 'backup' > "$SWEEP_HOME/Library/Application Support/MobileSync/Backup/keep-phone/info"
hidden="$(printf 'quit\n' | SWEEP_MIN_KB=1024 "$SWEEP" menu)"
printf '%s\n' "$hidden" | grep -q 'big.visible' || fail 'a large folder was hidden'
printf '%s\n' "$hidden" | grep -q 'tiny.hidden' && fail 'a tiny folder was listed' || true
printf '%s\n' "$hidden" | grep -q 'smaller folders are hidden' || fail 'the hidden-folder note was missing'
printf '%s\n' go yes quit | SWEEP_MIN_KB=1024 "$SWEEP" menu >/dev/null
test ! -e "$SWEEP_HOME/Library/Caches/big.visible" || fail 'go left a safe folder'
test -f "$SWEEP_HOME/Library/Caches/tiny.hidden/file" || fail 'go deleted a hidden folder'
test -f "$SWEEP_HOME/Library/Application Support/MobileSync/Backup/keep-phone/info" || fail 'go deleted a backup'
mkdir -p "$SWEEP_HOME/Library/Application Support/MobileSync/Backup/AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
printf 'x' > "$SWEEP_HOME/Library/Application Support/MobileSync/Backup/AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE/info"
"$SWEEP" items backups | grep -q 'Device backup AAAAAAAA' || fail 'a backup was shown as a raw id'

mkdir -p "$SWEEP_HOME/Library/Caches/com.spotify.client" "$bindir"
printf 'song' > "$SWEEP_HOME/Library/Caches/com.spotify.client/file"
cat > "$bindir/pgrep" <<'EOF'
#!/bin/bash
if [[ "$1" == "-x" && "$2" == "Spotify" ]]; then
  exit 0
fi
exit 1
EOF
chmod +x "$bindir/pgrep"
open_note="$(printf 'quit\n' | PATH="$bindir:$PATH" SWEEP_TEST=1 SWEEP_HOME="$SWEEP_HOME" "$SWEEP" menu)"
printf '%s\n' "$open_note" | grep -q 'app open' || fail 'an open app was not marked'

mkdir -p "$SWEEP_HOME/Downloads" "$SWEEP_HOME/Library/LaunchAgents" "$SWEEP_HOME/Applications/Widget.app/Contents"
printf 'pkg' > "$SWEEP_HOME/Downloads/Setup.pkg"
printf 'keep' > "$SWEEP_HOME/Downloads/notes.txt"
"$SWEEP" items downloads | grep -q 'Setup.pkg' || fail 'installer was not listed'
"$SWEEP" clean --yes downloads >/dev/null
test ! -e "$SWEEP_HOME/Downloads/Setup.pkg" || fail 'installer survived'
test -f "$SWEEP_HOME/Downloads/notes.txt" || fail 'a download that is not an installer was removed'

cat > "$SWEEP_HOME/Library/LaunchAgents/com.example.missing.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>Label</key><string>com.example.missing</string>
  <key>Program</key><string>/no/such/sweep-helper</string>
</dict></plist>
EOF
cat > "$SWEEP_HOME/Library/LaunchAgents/com.example.live.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>Label</key><string>com.example.live</string>
  <key>Program</key><string>/bin/echo</string>
</dict></plist>
EOF
"$SWEEP" login | grep -q 'com.example.missing.plist' || fail 'missing login helper was not listed'
"$SWEEP" login | grep -q 'com.example.live.plist' && fail 'a live login helper was listed' || true
"$SWEEP" login remove com.example.missing.plist --yes >/dev/null
test ! -e "$SWEEP_HOME/Library/LaunchAgents/com.example.missing.plist" || fail 'missing login helper survived'
test -f "$SWEEP_HOME/Library/LaunchAgents/com.example.live.plist" || fail 'a live login helper was removed'

cat > "$SWEEP_HOME/Applications/Widget.app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.example.widget</string>
  <key>CFBundleName</key><string>Widget</string>
</dict></plist>
EOF
mkdir -p "$SWEEP_HOME/Library/Caches/com.example.widget"
printf 'left' > "$SWEEP_HOME/Library/Caches/com.example.widget/file"
info="$("$SWEEP" uninstall Widget)"
case "$info" in
  *com.example.widget*) ;;
  *) fail 'uninstall did not list the bundle id' ;;
esac
"$SWEEP" uninstall Widget --yes >/dev/null
test -d "$SWEEP_HOME/.Trash/Widget.app" || fail 'the app was not moved to the Trash'
test -f "$SWEEP_HOME/Library/Caches/com.example.widget/file" || fail 'a leftover was removed without --leftovers'
mkdir -p "$SWEEP_HOME/Applications/Widget.app/Contents" "$SWEEP_HOME/Applications/WidgetCopy.app/Contents"
cp "$SWEEP_HOME/.Trash/Widget.app/Contents/Info.plist" "$SWEEP_HOME/Applications/Widget.app/Contents/Info.plist"
cp "$SWEEP_HOME/Applications/Widget.app/Contents/Info.plist" "$SWEEP_HOME/Applications/WidgetCopy.app/Contents/Info.plist"
if "$SWEEP" uninstall Widget --yes >/dev/null 2>&1; then
  fail 'a second copy should block uninstall'
fi
test -d "$SWEEP_HOME/Applications/Widget.app" || fail 'blocked uninstall removed the app'

printf 'ok\n'
