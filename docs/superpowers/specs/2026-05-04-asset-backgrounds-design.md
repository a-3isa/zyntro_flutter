# Asset Backgrounds Design

## Goal

Add a real background to `assets/splash_z_v5.png` and `assets/app_icon.png`, replacing the baked checkerboard pattern currently present in both 1024x1024 PNG files.

## Approved Direction

Use the Electric Gradient direction approved in the visual companion flow. The background should be a full-canvas diagonal blue/navy-to-dark-green gradient like the selected preview, without a circular glow behind the logo. This gives the assets a more active fitness feel without changing the brand mark.

## Implementation

Both files are flattened RGB PNGs, not transparent PNGs. The edit will isolate the saturated cyan/green logo pixels from the gray checkerboard, rebuild a soft alpha edge for the logo, and composite that mark over a generated 1024x1024 dark teal glow background.

## Verification

After editing, both PNGs must remain 1024x1024. The checkerboard should no longer be visible, and the splash/icon should still match the `flutter_native_splash` and `flutter_launcher_icons` paths in `pubspec.yaml`.
