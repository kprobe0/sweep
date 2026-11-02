#!/bin/bash
# Install sweep into ~/.local/bin, or $PREFIX/bin.
# A download is checked against the tagged script before it is copied into place.
set -euo pipefail

dest="${PREFIX:-$HOME/.local/bin}"
release_version="0.14.0"
url="https://raw.githubusercontent.com/kprobe0/sweep/v${release_version}/sweep"
expected_sha="34932bbb0d788b747235c4272491bdd3612a9f9de96efd08e3bde21d1b26e040"

mkdir -p "$dest"

source_dir=""
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  source_dir="$(dirname "${BASH_SOURCE[0]}")"
  got_dir="$(unset CDPATH; cd -- "$source_dir" 2>/dev/null && pwd)" || got_dir=""
  source_dir="$got_dir"
fi

if [[ -n "$source_dir" && -f "$source_dir/sweep" ]]; then
  install -m 755 "$source_dir/sweep" "$dest/sweep"
else
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  curl -fsSL "$url" -o "$tmp"
  got="$(shasum -a 256 "$tmp" | awk '{print $1}')"
  if [[ "$got" != "$expected_sha" ]]; then
    printf 'Refusing to install. The downloaded script did not match the published SHA-256.\n' >&2
    printf '  expected %s\n  got      %s\n' "$expected_sha" "$got" >&2
    exit 1
  fi
  install -m 755 "$tmp" "$dest/sweep"
fi

printf 'Installed %s\n' "$dest/sweep"
case ":$PATH:" in
  *":$dest:"*) ;;
  *) printf "Add it to your PATH:\n  export PATH=\"%s:\$PATH\"\n" "$dest" ;;
esac
