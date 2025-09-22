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

# This is generated automatically by the Android Gradle plugin.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task