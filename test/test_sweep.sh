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

unset SWEEP_MIN_KB SWEEP_SIM_LIST SWEEP_BTM_LIST SWEEP_RECEIPT_KEEP SWEEP_HOME || true
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
case "$last" in
  *Library/Caches/com.spotify.client*) ;;
  *) fail 'last did not record the folder path' ;;
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
test -d "$SWEEP_HOME/Library/Caches/com.example.app" || fail 'a cache with no app was treated as safe'
test ! -e "$SWEEP_HOME/Library/Caches/zz.big" || fail 'a rebuildable cache survived'
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
"$SWEEP" --version | grep -q '0.18.0'

if "$SWEEP" nope >/dev/null 2>&1; then
  fail 'unknown group should fail'
fi

bindir="$tmp/bin"
mkdir -p "$bindir" "$SWEEP_HOME/Library/Caches/Homebrew"
printf 'pkg' > "$SWEEP_HOME/Library/Caches/Homebrew/pkg"
printf 'old' > "$SWEEP_HOME/Library/Caches/Homebrew/aaaaaaaa--wget--1.0.tar.gz"
printf 'new' > "$SWEEP_HOME/Library/Caches/Homebrew/bbbbbbbb--wget--1.2.tar.gz"
touch -t 201901010000 "$SWEEP_HOME/Library/Caches/Homebrew/aaaaaaaa--wget--1.0.tar.gz"
touch -t 202001010000 "$SWEEP_HOME/Library/Caches/Homebrew/bbbbbbbb--wget--1.2.tar.gz"
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
brew_items="$(PATH="$bindir:$PATH" "$SWEEP" items homebrew)"
case "$brew_items" in
  *wget--1.0.tar.gz*) ;;
  *) fail 'an older Homebrew download was not listed' ;;
esac
case "$brew_items" in
  *wget--1.2.tar.gz*) fail 'the newest Homebrew download for a formula was listed' ;;
esac
case "$brew_items" in
  *pkg*) fail 'a fresh Homebrew download was listed' ;;
esac
PATH="$bindir:$PATH" "$SWEEP" clean --yes homebrew >/dev/null
test -f "$SWEEP_HOME/Library/Caches/Homebrew/pkg" || fail 'a fresh Homebrew download was removed'
test -f "$SWEEP_HOME/Library/Caches/Homebrew/bbbbbbbb--wget--1.2.tar.gz" || fail 'the newest old Homebrew download was removed'
test ! -e "$SWEEP_HOME/Library/Caches/Homebrew/aaaaaaaa--wget--1.0.tar.gz" || fail 'an older Homebrew download survived'
PATH="$bindir:$PATH" "$SWEEP" clean --yes homebrew --empty >/dev/null
case "$(cat "$SWEEP_HOME/brew.called")" in
  *--prune=all*) ;;
  *) fail 'emptying the Homebrew cache was not explicit' ;;
esac
test ! -e "$SWEEP_HOME/Library/Caches/Homebrew/pkg" || fail 'an explicit empty left a Homebrew download'

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
printf 'iso' > "$SWEEP_HOME/Downloads/Setup.iso"
printf 'zip' > "$SWEEP_HOME/Downloads/Setup.zip"
printf 'pics' > "$SWEEP_HOME/Downloads/photos.zip"
printf 'mov' > "$SWEEP_HOME/Downloads/movie.mp4"
printf 'part' > "$SWEEP_HOME/Downloads/unfinished.download"
printf 'keep' > "$SWEEP_HOME/Downloads/notes.txt"
downloads="$("$SWEEP" items downloads)"
case "$downloads" in
  *Setup.pkg*) ;;
  *) fail 'installer was not listed' ;;
esac
case "$downloads" in
  *Setup.iso*) ;;
  *) fail 'a disk image was not listed' ;;
esac
case "$downloads" in
  *Setup.zip*) ;;
  *) fail 'an installer archive was not listed' ;;
esac
case "$downloads" in
  *photos.zip*) fail 'a zip that is not an installer was listed' ;;
esac
case "$downloads" in
  *movie.mp4*) fail 'a movie was listed as an installer' ;;
esac
case "$downloads" in
  *unfinished.download*) fail 'a partial download was listed with installers' ;;
esac
"$SWEEP" items partial | grep -q 'unfinished.download' || fail 'a partial download was not listed'
"$SWEEP" clean --yes downloads >/dev/null
test ! -e "$SWEEP_HOME/Downloads/Setup.pkg" || fail 'installer survived'
test ! -e "$SWEEP_HOME/Downloads/Setup.iso" || fail 'a disk image survived'
test ! -e "$SWEEP_HOME/Downloads/Setup.zip" || fail 'an installer archive survived'
test -f "$SWEEP_HOME/Downloads/photos.zip" || fail 'a zip that is not an installer was removed'
loose="$("$SWEEP" items files)"
case "$loose" in
  *photos.zip*) ;;
  *) fail 'a download file was not listed' ;;
esac
case "$loose" in
  *movie.mp4*) ;;
  *) fail 'a movie in Downloads was not listed' ;;
esac
test -f "$SWEEP_HOME/Downloads/movie.mp4" || fail 'a movie was removed'
test -f "$SWEEP_HOME/Downloads/notes.txt" || fail 'a download that is not an installer was removed'
test -f "$SWEEP_HOME/Downloads/unfinished.download" || fail 'a partial download was removed with installers'
"$SWEEP" clean --yes partial >/dev/null
test ! -e "$SWEEP_HOME/Downloads/unfinished.download" || fail 'a partial download survived'

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
login_out="$("$SWEEP" login)"
case "$login_out" in
  *com.example.missing.plist*) ;;
  *) fail 'missing login helper was not listed' ;;
esac
case "$login_out" in
  *com.example.live.plist*) fail 'a live login helper was listed' ;;
esac
login_menu="$(printf 'login\n\nquit\n' | "$SWEEP" menu)"
case "$login_menu" in
  *com.example.missing.plist*) ;;
  *) fail 'the menu hid a missing login helper' ;;
