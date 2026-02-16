# Assets Folder

This folder contains app assets including icons, images, and other static resources.

## Required Files

Before running the app icons/splash generation, add these files:

- `icon.png` - App icon (1024x1024 recommended)
- `icon_foreground.png` - Adaptive icon foreground for Android (512x512)
- `splash_icon.png` - Splash screen icon (256x256 or larger)

## Generating Icons & Splash

After adding the required files, run:

```bash
# Generate app icons
flutter pub run flutter_launcher_icons

# Generate splash screens
flutter pub run flutter_native_splash:create
```

## Copying Assets from React Native

If migrating from the React Native project, copy:
- `../zyntro-1/assets/icon.png` → `./icon.png`
- `../zyntro-1/assets/splash-icon.png` → `./splash_icon.png`
