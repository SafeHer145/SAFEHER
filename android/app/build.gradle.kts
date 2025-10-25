import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") // ✅ this is the correct plugin id for Kotlin DSL
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // ✅ Firebase
}

android {
    namespace = "com.example.safeher"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.example.safeher"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    // Load keystore properties if present (for release signing)
    val keystorePropsFile = rootProject.file("key.properties")
    val keystoreProps = Properties()
    if (keystorePropsFile.exists()) {
        keystoreProps.load(FileInputStream(keystorePropsFile))
    }

    signingConfigs {
        create("release") {
            if (keystorePropsFile.exists()) {
                keyAlias = (keystoreProps["keyAlias"] as String?) ?: ""
                keyPassword = (keystoreProps["keyPassword"] as String?) ?: ""
                val storePath = (keystoreProps["storeFile"] as String?) ?: ""
                if (storePath.isNotEmpty()) {
                    storeFile = file(storePath)
                }
                storePassword = (keystoreProps["storePassword"] as String?) ?: ""
            }
        }
    }

    buildTypes {
        release {
            // Use real release signing if key.properties exists, otherwise fall back to debug for local builds
            signingConfig = if (keystorePropsFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
            // Explicitly disable shrink/obfuscation to avoid R8 mapping.txt locks on Windows during CI/local builds
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")

    // Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.2.0"))

    // Firebase Authentication
    implementation("com.google.firebase:firebase-auth")

    // (Optional) If you use Play Services for safety checks
    implementation("com.google.android.gms:play-services-auth-api-phone:18.0.1")

}
