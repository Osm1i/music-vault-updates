# Music Vault private update channel

Repository: Osm1i/music-vault-updates

## How releases are published

A push to main that changes files under release-assets/ starts the GitHub Actions workflow at .github/workflows/publish-music-vault-release.yml.

The workflow concatenates the fourteen ordered files in release-assets/package-b64/ (part-00a through part-00j, then part-01 through part-04), decodes the gzip tar archive, verifies its integrity and embedded version, creates the flat updater ZIP, calculates its SHA-256, generates music-vault-update-manifest.json, and publishes stable release vX.Y.Z.

## Requirements for future releases

- Increase release-assets/MUSIC_VAULT_RELEASE_VERSION.txt using semantic version format and never reuse a published tag.
- Replace all fourteen ordered base64 chunks in release-assets/package-b64/ with chunks from the new complete gzip tar archive. Keep the file names and concatenation order exactly as documented.
- Ensure the archive contains MUSIC_VAULT_RELEASE_VERSION.txt, the version-matched checksum file, and install-update.sh at its root.
- The installer must back up every changed app file, leave user data out of the package, run checks before restart, restart music-vault.service, verify http://127.0.0.1:8788/, and fail cleanly so the updater can roll back.
- Never include music, SQLite databases, profiles, playlists, favorites, EQ settings, tokens, secrets, or backups.
- Update release-assets/RELEASE_NOTES.md, then commit the version, chunks and notes to main. GitHub Actions publishes the release assets automatically.

The v8.12.1 release is the initial baseline. Vanguard 9.0.0 is the first full app-design release.
