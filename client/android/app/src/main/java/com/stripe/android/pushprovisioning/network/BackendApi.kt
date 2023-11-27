package com.stripe.android.pushprovisioning.network

import okhttp3.ResponseBody
import retrofit2.Response
import retrofit2.http.Field
import retrofit2.http.FormUrlEncoded
import retrofit2.http.GET
import retrofit2.http.POST

interface BackendApi {

    /**
     * Auth required!
     *
     * Create an ephemeral key to the given card to provision.
     */
    @FormUrlEncoded
    @POST("ephemeral_keys")
    suspend fun createEphemeralKey(
        @Field("api_version") apiVersion: String,
        @Field("card_id") cardId: String,
    ): ResponseBody

    /**
     * Auth required!
     *
     * Returns the list of cards available to the *authenticated* user for push provisioning.
     *
     * The backend may also filter the Stripe Card objects [https://stripe.com/docs/api/issuing/cards] by:
     * - whether the card can approve authorizations
     *   https://stripe.com/docs/api/issuing/cards/object#issuing_card_object-status
     * - Google Pay Eligibility
     *   https://stripe.com/docs/api/issuing/cards/object#issuing_card_object-wallets-google_pay-eligible
     * - other criteria such as permissions, ownership and state
     */
    @GET("cards")
    suspend fun availableCards(): Response<CardsResponse>
}