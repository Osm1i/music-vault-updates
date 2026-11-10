# Music Vault private update channel

Repository: Osm1i/music-vault-updates

## How releases are published

A push to main that changes files under release-assets/ starts the GitHub Actions workflow at .github/workflows/publish-music-vault-release.yml.

The workflow decodes release-assets/music-vault-update-package.tar.gz.b64, verifies the gzip archive and embedded version, creates the flat updater ZIP, calculates its SHA-256, generates music-vault-update-manifest.json, and publishes stable release vX.Y.Z.

## Requirements for future releases

- Increase release-assets/MUSIC_VAULT_RELEASE_VERSION.txt using semantic version format and never reuse a published tag.
- Replace release-assets/music-vault-update-package.tar.gz.b64 with the base64-encoded gzip tar archive of the complete package.
- Ensure the package contains MUSIC_VAULT_RELEASE_VERSION.txt, SHA256SUMS_9_0.txt (or the matching new version checksum list), and install-update.sh at its root.
- The installer must back up every changed app file, leave user data out of the package, run checks before restart, restart music-vault.service, verify http://127.0.0.1:8788/, and fail cleanly so the updater can roll back.
- Never include music, SQLite databases, profiles, playlists, favorites, EQ settings, tokens, secrets, or backups.
- Update release-assets/RELEASE_NOTES.md, then commit the version, archive and notes to main. GitHub Actions publishes the release assets automatically.

The v8.12.1 release is the initial baseline. Vanguard 9.0.0 is the first full app-design release.
