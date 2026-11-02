# Releasing sweep

The tag is the script people install. The commit after the tag only records the checksums. Do not put a checksum in the same commit the tag will hash.

1. Bump `VERSION` in `sweep` and the matching check in `test/test_sweep.sh`.
2. Run `bash test/test_sweep.sh`. If shellcheck is installed, run `shellcheck -s bash sweep install.sh`.
3. Commit that work and tag it `vX.Y.Z`. Push the commit and the tag.
4. Download the GitHub archive, not a `git archive`:

   `https://github.com/kprobe0/sweep/archive/refs/tags/vX.Y.Z.tar.gz`

5. Record its SHA-256 in `Formula/sweep.rb`.
6. Download the raw script at `https://raw.githubusercontent.com/kprobe0/sweep/vX.Y.Z/sweep` and record that SHA-256 in `install.sh` and the README.
7. Point the formula `url` at the tag. Keep `head` for people who want `main`.
8. Commit the formula, `install.sh`, and the README checksums. Push that commit. Do not move the tag.
9. Publish a GitHub release on the tag with both checksums.
10. Leave GitHub Actions off while the account is locked on a billing issue. A workflow only adds a failed check until that lock is cleared.

`go` and `clean` delete for good. Say so in the release notes when that behavior changes. The app uninstall moves the app to the Trash.
