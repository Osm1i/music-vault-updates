# Music Vault private update channel

Repository: Osm1i/music-vault-updates

## How releases are published

A push to main that changes files under release-assets/ starts the GitHub Actions workflow at .github/workflows/publish-music-vault-release.yml.

The workflow reads the semantic version, packages release-assets/package/ into a flat ZIP with MUSIC_VAULT_RELEASE_VERSION.txt at its root, calculates SHA-256, creates the updater manifest, and publishes stable release vX.Y.Z with the two required assets.

## Requirements for each real future update

- Increase the semantic version and never reuse a release tag.
- Put the complete transactional install-update.sh and every required application file in release-assets/package/.
- Keep release-assets/MUSIC_VAULT_RELEASE_VERSION.txt matched to the release version.
- Back up every changed app file, keep user data out of packages, test before restart where practical, restart music-vault.service, verify http://127.0.0.1:8788/, and restore changed files if anything fails.
- Never include music, SQLite databases, profiles, playlists, favorites, EQ settings, tokens, secrets, or backups.
- Commit the updated release-assets/ files to main; GitHub Actions publishes the release automatically.

The initial v8.12.1 release is a baseline-only no-op because that version is already installed.
