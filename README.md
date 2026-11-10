# Music Vault Updates

Public release channel for Music Vault Vanguard on CasaOS.

- Repository: `Osm1i/music-vault-updates`
- Stable release workflow: `.github/workflows/publish-music-vault-release.yml`
- Release packages are rebuilt, syntax-checked, checksummed and published as GitHub Releases.
- The app's music, database, profiles and server configuration remain on the user's CasaOS host.

The 9.2.0 release repairs the Update Center install action, hides repository/token/CasaOS setup fields from the user-facing Settings screen, and keeps the update channel configured internally.
