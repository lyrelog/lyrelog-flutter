// The Android half of the lyrelog Flutter plugin: a thin layer over the Lyrelog Android SDK,
// com.lyrelog:lyrelog-android, from Maven Central.
group = "com.lyrelog.flutter"
version = "1.0.1"

buildscript {
    val kotlinVersion = "2.4.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.3.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.lyrelog.flutter"

    // Flutter's default; the Android SDK's AAR asks apps for compileSdk 34 or newer.
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // No sourceSets block: src/main/kotlin is a default source folder with AGP 9's built-in Kotlin,
    // and configuring it here broke apps on an older AGP than this file's (a class cast across
    // the two AGP versions' class loaders, checked with Flutter 3.44's AGP 9.0.1).

    defaultConfig {
        minSdk = 24
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("com.lyrelog:lyrelog-android:1.0.0")
    // Pigeon's generated code runs the asynchronous calls (flush, stop) as coroutines.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
}