esac
case "$login_menu" in
  *com.example.live.plist*) fail 'the menu listed a live login helper' ;;
esac
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
mkdir -p "$SWEEP_HOME/Library/Containers/com.example.widget"
mkdir -p "$SWEEP_HOME/Library/Group Containers/ABCD.com.example.widget"
mkdir -p "$SWEEP_HOME/Library/Application Support/Example"
mkdir -p "$SWEEP_HOME/Library/Preferences"
printf 'left' > "$SWEEP_HOME/Library/Caches/com.example.widget/file"
printf 'sand' > "$SWEEP_HOME/Library/Containers/com.example.widget/file"
printf 'group' > "$SWEEP_HOME/Library/Group Containers/ABCD.com.example.widget/file"
printf 'vendor' > "$SWEEP_HOME/Library/Application Support/Example/file"
printf 'pref' > "$SWEEP_HOME/Library/Preferences/com.example.widget.plist"
mkdir -p "$SWEEP_HOME/Library/Saved Application State/com.example.widget.savedState"
printf 'win' > "$SWEEP_HOME/Library/Saved Application State/com.example.widget.savedState/window"
info="$("$SWEEP" uninstall Widget)"
case "$info" in
  *com.example.widget*) ;;
  *) fail 'uninstall did not list the bundle id' ;;
esac
case "$info" in
  *'team none'*) ;;
  *) fail 'uninstall did not show a team id line' ;;
esac
case "$info" in
  *'Full Disk Access is not required'*) ;;
  *) fail 'uninstall did not explain the leftovers search' ;;
esac
case "$info" in
  *'never a delete list'*ABCD.com.example.widget*) ;;
  *) fail 'uninstall hid a group container' ;;
esac
case "$info" in
  *'Application Support/Example'*) ;;
  *) fail 'uninstall hid a shared vendor folder' ;;
esac
case "$info" in
  *'own files'*) ;;
  *) fail 'uninstall did not explain a container' ;;
esac
case "$info" in
  *'Preferences/com.example.widget.plist'*) ;;
  *) fail 'uninstall hid the preference file' ;;
esac
case "$info" in
  *'Saved Application State/com.example.widget.savedState'*) ;;
  *) fail 'uninstall hid saved application state' ;;
esac
menu_app="$(printf 'uninstall\n1\n\nquit\n' | "$SWEEP" menu)"
case "$menu_app" in
  *com.example.widget*) ;;
  *) fail 'the menu uninstall preview hid the bundle id' ;;
esac
test -d "$SWEEP_HOME/Applications/Widget.app" || fail 'the menu preview moved the app'
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
rm -rf "$SWEEP_HOME/Applications/WidgetCopy.app"
"$SWEEP" uninstall Widget --leftovers --yes >/dev/null
test ! -e "$SWEEP_HOME/Library/Caches/com.example.widget" || fail 'an exact leftover survived --leftovers'
test -d "$SWEEP_HOME/Library/Group Containers/ABCD.com.example.widget" || fail 'a group container was deleted'
test -d "$SWEEP_HOME/Library/Application Support/Example" || fail 'a shared vendor folder was deleted'
test -f "$SWEEP_HOME/Library/Preferences/com.example.widget.plist" || fail 'a preference file was deleted'
test -d "$SWEEP_HOME/Library/Saved Application State/com.example.widget.savedState" || fail 'saved application state was deleted'
test ! -e "$SWEEP_HOME/Library/Containers/com.example.widget" || fail 'an exact container survived --leftovers'
touch -t 202001010000 "$SWEEP_HOME/Library/Group Containers/ABCD.com.example.widget"
mkdir -p "$SWEEP_HOME/Library/Group Containers/Adobe"
printf 'vendor' > "$SWEEP_HOME/Library/Group Containers/Adobe/file"
touch -t 202001010000 "$SWEEP_HOME/Library/Group Containers/Adobe"
mkdir -p "$SWEEP_HOME/Library/Group Containers/FRESH.com.example.other"
printf 'new' > "$SWEEP_HOME/Library/Group Containers/FRESH.com.example.other/file"
group_orphans="$("$SWEEP" orphans)"
case "$group_orphans" in
  *ABCD.com.example.widget*) ;;
  *) fail 'an old group container was hidden' ;;
esac
case "$group_orphans" in
  *Adobe*) fail 'a shared vendor folder was listed as a leftover' ;;
esac
case "$group_orphans" in
  *FRESH.com.example.other*) fail 'a new group container was listed' ;;
esac
case "$("$SWEEP" last)" in
  *'.Trash/Widget.app'*) ;;
  *) fail 'last did not record the Trash path' ;;
esac

mkdir -p "$SWEEP_HOME/Library/Caches/com.example.oldgone" "$SWEEP_HOME/Library/Caches/com.example.newgone"
printf 'old' > "$SWEEP_HOME/Library/Caches/com.example.oldgone/file"
printf 'new' > "$SWEEP_HOME/Library/Caches/com.example.newgone/file"
touch -t 202001010000 "$SWEEP_HOME/Library/Caches/com.example.oldgone" "$SWEEP_HOME/Library/Caches/com.example.oldgone/file"
orphans="$("$SWEEP" orphans)"
case "$orphans" in
  *com.example.oldgone*) ;;
  *) fail 'an old leftover was hidden' ;;
esac
case "$orphans" in
  *com.example.newgone*) fail 'a new leftover was offered' ;;
esac
"$SWEEP" orphans remove com.example.oldgone --yes >/dev/null
test ! -e "$SWEEP_HOME/Library/Caches/com.example.oldgone" || fail 'old leftover survived'
test -f "$SWEEP_HOME/Library/Caches/com.example.newgone/file" || fail 'a new leftover was removed'

mkdir -p "$SWEEP_HOME/Library/Application Support/com.example.oldgone"
dd if=/dev/zero of="$SWEEP_HOME/Library/Application Support/com.example.oldgone/file" bs=1024 count=2048 >/dev/null 2>&1
touch -t 202001010000 "$SWEEP_HOME/Library/Application Support/com.example.oldgone" \
  "$SWEEP_HOME/Library/Application Support/com.example.oldgone/file"
