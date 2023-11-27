package com.stripe.android.pushprovisioning

import android.app.Application
import android.os.Build
import android.os.StrictMode
import android.widget.Toast
import com.stripe.android.pushprovisioning.network.BackendApi
import com.stripe.android.pushprovisioning.network.BackendApiFactory


class SampleApp : Application() {

    val backendApi: BackendApi by lazy {
        BackendApiFactory(applicationContext).create()
    }

    override fun onCreate() {
        StrictMode.setThreadPolicy(
            StrictMode.ThreadPolicy.Builder()
                .detectAll()
                .penaltyLog()
                .penaltyFlashScreen()
                .penaltyDeathOnNetwork()
                .build()
        )

        super.onCreate()

        instance = this

        if (isEmulator()) {
            val emulatorError = getString(R.string.no_emulators)
            Toast.makeText(this, emulatorError, Toast.LENGTH_LONG).show()
            throw IllegalStateException(emulatorError)
        }
    }

    companion object {
        lateinit var instance: SampleApp
            private set

        fun isEmulator(): Boolean {
            return Build.PRODUCT.contains("sdk")
                    || Build.HARDWARE.contains("goldfish")
                    || Build.HARDWARE.contains("ranchu")
        }

        const val TAG = "SampleApp"
    }
}