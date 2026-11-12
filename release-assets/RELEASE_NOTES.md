# Music Vault Vanguard 9.5.0

- Redesigned Library → Songs for faster, clearer browsing and simpler playback/queue/favorite actions.
- Added press-and-hold song removal with confirmation and recoverable file moves to Music Vault Trash.
- Improved Recently Added loading with a shared short-lived cache and deduplicated album index requests while preserving its existing visual layout.
- Hid the Search caption in the compact bottom player island while keeping its icon.
- Made mood search and Radio stations use actual track genre metadata, with conservative artist/title fallback and no unrelated full-library fallback.
- Preserved existing GitHub Releases manifest/SHA-256 verification and user-approved installation. The update agent, Update Center route, and systemd update schedule are not replaced by this release.
