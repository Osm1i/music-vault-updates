# Music Vault — Android Car Screen

A small landscape Android WebView shell for the CasaOS Music Vault server.

## Connection
Default endpoint: http://100.83.43.110:8788/

The car screen must have Tailscale installed and connected to the same tailnet as the CasaOS host. If the address changes, open the ⋮ menu and choose **Change server address**. If the connection fails, the app offers **Open Tailscale**, **Retry**, and **Server Address**.

## Updating
The player UI and Music Vault features are served by the CasaOS web app, not bundled in this APK. Updates to the Music Vault server therefore appear in the Android app when it reloads; the APK normally only needs replacing when the Android wrapper itself changes.

## Build
Use JDK 17, Gradle 8.9, Android SDK platform 35, and Build Tools 35.0.0:
`gradle --no-daemon :app:assembleDebug`

APK output:
`app/build/outputs/apk/debug/app-debug.apk`

The GitHub Actions workflow builds and publishes the sideloadable APK.
