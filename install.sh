#!/bin/bash
# Install sweep into ~/.local/bin, or $PREFIX/bin.
set -euo pipefail

dest="${PREFIX:-$HOME/.local/bin}"
mkdir -p "$dest"
url="https://raw.githubusercontent.com/kprobe0/sweep/main/sweep"

source_dir=""
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  source_dir="$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
fi

if [[ -n "$source_dir" && -f "$source_dir/sweep" ]]; then
  install -m 755 "$source_dir/sweep" "$dest/sweep"
else
  curl -fsSL "$url" -o "$dest/sweep"
  chmod 755 "$dest/sweep"
fi

printf 'Installed %s\n' "$dest/sweep"
case ":$PATH:" in
  *":$dest:"*) ;;
  *) printf 'Add it to your PATH:\n  export PATH="%s:$PATH"\n' "$dest" ;;
esac
