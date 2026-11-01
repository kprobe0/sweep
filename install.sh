#!/bin/bash
# Install sweep into ~/.local/bin, or $PREFIX/bin.
# A download is checked against the tagged script before it is copied into place.
set -euo pipefail

dest="${PREFIX:-$HOME/.local/bin}"
release_version="0.13.0"
url="https://raw.githubusercontent.com/kprobe0/sweep/v${release_version}/sweep"
expected_sha="0bba7e30e2946ef3a0c6f281de39ea13748b8642c1e0e61abf5e35cef1f5fc55"

mkdir -p "$dest"

source_dir=""
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  source_dir="$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
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
  *) printf 'Add it to your PATH:\n  export PATH="%s:$PATH"\n' "$dest" ;;
esac
