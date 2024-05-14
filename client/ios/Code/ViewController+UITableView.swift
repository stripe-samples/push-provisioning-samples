//
//  ViewController+UITableViewDataSource.swift
//  StripeIssuingExample
//
//  Created by Vlad Chernis on 5/14/24.
//

import Foundation
import UIKit

extension ViewController: UITableViewDataSource, UITableViewDelegate {

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "cell")
        if indexPath.row == 0 {
            cell.textLabel?.text = "Server config"
            cell.detailTextLabel?.text = server.baseUrl.absoluteString
        }
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            didClickServerURL()
        }
    }

    /// update server URL
    func didClickServerURL() {
        let alert = UIAlertController(
            title: "Server config",
            message: nil,
            preferredStyle: UIAlertController.Style.alert
        )

        let ok = UIAlertAction(title: "OK", style: .default) { (alertAction) in
            let addressField = alert.textFields![0] as UITextField
            let userField = alert.textFields![1] as UITextField
            let passwordField = alert.textFields![2] as UITextField

            if let newAddress = addressField.text, newAddress != "" {
                if let newUrl = URL(string: newAddress) {
                    self.server.baseUrl = newUrl
                    self.tableView.reloadData()

                    let defaults = UserDefaults.standard
                    defaults.set(newAddress, forKey: "SAMPLE_PP_BACKEND_URL")
                } else {
                    self.log.warning("invalid URL: \(newAddress, privacy: .public)")
                }
            }

            if let newUser = userField.text, newUser != "" {
                self.server.user = newUser
                self.tableView.reloadData()

                let defaults = UserDefaults.standard
                defaults.set(newUser, forKey: "SAMPLE_PP_BACKEND_USERNAME")
            }

            if let newPassword = passwordField.text, newPassword != "" {
                self.server.password = newPassword
                self.tableView.reloadData()

                let defaults = UserDefaults.standard
                defaults.set(newPassword, forKey: "SAMPLE_PP_BACKEND_PASSWORD")
            }
        }

        alert.addTextField { (textField) in
            textField.placeholder = "URL"
            textField.text = self.server.baseUrl.absoluteString
        }

        alert.addTextField { (textField) in
            textField.placeholder = "username"
            textField.text = self.server.user
        }

        alert.addTextField { (textField) in
            textField.placeholder = "password"
            textField.text = self.server.password
        }

        alert.addAction(ok)

        alert.addAction(UIAlertAction(title: "Cancel", style: .default))

        present(alert, animated: true, completion: nil)
    }
}
