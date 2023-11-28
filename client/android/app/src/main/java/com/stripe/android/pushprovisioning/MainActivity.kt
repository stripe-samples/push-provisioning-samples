package com.stripe.android.pushprovisioning

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.AttributeSet
import android.util.Log
import android.view.ViewGroup
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.isInvisible
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.PagerSnapHelper
import androidx.recyclerview.widget.RecyclerView
import com.google.android.gms.tapandpay.TapAndPay
import com.stripe.android.pushProvisioning.PushProvisioningActivity
import com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
import com.stripe.android.pushprovisioning.databinding.MainActivityBinding
import com.stripe.android.pushprovisioning.network.BackendPushProvisioningEphemeralKeyProvider
import com.stripe.android.pushprovisioning.network.toNetwork
import com.stripe.android.pushprovisioning.network.toTsp
import kotlinx.coroutines.launch

class MainActivity : AppCompatActivity() {

    private val binding: MainActivityBinding by lazy {
        MainActivityBinding.inflate(layoutInflater)
    }

    private val viewModel: MainViewModel by lazy {
        ViewModelProvider(this)[MainViewModel::class.java]
    }

    private val pagerSnapHelper: PagerSnapHelper by lazy {
        PagerSnapHelper()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(binding.root)
    }

    override fun onStart() {
        super.onStart()

        binding.progressBar.isInvisible = false
        val tapAndPayClient = TapAndPay.getClient(this)

        lifecycleScope.launch {
            val eligibleCardsByStatus = viewModel.getEligibleCardsByStatus(tapAndPayClient)
            binding.progressBar.isInvisible = true

            val (notYetTokenized, alreadyTokenized) = when (eligibleCardsByStatus) {
                is EligibleCardsResponse.Success -> eligibleCardsByStatus.eligibleCards
                is EligibleCardsResponse.Failure -> {
                    binding.cardPicker.isInvisible = true
                    binding.resultPlaceholder.text =
                        eligibleCardsByStatus.exception.localizedMessage ?: getString(R.string.unknown_error)
                    return@launch
                }
            }

            if (notYetTokenized.isEmpty()) {
                binding.cardPicker.isInvisible = true
                binding.resultPlaceholder.text = getString(
                    if (alreadyTokenized.isEmpty()) {
                        R.string.no_eligible_cards
                    } else {
                        R.string.all_eligible_cards_are_already_tokenized
                    }
                )
                return@launch
            }

            binding.cardPicker.isInvisible = false
            binding.resultPlaceholder.text =
                getString(R.string.cards_eligible_for_push_provisioning, notYetTokenized.size)
            // TODO: consider rendering the cards in a a more polished way
            val canScroll = notYetTokenized.size > 1
            binding.cardPicker.layoutManager = HorizontalCardLayoutManager(this@MainActivity, canScroll)
            binding.cardPicker.adapter = CardPickerAdapter(this@MainActivity, notYetTokenized) { cardTokenizationStatus ->
                lifecycleScope.launch {
                    provision(cardTokenizationStatus)
                }
            }
            pagerSnapHelper.attachToRecyclerView(binding.cardPicker)
        }
    }

    private fun provision(cardTokenizationStatus: CardTokenizationStatus) {
        when (cardTokenizationStatus.tokenizationStatus) {
            TokenizationStatus.NotTokenized.GreenPath -> {
                Log.d(TAG, "embarking on push provisioning green path")
                pushProvision(cardTokenizationStatus)
            }

            // This edge case occurs if you begin tokenizing a card in Google Wallet then stop at the yellow path ID&V
            // step-up screen before you begin push provisioning in this app.
            // https://developers.google.com/pay/issuers/apis/push-provisioning/android/test-cases#continue_yellow_path_through_push_provisioning
            is TokenizationStatus.NotTokenized.YellowPath -> {
                Log.d(TAG, "resolving yellow path")
                resolveYellowPath(cardTokenizationStatus)
            }

            // This edge case occurs when the card wasn't tokenized before clicking "Add to Google Pay" but is now. NOOP
            TokenizationStatus.Tokenized -> {
                Log.d(TAG, "card already provisioned")
            }
        }
    }

