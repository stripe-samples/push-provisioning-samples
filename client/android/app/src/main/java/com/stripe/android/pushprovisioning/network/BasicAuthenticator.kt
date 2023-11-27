package com.stripe.android.pushprovisioning.network

import okhttp3.Authenticator
import okhttp3.Credentials
import okhttp3.Request
import okhttp3.Response
import okhttp3.Route

class BasicAuthenticator(private val username: String, private val password: String) : Authenticator {
    override fun authenticate(route: Route?, response: Response): Request? {
        if (response.request.header("Authorization") != null) {
            return null // Give up, we've already attempted to authenticate.
        }

        val credential = Credentials.basic(username, password)
        return response.request.newBuilder()
            .header("Authorization", credential)
            .build()
    }
}