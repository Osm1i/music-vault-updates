# Music Vault Updates

Private stable-release channel for Music Vault Vanguard on CasaOS.

- Private repository: `Osm1i/music-vault-updates`
- Stable release workflow: `.github/workflows/publish-music-vault-release.yml`
- Release packages are stored as fourteen ordered base64 chunks and assembled into a ZIP with a SHA-256 manifest.
- The CasaOS Update Center checks stable releases, verifies the archive, backs up changed code, installs, health-checks, and rolls back on failure.

See [UPDATE_PUBLISHING.md](UPDATE_PUBLISHING.md) for release instructions.
