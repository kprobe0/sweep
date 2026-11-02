# Contributing

sweep is a quiet disk cleaner. A change should make the list clearer, or make a delete harder to get wrong.

## Pull requests

- Keep the script on bash 3.2. That is the bash macOS ships.
- Run `bash test/test_sweep.sh` before you open a request.
- Run `shellcheck -s bash sweep install.sh` when shellcheck is installed.
- Commits on this repository use the account name kprobe0 only.

## These stay out

Do not add any of these, even as an optional flag:

- a RAM button, or any claim that deleting caches makes the Mac faster
- a virus, malware, or "critical" score
- wiping cookies, history, passwords, or autofill
- similar-photo or duplicate-photo cleanup
- stripping `.lproj` language files out of apps
- a System Data number, or a promise to shrink that bar
- a scheduled or unattended clean
- an update check that phones home
- Full Disk Access, other users' home folders, or `pkgutil --forget`

Documents, Desktop, Pictures, Movies, Music, Mail, Messages, Preferences, and `~/.ssh` stay out of the delete list. A preference file may be shown. It is not deleted.

Shared folders, including a vendor folder such as `Adobe` and a group container that belongs to more than one app, are shown and never selected.
