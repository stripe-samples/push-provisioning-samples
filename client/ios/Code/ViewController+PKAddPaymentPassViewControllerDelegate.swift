//
//  ViewController+PKAddPaymentPassViewControllerDelegate.swift
//  StripeIssuingExample
//
//  Created by Vlad Chernis on 5/14/24.
//

import Foundation
import OSLog
import PassKit

extension ViewController : PKAddPaymentPassViewControllerDelegate, URLSessionTaskDelegate {

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
        
        guard let card = card else {
            print("nil card, can't happen")
            return
        }
        
        Task {
            do {
                let keyDict = try await server.retrieveEphemeralKey("2024-11-20.acacia", cardId: card.id)
                
                guard let key = keyDict["secret"] as? String else {
                    print("can't get key")
                    return
                }

                var base64Certificates: [String] = []
                for certificate in certificates {
                    base64Certificates.append(certificate.base64EncodedString(options: []))
                }

                let details = try await retrievePushProvisioningDetails(key: key, cardId: card.id, certificates: certificates, nonce: nonce, nonceSignature: nonceSignature)
                
                guard let activationData = details["activation_data"] as? String else {
                    print("error: no activation data")
                    return
                }
                
                guard let encryptedPassData = details["contents"] as? String else {
                    print("error: no encryptedPassData")
                    return
                }
                
                guard let ephemeralPublicKey = details["ephemeral_public_key"] as? String else {
                    print("error: no ephemeralPublicKey")
                    return
                }
                
                let request = PKAddPaymentPassRequest()
                request.activationData = activationData.data(using: .utf8)
                request.encryptedPassData = encryptedPassData.data(using: .utf8)
                request.ephemeralPublicKey = ephemeralPublicKey.data(using: .utf8)
                handler(request)

            }
            
        }
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
            passesDidChange([ChangedPass.passNotRemoved(pass)])
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
    
    func retrievePushProvisioningDetails(key: String,
                                         cardId: String,
                                         certificates: [Data],
                                         nonce: Data,
                                         nonceSignature: Data) async throws -> [String: Any] {
        
        var base64Certificates: [String] = []
        for certificate in certificates {
            base64Certificates.append(certificate.base64EncodedString(options: []))
        }
        
        let parameters = [
            "ios": [
                "certificates": base64Certificates,
                "nonce": hexadecimalString(for: nonce),
                "nonce_signature": hexadecimalString(for: nonceSignature),
            ]
        ]
        
        let url = URL(string: "https://api.stripe.com/v1/issuing/cards/\(cardId)/push_provisioning_details")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
        request.setValue("true", forHTTPHeaderField:  "Stripe-Livemode")
        request.setValue("2020-08-27", forHTTPHeaderField:  "Stripe-Version")

        guard let url = request.url else {
            print("can't happen: no URL")
            return [:]
        }
        let urlString = url.absoluteString
        let query = query(parameters)
        request.url = URL(string: urlString + (url.query != nil ? "&\(query)" : "?\(query)"))
        
        let session = URLSession.shared
        
        let (data, genericReponse) = try await session.data(for: request, delegate: self)  // delegate for auth
        let response = genericReponse as! HTTPURLResponse // ! for simplicity
        
        if response.statusCode != 200 {
            print("status code: \(response.statusCode)")
        }
        
        let obj = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
        return obj
    }
    
    private func query(_ parameters: [String: Any]) -> String {
        var components: [(String, String)] = []
        
        for key in parameters.keys.sorted(by: <) {
            let value = parameters[key]!
            components += queryComponents(fromKey: escape(key), value: value)
        }
        return components.map { "\($0)=\($1)" }.joined(separator: "&")
    }
    
    /// Creates a percent-escaped, URL encoded query string components from the given key-value pair recursively.
    ///
    /// - Parameters:
    ///   - key:   Key of the query component.
    ///   - value: Value of the query component.
    ///
    /// - Returns: The percent-escaped, URL encoded query string components.
    private func queryComponents(fromKey key: String, value: Any) -> [(String, String)] {
        func unwrap<T>(_ any: T) -> Any {
            let mirror = Mirror(reflecting: any)
            guard mirror.displayStyle == .optional, let first = mirror.children.first else {
                return any
            }
            return first.value
        }
        
        var components: [(String, String)] = []
        switch value {
        case let dictionary as [String: Any]:
            for nestedKey in dictionary.keys.sorted() {
                let value = dictionary[nestedKey]!
                let escapedNestedKey = escape(nestedKey)
                components += queryComponents(fromKey: "\(key)[\(escapedNestedKey)]", value: value)
            }
        case let array as [Any]:
            for (index, value) in array.enumerated() {
                components += queryComponents(fromKey: "\(key)[\(index)]", value: value)
            }
        case let number as NSNumber:
            if number.isBool {
                components.append((key, escape(number.boolValue ? "true" : "false")))
            } else {
                components.append((key, escape("\(number)")))
            }
        case let bool as Bool:
            components.append((key, escape(bool ? "true" : "false")))
        case let set as Set<AnyHashable>:
            for value in Array(set) {
                components += queryComponents(fromKey: "\(key)", value: value)
            }
        default:
            let unwrappedValue = unwrap(value)
            components.append((key, escape("\(unwrappedValue)")))
        }
        return components
    }
    
    
    /// Creates a percent-escaped string following RFC 3986 for a query string key or value.
    ///
    /// - Parameter string: `String` to be percent-escaped.
    ///
    /// - Returns:          The percent-escaped `String`.
    private func escape(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: URLQueryAllowed) ?? string
    }
    
    
    private func hexadecimalString(for data: Data) -> String {
        return data.map { String(format: "%02hhx", $0) }.joined()
    }
}


extension NSNumber {
fileprivate var isBool: Bool {
    // Use Obj-C type encoding to check whether the underlying type is a `Bool`, as it's guaranteed as part of
    // swift-corelibs-foundation, per [this discussion on the Swift forums](https://forums.swift.org/t/alamofire-on-linux-possible-but-not-release-ready/34553/22).
    String(cString: objCType) == "c"
}
}

