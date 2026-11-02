# bash completion for sweep
_sweep() {
  local cur words
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  words="scan clean large help menu items last login uninstall orphans projects \
caches homebrew dev xcode apps quicklook logs trash \
browsers archives devices simulators docker backups downloads partial \
--yes --only --leftovers --empty --dry-run --version --help all remove"
  # shellcheck disable=SC2207
  COMPREPLY=( $(compgen -W "$words" -- "$cur") )
}
complete -F _sweep sweep
