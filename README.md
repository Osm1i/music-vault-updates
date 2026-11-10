# Music Vault Updates

Public release-only channel for Music Vault Vanguard on CasaOS.

- Repository: `Osm1i/music-vault-updates`
- Stable release workflow: `.github/workflows/publish-music-vault-release.yml`
- Stable release build is triggered by updating `release-assets/MUSIC_VAULT_RELEASE_VERSION.txt`.
- The workflow rebuilds the package, runs shell/JavaScript/Python checks, calculates SHA-256 checksums, and publishes a versioned GitHub Release.
- The private Music Vault server, user music, databases and profiles are not stored in this repository.

See [UPDATE_PUBLISHING.md](UPDATE_PUBLISHING.md) for release instructions.
