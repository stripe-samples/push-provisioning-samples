//
//  StripeIssuingExample
//  Copyright (c) 2024 Stripe Inc
//

import Foundation
import PassKit

/// Card represents a Stripe Issuing card, with just the bare info
/// we need for this example.
///
struct Card: Codable, Equatable {

    // MARK: - Types
    
    /// Convert the Stripe API representation (string) to PassKit
    enum Brand: String, Codable {
        case visa = "Visa"
        case mastercard = "MasterCard"

        func toPKPaymentNetwork() -> PKPaymentNetwork {
            switch self {
            case .visa:
                .visa
            case .mastercard:
                .masterCard
            }
        }
    }
    
    /// Identifies which wallets a card is in. Important for the UI to present
    /// the correct options.
    struct InWallet {
        var local: Bool
        var remote: Bool
    }

    // MARK: - Properties

    /// "Visa" or "MasterCard"
    var brand: Brand

    /// The cardholder's name; same as `cardholder.name`
    var cardholderName: String

    /// True if enabled and approved by Apple; same as `status == 'active'` && `wallets.apple_pay.eligible`
    var eligibleForApplePay: Bool

    /// The card's id (`ic_xxx`)
    var id: String

    /// The last 4 digits of the card's PAN, for identification. The last4 are not in PCI scope.
    var last4: String

    /// An identifier that can be used to determine if the card has been added to
    /// *this* wallet before. Same as `wallets.primary_account_identifier`.
    var primaryAccountIdentifier: String?

    // MARK: - Functions
    
    /// Which wallets is the card in?
    func isInWallet() -> InWallet {
        Card.isInWallet(primaryAccountIdentifier: primaryAccountIdentifier ?? "")
    }

    /// Can the card be added to (this device's) wallet?
    func canAddToWallet() -> Bool {
        Card.canAddToWallet(primaryAccountIdentifier: primaryAccountIdentifier ?? "")
    }

    // MARK: - Statics

    /// For simplicity, we use canAddToWallet() (which checks local and remote wallets) to determine whether to show
    /// the "Add to Apple Wallet" button, but this method tells us *which* wallet(s) contain a card with the specified
    /// primaryAccountIdentifier.
    static func isInWallet(primaryAccountIdentifier pai: String) -> InWallet {
        let passLib = PKPassLibrary()
        let match = { (pass: PKPass) in
            pass.secureElementPass?.primaryAccountIdentifier == pai
        }
        return InWallet(
            local: passLib.passes().contains(
                where: match
            ),
            remote: passLib.remoteSecureElementPasses.contains(
                where: match
            )
        )
    }

    /// This check is step 2 of https://stripe.com/docs/issuing/cards/digital-wallets?platform=iOS#check-eligibility
    /// If this returns false unexpectedly, please make sure to:
    /// (1) Run on a real iOS device, not a simulator
    /// (2) Receive Apple Pay access https://stripe.com/docs/issuing/cards/digital-wallets?platform=iOS#request-access
    ///     You need to have applied for Apple Pay using the Stripe Dashboard for Issuing and been approved by Apple.
    /// (3) Check that a card with the specified primaryAccountIdentifier hasn't already been added to all your local
    ///     and remote wallets (see isInWallet).
    static func canAddToWallet(primaryAccountIdentifier pai: String) -> Bool {
        return PKPassLibrary().canAddSecureElementPass(primaryAccountIdentifier: pai)
    }
}
