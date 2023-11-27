package com.stripe.android.pushprovisioning.network

import com.google.android.gms.tapandpay.TapAndPay
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class CardsResponse(
    val data: List<Card>,
)

@Serializable
data class Card(
    val id: String,
    val last4: String,
    val brand: String,
    @SerialName("cardholder_name") val cardholderName: String,
    @SerialName("eligible_for_google_pay") val eligibleForGooglePay: Boolean,
    @SerialName("eligible_for_apple_pay") val eligibleForApplePay: Boolean,
    @SerialName("primary_account_identifier") val primaryAccountIdentifier: String?,
)

fun String.toNetwork(): Int {
    return if (this == "Visa") {
        TapAndPay.CARD_NETWORK_VISA
    } else if (this == "MasterCard") {
        TapAndPay.CARD_NETWORK_MASTERCARD
    } else {
        throw IllegalStateException("Unexpected network: $this")
    }
}

fun String.toTsp(): Int {
    return if (this == "Visa") {
        TapAndPay.TOKEN_PROVIDER_VISA
    } else if (this == "MasterCard") {
        TapAndPay.TOKEN_PROVIDER_MASTERCARD
    } else {
        throw IllegalStateException("Unexpected TSP: $this")
    }
}