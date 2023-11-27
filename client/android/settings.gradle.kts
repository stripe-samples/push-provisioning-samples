pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven {
            // This directory is precreated to store the TapAndPay SDK,
            // which must be downloaded manually from Google.
            url = uri("./tapandpay_sdk/")
        }
    }
}

rootProject.name = "Push Provisioning Sample"
include(":app")
 