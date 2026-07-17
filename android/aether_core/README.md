# Aether Core for ShineNET VPN

This directory contains the Aether core source code for building the native library.

## Building libaether.so

### Prerequisites

- Android Studio with Android SDK 36
- Android NDK `26.3.11579264`
- CMake `3.22.1`
- JDK 17
- Rust stable, including the Android target for your ABI
- `cargo-ndk`

### Build Steps (arm64-v8a)

```powershell
cd android\aether_core
.\build-android.ps1
```

### Copy to JNI Libraries

After building, copy the resulting `libaether.so` to the JNI libraries directory:

```powershell
New-Item -ItemType Directory -Force android\app\src\main\jniLibs\arm64-v8a
Copy-Item android\aether_core\android-libs\arm64-v8a\libaether.so android\app\src\main\jniLibs\arm64-v8a\libaether.so -Force
```

### Build APK

```powershell
flutter build apk
```

## Supported Protocols

| Protocol | Core Name | Description |
| --- | --- | --- |
| MASQUE | masque | HTTP/3 tunnel (Recommended) |
| WireGuard | wireguard | Fast direct transport |
| WARP-on-WARP | gool | Double-layer tunnel |

## How It Works

1. The Aether core is compiled from Rust source to `libaether.so`
2. `libaether_jni.so` is built by Gradle's CMake integration, linking against `libaether.so`
3. Kotlin code (`AetherNativeCore.kt`) loads both native libraries
4. Flutter communicates with the native layer via MethodChannel
5. The `AetherVpnService` manages the Android VPN/TUN interface
