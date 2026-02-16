# Flutter Deployment Finalization Guide

This guide covers the remaining manual steps to finalize your Zyntro Flutter deployment setup.

## 1. Firebase Configuration Files

You need to download the configuration files for each environment (Dev, Staging, Prod) and place them in the correct directories.

### Android (`google-services.json`)

1.  Go to the [Firebase Console](https://console.firebase.google.com/).
2.  Select your project (e.g., `gym-avatar` for Prod).
3.  Click the **Gear icon** (Project Settings) > **General**.
4.  Scroll down to **Your apps** and select the **Android** app (`com.zyntro.app`).
5.  Click **Download google-services.json**.
6.  Move the file to:
    *   **Prod:** `android/app/src/prod/google-services.json` (Also copy to `android/app/google-services.json` as default)
    *   **Dev:** `android/app/src/dev/google-services.json`
    *   **Staging:** `android/app/src/staging/google-services.json`

### iOS (`GoogleService-Info.plist`)

1.  In the Firebase Console, select the **iOS** app (`com.zyntro.app`).
2.  Click **Download GoogleService-Info.plist**.
3.  Move the file to `ios/Runner/GoogleService-Info.plist`.
    *   *Note: For multi-environment iOS, you typically use a script to copy the correct file during build, or manage different schemes. For now, place the Prod one in `ios/Runner/`.*

## 2. Generate Android Release Keystore

The keystore is used to sign your app for the Google Play Store. **Keep this file safe and private!**

### Step 1: Run Keytool Command

Open your terminal (Git Bash or PowerShell) and run:

```bash
keytool -genkey -v -keystore zyntro-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias zyntro-key-alias
```

*   It will ask you to create a password (remember this!) and enter your organization details.
*   Move the generated `zyntro-release-key.jks` to a secure location (e.g., `~/.android/` or outside the project). **Do not commit it to Git.**

### Step 2: Configure `key.properties`

1.  Copy the template file:
    ```bash
    cp android/key.properties.template android/key.properties
    ```
2.  Open `android/key.properties` and fill in your details:

    ```properties
    storePassword=<your-keystore-password>
    keyPassword=<your-key-password> (usually same as store)
    keyAlias=zyntro-key-alias
    storeFile=<absolute/path/to/zyntro-release-key.jks>
    ```

    *   *Tip: On Windows, use forward slashes for paths, e.g., `C:/Users/You/keys/zyntro-release-key.jks`.*

## 3. App Icons & Splash Screen

**✅ Done!**

New premium app icons have been automatically generated and applied:
*   **Design:** Energetic "Z" logo with Vibrant Orange/Magenta gradient on a dark background.
*   **Adaptive Background:** Dark Grey (`#121212`) for a sleek look.
*   **Splash Screen:** Matches the app logo.

To regenerate icons in the future (if you change the files in `assets/`), run:
```bash
flutter pub run flutter_launcher_icons
flutter pub run flutter_native_splash:create
```
