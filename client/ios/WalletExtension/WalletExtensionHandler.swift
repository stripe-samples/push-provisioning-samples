//
//  StripeIssuingExample
//  Copyright (c) 2024 Stripe Inc
//

import Foundation
import OSLog
import PassKit

/// Implements a bare bones Wallet Extension. For more information, see Apple's
/// _Getting Started with Apple Pay: In-App Provisioning, Verification, Security, and Wallet Extensions_
///
/// Apple's docs mention several times that there are strict latency requirements for the extension's responses,
/// and this example simply assumes that the calls it makes will return in time. This may not be realistic
/// for your situation.
class WalletExtensionHandler : PKIssuerProvisioningExtensionHandler {
    
    // MARK: - Properties
    
    /// Ensures log messages go to console.
    private var log = Logger()
    
    /// The `Server` we'll use for communication.
    var server = Server()
    
    // MARK: - Init
    
    /// Note that this example does not currently share the defaults with the main app,
    /// so for the time being you need to copy the correct values in here. These should
    /// be shared as part of an app group with the main app.
    override init() {
        super.init()
    }
    
    // MARK: - API
    
    /// After the user taps the + button, Wallet calls this to find out if we have anything that can be
    /// added:
    /// "The status(completion:) indicates whether a payment pass is vailable to add and whether adding it
    /// requires authentication. The issuer app icon displays in Apple Wallet if there are any passes that
    /// the issuer app needs to add."
    override func status(completion: @escaping (PKIssuerProvisioningExtensionStatus) -> Void) {
        
        log.info("status")

        server.baseUrl = URL(string: "http://192.168.68.107:4242")!
        server.user = "cardholder"
        server.password = "secret"

        let status = PKIssuerProvisioningExtensionStatus()
        status.passEntriesAvailable = false
        status.remotePassEntriesAvailable = false
        status.requiresAuthentication = false
        
        Task {
            do {
                let cards = try await server.retrieveEligibleCards()
                
                for card in cards {
                    let inWallet = card.isInWallet()
                    if inWallet.local == false { // the wallet on this device
                        status.passEntriesAvailable = true
                    }
                    if inWallet.remote == false { // the watch's wallet
                        status.remotePassEntriesAvailable = true
                    }

                }
                
                completion(status)
            } catch {
                log.error("error retrieving cards")
                completion(status)
            }
        }
    }
    
    /// Next, Wallet wants to know the card details it should show.
    ///
    /// "Apple Wallet uses PKIssuerProvisioningExtensionPaymentPassEntry to interrogate the issuer app to determine the list
    /// of payment passes available to add to the user’s iPhone and Apple Watch."
    override func passEntries(completion: @escaping ([PKIssuerProvisioningExtensionPassEntry]) -> Void) {
        
        log.error("passEntries")
        var entries = [PKIssuerProvisioningExtensionPassEntry]()
        
        Task {
            do {
                let cards = try await server.retrieveEligibleCards()
                
                for card in cards {
                    
                    guard let config = PKAddPaymentPassRequestConfiguration(encryptionScheme: .ECC_V2) else {
                        log.error("no config")
                        completion(entries)
                        return
                    }
                    
                    config.cardholderName = card.cardholderName
                    config.primaryAccountSuffix = card.last4
                    config.localizedDescription = "StripeIssuingExample Card"
                    config.style = .payment
                    config.paymentNetwork = card.brand.toPKPaymentNetwork()
                    config.primaryAccountIdentifier = card.primaryAccountIdentifier
                    
                    if let entry = PKIssuerProvisioningExtensionPaymentPassEntry(
                        identifier: card.id,
                        title: "Stripe Example",
                        art: UIImage(systemName: "heart")!.cgImage!,
                        addRequestConfiguration: config) {
                        
                        entries.append(entry)
                    } else {
                        log.info("failed to make pass entry")

                    }
                }
                completion(entries)
                
            } catch {
                log.error("error retrieving cards: \(error)")
                completion(entries)
            }
        }
                
    }
    
    /// Finally, if the user taps the card, Wallet calls this to provision it.
    ///
    /// "Apple Wallet uses
    /// generateAddPaymentPassRequestForPassEntryWithIdentifier:configuration:certificateChain:nonce:nonceSignature:completionHandler:
    /// to interrogate the issuer app for the PKAddPaymentPassRequest and supplies the identifier, configuration data,
    /// certificates, nonce, and nonce signatures for the selected payment passes."
    override func generateAddPaymentPassRequestForPassEntryWithIdentifier(_ identifier: String,
                                                                          configuration: PKAddPaymentPassRequestConfiguration,
                                                                          certificateChain certificates: [Data],
                                                                          nonce: Data,
                                                                          nonceSignature: Data,
                                                                          completionHandler: @escaping (PKAddPaymentPassRequest?) -> Void) {
        log.error("generateAdd")
        
        Task {
            log.info("walletfoo about to retrieving details")
            let ppd = PushProvisioningDetails(server: server)
            log.info("walletfoo retrieving details")
            let request = await ppd.retrieveDetails(cardId: identifier, certificates: certificates, nonce: nonce, nonceSignature: nonceSignature)
            log.info("walletfoo calling completion handler")
            completionHandler(request)
        }
    }
}

