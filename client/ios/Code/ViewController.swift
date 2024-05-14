//
//  StripeIssuingExample
//

import OSLog
import PassKit
import Stripe
import UIKit

/// This class illustrates, as simply as possible, how to perform push provisioning in iOS using Stripe Issuing.
class ViewController: UIViewController, STPIssuingCardEphemeralKeyProvider, UIScrollViewDelegate {
    // MARK: - Properties

    /// The card we'll be provisioning. Initialize it to a default empty `Card` so the UI has something to display.
    private var _card: Card? = nil
    var card: Card? {
        get {
            _card
        }
        set(newCard) {
            if card != newCard {
                _card = newCard
                addPassButton.isHidden = shouldHideAddPassButton()
            }
        }
    }

    // Issuing cards that, once loaded, can be paged through to choose one to add to wallet
    var cardPages: [CardPage] = []

    /// Ensures log messages go to console.
    public private(set) var log = Logger()

    /// The `Server` we'll use for communication.
    var server = Server()

    private var pkPassLibrary = PKPassLibrary()

    // MARK: - Outlets

    /// The 'Add to Apple Wallet', which is hidden by default in the Storyboard. Apple guidelines require it
    /// to be visible only when conditions are met -- see `retrieveCard`.
    /// To set button style, initialize `addPassButton` in code with `PKAddPassButton(addPassButtonStyle:)`
    @IBOutlet var addPassButton: PKAddPassButton!

    // A text view with instructions.
    @IBOutlet var textView: UITextView!

    // Container for swiping between cards
    @IBOutlet var scrollView: UIScrollView!

    @IBOutlet var pageControl: UIPageControl!

    @IBOutlet var tableView: UITableView!

