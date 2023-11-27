package com.stripe.android.pushprovisioning.core

import android.content.pm.ApplicationInfo
import android.content.pm.Signature
import android.util.Log
import com.google.android.gms.tapandpay.TapAndPayClient
import com.google.android.gms.tapandpay.issuer.IsTokenizedRequest
import com.stripe.android.pushprovisioning.SampleApp
import com.stripe.android.pushprovisioning.getSignaturesCompat
import com.stripe.android.pushprovisioning.network.toNetwork
import com.stripe.android.pushprovisioning.network.toTsp
import kotlinx.coroutines.tasks.await
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate

fun SampleApp.isDebug() = 0 != applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE

suspend fun SampleApp.detectIncorrectSigning(tapAndPayClient: TapAndPayClient, last4: String, brand: String?) {
    val isTokenized = brand?.let {
        val request = IsTokenizedRequest.Builder()
            .setIdentifier(last4)
            .setNetwork(brand.toNetwork())
            .setTokenServiceProvider(brand.toTsp())
            .build()
        tapAndPayClient.isTokenized(request).await()
    } ?: true

    if (isTokenized) {
        if (isDebug() && usingDefaultDebugCert()) {
            Log.e(SampleApp.TAG, "Default debug signing certificate detected. Please check the readme for signing info")
        }
        // Otherwise, if you do not see your tokens in the listTokens API response, please consult with your TSP on
        // how to set the issuer app field so it links to your app in the card details view and this API. For Visa,
        // this is the CardMetaData.bankAppAddress field sent in the "Enroll PAN" response and, for Mastercard, this
        // comes from the productConfig.issuerMobileApp.openIssuerMobileAppAndroidIntent.packageName field sent in
        // the "Digitize" response.
        // - https://developers.google.com/pay/issuers/apis/push-provisioning/android/reading-wallet#listtokens
    }
}

private fun SampleApp.usingDefaultDebugCert(): Boolean {
    val signatures: Array<Signature> = packageManager.getSignaturesCompat(packageName)
    return signatures.any { signature ->
        val cf = CertificateFactory.getInstance("X.509")
        val appCertificate = cf.generateCertificate(signature.toByteArray().inputStream()) as X509Certificate
        // In case of default debug certificate, this will be a Principal named "CN=Android Debug,O=Android,C=US"
        val subject = appCertificate.subjectDN
        subject.name
            .split(",")
            .all {
                val (attrType, attrValue) = it.split("=")
                when (attrType) {
                    "CN" -> attrValue == "Android Debug"
                    "O" -> attrValue == "Android"
                    else -> true
                }
            }
    }
}