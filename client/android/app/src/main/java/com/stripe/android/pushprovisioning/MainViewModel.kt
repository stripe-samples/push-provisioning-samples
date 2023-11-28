package com.stripe.android.pushprovisioning

import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import android.util.Log
import androidx.lifecycle.ViewModel
import com.google.android.gms.tapandpay.TapAndPay
import com.google.android.gms.tapandpay.TapAndPayClient
import com.google.android.gms.tapandpay.issuer.TokenInfo
import com.stripe.android.pushprovisioning.core.detectIncorrectSigning
import com.stripe.android.pushprovisioning.network.BackendApi
import com.stripe.android.pushprovisioning.network.Card
import com.stripe.android.pushprovisioning.network.CardsResponse
import kotlinx.coroutines.tasks.await
import retrofit2.Response
import java.io.IOException


class MainViewModel : ViewModel() {

    private val app: SampleApp = SampleApp.instance
    private val backendApi: BackendApi = app.backendApi

    suspend fun getEligibleCardsByStatus(tapAndPayClient: TapAndPayClient): EligibleCardsResponse {
        val cardsResponse: Response<CardsResponse>
        try {
            cardsResponse = backendApi.availableCards()
        } catch (ioe: IOException) {
            return EligibleCardsResponse.Failure(ioe)
        }
        if (!cardsResponse.isSuccessful) {
            val errorMessage = "Error fetching cards: ${cardsResponse.raw().code} ${cardsResponse.errorBody()?.string()}"
            val ex = Exception(errorMessage)
            Log.e(TAG, null, ex)
            return EligibleCardsResponse.Failure(ex)
        }
        val cards: List<Card> = cardsResponse.body()!!.data
        val eligibleCards = cards.filter { card ->
            // Both card.status == "active" and card.wallets.google_pay.eligible checked are combined on the backend.
            card.eligibleForGooglePay
        }

        val (notYetTokenized, alreadyTokenized) = eligibleCards.map { card ->
                val status = getTokenizationStatus(tapAndPayClient, card.last4, card.brand)
                CardTokenizationStatus(card, status)
            }
            .partition { (_, status) -> status is TokenizationStatus.NotTokenized }
        return EligibleCardsResponse.Success(notYetTokenized, alreadyTokenized)
    }

    // Retrieve a list of all of your matching cards already present on the device to check their status. See
    // https://stripe.com/docs/issuing/cards/digital-wallets?platform=Android#update-your-app for details on how and
    // why we use listTokens() instead of isTokenized().
    // See also https://developers.google.com/pay/issuers/apis/push-provisioning/android/reading-wallet#listtokens
    private suspend fun getTokenizationStatus(tapAndPayClient: TapAndPayClient, last4: String, brand: String? = null): TokenizationStatus {
        val tokenInfos = tapAndPayClient.listTokens().await()
        Log.d(TAG, "listTokens() => ${tokenInfos.map { it.prettyPrint() }}")
        val matchingTokens = tokenInfos.filter { token ->
            token.fpanLastFour == last4
        }
        if (matchingTokens.isEmpty()) {
            app.detectIncorrectSigning(tapAndPayClient, last4, brand)
            return TokenizationStatus.NotTokenized.GreenPath
        }
        Log.d(TAG, "matchingTokens => ${matchingTokens.map { it.prettyPrint() }}")

        // There's a potential for collisions in the last4 but we don't yet have a better way to resolve them than just
        // picking the first match
        val matchingToken = matchingTokens.first()

        // Check if the user already tried to add this card to Google Pay, likely with manual provisioning
        return if (matchingToken.tokenState == TapAndPay.TOKEN_STATE_NEEDS_IDENTITY_VERIFICATION) {
            TokenizationStatus.NotTokenized.YellowPath(matchingToken.issuerTokenId)
        } else {
            TokenizationStatus.Tokenized
        }
    }

    companion object {
        private const val TAG = "MainViewModel"
    }
}

data class EligibleCards(
    val notYetTokenized: List<CardTokenizationStatus>,
    val alreadyTokenized: List<CardTokenizationStatus>,
)

sealed interface EligibleCardsResponse {
    data class Success(val eligibleCards: EligibleCards) : EligibleCardsResponse {
        constructor(
            notYetTokenized: List<CardTokenizationStatus>,
            alreadyTokenized: List<CardTokenizationStatus>
        ) : this(EligibleCards(notYetTokenized, alreadyTokenized))
    }

    data class Failure(val exception: Exception) : EligibleCardsResponse
}

sealed interface TokenizationStatus {
    data object Tokenized : TokenizationStatus

    sealed interface NotTokenized : TokenizationStatus {
        data object GreenPath : NotTokenized
        data class YellowPath(val tokenReferenceId: String) : NotTokenized
    }
}

data class CardTokenizationStatus(
    val card: Card,
    val tokenizationStatus: TokenizationStatus,
)

fun TokenInfo.prettyPrint(): String {
    // https://developers.google.com/pay/issuers/apis/push-provisioning/android/enumerated-values#card_network
    val network = when (network) {
        TapAndPay.CARD_NETWORK_MASTERCARD -> "Mastercard"
        TapAndPay.CARD_NETWORK_VISA -> "Visa"
        else -> "other: $network"
    }
    // https://developers.google.com/pay/issuers/apis/push-provisioning/android/enumerated-values#token_provider
    val tokenServiceProvider = when (tokenServiceProvider) {
        TapAndPay.TOKEN_PROVIDER_MASTERCARD -> "Mastercard"
        TapAndPay.TOKEN_PROVIDER_VISA -> "Visa"
        else -> "other: $tokenServiceProvider"
    }
    // https://developers.google.com/pay/issuers/apis/push-provisioning/android/enumerated-values#token_status
    val tokenState = when (tokenState) {
        TapAndPay.TOKEN_STATE_NEEDS_IDENTITY_VERIFICATION -> "needs identity verification"
        TapAndPay.TOKEN_STATE_ACTIVE -> "active"
        else ->  "other: $tokenState"
    }
    return """
        network              = $network
        tokenServiceProvider = $tokenServiceProvider
        tokenState           = $tokenState
        dpanLastFour         = $dpanLastFour
        fpanLastFour         = $fpanLastFour
        issuerName           = $issuerName
        issuerTokenId        = $issuerTokenId
        portfolioName        = $portfolioName
    """
}

fun PackageManager.getSignaturesCompat(packageName: String): Array<Signature> {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getPackageInfo(
                packageName,
                PackageManager.PackageInfoFlags.of(PackageManager.GET_SIGNING_CERTIFICATES.toLong())
            )
        } else {
            @Suppress("DEPRECATION")
            getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
        }
        packageInfo.signingInfo.run {
            if (hasMultipleSigners()) {
                apkContentsSigners
            } else {
                signingCertificateHistory
            }
        }
    } else {
        @Suppress("DEPRECATION")
        getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
    }
}