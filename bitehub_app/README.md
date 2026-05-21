# Bite Hub

Flutter client for the Bite Hub campus ordering system.

## Fast APK Build

From the repo root:

```powershell
.\build_apk_fast.ps1 -Mode debug
```

From inside `bitehub_app`:

```powershell
.\scripts\build_apk_fast.ps1 -Mode debug
```

Useful variants:

```powershell
.\build_apk_fast.ps1 -Mode release -SplitPerAbi
.\build_apk_fast.ps1 -Mode debug -PubGet
```

The fast daily path is `debug`. After the first warm-up build, repeated debug APK builds should benefit from Gradle daemon and build cache.

APK output:

- `build/app/outputs/flutter-apk/app-debug.apk`
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

## Development

```powershell
flutter pub get
flutter analyze
flutter test
```
