import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// Application id
//
// Defaults to com.trainerapp.app and can be overridden without touching this
// file, either with -PtrainerAppApplicationId=... or by setting
// trainerAppApplicationId in android/gradle.properties.
// ---------------------------------------------------------------------------
val trainerApplicationId: String =
    (project.findProperty("trainerAppApplicationId") as String?) ?: "com.trainerapp.app"

// ---------------------------------------------------------------------------
// Minimum SDK
//
// The target was API 23, but that is not reachable on this toolchain:
//
//   * Flutter 3.35 stable sets its own default and documented minimum to API 24
//     (FlutterExtension.minSdkVersion = 24), having dropped Android 6.0.
//   * url_launcher_android, shared_preferences_android and path_provider_android
//     each declare minSdk 24, so the manifest merger raises the effective
//     minSdk to 24 whatever this file asks for.
//
// Declaring 23 here would therefore be inaccurate: the installed APK would
// still report 24. It is set to 24 and left overridable with
// -PtrainerAppMinSdk=... so that it can be lowered if those plugins are ever
// pinned to versions that support an older API.
// ---------------------------------------------------------------------------
val trainerMinSdk: Int =
    (project.findProperty("trainerAppMinSdk") as String?)?.toInt() ?: 24

// ---------------------------------------------------------------------------
// Release signing
//
// If android/key.properties exists it is used to sign release builds. If it is
// absent, release builds fall back to the debug signing config so that CI can
// always produce an APK and an AAB. A build signed with debug keys cannot be
// uploaded to Google Play, so CI logs which path was taken.
// ---------------------------------------------------------------------------
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) {
        keyPropertiesFile.inputStream().use { load(it) }
    }
}

val hasReleaseSigning = keyPropertiesFile.exists() &&
    keyProperties.getProperty("storeFile") != null &&
    keyProperties.getProperty("storePassword") != null &&
    keyProperties.getProperty("keyAlias") != null &&
    keyProperties.getProperty("keyPassword") != null

android {
    namespace = "com.trainerapp.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Needed by flutter_local_notifications, which uses java.time APIs
        // that are only available natively from API 26.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = trainerApplicationId
        minSdk = trainerMinSdk
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Hindi and English are the only shipped translations.
        resourceConfigurations += setOf("en", "hi")
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // Surface which signing path was used, so a CI build is never mistaken for
    // an uploadable artifact.
    gradle.projectsEvaluated {
        if (hasReleaseSigning) {
            logger.lifecycle("TrainerApp: release signing from android/key.properties")
        } else {
            logger.lifecycle(
                "TrainerApp: android/key.properties not found, release builds are " +
                    "signed with the debug key and cannot be uploaded to Google Play"
            )
        }
        logger.lifecycle("TrainerApp: applicationId = $trainerApplicationId")
        logger.lifecycle("TrainerApp: minSdk = $trainerMinSdk")
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
