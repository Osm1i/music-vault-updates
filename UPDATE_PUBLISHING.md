# Music Vault update publishing

Release channel: `Osm1i/music-vault-updates`

## Stable releases

The workflow in `.github/workflows/publish-music-vault-release.yml` rebuilds a release from the ordered archive chunks under `release-assets/package-b64/`. It validates the gzip archive, extracts the release package, runs the version-specific preparation script, verifies JavaScript and shell syntax, recalculates package SHA-256 checksums, builds the CasaOS ZIP and publishes the stable release.

To publish the next release, update all package chunks and notes first, then update `release-assets/MUSIC_VAULT_RELEASE_VERSION.txt` last. That final version-file commit triggers the workflow.

## Vanguard 9.1.0 Velocity Edition

The 9.1.0 workflow preparation script is `.github/velocity-9.1/prepare_release.py`. It adds the performance assets, advances the service-worker cache version, injects additive stylesheet/script references into the existing installer, updates the embedded version, and regenerates the package checksum manifest.

The 9.1 runtime improvements include native lazy loading for below-the-fold artwork, asynchronous image decoding, bounded MutationObserver work for dynamically added library content, and CSS content-visibility for long album/track collections.

## Safety requirements

- Keep release ZIPs free of music, SQLite databases, personal profiles, playlists, favorites, EQ settings, tokens, secrets and backups.
- Use semantic versions and never reuse a published tag.
- Preserve the existing player, routes, data and server configuration.
- Require package checksum verification, a code-only backup, service restart, HTTP health check and rollback on failure.