shown="$(printf 'quit\n' | "$SWEEP" menu | sed $'s/\033\\[[0-9;]*m//g')"
case "$shown" in
  *Oldgone*stays*) ;;
  *) fail 'an old leftover was missing from the first list' ;;
esac
walk_stays="$(printf 'walk stays\nno\nquit\n' | "$SWEEP" menu | sed $'s/\033\\[[0-9;]*m//g')"
case "$walk_stays" in
  *Oldgone*) ;;
  *) fail 'walk stays hid an old leftover' ;;
esac
test -d "$SWEEP_HOME/Library/Application Support/com.example.oldgone" || fail 'walk stays deleted a leftover on no'
info_out="$(printf 'info Oldgone\nquit\n' | "$SWEEP" menu | sed $'s/\033\\[[0-9;]*m//g')"
case "$info_out" in
  *com.example.oldgone*) ;;
  *) fail 'info hid the bundle id' ;;
esac
case "$info_out" in
  *'Unused for'*) ;;
  *) fail 'info hid how long a leftover has been unused' ;;
esac
case "$info_out" in
  *'No installed app owns it'*) ;;
  *) fail 'info hid that no app owns the leftover' ;;
esac
scan_left="$("$SWEEP" scan)"
case "$scan_left" in
  *leftovers*) ;;
  *) fail 'scan hid leftovers' ;;
esac
case "$scan_left" in
  *'Nothing was deleted'*) ;;
  *) fail 'scan deleted something while listing leftovers' ;;
esac

mkdir -p "$SWEEP_HOME/Applications/Live.app/Contents"
cat > "$SWEEP_HOME/Applications/Live.app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.example.liveapp</string>
  <key>CFBundleExecutable</key><string>LiveBin</string>
</dict></plist>
EOF
mkdir -p "$SWEEP_HOME/Library/Caches/com.example.liveapp" "$SWEEP_HOME/Library/Caches/com.example.nocacheapp"
dd if=/dev/zero of="$SWEEP_HOME/Library/Caches/com.example.liveapp/file" bs=1024 count=2048 >/dev/null 2>&1
dd if=/dev/zero of="$SWEEP_HOME/Library/Caches/com.example.nocacheapp/file" bs=1024 count=2048 >/dev/null 2>&1
mkdir -p "$SWEEP_HOME/Library/Caches/com.spotify.client" "$SWEEP_HOME/Library/Caches/closed.app" "$bindir"
dd if=/dev/zero of="$SWEEP_HOME/Library/Caches/com.spotify.client/file" bs=1024 count=2048 >/dev/null 2>&1
dd if=/dev/zero of="$SWEEP_HOME/Library/Caches/closed.app/file" bs=1024 count=2048 >/dev/null 2>&1
cat > "$bindir/pgrep" <<'EOF'
#!/bin/bash
if [[ "$1" == "-x" && "$2" == "Spotify" ]]; then
  exit 0
fi
exit 1
EOF
chmod +x "$bindir/pgrep"
go_note="$(printf '%s\n' go yes quit | PATH="$bindir:$PATH" SWEEP_MIN_KB=1024 "$SWEEP" menu | sed $'s/\033\\[[0-9;]*m//g')"
case "$go_note" in
  *'Left unticked'*Oldgone*) ;;
  *) fail 'go did not name a stays line it left behind' ;;
esac
test -d "$SWEEP_HOME/Library/Caches/com.spotify.client" || fail 'go removed a cache while its app was open'
test ! -e "$SWEEP_HOME/Library/Caches/closed.app" || fail 'go left a closed app cache'
test ! -e "$SWEEP_HOME/Library/Caches/com.example.liveapp" || fail 'go left a cache whose app is installed and closed'
test -d "$SWEEP_HOME/Library/Caches/com.example.nocacheapp" || fail 'go removed a cache whose app is gone'
test -d "$SWEEP_HOME/Library/Application Support/com.example.oldgone" || fail 'go removed an old leftover'
kept="$("$SWEEP" orphans)"
case "$kept" in
  *'Application Support/com.example.oldgone'*) ;;
  *) fail 'an old support leftover was hidden after go' ;;
esac
"$SWEEP" orphans remove com.example.oldgone --yes >/dev/null
test ! -e "$SWEEP_HOME/Library/Application Support/com.example.oldgone" || fail 'old support leftover survived'

cat > "$tmp/sims.txt" <<'EOF'
-- iOS 17.0 --
    iPhone 15 (AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE) (unavailable)
    iPad Air (BBBBBBBB-BBBB-CCCC-DDDD-EEEEEEEEEEEE) (Shutdown)
EOF
sims="$(SWEEP_SIM_LIST="$tmp/sims.txt" "$SWEEP" items simulators)"
case "$sims" in
  *'unknown'*'iPhone 15'*) ;;
  *) fail 'an unavailable simulator was not named with an unknown size' ;;
esac
case "$sims" in
  *'1.0 MB'*) fail 'a simulator was shown as 1.0 MB' ;;
esac
case "$sims" in
  *'iPad Air'*) fail 'a shutdown simulator was treated as unavailable' ;;
esac
sim_scan="$(SWEEP_SIM_LIST="$tmp/sims.txt" "$SWEEP" scan)"
case "$sim_scan" in
  *'iPhone 15'*) ;;
  *) fail 'scan hid an unavailable simulator' ;;
esac
case "$("$SWEEP" last all)" in
  *Spotify*) ;;
  *) fail 'last all hid an older removal' ;;
esac

