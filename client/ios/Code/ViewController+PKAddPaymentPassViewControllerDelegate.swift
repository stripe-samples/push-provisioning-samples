//
//  ViewController+PKAddPaymentPassViewControllerDelegate.swift
//  StripeIssuingExample
//
//  Created by Vlad Chernis on 5/14/24.
//

import Foundation
import OSLog
import PassKit
import Stripe

extension ViewController : PKAddPaymentPassViewControllerDelegate {

    /// These will be called by `PKAddPaymentPassViewController` to provision a card as described here:
    /// https://stripe.com/docs/issuing/cards/digital-wallets?platform=iOS#provision-a-card
    func addPaymentPassViewController(
        _ controller: PKAddPaymentPassViewController,
        generateRequestWithCertificateChain certificates: [Data],
        nonce: Data,
        nonceSignature: Data,
        completionHandler handler: @escaping (
            PKAddPaymentPassRequest
        ) -> Void
    ) {
        STPPushProvisioningContext(keyProvider: self)
            .addPaymentPassViewController(
                controller,
                generateRequestWithCertificateChain: certificates,
                nonce: nonce,
                nonceSignature: nonceSignature,
                completionHandler: handler
            )
    }

    /// Error parameter will use codes from the PKAddPaymentPassError enumeration, using PKPassKitErrorDomain.
    func addPaymentPassViewController(
        _ controller: PKAddPaymentPassViewController,
        didFinishAdding pass: PKPaymentPass?,
        error: Error?
    ) {
        textView.text = ""

        if let error = error {
            logAddPaymentPass(error: error)
        } else if let pass: PKSecureElementPass = pass {
            // Update our local cache of the newly-added card if it had a nil `primaryAccountIdentifier` so it
            // matches future `PKPassLibrary().passes()` results. Otherwise, the stale cache will give the mistaken
            // impression that this card isn't in Apple Pay, causing the `addPassButton` to erroneously show for this
            // card that we've just added.
            // NB: Cards may have nil primaryAccountIdentifiers when they haven't yet been added to *any* wallet.
            if card?.primaryAccountIdentifier == nil && card?.last4 == pass.primaryAccountNumberSuffix {
                card?.primaryAccountIdentifier = pass.primaryAccountIdentifier
            }

            let activationState = String(describing: pass.passActivationState)
            log.error("didFinishAdding pass with state: \(activationState, privacy: .public)")

            // After provisioning the pass, the issuer can replace the button with text, such as Added to Apple Wallet
            // or Available in Apple Wallet.
            textView.text = "Available in Apple Wallet: \(activationState)"

            // Maybe hide add pass button since we just added this card.
            // Don't hide if it can still be added to another device such as an Apple Watch.
            // Also update corresponding card page.
            passesDidChange([ChangedPass.pass(pass)])
        } else {
            fatalError("expected either pass or error to be non-nil")
        }
        dismiss(animated: true, completion: nil)
    }

    private func logAddPaymentPass(error: Error) {
        let errorCase: String? = switch error {
        case PKPassKitError.invalidSignature:
            "invalidSignature"
        case PKPassKitError.notEntitledError:
            "notEntitledError"
        default:
            // We don't care about other cases as much, e.g. invalidSignature could be the user canceling.
            nil
        }

        let logLevel: OSLogType
        if let errorCase = errorCase {
            log.error("addPaymentPassViewController error: \(errorCase, privacy: .public)")
            self.textView.text = "\(errorCase): \(error.localizedDescription)"
            logLevel = .error
        } else {
            logLevel = .info

        }
        log.log(
            level: logLevel,
            "addPaymentPassViewController error description: \(error.localizedDescription, privacy: .public)"
        )
    }
}