    private fun pushProvision(cardTokenizationStatus: CardTokenizationStatus) {
        val card = cardTokenizationStatus.card
        // TODO: add javadoc explaining args to our sdk. Ideally the javadoc would be included in the SDK.
        val ephemeralKeyProvider = BackendPushProvisioningEphemeralKeyProvider(card.id, SampleApp.instance.backendApi)
        val enableLogs = true
        val args = PushProvisioningActivityStarter.Args(
            card.cardholderName,
            ephemeralKeyProvider,
            enableLogs
        )
        PushProvisioningActivityStarter(this, args).startForResult()
    }

    /**
     * Consider switching to [androidx.activity.result.contract.ActivityResultContract] as recommended by the
     * deprecation warning on [androidx.activity.ComponentActivity.onActivityResult]. This may require an SDK change.
     */
    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            PushProvisioningActivityStarter.REQUEST_CODE -> {
                binding.resultPlaceholder.text = when (resultCode) {
                    RESULT_OK -> {
                        val success = PushProvisioningActivityStarter.Result.fromIntent(data!!)
                        getString(R.string.success_card_token_id, success.cardTokenId)
                    }
                    PushProvisioningActivity.RESULT_ERROR -> {
                        val error = PushProvisioningActivityStarter.Error.fromIntent(data!!)
                        getString(R.string.push_provisioning_error, error.code, error.message)
                    }
                    RESULT_CANCELED -> {
                        // User exited the push provisioning flow, nothing more to do.
                        binding.resultPlaceholder.text
                    }
                    else -> {
                        throw IllegalArgumentException("unexpected result code: " + resultCode +
                                " with data: " + data +
                                " for request code: " + requestCode)
                    }
                }
            }

            REQUEST_CODE_YELLOW_PATH_TOKENIZE -> {
                when (resultCode) {
                    RESULT_OK -> {
                        val message = getString(R.string.card_successfully_provisioned_from_yellow_path)
                        Toast.makeText(this, message, Toast.LENGTH_LONG).show()
                        Log.d(TAG, message)
                    }
                }
            }
        }
    }

    /**
     * "You may find tokens have been added to Google Pay already but are not yet active. Most often, this occurs when a
     * user attempts to add a card manually to Google Pay but never completes ID&V and, later, tries to add the card
     * through the issuer's app."
     * https://developers.google.com/pay/issuers/apis/push-provisioning/android/wallet-operations#resolving_yellow_path
     */
    private fun resolveYellowPath(cardTokenizationStatus: CardTokenizationStatus) {
        val brand = cardTokenizationStatus.card.brand
        val yellowPath = cardTokenizationStatus.tokenizationStatus as TokenizationStatus.NotTokenized.YellowPath

        TapAndPay.getClient(this).tokenize(
            this,
            yellowPath.tokenReferenceId,
            brand.toTsp(),
            // TODO: get card display name. Probably Need to add it to Card through the backend
            "TODO: get card display name",
            brand.toNetwork(),
            REQUEST_CODE_YELLOW_PATH_TOKENIZE,
        )
    }

    companion object {
        @Suppress("unused")
        private const val TAG = "MainActivity"

        private const val REQUEST_CODE_YELLOW_PATH_TOKENIZE = 9000
    }
}

class HorizontalCardLayoutManager(
    context: Context,
    private val canScroll: Boolean,
) : LinearLayoutManager(context, HORIZONTAL, false) {
        override fun canScrollHorizontally(): Boolean {
            return canScroll
        }

        override fun generateDefaultLayoutParams() =
            fullWidthLayoutParams(super.generateDefaultLayoutParams())

        override fun generateLayoutParams(lp: ViewGroup.LayoutParams?) =
            fullWidthLayoutParams(super.generateLayoutParams(lp))

        override fun generateLayoutParams(c: Context?, attrs: AttributeSet?) =
            fullWidthLayoutParams(super.generateLayoutParams(c, attrs))

        private fun fullWidthLayoutParams(layoutParams: RecyclerView.LayoutParams) = layoutParams.apply {
            width = fullWidth
        }

        private val fullWidth get() = width - paddingStart - paddingEnd
    }