mkdir -p "$SWEEP_HOME/Library/Developer/Xcode/DerivedData/OldApp" "$SWEEP_HOME/Library/Developer/Xcode/DerivedData/NewApp"
mkdir -p "$SWEEP_HOME/Library/Developer/Xcode/Archives/OldExport.xcarchive"
printf 'old' > "$SWEEP_HOME/Library/Developer/Xcode/DerivedData/OldApp/file"
printf 'new' > "$SWEEP_HOME/Library/Developer/Xcode/DerivedData/NewApp/file"
printf 'arc' > "$SWEEP_HOME/Library/Developer/Xcode/Archives/OldExport.xcarchive/file"
mkdir -p "$SWEEP_HOME/Library/Developer/Xcode/Archives/2024-05-01.xcarchive"
python3 - <<PY
import plistlib
p="$SWEEP_HOME/Library/Developer/Xcode/Archives/2024-05-01.xcarchive/Info.plist"
plistlib.dump({"Name":"DatedApp"}, open(p,"wb"))
PY
printf 'arc' > "$SWEEP_HOME/Library/Developer/Xcode/Archives/2024-05-01.xcarchive/file"
touch -t 202001010000 "$SWEEP_HOME/Library/Developer/Xcode/DerivedData/OldApp" \
  "$SWEEP_HOME/Library/Developer/Xcode/DerivedData/OldApp/file"
xcode_items="$("$SWEEP" items xcode)"
case "$xcode_items" in
  *'NewApp'*newest*) ;;
  *) fail 'the newest DerivedData project was not marked' ;;
esac
archive_items="$("$SWEEP" items archives)"
case "$archive_items" in
  *'OldExport.xcarchive,'*) ;;
  *) fail 'an archive was shown without a date' ;;
esac
case "$archive_items" in
  *'DatedApp,'*) ;;
  *) fail 'a date-named archive hid the app name' ;;
esac
"$SWEEP" clean --yes xcode >/dev/null
test ! -e "$SWEEP_HOME/Library/Developer/Xcode/DerivedData/OldApp" || fail 'an old DerivedData project survived'
test -d "$SWEEP_HOME/Library/Developer/Xcode/DerivedData/NewApp" || fail 'the newest DerivedData project was removed'

mkdir -p "$SWEEP_HOME/Library/Mobile Documents/com.example"
printf 'cloud' > "$SWEEP_HOME/Library/Mobile Documents/com.example/file"
large_out="$("$SWEEP" large)"
case "$large_out" in
  *'Mobile Documents'*) fail 'iCloud Drive was listed' ;;
esac
test -f "$SWEEP_HOME/Library/Mobile Documents/com.example/file" || fail 'iCloud Drive was removed'

mkdir -p "$SWEEP_HOME/Library/Caches/linked.dir"
printf 'same' > "$SWEEP_HOME/Library/Caches/linked.dir/file"
ln "$SWEEP_HOME/Library/Caches/linked.dir/file" "$SWEEP_HOME/Library/Caches/linked.dir/file2"
"$SWEEP" clean --yes caches >/dev/null 2>"$tmp/link.err" || true
test -f "$SWEEP_HOME/Library/Caches/linked.dir/file" || fail 'a hard-linked cache was removed'
case "$(cat "$tmp/link.err")" in
  *'shares bytes'*) ;;
  *) fail 'a shared file was removed without an explanation' ;;
esac

mkdir -p "$SWEEP_HOME/Library/Caches/locked.dir"
printf 'hid' > "$SWEEP_HOME/Library/Caches/locked.dir/file"
chmod 000 "$SWEEP_HOME/Library/Caches/locked.dir"
"$SWEEP" items caches >/dev/null 2>"$tmp/read.err" || true
chmod 755 "$SWEEP_HOME/Library/Caches/locked.dir"
case "$(cat "$tmp/read.err")" in
  *'Could not read'*locked.dir*) ;;
  *) fail 'an unreadable folder was silent' ;;
esac

chflags dataless "$SWEEP_HOME/Downloads/notes.txt" 2>/dev/null || true
flags="$(ls -ldO "$SWEEP_HOME/Downloads/notes.txt" 2>/dev/null || true)"
case "$flags" in
  *dataless*)
    "$SWEEP" clean --yes files >/dev/null 2>"$tmp/data.err" || true
    test -f "$SWEEP_HOME/Downloads/notes.txt" || fail 'an offline file was removed'
    case "$(cat "$tmp/data.err")" in
      *offline*) ;;
      *) fail 'an offline file was not explained' ;;
    esac
    ;;
esac
chflags nodataless "$SWEEP_HOME/Downloads/notes.txt" 2>/dev/null || true

mkdir -p "$SWEEP_HOME/Applications/Restore.app/Contents"
cat > "$SWEEP_HOME/Applications/Restore.app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.example.restore</string>
</dict></plist>
EOF
"$SWEEP" uninstall Restore --yes >/dev/null
test -d "$SWEEP_HOME/.Trash/Restore.app" || fail 'restore fixture was not moved to the Trash'
"$SWEEP" uninstall restore Restore >/dev/null
test -d "$SWEEP_HOME/Applications/Restore.app" || fail 'the app was not restored from the Trash'
test ! -e "$SWEEP_HOME/.Trash/Restore.app" || fail 'the restored app stayed in the Trash'

cat > "$tmp/btm.txt" <<'EOF'
com.apple.LSSharedFileList.SessionLoginItems
                 Name: com.apple.Safari
                 Name: Menu Helper
EOF
btm_out="$(SWEEP_BTM_LIST="$tmp/btm.txt" "$SWEEP" login)"
case "$btm_out" in
  *'Menu Helper'*) ;;
  *) fail 'a non-plist login item was hidden' ;;
esac
case "$btm_out" in
  *'com.apple.Safari'*) ;;
  *) fail 'an Apple login item was hidden' ;;
esac
case "$btm_out" in
  *'shown only'*) ;;
  *) fail 'a non-plist login item looked removable' ;;
esac
case "$btm_out" in
  *'Nothing below can be removed'*) ;;
  *) fail 'login items looked like one deletable list' ;;
esac

SWEEP_SIM_LIST="$tmp/sims.txt" "$SWEEP" clean simulators --only "iPhone 15" --yes >/dev/null
case "$(cat "$SWEEP_HOME/sim.deleted")" in
  *AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE*) ;;
  *) fail 'ticking one simulator did not remove that simulator' ;;
