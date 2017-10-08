//
//  ForgotPasswordViewController.swift
//  flocal
//
//  Created by George Tang on 5/30/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseAuth
import FirebaseAnalytics

class ForgotPasswordViewController: UIViewController, UITextFieldDelegate {
    
    // MARK: - Outlets
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var emailTextField: UITextField!
    
    @IBOutlet weak var confirmButton: UIButton!
    @IBAction func confirmButtonTapped(_ sender: Any) {
        self.sendPasswordReset()
    }
    
    // MARK: - Vars
    
    let misc = Misc()
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.confirmButton.layer.cornerRadius = 2.5
        self.emailTextField.delegate = self
        self.preferredContentSize = CGSize(width: 320, height: 100)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.portrait)
        self.logViewForgotPassword()    
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let titleLabelHeight = self.titleLabel.bounds.height
        let emailFieldHeight = self.emailTextField.bounds.height
        let confirmButtonHeight = self.confirmButton.frame.height
        let preferredHeight = titleLabelHeight + emailFieldHeight + confirmButtonHeight
        self.preferredContentSize = CGSize(width: 320, height: preferredHeight + 32)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Text Field
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }
        let length = text.characters.count + string.characters.count - range.length
        return length <= 255
    }
    
    // MARK: - Misc
    
    func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func displayAlert(_ alertTitle: String, alertMessage: String) {
        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        alertController.view.tintColor = misc.flocalColor
        DispatchQueue.main.async(execute: {
            self.confirmButton.isEnabled = true
        })
    }
    
    // MARK: - Analytics
    
    func logViewForgotPassword() {
        Analytics.logEvent("viewForgotPassword_iOS", parameters: nil)
    }
    
    // MARK: - Firebase
    
    func sendPasswordReset() {
        misc.playSound("button_click.wav", start: 0)
        self.dismissKeyboard()
        let email: String = self.emailTextField.text!.trimSpace()
        
        if email.isEmpty {
            self.displayAlert("Incomplete Info", alertMessage: "Please fill the empty fields.")
            return
        }
        
        Auth.auth().sendPasswordReset(withEmail: email, completion: { (error) in
            DispatchQueue.main.async(execute: {
                if error != nil {
                    if let errorString = error?.localizedDescription {
                        self.displayAlert("Oops", alertMessage: errorString)
                        return
                    } else {
                        self.displayAlert("Oops", alertMessage: "An error occured. Please try again later. If the problem persists, email us at flocalApp@gmail.com")
                        return
                    }
                } else {
                    let alertController = UIAlertController(title: "Email Sent!", message: "Please check your email to reset your password.", preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "Ok", style: .default) { action in
                        self.dismiss(animated: true, completion: nil)
                    }
                    alertController.addAction(okAction)
                    alertController.view.tintColor = self.misc.flocalColor
                    self.present(alertController, animated: true, completion: nil)
                }
            })
        })
        
    }

}
