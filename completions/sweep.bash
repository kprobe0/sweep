# bash completion for sweep
_sweep() {
  local cur prev words apps
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  if [[ "$prev" == "uninstall" || "$prev" == "restore" ]]; then
    apps="$(sweep uninstall 2>/dev/null | awk '/^  [^ ]/ && $2=="" { print $1 }')"
    # shellcheck disable=SC2207
    COMPREPLY=( $(compgen -W "$apps restore" -- "$cur") )
    return
  fi
  words="scan clean large help menu items last login uninstall orphans projects walk \
caches homebrew dev xcode apps quicklook logs trash \
browsers archives devices simulators docker backups downloads partial files \
--yes --only --leftovers --empty --dry-run --version --help all remove restore stays"
  # shellcheck disable=SC2207
  COMPREPLY=( $(compgen -W "$words" -- "$cur") )
}
complete -F _sweep sweep