esac

mkdir -p "$SWEEP_HOME/Library/Caches/trim.me"
printf 't' > "$SWEEP_HOME/Library/Caches/trim.me/file"
SWEEP_RECEIPT_KEEP=2 "$SWEEP" clean caches --only trim.me --yes >/dev/null
kept="$(wc -l < "$SWEEP_HOME/.local/share/sweep/removed-caches.txt" | tr -d ' ')"
if [[ "$kept" -gt 2 ]]; then
  fail "the receipt kept $kept lines"
fi
case "$("$SWEEP" last)" in
  *'Homebrew downloads'*) ;;
  *) fail 'a cache wipe pushed the Homebrew receipt off the list' ;;
esac

mkdir -p "$SWEEP_HOME/Library/Application Support/MobileSync/Backup/only-phone"
python3 - <<PY
import datetime, plistlib
p="$SWEEP_HOME/Library/Application Support/MobileSync/Backup/only-phone/Info.plist"
plistlib.dump({"Device Name":"OnlyPhone","Last Backup Date":datetime.datetime(2024,5,1)}, open(p,"wb"))
PY
printf 'b' > "$SWEEP_HOME/Library/Application Support/MobileSync/Backup/only-phone/info"
backups="$("$SWEEP" items backups)"
case "$backups" in
  *'only backup of this device'*) ;;
  *) fail 'the only backup of a device was not marked' ;;
esac

mkdir -p "$SWEEP_HOME/Library/Developer/Xcode/iOS DeviceSupport/iPhone 17.4 (21E213)"
printf 's' > "$SWEEP_HOME/Library/Developer/Xcode/iOS DeviceSupport/iPhone 17.4 (21E213)/file"
devices="$("$SWEEP" items devices)"
case "$devices" in
  *'only copy of this version'*) ;;
  *) fail 'the only device-support folder was not marked' ;;
esac
case "$devices" in
  *'does not boot'*) ;;
  *) fail 'device support hid that the Mac does not boot from it' ;;
esac
backup_menu="$(printf 'backups\n1\nclean\nyes\nOnlyPhone\nquit\n' | "$SWEEP" menu | sed $'s/\033\\[[0-9;]*m//g')"
case "$backup_menu" in
  *'Type the device name'*) ;;
  *) fail 'the only backup did not ask for the device name' ;;
esac
case "$backup_menu" in
  *'Bye'*) ;;
  *) fail 'a backup confirm left the menu' ;;
esac
test ! -d "$SWEEP_HOME/Library/Application Support/MobileSync/Backup/only-phone" || fail 'a confirmed backup was kept'
device_menu="$(printf 'devices\n1\nclean\nyes\n21E213\nquit\n' | "$SWEEP" menu | sed $'s/\033\\[[0-9;]*m//g')"
case "$device_menu" in
  *'Type the system version'*) ;;
  *) fail 'the only device-support folder did not ask for the version' ;;
esac
test ! -d "$SWEEP_HOME/Library/Developer/Xcode/iOS DeviceSupport/iPhone 17.4 (21E213)" || fail 'a confirmed device-support folder was kept'

mkdir -p "$SWEEP_HOME/Downloads/OldInstallers"
printf 'i' > "$SWEEP_HOME/Downloads/OldInstallers/setup.dmg"
printf 'disk' > "$SWEEP_HOME/Downloads/Extra.dmg"
loose2="$("$SWEEP" items files)"
case "$loose2" in
  *OldInstallers*) ;;
  *) fail 'a folder in Downloads was not listed' ;;
esac
scan_dl="$("$SWEEP" scan)"
case "$scan_dl" in
  *downloads*) ;;
  *) fail 'scan hid installer downloads' ;;
esac
test -d "$SWEEP_HOME/Downloads/OldInstallers" || fail 'scan removed a downloads folder'

sample="$tmp/diskutil.txt"
printf 'Purgeable: 2.0 GB (2147483648 Bytes)\n' > "$sample"
purge_out="$(SWEEP_DISKUTIL_SAMPLE="$sample" "$SWEEP" scan)"
case "$purge_out" in
  *'sweep will not purge it'*) ;;
  *) fail 'purgeable space was hidden' ;;
esac

mkdir -p "$SWEEP_HOME/.Trash/Stamp.app"
printf 'old' > "$SWEEP_HOME/.Trash/Stamp.app/old"
mkdir -p "$SWEEP_HOME/Applications/Stamp.app/Contents"
cat > "$SWEEP_HOME/Applications/Stamp.app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.example.stamp</string>
</dict></plist>
EOF
"$SWEEP" uninstall Stamp --yes >/dev/null
stamped="$(find "$SWEEP_HOME/.Trash" -maxdepth 1 -name 'Stamp-*.app' -print)"
test -n "$stamped" || fail 'a second uninstall did not use a timestamped Trash name'
"$SWEEP" uninstall restore Stamp >/dev/null
test -d "$SWEEP_HOME/Applications/Stamp.app" || fail 'a timestamped Trash app was not restored'
test ! -e "$SWEEP_HOME/.Trash/Stamp-"*.app || fail 'the timestamped app stayed in the Trash'

dd if=/dev/zero of="$SWEEP_HOME/Applications/Stamp.app/payload" bs=1024 count=2048 >/dev/null 2>&1
app_list="$(printf 'quit\n' | SWEEP_MIN_KB=1024 "$SWEEP" menu | sed $'s/\033\\[[0-9;]*m//g')"
case "$app_list" in
  *Stamp*stays*) ;;
  *) fail 'an installed app was missing from the first list' ;;
esac
case "$app_list" in
  *'still measuring'*) ;;
  *) fail 'the first screen waited for every group' ;;
esac
info_app="$(printf 'info Stamp\nquit\n' | SWEEP_MIN_KB=1024 "$SWEEP" menu | sed $'s/\033\\[[0-9;]*m//g')"
case "$info_app" in
  *com.example.stamp*) ;;
  *) fail 'info hid the app bundle id' ;;
