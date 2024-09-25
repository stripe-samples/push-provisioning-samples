package com.stripe.android.pushprovisioning.core

import android.content.Context
import android.content.pm.PackageManager

class Settings(context: Context) {
    private val appContext = context.applicationContext
    private val backendUrlMetadata = getMetadata(METADATA_KEY_BACKEND_URL_KEY)
    private val backendUsernameMetadata = getMetadata(METADATA_KEY_BACKEND_USERNAME_KEY)
    private val backendPasswordMetadata = getMetadata(METADATA_KEY_BACKEND_PASSWORD_KEY)

    val backendUrl: String
        get() {
            return backendUrlMetadata ?: BASE_URL
        }

    val backendUsername: String
        get() {
            return backendUsernameMetadata ?: USERNAME
        }


    val backendPassword: String
        get() {
            return backendPasswordMetadata ?: PASSWORD
        }

    private fun getMetadata(key: String): String? {
        @Suppress("DEPRECATION")
        return appContext.packageManager
            .getApplicationInfo(appContext.packageName, PackageManager.GET_META_DATA)
            .metaData
            .getString(key)
            .takeIf { it?.isNotBlank() == true }
    }

    private companion object {
        /**
         * Note: only necessary if not configured via `gradle.properties`.
         *
         * Set to the base URL of your test backend. The URL will be something like
         * `https://push-provisioning-samples.onrender.com`.
         */
        private const val BASE_URL = "put your base url here"

        /**
         * Note: only necessary if not configured via `gradle.properties`.
         *
         * Set to the username for your test backend. This should match the password configured on the above backend.
         */
        private const val USERNAME = "put your username here"

        /**
         * Note: only necessary if not configured via `gradle.properties`.
         *
         * Set to the password for your test backend. This should match the password configured on the above backend.
         */
        private const val PASSWORD = "put your password here"

        private const val METADATA_KEY_BACKEND_URL_KEY =
            "com.stripe.example.metadata.backend_url"

        private const val METADATA_KEY_BACKEND_USERNAME_KEY =
            "com.stripe.example.metadata.backend_username"

        private const val METADATA_KEY_BACKEND_PASSWORD_KEY =
            "com.stripe.example.metadata.backend_password"
    }
}
