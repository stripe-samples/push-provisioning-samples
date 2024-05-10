//
//  StripeIssuingExample
//

import OSLog
import StripeCore

/// Server is an interface to the included ruby server endpoints.
/// It is simplified for example purposes.
class Server: NSObject, URLSessionTaskDelegate {

    // MARK: - Properties

    /// Ensures log messages go to console.
    private var log = Logger()

    /// The address to find the ruby server at. As shipped, the server
    /// listens only to `localhost` on the Sinatra port by default.
    var baseUrl = URL(string: "http://127.0.0.1:4242")!

    var user: String!
    var password: String!

    override init() {
        super.init()

        let defaults = UserDefaults.standard
        let infoDictionary = Bundle.main.infoDictionary ?? [:]

        if let urlString = defaults.string(forKey: "SAMPLE_PP_BACKEND_URL") {
            if let baseUrl = URL(string: urlString) {
                self.baseUrl = baseUrl
            } else {
                // erase user default when it's not a valid URL
                defaults.removeObject(forKey: "SAMPLE_PP_BACKEND_URL")
            }
        } else if let urlString = infoDictionary["SAMPLE_PP_BACKEND_URL"] as? String {
            if let baseUrl = URL(string: urlString) {
                self.baseUrl = baseUrl
            } else {
                fatalError("Please check the SAMPLE_PP_BACKEND_URL build setting. `\(urlString)` isn't a URL")
            }
        }

        if let user = defaults.string(forKey: "SAMPLE_PP_BACKEND_USERNAME") {
            self.user = user
        } else {
            user = infoDictionary["SAMPLE_PP_BACKEND_USERNAME"] as? String
        }

        if let password = defaults.string(forKey: "SAMPLE_PP_BACKEND_PASSWORD") {
            self.password = password
        } else {
            password = infoDictionary["SAMPLE_PP_BACKEND_PASSWORD"] as? String
        }

        guard baseUrl != nil else {
            fatalError("Please check the SAMPLE_PP_BACKEND_URL build setting")
        }
        guard user != nil else {
            fatalError("Please check the SAMPLE_PP_BACKEND_USERNAME build setting")
        }
        guard password != nil else {
            fatalError("Please check the SAMPLE_PP_BACKEND_PASSWORD build setting")
        }
    }

    // MARK: - Error

    /// Just a simple thing to throw when needed.
    enum ServerError: Error {
        case genericError(_ message: String)
    }

    // MARK: - Retrieval Functions

    private func requestToEndpoint(
        _ path: String,
        httpMethod: String = "GET",
        formPayload: [String: String] = [:]
    ) async throws -> Data {
        let url = URL(string: "\(baseUrl)/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        if !formPayload.isEmpty {
            guard let formUrlEncodedPayload = urlEncode(formPayload: formPayload) else {
                log.error("failed to form url encode \(httpMethod) payload: \(formPayload) for /\(path)")
                throw ServerError.genericError(
                    "failed to form url encode \(httpMethod) payload: \(formPayload) for /\(path)")
            }
            request.httpBody = formUrlEncodedPayload
        }

        let session = URLSession.shared

        let (data, genericReponse) = try await session.data(for: request, delegate: self)  // delegate for auth
        let response = genericReponse as! HTTPURLResponse // ! for simplicity

        if response.statusCode != 200 {
            log.error("status code: \(response.statusCode) for /\(path)")
            throw ServerError.genericError("status code: \(response.statusCode) for /\(path)")
        }

        return data
    }

    private func urlEncode(formPayload: [String: String]) -> Data? {
        var components = URLComponents()
        components.queryItems = formPayload.map { (name, value) -> URLQueryItem in
            URLQueryItem(name: name, value: value)
        }
        return components.percentEncodedQuery?.data(using: .utf8)
    }

    /// Retrieves the cards from server and filters for eligibility. We can imagine this function retrieves the
    /// appropriately provisioned card for the authenticated user.
    ///
    /// - Throws: Throws on any error.
    ///
    /// - Returns: A decoded `Card` instance.
    func getEligibleCards() async throws -> [Card] {
        let data = try await requestToEndpoint("cards", httpMethod: "GET")

        let decoder: JSONDecoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let cardResponse = try decoder.decode(CardsResponse.self, from: data)
        let eligibleCards = cardResponse.data.filter { card in
            card.eligibleForApplePay
        }
        return eligibleCards
    }

    /// Retrieves an ephemeral key from server. This is passed to the Stripe iOS
    /// API as part of push provisoning.
    ///
    /// - Throws: Throws on any error.
    ///
    /// - Returns: The JSON response, decoded into a Dictionary. This is how
    ///            the API wants it. 
    func retrieveEphemeralKey(_ apiVersion: String, cardId: String) async throws -> [AnyHashable: Any] {
        let formPayload = [
            "api_version": apiVersion,
            "card_id": cardId,
        ]
        let data = try await requestToEndpoint("ephemeral_keys", httpMethod: "POST", formPayload: formPayload)
        let obj = try JSONSerialization.jsonObject(with: data, options: []) as! [AnyHashable: Any] // ! for simplicity
        return obj
    }

    // MARK: - URLSessionTaskDelegate

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (
        URLSession.AuthChallengeDisposition,
        URLCredential?
    ) {
        let authChallengeDisposition: URLSession.AuthChallengeDisposition =
        challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic ?
            .useCredential : .performDefaultHandling

        let credential = URLCredential(user: user, password: password, persistence: .none)
        let credUser = credential.user ?? "(nil user)"
        let credPass = credential.password ?? "(nil password)"
        log.info("received challenge, sending credentials: \(credUser) / \(credPass)")

        return (authChallengeDisposition, credential)
    }
}