esac
case "$info_app" in
  *'Team none'*) ;;
  *) fail 'info hid the team id' ;;
esac
case "$info_app" in
  *'Restores to'*) ;;
  *) fail 'info hid the restore folder' ;;
esac
walk_app="$(printf 'walk stays\nno\nno\nno\nno\nno\nno\nno\nno\nquit\n' | SWEEP_MIN_KB=1024 "$SWEEP" menu | sed $'s/\033\\[[0-9;]*m//g')"
case "$walk_app" in
  *'move it to the Trash'*) ;;
  *) fail 'walk did not say an app goes to the Trash' ;;
esac
case "$walk_app" in
  *'delete it for good'*) ;;
  *) fail 'walk did not say a backup or leftover is deleted for good' ;;
esac
printf 'Stamp\nclean\nyes\nquit\n' | SWEEP_MIN_KB=1024 "$SWEEP" menu >/dev/null
test -d "$SWEEP_HOME/.Trash/Stamp.app" || fail 'ticking an app did not move it to the Trash'
test ! -d "$SWEEP_HOME/Applications/Stamp.app" || fail 'ticking an app deleted it in place'

page_out="$(printf 'more\nuninstall\n\nquit\n' | "$SWEEP" menu | sed $'s/\033\\[[0-9;]*m//g')"
case "$page_out" in
  *'Page 2'*) ;;
  *) fail 'uninstall returned to the first page' ;;
esac

printf 'loose' > "$SWEEP_HOME/.Trash/loose.txt"
"$SWEEP" clean --yes trash >/dev/null
test -d "$SWEEP_HOME/.Trash/Stamp.app" || fail 'emptying the Trash deleted an app'
test ! -e "$SWEEP_HOME/.Trash/loose.txt" || fail 'a loose Trash file survived'

mkdir -p "$SWEEP_HOME/Applications/Tiny.app/Contents"
cat > "$SWEEP_HOME/Applications/Tiny.app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.example.tiny</string>
</dict></plist>
EOF
tiny_menu="$(printf 'quit\n' | SWEEP_APP_MIN_KB=102400 "$SWEEP" menu | sed $'s/\033\\[[0-9;]*m//g')"
case "$tiny_menu" in
  *Tiny*) fail 'a small app was on the first list' ;;
esac
case "$("$SWEEP" uninstall)" in
  *Tiny*) ;;
  *) fail 'uninstall hid a small app' ;;
esac

mkdir -p "$SWEEP_HOME/Applications/OpenMe.app/Contents"
cat > "$SWEEP_HOME/Applications/OpenMe.app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.example.openme</string>
  <key>CFBundleExecutable</key><string>OpenBin</string>
</dict></plist>
EOF
cat > "$bindir/pgrep" <<'EOF'
#!/bin/bash
if [[ "$1" == "-x" && "$2" == "OpenBin" ]]; then
  exit 0
fi
exit 1
EOF
chmod +x "$bindir/pgrep"
open_menu="$(printf 'OpenMe\nclean\nyes\nquit\n' | PATH="$bindir:$PATH" "$SWEEP" menu | sed $'s/\033\\[[0-9;]*m//g')"
case "$open_menu" in
  *'is open'*) ;;
  *) fail 'an open app was moved without a warning' ;;
esac
case "$open_menu" in
  *'Bye'*) ;;
  *) fail 'refusing an open app left the menu' ;;
esac
test -d "$SWEEP_HOME/Applications/OpenMe.app" || fail 'an open app was moved to the Trash'

mkdir -p "$SWEEP_HOME/Applications/Two.app/Contents" "$SWEEP_HOME/Applications/TwoCopy.app/Contents"
cat > "$SWEEP_HOME/Applications/Two.app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.example.two</string>
</dict></plist>
EOF
cp "$SWEEP_HOME/Applications/Two.app/Contents/Info.plist" "$SWEEP_HOME/Applications/TwoCopy.app/Contents/Info.plist"
copy_menu="$(printf 'Two\nclean\nyes\nquit\n' | "$SWEEP" menu | sed $'s/\033\\[[0-9;]*m//g')"
case "$copy_menu" in
  *'Another copy'*) ;;
  *) fail 'a second copy was moved without a warning' ;;
esac
case "$copy_menu" in
  *'Bye'*) ;;
  *) fail 'refusing a second copy left the menu' ;;
esac
test -d "$SWEEP_HOME/Applications/Two.app" || fail 'a second copy was moved to the Trash'

i=1
while [[ "$i" -le 5 ]]; do
  dd if=/dev/zero of="$SWEEP_HOME/Downloads/stay$i.bin" bs=1024 count=3072 >/dev/null 2>&1
  i=$((i + 1))
done
stay_note="$(printf 'go\nyes\nquit\n' | SWEEP_MIN_KB=1024 "$SWEEP" menu | sed $'s/\033\\[[0-9;]*m//g')"
case "$stay_note" in
  *', and '*more*) ;;
  *) fail 'go hid the rest of the stays list' ;;
esac

if cp -c "$SWEEP_HOME/Downloads/notes.txt" "$SWEEP_HOME/Downloads/notes-copy.txt" 2>/dev/null; then
  "$SWEEP" clean --yes files >/dev/null 2>"$tmp/clone.err" || true
  test -f "$SWEEP_HOME/Downloads/notes.txt" || fail 'an APFS clone was removed'
  test -f "$SWEEP_HOME/Downloads/notes-copy.txt" || fail 'an APFS clone copy was removed'
  case "$(cat "$tmp/clone.err")" in
    *notes.txt*|*notes-copy.txt*|*'cannot see which copy'*) ;;
    *) fail 'an APFS clone was skipped without naming a copy' ;;
  esac
fi

