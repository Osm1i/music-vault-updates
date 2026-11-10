# Music Vault Vanguard 9.2.0 — Update Center Repair

A reliability and privacy-focused follow-up to Vanguard 9.0 and the 9.1 Velocity performance release.

## Update installation now has a real system service
- The Install Update action starts a dedicated systemd install service instead of spawning a detached sudo process from the web worker.
- Update-start permission failures are returned to the app immediately instead of looking like a successful launch.
- Scoped sudoers rules allow only starting the update-check and update-install services.
- The app displays install progress, polls for the installed version, reports an update error, and refreshes after a confirmed successful install.

## Cleaner Settings
- Removes visible CasaOS-specific setup details.
- Hides GitHub repository and personal access token fields from the user-facing Settings screen.
- The updater keeps its release-channel configuration internally and does not persist a GitHub token.

## Preserved
- Vanguard 9.0 app design and 9.1 Velocity rendering improvements.
- Existing player, audio engine, EQ, profiles, playlists, favorites, family data, databases and music library.
- Update package SHA-256 verification, backup and health-check flow.

## Install
Open Music Vault → Settings → Update Center → Check now → Install update.
