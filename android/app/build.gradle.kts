plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.ai_img_generator"
    compileSdk = 35 // Replace with your actual compileSdk
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        (this as org.jetbrains.kotlin.gradle.dsl.KotlinJvmOptions).jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.example.ai_img_generator"
        minSdk = 21 // Set your minSdkVersion manually
        targetSdk = 34 // Set your targetSdkVersion manually
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// ❌ REMOVE flutter { source = ... } => Not supported in Kotlin DSL
