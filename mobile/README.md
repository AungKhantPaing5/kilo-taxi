# Kilo Taxi native driver apps

Native Android and iPhone clients reuse the existing HTTPS taxi API. They are **not** WebView/PWA wrappers. Default server: `https://thai1.payapi.uk`. Login with an account created by the website administrator. Driver account needs `calculate`, `save_trips`, and `view_own` permissions. Server-owned rates, first 600 waiting seconds free, trip profile snapshots and GPS history remain unchanged.

## Android: install without Play Store

1. GitHub → Actions → **Native mobile builds** → latest successful run → download `kilo-taxi-android-test-apk` artifact.
2. Unzip, transfer `app-debug.apk` to the phone, open it and allow **Install unknown apps** for the browser/file manager used.
3. Login, tap Start and grant precise location. Allow notifications so the ongoing trip is visible.
4. Start/resume GPS while the app is visible. The location foreground service keeps tracking with a persistent notification when you switch apps or lock the screen. Pause/Finish stops GPS.
5. On some phones, battery restrictions must be adjusted by the user. Force Stop, restarting the phone, revoking permissions or OS termination stops tracking. Open the app and explicitly reconnect an existing ride.

The artifact is a signed **debug/test APK**, not a production release. GitHub runner debug signing keys may differ between runs, so later test APKs may require uninstalling the previous APK first. Server history remains but the phone's login session is removed. For stable in-place production updates, configure a persistent private release signing key; never commit it. Do not use a debug APK as a certified fare meter.

### Local build

Android Studio / JDK 17, Android SDK 35, Gradle 8.9:

```bash
cd mobile/android
gradle :app:assembleDebug :app:lintDebug
```

APK: `app/build/outputs/apk/debug/app-debug.apk`. No third-party runtime GPS library and no Google Maps billing key is required. Native LocationManager provides GPS; existing server calculates fare.

## iPhone: no App Store publication, but Apple signing is required

A website download cannot install an arbitrary unsigned iPhone app. The workflow builds an **unsigned iPhone app ZIP**, which is **not directly installable**. There is no claim this ZIP is an installable IPA.

### Own iPhone via Xcode

On a Mac with Xcode and XcodeGen:

```bash
cd mobile/ios
xcodegen generate
open KiloTaxi.xcodeproj
```

Select the `KiloTaxi` target → Signing & Capabilities → your Apple team, choose a unique bundle ID if necessary, connect the iPhone, trust/enable Developer Mode as required by Xcode, then Run. A free Apple Personal Team can be used for personal device testing with provisioning limits/expiry; renewal may be necessary. For distribution to registered iPhones via Ad Hoc, an Apple Developer Program membership, device registration and matching certificate/provisioning profile are needed. Signed Ad Hoc IPA export is performed in Xcode Organizer. Keep signing keys private; do not send passwords or certificates in chat.

The project declares the location background mode, explicit When In Use/Always descriptions, continuous Core Location updates and visible location indicator. Start the ride in foreground after granting Location. A force-quit app cannot be expected to continue tracking. iOS controls when location callbacks/network execution occur; uninterrupted background timers are not guaranteed, especially when stationary.

## Data, connectivity and safety

- Password is used only for login; not saved. Session cookie is stored in private no-backup Android app preferences / iOS Keychain (device-only). HTTPS is mandatory, certificate checks stay enabled.
- Live GPS fixes and heartbeats are sent to the configured server during an active trip. Native tracking stops on manual Pause, Finish or authentication failure. No GPS before user starts/reconnects a trip. OS GPS permission alone does not start a ride.
- The native app and browser should not control the same ride simultaneously.
- History opens the website in the system browser. It has a separate login session; native credentials are not passed in URLs.
- Network/GPS loss uses existing server safety rules: missing km is not invented; waiting during an unobserved request gap is capped. No offline trip replay/automatic backbilling is implemented. A full offline meter needs a separate sequenced ingestion design.
- Background tracking consumes battery. App/service termination, stationary suspension, permission changes, server session expiry and network outages can interrupt metering. The user must monitor the visible status/notification.
- These apps use the existing approximate GPS meter, including its ~5 km/h movement threshold and accuracy filter. Slow walking can be ignored. They are not certified taximeters.

## Device acceptance test (required before actual fare collection)

Test Android and iPhone independently: permission denial/regrant, real outdoor GPS, start → lock screen → drive → reopen; switch to navigation for 10 minutes; wait over 600 seconds while locked and compare server totals; pause/resume; finish and inspect Admin history/route/profile; airplane mode and recovery; revoke location, force-stop/kill, session expiry; verify no distance invented across gaps, no duplicate fare, and GPS stops at Finish. Compare a known route against a reliable distance reference. Build success is not a substitute for these device tests.
