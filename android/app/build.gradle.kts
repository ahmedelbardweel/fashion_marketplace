plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Automatically enable Firebase / FCM native config when google-services.json is present.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.example.fashion_marketplace"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.fashion_marketplace"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        // Target API 33 ensures runtime backward-compatibility for dynamic receivers on Android 14+ (One UI 6+)
        targetSdk = 33
        multiDexEnabled = true
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    signingConfigs {
        getByName("debug") {
            val sharedDebugKeystore = file("debug.keystore")
            if (sharedDebugKeystore.exists()) {
                storeFile = sharedDebugKeystore
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("com.google.mediapipe:tasks-vision:0.10.21")
    implementation("com.aliyun.aio:AliVCSDK_ARTC:7.11.0")
}

// flutter_webrtc declares com.github.davidliu:audioswitch:89582c47... while
// decart_vton_flutter -> livekit-android requires 039a35ae... (which adds
// CommDeviceAudioSwitch). Gradle compares the hex prefixes numerically
// (89582 > 39) and silently downgrades to the older commit, causing a fatal
// NoClassDefFoundError on Android when LiveKit starts audio routing.
configurations.configureEach {
    resolutionStrategy {
        force("com.github.davidliu:audioswitch:039a35aefab7747c557242fa216c9ea11743b604")
    }
}
