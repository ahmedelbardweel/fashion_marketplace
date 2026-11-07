# ProGuard and R8 rules for Fashion Marketplace

# Disable aggressive bytecode optimization to prevent JNI and MethodChannel breakage
-dontoptimize

# 1. Flutter Engine, Plugins, and MethodChannels
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.plugins.**
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.app.** { *; }

# Generated Plugin Registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class * implements io.flutter.plugin.common.PluginRegistry$PluginRegistrantCallback { *; }
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class io.flutter.plugin.common.** { *; }
-dontwarn io.flutter.plugin.common.**

# 2. ONNX Runtime & Native JNI bindings (used by background removal)
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**
-keep class ai.onnxruntime.extensions.** { *; }
-dontwarn ai.onnxruntime.extensions.**
-keep class com.masicai.flutteronnxruntime.** { *; }
-dontwarn com.masicai.flutteronnxruntime.**

# 3. WebRTC (used by virtual try-on)
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**
-keep class com.cloudwebrtc.webrtc.** { *; }
-dontwarn com.cloudwebrtc.webrtc.**

# 4. Google ML Kit Pose Detection
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.vision.**
-dontwarn com.google_mlkit_pose_detection.**

# 5. Preserve all native methods across the application and plugins
-keepclasseswithmembernames class * {
    native <methods>;
}

# 6. Keep reflection and type metadata
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