    // MARK: - View Lifecycle

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ViewController.processNotification(_:)),
            name: NSNotification.Name(
                rawValue: PKPassLibraryNotificationName.PKPassLibraryDidChange.rawValue
            ),
            object: pkPassLibrary
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ViewController.processNotification(_:)),
            name: NSNotification.Name(
                rawValue: PKPassLibraryNotificationName.PKPassLibraryRemotePaymentPassesDidChange.rawValue
            ),
            object: pkPassLibrary
        )
    }

    /// Called by Notification Center, not necessarily on the main thread
    @objc
    private func processNotification(_ notification: NSNotification) {
        func changedPasses(forPasses passes: [PKPass]) -> [ChangedPass] {
            passes.compactMap { pass in
                if let secureElementPass = pass.secureElementPass {
                    .pass(secureElementPass)
                } else {
                    nil
                }
            }
        }

        func changedPasses(forDictionaries dictionaries: [RemovedPassDict]) -> [ChangedPass] {
            dictionaries.compactMap { (dict: RemovedPassDict) -> ChangedPass? in
                guard let serialNumber = dict[.serialNumberUserInfoKey] else { return nil }
                guard let passTypeIdentifier = dict[.passTypeIdentifierUserInfoKey] else { return nil }
                return .removedPass(ChangedPass.Removed(
                    serialNumber: serialNumber,
                    passTypeIdentifier: passTypeIdentifier
                ))
            }
        }

        let info = notification.userInfo
        var allChangedPasses: [ChangedPass] = []

        // PKPassLibraryAddedPassesUserInfoKey: an array of passes
        if let passes = info?[PKPassLibraryNotificationKey.addedPassesUserInfoKey] as? [PKPass] {
            allChangedPasses.append(contentsOf: changedPasses(forPasses: passes))
        }

        // PKPassLibraryReplacementPassesUserInfoKey: an array of passes
        if let passes = info?[PKPassLibraryNotificationKey.replacementPassesUserInfoKey] as? [PKPass] {
            allChangedPasses.append(contentsOf: changedPasses(forPasses: passes))
        }

        // PKPassLibraryRemovedPassInfosUserInfoKey: an array of dictionaries, each of which has keys
        // PKPassLibraryPassTypeIdentifierUserInfoKey and PKPassLibrarySerialNumberUserInfoKey mapping to strings.
        if let dictionaries = info?[PKPassLibraryNotificationKey.removedPassInfosUserInfoKey] as? [RemovedPassDict] {
            allChangedPasses.append(contentsOf: changedPasses(forDictionaries: dictionaries))
        }

        // update UI on main thread
        Task { @MainActor in
            passesDidChange(allChangedPasses)
        }
    }

    private typealias RemovedPassDict = [PKPassLibraryNotificationKey:String]

    enum ChangedPass {
        struct Removed {
            var serialNumber: String
            var passTypeIdentifier: String
        }
        case removedPass(Removed)
        case pass(PKSecureElementPass)

        var serialNumber: String {
            switch self {
            case .removedPass(let removed):
                removed.serialNumber
            case .pass(let pass):
                pass.serialNumber
            }
        }
    }

    func passesDidChange(_ passes: [ChangedPass]) {
        assert(Thread.isMainThread)
        addPassButton.isHidden = shouldHideAddPassButton()
        refreshPages(for: passes)
    }

    private func shouldHideAddPassButton() -> Bool {
        if let card = card {
            // According to section 7.9 _In-App Provisioning Flow Technical Overview of Getting Started with Apple Pay
            // In App Provisioning Verification and Security v4.pdf_, "issuer app checks existing passes with passes()
            // and remoteSecureElementPasses or canAddSecureElementPass(primaryAccountIdentifier:)."
            !card.canAddToWallet() || !card.eligibleForApplePay
        } else {
            true
        }
    }

    /// Refresh a subset of card pages based on serial numbers of changedPasses
    private func refreshPages(for changedPasses: [ChangedPass]) {
        let serialNumbersOfChanges = Set(changedPasses.map { $0.serialNumber })
        let pagesToRefresh = cardPages.filter { page in
            if let serialNumber = page.serialNumber {
                serialNumbersOfChanges.contains(serialNumber)
            } else {
                // always refresh pages with unknown serial numbers to be safe
                true
            }
        }
        pagesToRefresh.forEach {
            $0.tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // PKAddPassButton is fiddly in IB, and this is a simple way to set its action.
        addPassButton.addTarget(self, action: #selector(provisionCard(sender:)), for: .touchUpInside)

        scrollView.delegate = self
        pageControl.numberOfPages = 0
    }

    // MARK: - Actions

    /// Retrieves the cards for this authenticated user from the server.
    @IBAction func retrieveCards(sender: UIButton) {
        Task {
            do {
                let cards = try await server.getEligibleCards()
                guard let chosenCard = cards.first else {
                    addPassButton.isHidden = true
                    alertError(
                        """
                        Please make sure to:
                        (1) have at least one active card available for issuing
                        (2) receive Apple Pay access [\(requestAccessLink)]
                        """,
                        title: "No eligible cards",
                        moreActions: copyLinkAction
                    )
                    return
                }
                card = chosenCard

                setupCardPicker(cards: cards)
                addPassButton.isHidden = shouldHideAddPassButton()
            } catch {
                alertError("\(error.localizedDescription)\n See console for more info.")
            }
        }
    }

    private func alertError(_ message: String, title: String = "Error", moreActions: UIAlertAction...) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        for action in moreActions {
            alert.addAction(action)
        }
        self.present(alert, animated: true, completion: nil)
    }

    private func setupCardPicker(cards: [Card]) {
        cardPages = createCardPages(cards)
        setupScrollView()
        pageControl.numberOfPages = cardPages.count
        pageControl.currentPage = 0
        scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
        view.bringSubviewToFront(pageControl)
    }

    private func createCardPages(_ cards: [Card]) -> [CardPage] {
        cards.map { card in
            let cardPage = Bundle.main.loadNibNamed("CardPage", owner: self, options: nil)?.first as! CardPage
            cardPage.translatesAutoresizingMaskIntoConstraints = false
            cardPage.card = card
            cardPage.tableView.reloadData()
            return cardPage
        }
    }

    private func setupScrollView() {
        var leadingAnchor = scrollView.contentLayoutGuide.leadingAnchor
        for cardPage in cardPages {
            scrollView.addSubview(cardPage)

            NSLayoutConstraint.activate([
                cardPage.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                cardPage.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                cardPage.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
                cardPage.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
                cardPage.leadingAnchor.constraint(equalTo: leadingAnchor)
            ])
            leadingAnchor = cardPage.trailingAnchor
        }
        cardPages.last?.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor).isActive = true
    }

    /// Provision the card into Apple Wallet. See https://stripe.com/docs/issuing/cards/digital-wallets?platform=iOS#provision-a-card
    @IBAction func provisionCard(sender: UIButton) {
        guard let card = card else {
            // This should never happen: card should be non-nil when Add to Apple Wallet button is visible
            return
        }
        let config = STPPushProvisioningContext.requestConfiguration(
            withName: card.cardholderName,
            description: "StripeIssuingExample Card",
            last4: card.last4,
            brand: card.brand.toSTPCardBrand(),
            primaryAccountIdentifier: card.primaryAccountIdentifier
        )
        let controller = PKAddPaymentPassViewController(requestConfiguration: config, delegate: self)
        self.present(controller!, animated: true, completion: nil)
    }

    // MARK: - STPIssuingCardEphemeralKeyProvider

    /// Needed by `STPPushProvisioningContext` to provision a card as described here:
    /// https://stripe.com/docs/issuing/cards/digital-wallets?platform=iOS#provision-a-card
    func createIssuingCardKey(
        withAPIVersion apiVersion: String,
        completion: @escaping STPJSONResponseCompletionBlock
    ) {
        Task {
            do {
                let key = try await server.retrieveEphemeralKey(apiVersion, cardId: card!.id)
                completion(key, nil)
            } catch {
                log.error("createIssuingCardKey received: \(error, privacy: .public)")
                completion(nil, error)
            }
        }
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == self.scrollView else {
            return
        }
        let pageIndex = Int(round(scrollView.contentOffset.x / scrollView.frame.width))
        card = if 0 <= pageIndex && pageIndex < cardPages.count {
            cardPages[pageIndex].card
        } else {
            card ?? nil
        }

        if pageControl.currentPage != pageIndex {
            pageControl.currentPage = pageIndex
        }
    }
}

private let requestAccessLink = "https://stripe.com/docs/issuing/cards/digital-wallets?platform=iOS#request-access"

private let copyLinkAction = UIAlertAction(
    title: "Copy link",
    style: .default,
    handler: { _ in
        UIPasteboard.general.string = requestAccessLink
    }
)
