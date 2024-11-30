//
//  StripeIssuingExample
//  Copyright (c) 2024 Stripe Inc
//

import Foundation
import OSLog
import PassKit

/// This class demonstrates how to call the Stripe `push_provisioning_details` API
/// without using the Stripe API
struct PushProvisioningDetails {
    
    // MARK: - Statics
    
    /// We must specify an API version when calling Stripe API
    static let APIVersion = "2020-08-27"
    
    // MARK: - Properties
    
    /// Ensures log messages go to console.
    private var log = Logger()
    
    /// Creates a CharacterSet from RFC 3986 allowed characters.
    ///
    /// RFC 3986 states that the following characters are "reserved" characters.
    ///
    /// - General Delimiters: ":", "#", "[", "]", "@", "?", "/"
    /// - Sub-Delimiters: "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "="
    ///
    /// In RFC 3986 - Section 3.4, it states that the "?" and "/" characters should not be escaped to allow
    /// query strings to include a URL. Therefore, all "reserved" characters with the exception of "?" and "/"
    /// should be percent-escaped in the query string.
    let URLQueryAllowed: CharacterSet = {
        // does not include "?" or "/" due to RFC 3986 - Section 3.4.
        let generalDelimitersToEncode = ":#[]@"
        let subDelimitersToEncode = "!$&'()*+,;="
        let encodableDelimiters = CharacterSet(
            charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)"
        )
        
        return CharacterSet.urlQueryAllowed.subtracting(encodableDelimiters)
    }()
    
    /// Our "server," which mimics your back end server. We need it to get an ephemeral key.
    let server = Server()
    
    // MARK: - API
    
    /// This is intended to be called from your implementation of PKAddPaymentPassViewControllerDelegate's
    /// addPaymentPassViewController(generateRequestWithCertificateChain:, nonce:, nonceSignature:, completionHandler:)
    ///
    /// It will first ask our backend server for an ephemeral key bound to our card. (This needs be done by the backend,
    /// and not this app, because retrieving the ephemeral key from Stripe requires a proper secret key, which should
    /// not be included in mobile apps.)
    ///
    /// Once it has the ephemeral key, it then fetches the push provisioning details directly (without going through the backend).
    /// Doing this directly from the mobile app is Stripe's recommendation.
    ///
    /// - Parameter cardId: The ID of the card (`ic_`) to provision.
    /// - Parameter certificates: The certificate blob passed to the PKAddPaymentPassViewControllerDelegate.
    /// - Parameter nonce: The nonce passed to the PKAddPaymentPassViewControllerDelegate.
    /// - Parameter nonceSignature: The nonceSignature passed to the PKAddPaymentPassViewControllerDelegate.
    ///
    /// - Returns The dictionary of results. // TODO: turn this into a proper struct.
    func retrieveDetails(cardId: String, certificates: [Data], nonce: Data, nonceSignature: Data) async ->  PKAddPaymentPassRequest? {

        func hexadecimalString(for data: Data) -> String {
            return data.map { String(format: "%02hhx", $0) }.joined()
        }

        do {
            let keyDict = try await server.retrieveEphemeralKey(PushProvisioningDetails.APIVersion, cardId: cardId)
            
            guard let key = keyDict["secret"] as? String else {
                log.error("ephemeral key is nil")
                return nil
            }
            
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
            
            // https://docs.stripe.com/api/issuing/push-provisioning-details -- access may be gated
            
            let url = URL(string: "https://api.stripe.com/v1/issuing/cards/\(cardId)/push_provisioning_details")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
            request.setValue("true", forHTTPHeaderField:  "Stripe-Livemode")
            request.setValue(PushProvisioningDetails.APIVersion, forHTTPHeaderField:  "Stripe-Version")
            
            let urlString = request.url!.absoluteString
            let query = query(parameters)
            request.url = URL(string: urlString + (url.query != nil ? "&\(query)" : "?\(query)"))
            
            let session = URLSession.shared
            
            let (data, genericReponse) = try await session.data(for: request)
            let response = genericReponse as! HTTPURLResponse // ! for simplicity
            
            if response.statusCode != 200 {
                log.info("status code: \(response.statusCode)")
            }
            
            let details = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]

            guard let activationData = details["activation_data"] as? String else {
                print("error: no activation data")
                return nil
            }
            
            guard let encryptedPassData = details["contents"] as? String else {
                print("error: no encryptedPassData")
                return nil
            }
            
            guard let ephemeralPublicKey = details["ephemeral_public_key"] as? String else {
                print("error: no ephemeralPublicKey")
                return nil
            }
            
            let passRequest = PKAddPaymentPassRequest()
            passRequest.activationData = activationData.data(using: .utf8)
            passRequest.encryptedPassData = encryptedPassData.data(using: .utf8)
            passRequest.ephemeralPublicKey = ephemeralPublicKey.data(using: .utf8)

            return passRequest
            
        } catch {
            log.error("\(error)")

            return nil
        }
    }

    // MARK: Helpers
    
    /// Creates a percent-escaped, URL encoded query string from the parameters.
    ///
    /// - Parameters:
    ///   - parameters: The parameters to encode
    ///
    /// - Returns: The escaped query string
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
}

extension NSNumber {
    fileprivate var isBool: Bool {
        // Use Obj-C type encoding to check whether the underlying type is a `Bool`, as it's guaranteed as part of
        // swift-corelibs-foundation, per [this discussion on the Swift forums](https://forums.swift.org/t/alamofire-on-linux-possible-but-not-release-ready/34553/22).
        String(cString: objCType) == "c"
    }
}

