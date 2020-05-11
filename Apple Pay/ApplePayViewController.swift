//
//  ApplePayViewController.swift
//  Apple Pay
//
//  Created by Rahul Sharma on 29/10/19.
//  Copyright © 2019 3Embed. All rights reserved.
//

import UIKit
import PassKit
import Stripe
class ApplePayViewController: UIViewController {

    
    @IBOutlet weak var applePayBtn: UIButton!
    let applePayButton: PKPaymentButton = PKPaymentButton(paymentButtonType: .plain, paymentButtonStyle: .black)
    var paymentSucceeded = false


    override func viewDidLoad() {
        super.viewDidLoad()
        applePayButton.isEnabled = Stripe.deviceSupportsApplePay()

        // Do any additional setup after loading the view.
    }
    @IBAction func applePayAtn(_ sender: Any) {
        handleApplePayButtonTapped()
    }
    
    func handleApplePayButtonTapped() {
        let merchantIdentifier = "merchant.com.demo.applypay"
        let paymentRequest = Stripe.paymentRequest(withMerchantIdentifier: merchantIdentifier, country: "US", currency: "USD")

        // Configure the line items on the payment request
        paymentRequest.paymentSummaryItems = [
            PKPaymentSummaryItem(label: "Fancy Hat", amount: 0.01),
            // The final line should represent your company;
            // it'll be prepended with the word "Pay" (i.e. "Pay iHats, Inc $50")
            PKPaymentSummaryItem(label: "iHats, Inc", amount: 0.01),
        ]
        
        // Present Apple Pay payment sheet
        /**
         Whether or not this device is capable of using Apple Pay. This checks both
         whether the device supports Apple Pay, as well as whether or not they have
         stored Apple Pay cards on their device.

         @param paymentRequest The return value of this method depends on the
         `supportedNetworks` property of this payment request, which by default should be
         `@[PKPaymentNetworkAmex, PKPaymentNetworkMasterCard, PKPaymentNetworkVisa, PKPaymentNetworkDiscover]`.

         @return whether or not the user is currently able to pay with Apple Pay.
        */

        if Stripe.canSubmitPaymentRequest(paymentRequest),
            let paymentAuthorizationViewController = PKPaymentAuthorizationViewController(paymentRequest: paymentRequest) {
            paymentAuthorizationViewController.delegate = self
            present(paymentAuthorizationViewController, animated: true)
            
        } else {
            let alert = UIAlertController(title: "Alert", message: "There is no card or your device not support Apple Pay", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)

            // There is a problem with your Apple Pay configuration
        }
    }

    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
}

extension ApplePayViewController: PKPaymentAuthorizationViewControllerDelegate, STPAuthenticationContext {
    func authenticationPresentingViewController() -> UIViewController {
        return self
    }

    @available(iOS 11.0, *)
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, handler: @escaping (PKPaymentAuthorizationResult) -> Void) {
        // Convert the PKPayment into a PaymentMethod
        STPAPIClient.shared().createPaymentMethod(with: payment) { (paymentMethod: STPPaymentMethod?, error: Error?) in
            guard let paymentMethod = paymentMethod, error == nil else {
                // Present error to customer...
                return
            }
            let clientSecret = "client secret of the PaymentIntent created at the beginning of the checkout flow"
            let paymentIntentParams = STPPaymentIntentParams(clientSecret: clientSecret)
            paymentIntentParams.paymentMethodId = paymentMethod.stripeId

            // Confirm the PaymentIntent with the payment method
            STPPaymentHandler.shared().confirmPayment(withParams: paymentIntentParams, authenticationContext: self) { (status, paymentIntent, error) in
                switch (status) {
                case .succeeded:
                    // Save payment success
                    self.paymentSucceeded = true
                    handler(PKPaymentAuthorizationResult(status: .success, errors: nil))
                case .canceled:
                    handler(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                case .failed:
                    // Save/handle error
                    let errors = [STPAPIClient.pkPaymentError(forStripeError: error)].compactMap({ $0 })
                    handler(PKPaymentAuthorizationResult(status: .failure, errors: errors))
                @unknown default:
                    handler(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                }
            }
        }
    }

    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        // Dismiss payment authorization view controller
        dismiss(animated: true, completion: {
            if (self.paymentSucceeded) {
                // Show a receipt page...
            } else {
                // Present error to customer...
            }
        })
    }
}
