package com.stripe.android.pushprovisioning.network

import android.content.Context
import com.jakewharton.retrofit2.converter.kotlinx.serialization.asConverterFactory
import com.stripe.android.pushprovisioning.core.Settings
import kotlinx.serialization.json.Json
import okhttp3.Authenticator
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import java.util.concurrent.TimeUnit

/**
 * Factory to generate our Retrofit instance.
 */
class BackendApiFactory internal constructor(
    private val backendUrl: String,
    private val authenticator: Authenticator,
) {

    constructor(context: Context) : this(
        Settings(context)
    )

    constructor(settings: Settings) : this(
        settings.backendUrl,
        BasicAuthenticator(settings.backendUsername, settings.backendPassword)
    )

    private val json = Json { ignoreUnknownKeys = true }

    fun create(): BackendApi {
        // Set your desired log level. Use Level.BODY for debugging errors.
        val logging = HttpLoggingInterceptor()
            .setLevel(HttpLoggingInterceptor.Level.BODY)

        val httpClient = OkHttpClient.Builder()
            .connectTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .readTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .addInterceptor(logging)
            .authenticator(authenticator)
            .build()

        return Retrofit.Builder()
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .baseUrl(backendUrl)
            .client(httpClient)
            .build()
            .create(BackendApi::class.java)
    }

    private companion object {
        private const val TIMEOUT_SECONDS = 15L
    }
}