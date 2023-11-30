//
//  CardPage.swift
//  StripeIssuingExample
//
//  Created by Vlad Chernis on 11/2/23.
//

import UIKit
import PassKit

class CardPage: UIView, UITableViewDataSource {

    var card: Card!

    // Returns nil when the serial number isn't definitively known. This happens when:
    // - more than one passes match our card, we can't know for sure which pass's serial number to return. This seems
    //   unlikely, but actually happens since the combination of (last4, primaryAccountIdentifier) isn't guaranteed to
    //   uniquely identify a pass.
    // - no passes match, for example if our card has a nil primaryAccountIdentifiers. This happens when the card hasn't
    //   yet been added to *any* wallet.
    var serialNumber: String? {
        let passLib = PKPassLibrary()
        let sePasses = passLib.remoteSecureElementPasses + passLib.passes().compactMap { $0.secureElementPass }
        let matches = sePasses.filter { pass in
            card.last4 == pass.primaryAccountNumberSuffix &&
            card.primaryAccountIdentifier == pass.primaryAccountIdentifier
        }
        return if matches.count == 1 {
            matches.first?.serialNumber
        } else {
            nil
        }
    }

    // MARK: - Outlets

    /// A table view used to display basic info for a single issuing card
    @IBOutlet var tableView: UITableView!

    override func awakeFromNib() {
        super.awakeFromNib()
        tableView.dataSource = self
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        6
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = UITableViewCell(style: .value1, reuseIdentifier: "cell")

        if indexPath.row == 0 {
            cell.textLabel?.text = "Name"
            cell.detailTextLabel?.text = card.cardholderName
        } else if indexPath.row == 1 {
            cell.textLabel?.text = "Last 4"
            cell.detailTextLabel?.text = card.last4
        } else if indexPath.row == 2 {
            cell.textLabel?.text = "Eligible for Apple Pay"
            let eligibleText = String(card.eligibleForApplePay)
            cell.detailTextLabel?.text = eligibleText
        } else if indexPath.row == 3 {
            cell.textLabel?.text = "Can add to wallet"
            cell.detailTextLabel?.text = String(card.canAddToWallet())
        } else if indexPath.row == 4 {
            let inWallet = card.isInWallet()
            cell.textLabel?.text = "Is in wallet"
            cell.detailTextLabel?.text = "local: \(String(inWallet.local)), remote: \(String(inWallet.remote))"
        } else if indexPath.row == 5 {
            cell.textLabel?.text = "Brand"
            cell.detailTextLabel?.text = card?.brand.rawValue
        }

        return cell
    }
}
