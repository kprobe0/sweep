# sweep

A quiet disk cleaner for macOS. Open it, type a number, tick the folders you want, then type `yes`. Nothing is deleted before that.

Paid cleaner apps charge you to empty caches, then sell a subscription on top. sweep is one command, the list of paths is in the source, and it does not free RAM, scan for viruses, or phone home.

## Install

Open Terminal, paste this, and press Return:

```bash
curl -fsSL https://raw.githubusercontent.com/kprobe0/sweep/main/install.sh | bash
```

If it says to add a PATH line, paste that too. Then type:

```bash
sweep
```

You can also install from a clone:

```bash
git clone https://github.com/kprobe0/sweep.git
cd sweep
make install
```

## The menu

`sweep` opens a list. Type a number and press Return. That opens the folders inside it.

- Type `1` or `1 3` to tick lines.
- Type `all` to tick every line in that list.
- Type `clean`, then type `yes` to delete the ticked lines.
- Press Return, or type anything other than `yes`, to cancel.
- Type `back` for the first list, and `quit` to leave.

`all` on the first screen deletes the safe groups only, and only after you type `yes`. Backups, browsers, and device files are not in that set. Open them by number if you want them.

## Commands

```bash
sweep
sweep items caches
sweep clean caches --only "Google/AndroidStudio" --yes
sweep scan
sweep large
```

`sweep clean --yes` covers caches the system or the tool will rebuild: user caches, Homebrew, npm and the other dev caches, Xcode DerivedData, a few app caches, old logs, Quick Look thumbnails, and the Trash.

These stay put unless you name them:

| Group | What it removes |
| --- | --- |
| `browsers` | Safari, Chrome, Firefox, Brave, Arc, Edge, Opera caches |
| `archives` | Xcode archives |
| `devices` | iOS, watch, tv, and vision device-support files |
| `simulators` | Simulators whose runtime is no longer installed |
| `docker` | Stopped containers, dangling images, unused networks |
| `backups` | iPhone and iPad backups. This cannot be undone |
| `projects` | `node_modules` next to a `package.json`, Cargo `target`, Swift `.build`, `__pycache__` |

CloudKit, HomeKit, and Family Sharing caches are left alone. Documents, Desktop, Photos, Music, Movies, Mail, Messages, Preferences, and `~/.ssh` are never deleted. Crash reports in DiagnosticReports are kept.

Quit a browser before `sweep clean browsers --yes`. That clears the page cache. Cookies live somewhere else and stay put.

## Why the first run can sit there

Measuring `~/Library/Caches` means reading the size of every folder in it. That is the slow part. The delete, once you ask for it, is the fast part.
