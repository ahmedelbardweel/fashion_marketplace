# ProGuard and R8 rules for Fashion Marketplace

# 1. ONNX Runtime & Native JNI bindings (used by background removal)
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**
-keep class ai.onnxruntime.extensions.** { *; }
-dontwarn ai.onnxruntime.extensions.**
-keep class com.masicai.flutteronnxruntime.** { *; }
-dontwarn com.masicai.flutteronnxruntime.**

# 2. WebRTC (used by virtual try-on)
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**
-keep class com.cloudwebrtc.webrtc.** { *; }
-dontwarn com.cloudwebrtc.webrtc.**

# 3. Google ML Kit Pose Detection
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.vision.**
-dontwarn com.google_mlkit_pose_detection.**

# 4. Preserve all native methods across the application and plugins
-keepclasseswithmembernames class * {
    native <methods>;
}

# 5. Keep reflection and type metadata
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
