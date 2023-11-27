package com.stripe.android.pushprovisioning.network

import android.os.Parcel
import android.os.Parcelable
import com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
import com.stripe.android.pushprovisioning.SampleApp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import com.stripe.android.pushProvisioning.EphemeralKeyUpdateListener as PushProvisioningEphemeralKeyUpdateListener

class BackendPushProvisioningEphemeralKeyProvider(
    private val cardId: String,
    private val backendApi: BackendApi,
) : PushProvisioningEphemeralKeyProvider {

    constructor(parcel: Parcel) : this(parcel.readString()!!, SampleApp.instance.backendApi)

    override fun createEphemeralKey(apiVersion: String, keyUpdateListener: PushProvisioningEphemeralKeyUpdateListener) {
        CoroutineScope(Dispatchers.IO).launch {
            val response =
                runCatching<String> {
                    backendApi
                        .createEphemeralKey(
                            apiVersion = apiVersion,
                            cardId = cardId,
                        )
                        .string()
                }

            withContext(Dispatchers.Main) {
                response.fold(
                    onSuccess = {
                        keyUpdateListener.onKeyUpdate(it)
                    },
                    onFailure = {
                        keyUpdateListener.onKeyUpdateFailure(0, it.message.orEmpty())
                    }
                )
            }
        }
    }

    override fun writeToParcel(parcel: Parcel, flags: Int) {
        parcel.writeString(cardId)
    }

    override fun describeContents(): Int {
        return hashCode()
    }

    companion object CREATOR : Parcelable.Creator<BackendPushProvisioningEphemeralKeyProvider> {
        override fun createFromParcel(parcel: Parcel): BackendPushProvisioningEphemeralKeyProvider {
            return BackendPushProvisioningEphemeralKeyProvider(parcel)
        }

        override fun newArray(size: Int): Array<BackendPushProvisioningEphemeralKeyProvider?> {
            return arrayOfNulls(size)
        }
    }
}