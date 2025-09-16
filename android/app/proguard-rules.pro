# Flutter renderer optimization rules
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }

# Prevent Vulkan/Impeller related crashes
-dontwarn io.flutter.embedding.engine.renderer.**
-dontwarn io.flutter.embedding.engine.mutatorsstack.**

# Keep renderer fallback classes
-keep class io.flutter.embedding.engine.renderer.FlutterRenderer { *; }
-keep class io.flutter.embedding.engine.renderer.RenderSurface { *; }

# GPU/Graphics related optimizations
-dontwarn android.opengl.**
-dontwarn javax.microedition.khronos.**

# VPN related optimizations
-keep class com.shythonx.shinenet_vpn.** { *; }
-keep class flutter_v2ray.** { *; }
