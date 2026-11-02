# sweep

A quiet disk cleaner for macOS. Open it, type a number, tick the folders you want, then type `yes`. Nothing is deleted before that.

![sweep menu, with Spotify ticked](docs/menu.png)

Paid cleaner apps charge you to empty caches, then sell a subscription on top. sweep is one command, the list of paths is in the source, and it does not free RAM, scan for viruses, or phone home.

## Install

From Terminal:

```bash
brew tap kprobe0/sweep https://github.com/kprobe0/sweep
brew install kprobe0/sweep/sweep
```

That installs the [0.14.0 archive](https://github.com/kprobe0/sweep/archive/refs/tags/v0.14.0.tar.gz). Its SHA-256 is `881a879dc334e119c1c44f6afca5b13591681c3a032c5fbf00af4bc33c291f86`.

Or paste this and press Return:

```bash
curl -fsSL https://raw.githubusercontent.com/kprobe0/sweep/main/install.sh | bash
```

That downloads the tagged 0.14.0 script and stops if its SHA-256 is not `34932bbb0d788b747235c4272491bdd3612a9f9de96efd08e3bde21d1b26e040`.

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

`sweep` opens on the biggest folders, largest first, with plain names (Spotify, not a bundle id). `rebuilds` means the app or tool creates it again. `stays` means the space stays gone, which is why backups and old installers are not part of `go`. `ask first` and `app open` mean look before you delete.

- Type `1` or `1 3` to tick lines. Type `Spotify` to tick that line.
- Type `more` for the next page, and `find music` to show only matching names.
- Type `clean`, then type `yes`, to delete what you ticked.
- Press Return instead of `yes` to cancel.
- Type `caches`, `trash`, `dev`, or `backups` to open just that list.
- Type `groups` for the short list of those names.
- Type `safe`, then `yes`, to clear the usual caches and leave backups alone.
- Type `go`, then `yes`, to remove the safe folders on the list. Folders under 1 MB stay hidden until you type `small`. `go` leaves a folder alone when its app is still open, and it names the `stays` lines it did not touch.
- Type `walk stays` to answer yes or no for backups, installers, and leftovers.
- Type `walk` to go one safe folder at a time. `yes` deletes it, `no` keeps it, `quit` stops.
- Type `help` if you want the rest of the commands, and `quit` to leave.
- Type `info 1` to see the real folder for a line. Type `last` to see what was already removed.
- Type `uninstall` for a numbered list of apps. The preview shows the team id, any package receipt, a container note, the preference file, and shared folders. Shared folders and the preference file are shown and never deleted. Type `yes` and the app moves to the Trash. Leftovers stay unticked.
- Type `login` for helpers whose program is already gone. A helper that still exists is not on the list. Nothing is selected.
- A folder left behind by an app appears on the first list after it has sat unused for 30 days, marked `stays`, unticked. A cache whose app is gone is also `stays`, and `go` leaves it. `go` still clears caches of apps that are installed.
- Type `info 1` for the path. On a leftover it also shows the bundle id, how many days it has been unused, and that no installed app owns it.
- `sweep last` records the date, the size, the name, and the path. `sweep last all` prints the whole receipt.
- `go` and `clean` delete for good. They do not move those folders to the Trash.

## Commands

```bash
sweep
sweep items caches
sweep clean caches --only "Google/AndroidStudio" --yes
sweep scan
sweep large
sweep orphans
sweep orphans remove com.example.oldapp --yes
sweep uninstall Name
sweep last all
sweep clean homebrew --empty --yes
```

`sweep clean --yes` covers caches the system or the tool will rebuild: user caches whose app is still installed, Homebrew downloads older than 120 days, npm and the other dev caches, Xcode DerivedData, a few app caches, old logs, Quick Look thumbnails, and the Trash. `sweep clean homebrew --empty --yes` clears the rest of the Homebrew cache.

These stay put unless you name them:

| Group | What it removes |
| --- | --- |
| `browsers` | Safari, Chrome, Firefox, Brave, Arc, Edge, Opera caches |
| `archives` | Xcode archives |
| `devices` | iOS, watch, tv, and vision device-support files |
| `simulators` | Simulators whose runtime is no longer installed, listed by name. Cleaning them removes every unavailable simulator |
| `docker` | Stopped containers, dangling images, unused networks |
| `backups` | One line per iPhone or iPad backup, with the device and the date. This cannot be undone |
| `downloads` | Disk images and installers: `.dmg`, `.pkg`, `.mpkg`, `.iso`, and a `.zip` whose name looks like an installer |
| `files` | Other files in Downloads. Unticked, and not part of `go` |
| `partial` | Unfinished downloads, `.download` and `.crdownload` |
| `projects` | `node_modules` next to a `package.json`, Cargo `target`, Swift `.build`, `__pycache__` |

CloudKit, HomeKit, and Family Sharing caches are left alone. Documents, Desktop, Photos, Music, Movies, Mail, Messages, Preferences, and `~/.ssh` are never deleted. Crash reports in DiagnosticReports are kept.

Quit a browser before `sweep clean browsers --yes`. That clears the page cache. Cookies live somewhere else and stay put.

The free-space line names purgeable space when Disk Utility reports it. sweep does not purge it. A local Time Machine snapshot is named and is not deleted.

Set `NO_COLOR` to any non-empty value for plain text. `man sweep` describes the same rules after the manual page is installed. The release steps are in `RELEASE.md`.

## Why the first run can sit there

Measuring `~/Library/Caches` means reading the size of every folder in it. That is the slow part. The delete, once you ask for it, is the fast part.
