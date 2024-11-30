//
//  StripeIssuingExample
//  Copyright (c) 2024 Stripe Inc
//

import UIKit
import PassKit

class ActionViewController: UIViewController, PKIssuerProvisioningExtensionAuthorizationProviding {
    
    var completionHandler: ((PKIssuerProvisioningExtensionAuthorizationResult) -> Void)?
    
    @IBAction func authenticate(sender: UIButton) {
           completionHandler?(PKIssuerProvisioningExtensionAuthorizationResult.authorized)
       }
       
   @IBAction func cancel(sender: UIButton) {
         completionHandler?(PKIssuerProvisioningExtensionAuthorizationResult.canceled)
    }
}
