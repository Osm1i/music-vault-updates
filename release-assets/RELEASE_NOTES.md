# Music Vault Vanguard 9.3.0 — Queue Cancel and Public Release Polish

## Download Queue Control
- Cancel an active or stuck URL download without waiting for it to finish.
- Stop the isolated downloader process group (including yt-dlp/FFmpeg descendants) and remove only that job's staging files.
- Keep queued, completed and unrelated library data intact.
- Keep Cancel available through yt-dlp extraction and post-processing; protect only the final library tagging/copy phase.

## Public Settings and Updates
- Hide CasaOS dashboard/admin controls and personal GitHub repository/token inputs from public Settings.
- Keep USB drive selection, folder configuration and library scanning available.
- Manage the official Music Vault update channel internally, preserving a server-side token for private-channel testing.
- Check/Install actions use systemd services with scoped sudoers rules and report service-start errors accurately.

## Preserved
- Existing player, playback engine, equalizer, profiles, playlists, favorites, family data, database and music collection.
- SHA-256 verified update installation, file-level backup and automatic rollback after failed health checks.

## Install
Open Music Vault → Settings → Update Center → Check for updates → Install update.
