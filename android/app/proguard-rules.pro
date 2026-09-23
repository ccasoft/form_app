# Flutter wrapper — keep everything Flutter's own engine needs
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# TensorFlow Lite — GPU delegate is optional and not bundled in this app;
# these classes are expected to be missing, safe to ignore.
-dontwarn org.tensorflow.lite.gpu.**
-dontwarn org.tensorflow.**
-keep class org.tensorflow.lite.** { *; }

# Google ML Kit (face detection)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# CameraX (used by the camera plugin)
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

-dontwarn com.google.android.play.core.**