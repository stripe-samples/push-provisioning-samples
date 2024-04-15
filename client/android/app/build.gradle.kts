plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization")
}

// Read values from gradle.properties or system environment variable
fun getBackendUrl(): String {
    return property("SAMPLE_PP_BACKEND_URL") as? String ?: ""
}
fun getBackendUsername(): String {
    return property("SAMPLE_PP_BACKEND_USERNAME") as? String ?: ""
}
fun getBackendPassword(): String {
    return property("SAMPLE_PP_BACKEND_PASSWORD") as? String ?: ""
}
fun getUsesClearTextTraffic(): String {
    return if (hasProperty("SAMPLE_PP_BACKEND_USES_CLEAR_TEXT_TRAFFIC")) {
        property("SAMPLE_PP_BACKEND_USES_CLEAR_TEXT_TRAFFIC") as? String ?: "false"
    } else {
        "false"
    }
}
fun getSigningKeystore(): String {
    return property("SIGNING_KEYSTORE") as? String ?: ""
}
fun getSigningKeyAlias(): String {
    return property("SIGNING_KEY_ALIAS") as? String ?: ""
}
fun getSigningPassword(): String {
    return property("SIGNING_PASSWORD") as? String ?: ""
}

// Please change this package name, then allowlist the new package name and app fingerprint as described at
// https://developers.google.com/pay/issuers/apis/push-provisioning/android/allowlist
val packageName = "com.stripe.android.pushprovisioning"

android {
    namespace = packageName
    compileSdk = 34

    signingConfigs {
        getByName("debug") {
            storeFile = file(getSigningKeystore())
            keyAlias = getSigningKeyAlias()
            storePassword = getSigningPassword()
            keyPassword = getSigningPassword()
        }
    }

    defaultConfig {
        applicationId = packageName
        minSdk = 23
        //noinspection OldTargetApi
        targetSdk = 33
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        manifestPlaceholders.putAll(
            mapOf(
                "BACKEND_URL" to getBackendUrl(),
                "BACKEND_USERNAME" to getBackendUsername(),
                "BACKEND_PASSWORD" to getBackendPassword(),
                "USES_CLEAR_TEXT_TRAFFIC" to getUsesClearTextTraffic(),
            )
        )
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    buildFeatures {
        viewBinding = true
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = "11"
    }
    kotlin {
        jvmToolchain {
            languageVersion.set(JavaLanguageVersion.of("11"))
        }
    }
}

dependencies {

    //noinspection GradleDependency
    implementation("androidx.core:core-ktx:1.10.1")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.9.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")

    val coroutineVersion = "1.7.0"
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:$coroutineVersion")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:$coroutineVersion")

    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.6.2")

    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.5.1")

    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.11.0")
    implementation("com.squareup.okhttp3:okhttp:4.11.0")
    implementation("com.jakewharton.retrofit:retrofit2-kotlinx-serialization-converter:1.0.0")


    // Make sure the tapandpay_sdk directory contains the same version of play-services-tapandpay that this version of
    // stripe-android-issuing-push-provisioning depends on.
    // See https://central.sonatype.com/artifact/com.stripe/stripe-android-issuing-push-provisioning
    implementation("com.stripe:stripe-android-issuing-push-provisioning:1.2.2")

    // 18.3.3 also seems to work. Only the latest version is available to new users at
    // https://developers.google.com/pay/issuers/apis/push-provisioning/android/releases
    implementation("com.google.android.gms:play-services-tapandpay:18.2.0")

    // https://developers.google.com/android/guides/tasks#kotlin_coroutine
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.7.0")
}