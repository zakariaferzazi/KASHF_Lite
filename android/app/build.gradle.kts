import org.jetbrains.kotlin.gradle.dsl.JvmTarget
plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("dev.flutter.flutter-gradle-plugin")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.aidata.kashfLite"
    compileSdk = flutter.compileSdkVersion
     ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.aidata.kashfLite"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        externalNativeBuild {
            cmake {
                version = "3.31.6"
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

// Pin transitive androidx dependencies that ship with newer plugins
// (e.g. url_launcher, package_info_plus) to versions that are still
// compatible with Android Gradle Plugin 8.7.0. Newer 1.16.x / 1.17.x
// artifacts require AGP 8.9.1+, which we deliberately avoid to keep
// the toolchain stable.
//
// Reference: https://developer.android.com/build/releases/gradle-plugin
configurations.all {
    resolutionStrategy {
        force(
            "androidx.core:core:1.15.0",
            "androidx.core:core-ktx:1.15.0",
            "androidx.browser:browser:1.8.0",
            // image_picker_android pulls in androidx.activity:1.12.x
            // which requires AGP 8.9.1+. Pin to 1.10.1 (the last
            // release that's happy on AGP 8.7.0).
            "androidx.activity:activity:1.10.1",
            "androidx.activity:activity-ktx:1.10.1"
        )
    }
}
