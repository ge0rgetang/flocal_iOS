//
//  EditLoginViewController.swift
//  flocal
//
//  Created by George Tang on 5/23/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseDatabase
import FirebaseAnalytics
import FirebaseAuth

class EditLoginViewController: UIViewController, UITextFieldDelegate {

    // MARK: - Outlets

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var currentEmailTextField: UITextField!
    @IBOutlet weak var currentPasswordTextField: UITextField!
    @IBOutlet weak var instructionsLabel: UILabel!
    @IBOutlet weak var newEmailTextField: UITextField!
    @IBOutlet weak var newPasswordTextField: UITextField!
    
    @IBOutlet weak var confirmButton: UIButton!
    @IBAction func confirmButtonTapped(_ sender: Any) {
        self.authenticate()
    }
    
    // MARK - Vars
    
    var myID: String = "0"
    var currentEmailText: String = "blank"
    var ref = Database.database().reference()
    let misc = Misc()
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if self.currentEmailText != "blank" {
            self.currentEmailTextField.text = self.currentEmailText
        }
        
        self.currentEmailTextField.delegate = self
        self.currentEmailTextField.tag = 0
        self.currentPasswordTextField.delegate = self
        self.currentPasswordTextField.tag = 1
        self.newEmailTextField.delegate = self
        self.newEmailTextField.tag = 2
        self.newPasswordTextField.delegate = self
        self.newPasswordTextField.tag = 3
        
        self.titleLabel.textColor = misc.flocalBlue
        self.confirmButton.backgroundColor = misc.flocalBlue 
        self.confirmButton.layer.cornerRadius = 2.5

        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
        
        self.myID = misc.setMyID()
        if self.myID == "0" {
            let alertController = UIAlertController(title: "Oops", message: "We messed up and can't change info at this time. Please report this bug if it persists", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "Ok", style: .default) { action in
                self.dismiss(animated: true, completion: nil)
            }
            alertController.view.tintColor = self.misc.flocalColor
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.portrait)
        self.confirmButton.isEnabled = true
        self.logViewEditLogin()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let loginLabelHeight = self.titleLabel.frame.size.height
        let emailHeight = self.currentEmailTextField.frame.size.height
        let passHeight = self.currentPasswordTextField.frame.size.height
        
        let infoHeight = self.instructionsLabel.frame.size.height
        let newEmailHeight = self.newEmailTextField.frame.size.height
        let newPassHeight = self.newPasswordTextField.frame.size.height
        
        let confirmButtonHeight = self.confirmButton.frame.size.height
        
        let preferredHeight = loginLabelHeight + emailHeight + passHeight + infoHeight + newEmailHeight + newPassHeight + confirmButtonHeight + 112
        self.preferredContentSize = CGSize(width: 320, height: preferredHeight)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - TextField
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }
        let length = text.characters.count + string.characters.count - range.length
        return length <= 255
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.dismissKeyboard()
    }
    
    // MARK: - Keyboard
    
    @objc func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    // MARK: - Misc
    
    func displayAlert(_ alertTitle: String, alertMessage: String) {
        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        alertController.view.tintColor = misc.flocalColor
        DispatchQueue.main.async(execute: {
            self.confirmButton.isEnabled = true
            self.present(alertController, animated: true, completion: nil)
        })
    }
    
    // MARK: - Analytics
    
    func logViewEditLogin() {
        Analytics.logEvent("viewEditLogin_iOS", parameters: [
            "myID": self.myID as NSObject
            ])
    }
    
    func logEditedEmail() {
        Analytics.logEvent("editedEmail_iOS", parameters: [
            "myID": self.myID as NSObject,
            ])
    }
    
    func logEditedPass() {
        Analytics.logEvent("editedPassword_iOS", parameters: [
            "myID": self.myID as NSObject,
            ])
    }
    
    // MARK: - Firebase
    
    func authenticate() {
        misc.playSound("button_click.wav", start: 0)
        self.dismissKeyboard()
        self.confirmButton.isEnabled = false
        
        let emailText: String! = self.currentEmailTextField.text?.trimSpace()
        let passText: String! = self.currentPasswordTextField.text
        let newPassText: String! = self.newPasswordTextField.text
        
        if emailText.isEmpty || passText.isEmpty {
            self.displayAlert("Current Login Info Empty", alertMessage: "Please fill in your current email and password.")
            return
        }
        
        if !newPassText.isEmpty && newPassText.characters.count < 6 {
            self.displayAlert("New Password Too Short", alertMessage: "Your new password needs to be at least 6 characters.")
            return
        }
        
        let credential = EmailAuthProvider.credential(withEmail: emailText!, password: passText!)
        let user = Auth.auth().currentUser
        user?.reauthenticate(with: credential) { error in
            if error != nil {
                self.displayAlert("Oops", alertMessage: "Please check to see your email and password are valid.")
                return
            } else {
                self.editLoginInfo()
            }
        }
    }
    
    func updatePassword(_ newPassword: String) {
        let user = Auth.auth().currentUser
        user?.updatePassword(to: newPassword) { error in
            if error != nil {
                print(error?.localizedDescription ?? "error")
                self.displayAlert("Oops", alertMessage: "We encountered an email error - please try again. Report the bug if it persists.")
                return
            } else {
                self.logEditedPass()
            }
        }
    }
    
    func updateEmail(_ newEmail: String) {
        let user = Auth.auth().currentUser
        user?.updateEmail(to: newEmail) { error in
            if error != nil {
                print(error?.localizedDescription ?? "error")
                self.displayAlert("Oops", alertMessage: "We encountered a password error - please try again. Report the bug if it persists.")
                return
            } else {
                let ref = self.ref.child("users").child(self.myID)
                ref.child("email").setValue(newEmail)
                self.logEditedEmail()
            }
        }
    }
    
    func editLoginInfo() {
        let newEmail: String! = self.newEmailTextField.text?.trimSpace()
        let newPassword: String! = self.newPasswordTextField.text
        
        if !newPassword.isEmpty {
            self.updatePassword(newPassword!)
        }
        
        if !newEmail.isEmpty {
            self.updateEmail(newEmail!)
        }
        
        self.dismiss(animated: true, completion: nil)
    }

}