sparse="$SWEEP_HOME/Downloads/sparse.bin"
dd if=/dev/zero of="$sparse" bs=1 count=1 seek=10485760 >/dev/null 2>&1 || true
if [[ -f "$sparse" ]]; then
  logical="$(stat -f %z "$sparse")"
  allocated="$(du -sk "$sparse" | awk '{print $1}')"
  if [[ "${logical:-0}" -gt $((allocated * 1024 * 4)) ]]; then
    sparse_info="$(printf 'files\ninfo sparse.bin\nquit\n' | "$SWEEP" menu | sed $'s/\033\\[[0-9;]*m//g')"
    case "$sparse_info" in
      *'On disk'*'claims'*) ;;
      *) fail 'info hid a file that claims more than it uses' ;;
    esac
  fi
fi

mkdir -p "$SWEEP_HOME/.Trash/Kept.app"
dd if=/dev/zero of="$SWEEP_HOME/.Trash/Kept.app/payload" bs=1024 count=8192 >/dev/null 2>&1
printf 'loose' > "$SWEEP_HOME/.Trash/loose-go.txt"
go_trash="$(printf 'go\nyes\nquit\n' | "$SWEEP" menu | sed $'s/\033\\[[0-9;]*m//g')"
test -d "$SWEEP_HOME/.Trash/Kept.app" || fail 'go deleted an app that was already in the Trash'
test ! -e "$SWEEP_HOME/.Trash/loose-go.txt" || fail 'go left a loose Trash file'
left_line="$(printf '%s\n' "$go_trash" | grep 'Left unticked' || true)"
case "$left_line" in
  *Kept*) ;;
  *) fail 'go did not name the trashed app it left' ;;
esac
case "$left_line" in
  *loose-go*) fail 'go said it left a trash file it deleted' ;;
esac
measuring_n="$(printf '%s\n' "$go_trash" | grep -c 'still measuring' || true)"
if [[ "$measuring_n" -ne 1 ]]; then
  fail "a finished menu said groups were still measuring ($measuring_n)"
fi

mkdir -p "$SWEEP_HOME/Library/Caches/zz.walked"
dd if=/dev/zero of="$SWEEP_HOME/Library/Caches/zz.walked/file" bs=1024 count=16384 >/dev/null 2>&1
walk_out="$(printf 'walk\nno\nquit\nwalk\nquit\nquit\n' | "$SWEEP" menu | sed $'s/\033\\[[0-9;]*m//g')"
walk_names="$(printf '%s\n' "$walk_out" | awk '/ of [0-9]/ { print name } { name=prev; prev=$0 }')"
first_walk="$(printf '%s\n' "$walk_names" | head -n 1)"
second_walk="$(printf '%s\n' "$walk_names" | sed -n '2p')"
case "$first_walk" in
  *zz.walked*) ;;
  *) fail 'walk did not start at the large cache' ;;
esac
case "$second_walk" in
  *zz.walked*) fail 'walk repeated a folder that was kept' ;;
esac
[[ -n "$second_walk" ]] || fail 'the next walk had no folder'

mkdir -p "$SWEEP_HOME/Library/Caches/sizeme"
dd if=/dev/zero of="$SWEEP_HOME/Library/Caches/sizeme/file" bs=1024 count=8 >/dev/null 2>&1
"$SWEEP" items caches >/dev/null
dd if=/dev/zero of="$SWEEP_HOME/Library/Caches/sizeme/file" bs=1024 count=2048 >/dev/null 2>&1
size_line="$( "$SWEEP" items caches | grep sizeme || true)"
case "$size_line" in
  *'2.0 MB'*) fail 'a saved size was ignored while the folder date was unchanged' ;;
esac
touch "$SWEEP_HOME/Library/Caches/sizeme"
size_line="$( "$SWEEP" items caches | grep sizeme || true)"
case "$size_line" in
  *'2.0 MB'*) ;;
  *) fail 'a changed folder kept its old size' ;;
esac

mkdir -p "$SWEEP_HOME/Library/Caches/Homebrew"
printf 'old' > "$SWEEP_HOME/Library/Caches/Homebrew/cccccccc--curl--1.0.tar.gz"
printf 'new' > "$SWEEP_HOME/Library/Caches/Homebrew/dddddddd--curl--1.2.tar.gz"
touch -t 201901010000 "$SWEEP_HOME/Library/Caches/Homebrew/cccccccc--curl--1.0.tar.gz"
touch -t 202001010000 "$SWEEP_HOME/Library/Caches/Homebrew/dddddddd--curl--1.2.tar.gz"
first_brew="$(printf 'quit\n' | PATH="$bindir:$PATH" "$SWEEP" menu | sed $'s/\033\\[[0-9;]*m//g')"
case "$first_brew" in
  *curl--1.0*) fail 'Homebrew was on the first screen' ;;
esac
printf 'go\nyes\nquit\n' | PATH="$bindir:$PATH" "$SWEEP" menu >/dev/null
test ! -e "$SWEEP_HOME/Library/Caches/Homebrew/cccccccc--curl--1.0.tar.gz" || fail 'go skipped a Homebrew download that was not on the first screen'
test -f "$SWEEP_HOME/Library/Caches/Homebrew/dddddddd--curl--1.2.tar.gz" || fail 'go removed the newest Homebrew download'

mkdir -p "$SWEEP_HOME/Library/Developer/Xcode/DerivedData/OldZ" "$SWEEP_HOME/Library/Developer/Xcode/DerivedData/NewZ"
printf 'old' > "$SWEEP_HOME/Library/Developer/Xcode/DerivedData/OldZ/file"
printf 'new' > "$SWEEP_HOME/Library/Developer/Xcode/DerivedData/NewZ/file"
touch -t 201901010000 "$SWEEP_HOME/Library/Developer/Xcode/DerivedData/OldZ" \
  "$SWEEP_HOME/Library/Developer/Xcode/DerivedData/OldZ/file"
printf 'go\nyes\nquit\n' | "$SWEEP" menu >/dev/null
test ! -e "$SWEEP_HOME/Library/Developer/Xcode/DerivedData/OldZ" || fail 'go skipped an old Xcode build'

mkdir -p "$SWEEP_HOME/Pictures/Photos Library.photoslibrary/proj/node_modules" \
  "$SWEEP_HOME/Music/album/node_modules" \
  "$SWEEP_HOME/src/keptproj/node_modules"
printf '{}' > "$SWEEP_HOME/src/keptproj/package.json"
printf '{}' > "$SWEEP_HOME/Pictures/Photos Library.photoslibrary/proj/package.json"
printf '{}' > "$SWEEP_HOME/Music/album/package.json"
printf 'n' > "$SWEEP_HOME/src/keptproj/node_modules/n"
printf 'n' > "$SWEEP_HOME/Pictures/Photos Library.photoslibrary/proj/node_modules/n"
printf 'n' > "$SWEEP_HOME/Music/album/node_modules/n"
proj_list="$("$SWEEP" items projects)"
case "$proj_list" in
  *keptproj*) ;;
  *) fail 'a project outside Pictures was hidden' ;;
esac
case "$proj_list" in
  *photoslibrary*|*Music/album*) fail 'the project search walked Pictures or Music' ;;
esac

mkdir -p "$SWEEP_HOME/Library/Caches/linked.menu"
printf 'same' > "$SWEEP_HOME/Library/Caches/linked.menu/file"
ln "$SWEEP_HOME/Library/Caches/linked.menu/file" "$SWEEP_HOME/Library/Caches/linked.menu/file2"
link_menu="$(printf 'linked.menu\nclean\nyes\nquit\n' | "$SWEEP" menu | sed $'s/\033\\[[0-9;]*m//g')"
test -f "$SWEEP_HOME/Library/Caches/linked.menu/file" || fail 'the menu removed a shared file'
case "$link_menu" in
  *'Left in place'*linked.menu*) ;;
  *) fail 'the menu counted a skipped file as removed' ;;
esac

mkdir -p "$SWEEP_HOME/pnpm-store/v3"
printf 'pkg' > "$SWEEP_HOME/pnpm-store/v3/pkg"
cat > "$bindir/pnpm" <<'EOF'
#!/bin/bash
if [[ "$1" == "store" && "$2" == "path" ]]; then
  printf '%s\n' "$SWEEP_HOME/pnpm-store/v3"
  exit 0
fi
if [[ "$1" == "store" && "$2" == "prune" ]]; then
  printf 'prune\n' >> "$SWEEP_HOME/pnpm.called"
  exit 0
fi
exit 0
EOF
chmod +x "$bindir/pnpm"
pnpm_items="$(PATH="$bindir:$PATH" "$SWEEP" items dev)"
case "$pnpm_items" in
  *'pnpm store'*) ;;
  *) fail 'the pnpm store was not listed' ;;
esac
PATH="$bindir:$PATH" "$SWEEP" clean dev >/dev/null
test -f "$SWEEP_HOME/pnpm-store/v3/pkg" || fail 'a dry run deleted the pnpm store'
PATH="$bindir:$PATH" "$SWEEP" clean --yes dev >/dev/null
case "$(cat "$SWEEP_HOME/pnpm.called")" in
  *prune*) ;;
  *) fail 'the pnpm store was removed without pnpm store prune' ;;
esac

rm -rf "$SWEEP_HOME/Library/Application Support/MobileSync/Backup"
mkdir -p "$SWEEP_HOME/Library/Application Support/MobileSync/Backup/only-phone"
python3 - <<PY
import datetime, plistlib
p="$SWEEP_HOME/Library/Application Support/MobileSync/Backup/only-phone/Info.plist"
plistlib.dump({"Device Name":"OnlyPhone","Last Backup Date":datetime.datetime(2024,5,1)}, open(p,"wb"))
PY
printf 'b' > "$SWEEP_HOME/Library/Application Support/MobileSync/Backup/only-phone/info"
printf 'nope\n' | SWEEP_FORCE_CONFIRM=1 "$SWEEP" clean --yes backups >/dev/null
test -d "$SWEEP_HOME/Library/Application Support/MobileSync/Backup/only-phone" || fail 'a wrong device name deleted the only backup'
printf 'OnlyPhone\n' | SWEEP_FORCE_CONFIRM=1 "$SWEEP" clean --yes backups >/dev/null
test ! -d "$SWEEP_HOME/Library/Application Support/MobileSync/Backup/only-phone" || fail 'the device name did not confirm the backup'

rm -rf "$SWEEP_HOME/Library/Developer/Xcode/iOS DeviceSupport"
mkdir -p "$SWEEP_HOME/Library/Developer/Xcode/iOS DeviceSupport/iPhone 17.4 (21E213)"
printf 's' > "$SWEEP_HOME/Library/Developer/Xcode/iOS DeviceSupport/iPhone 17.4 (21E213)/file"
printf 'nope\n' | SWEEP_FORCE_CONFIRM=1 "$SWEEP" clean --yes devices >/dev/null
test -d "$SWEEP_HOME/Library/Developer/Xcode/iOS DeviceSupport/iPhone 17.4 (21E213)" || fail 'a wrong version deleted the only device-support folder'
printf '21E213\n' | SWEEP_FORCE_CONFIRM=1 "$SWEEP" clean --yes devices >/dev/null
test ! -d "$SWEEP_HOME/Library/Developer/Xcode/iOS DeviceSupport/iPhone 17.4 (21E213)" || fail 'the system version did not confirm device support'

i=1
while [[ "$i" -le 5 ]]; do
  dd if=/dev/zero of="$SWEEP_HOME/Downloads/stay$i.bin" bs=1024 count=2048 >/dev/null 2>&1
  i=$((i + 1))
done
stay_list="$(printf 'stays\n\nquit\n' | SWEEP_MIN_KB=1024 "$SWEEP" menu | sed $'s/\033\\[[0-9;]*m//g')"
i=1
while [[ "$i" -le 5 ]]; do
  case "$stay_list" in
    *"stay$i.bin"*) ;;
    *) fail "stays hid stay$i.bin" ;;
  esac
  i=$((i + 1))
done

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -s bash "$ROOT/sweep" "$ROOT/install.sh"
fi

printf 'ok\n'
