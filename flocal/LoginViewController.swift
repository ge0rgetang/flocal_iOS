//
//  LoginViewController.swift
//  flocal
//
//  Created by George Tang on 5/22/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseAnalytics
import FirebaseAuth
import FirebaseDatabase
import FirebaseStorage
import SDWebImage
import SideMenu

class LoginViewController: UIViewController, UITextFieldDelegate, UIPopoverPresentationControllerDelegate {
    
    // MARK: - Outlets

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var flocalTitleLabel: UILabel!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!

    @IBOutlet weak var loginButton: UIButton!
    @IBAction func loginButtonTapped(_ sender: Any) {
        self.login()
    }
    
    @IBOutlet weak var forgotPasswordButton: UIButton!
    @IBAction func forgotPasswordButtonTapped(_ sender: Any) {
        self.presentForgotPassword()
    }
    
    // MARK: - Vars
    
    var ref = Database.database().reference()
    let storageRef = Storage.storage().reference()

    let misc = Misc()
    var activityView = UIView()
    var activityIndicator = UIActivityIndicatorView()
    var activityLabel = UILabel()
    var sideMenuButton = UIButton()
    var sideMenuBarButton = UIBarButtonItem()
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // imageview = image 
        
        self.navigationItem.title = "Login"
        self.navigationController?.navigationBar.tintColor = misc.flocalColor
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: misc.flocalColor]

        self.emailTextField.delegate = self
        self.passwordTextField.delegate = self
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
        tap.cancelsTouchesInView = false
        
        self.loginButton.layer.cornerRadius = 2.5
        self.setSideMenu()
    }

    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.portrait)
        misc.setSideMenuIndex(1)

        self.setNotifications()
        self.logViewLogin()
        self.loginButton.isEnabled = true
        self.emailTextField.text = ""
        self.passwordTextField.text = ""
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
        self.removeNotifications()
        self.activityView.removeFromSuperview()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        misc.clearWebImageCache()
    }
    
    // MARK: - SideMenu
    
    func setSideMenu() {
        if let sideMenuNavigationController = storyboard?.instantiateViewController(withIdentifier: "SideMenuNavigationController") as? UISideMenuNavigationController {
            sideMenuNavigationController.leftSide = true
            SideMenuManager.menuLeftNavigationController = sideMenuNavigationController
            SideMenuManager.menuPresentMode = .menuSlideIn
            SideMenuManager.menuAnimationBackgroundColor = misc.flocalSideMenu
            SideMenuManager.menuAnimationFadeStrength = 0.35
            SideMenuManager.menuAnimationTransformScaleFactor = 1.0
            SideMenuManager.menuAddPanGestureToPresent(toView: self.navigationController!.navigationBar)
            SideMenuManager.menuAddScreenEdgePanGesturesToPresent(toView: self.navigationController!.view, forMenu: UIRectEdge.left)
            
            self.sideMenuButton.setImage(UIImage(named: "menuS"), for: .normal)
            self.sideMenuButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            self.sideMenuButton.addTarget(self, action: #selector(self.presentSideMenu), for: .touchUpInside)
            self.sideMenuBarButton.customView = self.sideMenuButton
            self.navigationItem.setLeftBarButton(self.sideMenuBarButton, animated: false)
        }
    }
    
    @objc func presentSideMenu() {
        self.present(SideMenuManager.menuLeftNavigationController!, animated: true, completion: nil)
    }


    // MARK: - Navigation
    
    func presentForgotPassword() {
        let forgotPasswordViewController = storyboard?.instantiateViewController(withIdentifier: "ForgotPasswordViewController") as! ForgotPasswordViewController
        forgotPasswordViewController.modalPresentationStyle = .popover
        forgotPasswordViewController.preferredContentSize = CGSize(width: 320, height: 100)
        
        if let popoverController = forgotPasswordViewController.popoverPresentationController {
            popoverController.delegate = self
            popoverController.sourceView = self.forgotPasswordButton
            popoverController.sourceRect = self.forgotPasswordButton.bounds
        }
        
        self.present(forgotPasswordViewController, animated: true, completion: nil)
    }
    
    // MARK: - Popover
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
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
    
    // MARK: - Keyboard
    
    @objc func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    @objc func keyboardWillShow(_ notification: Notification) {
        var userInfo = notification.userInfo!
        var keyboardFrame: CGRect = (userInfo[UIKeyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue
        keyboardFrame = self.view.convert(keyboardFrame, from: nil)
        
        var contentInset: UIEdgeInsets = self.scrollView.contentInset
        contentInset.bottom = keyboardFrame.size.height + 8
        self.scrollView.contentInset = contentInset
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        let contentInset: UIEdgeInsets = UIEdgeInsets.zero
        self.scrollView.contentInset = contentInset
    }
    
    // MARK: - Notification Center
    
    func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow(_:)), name: Notification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: Notification.Name.UIKeyboardWillHide, object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIKeyboardWillHide, object: nil)
    }
    
    // MARK: - Misc
    
    func displayAlert(_ alertTitle: String, alertMessage: String) {
        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        alertController.view.tintColor = misc.flocalColor
        DispatchQueue.main.async(execute: {
            self.activityView.removeFromSuperview()
            self.loginButton.isEnabled = true
            self.present(alertController, animated: true, completion: nil)
        })
    }
    
    func displayActivity(_ message: String, indicator: Bool) {
        self.activityLabel = UILabel(frame: CGRect(x: 8, y: 0, width: self.view.frame.width - 16, height: 50))
        self.activityLabel.text = message
        self.activityLabel.textAlignment = .center
        self.activityLabel.textColor = .white
        self.activityView = UIView(frame: CGRect(x: 8, y: self.view.frame.height/2 - 77.5, width: self.view.frame.width - 16, height: 50))
        self.activityView.backgroundColor = UIColor(white: 0, alpha: 0.5)
        self.activityView.layer.cornerRadius = 5
        if indicator {
            self.activityIndicator.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
            self.activityView.addSubview(self.activityIndicator)
            self.activityIndicator.activityIndicatorViewStyle = .white
            self.activityIndicator.startAnimating()
        }
        self.activityView.addSubview(self.activityLabel)
        self.view.addSubview(self.activityView)
    }
    
    // MARK: - Analytics
    
    func logViewLogin() {
        Analytics.logEvent("viewLogin_iOS", parameters: nil)
    }
    
    func logLoggedIn(_ userID: String) {
        Analytics.logEvent("loggedIn_iOS", parameters: [
            "userID": userID as NSObject
            ])
    }
    
    // MARK: - Firebase
    
    func login() {
        misc.playSound("button_click.wav", start: 0)
        self.dismissKeyboard()
        self.displayActivity("logging in...", indicator: true)
        
        let email: String = self.emailTextField.text!.trimSpace()
        let password: String = self.passwordTextField.text!
        
        if email.isEmpty || password.isEmpty {
            self.displayAlert("Incomplete Info", alertMessage: "Please fill the empty fields.")
            return
        }
        
        var deviceToken: String
        if let token = UserDefaults.standard.string(forKey: "deviceToken.flocal") {
            deviceToken = token
        } else {
            deviceToken = "n/a"
        }

        Auth.auth().signIn(withEmail: email, password: password) {(user, error) in
            self.activityView.removeFromSuperview()

            if error != nil {
                print(error ?? "error")
                if let desc = error?.localizedDescription {
                    if desc == "The user account has been disabled by an administrator." {
                        self.displayAlert("Account Disabled", alertMessage: "Your account has been disabled. Please contact us for further information.")
                        return
                    } else {
                        self.displayAlert("Invalid Login", alertMessage: "Your email/pass was incorrect.")
                        return
                    }
                } else {
                    self.displayAlert("Invalid Login", alertMessage: "Your email/pass was incorrect.")
                    return
                }
            } else {
                if let user = Auth.auth().currentUser {
                    let uid = user.uid
                    let userRef = self.ref.child("users").child(uid)

                    UserDefaults.standard.removeObject(forKey: "myID.flocal")
                    UserDefaults.standard.set(uid, forKey: "myID.flocal")
                    UserDefaults.standard.synchronize()
                    
                    let loginFirstTime = UserDefaults.standard.bool(forKey: "loginFirstTime.flocal")
                    if loginFirstTime {
                        UserDefaults.standard.removeObject(forKey: "loginFirstTime.flocal")
                        UserDefaults.standard.synchronize()
                        let h = UserDefaults.standard.string(forKey: "handle.flocal")
                        let handle = h ?? "Please tap to reset your handle"
                        userRef.child("email").setValue(email)
                        userRef.child("handle").setValue(handle)
                        userRef.child("handleLower").setValue(handle.lowercased())
                        userRef.child("name").setValue("no name set")
                        userRef.child("description").setValue("no description set")
                        userRef.child("birthday").setValue("no bday set")
                        userRef.child("phoneNumber").setValue("no phone set")
                        userRef.child("longitude").setValue(420)
                        userRef.child("latitude").setValue(420)
                        userRef.child("followersCount").setValue(0)
                        userRef.child("points").setValue(0)
                        userRef.child("postPoints").setValue(0)
                        userRef.child("replyPoints").setValue(0)
                        userRef.child("lastNotificationType").setValue("clear")
                        userRef.child("notificationBadge").setValue(0)
                    }
                    
                    userRef.child("deviceToken").setValue(deviceToken)
                    userRef.child("OS").setValue("iOS")
                    
                    self.misc.clearWebImageCache()
                    let profilePicRefLarge = self.storageRef.child("profilePic/\(uid)_large.jpg")
                    profilePicRefLarge.downloadURL { url, error in
                        if let error = error {
                            print(error.localizedDescription)
                        } else {
                            let image = UIImageView()
                            image.sd_setImage(with: url)
                        }
                    }
                    let profilePicRefSmall = self.storageRef.child("profilePic/\(uid)_small.jpg")
                    profilePicRefSmall.downloadURL { url, error in
                        if let error = error {
                            print(error.localizedDescription)
                        } else {
                            let image = UIImageView()
                            image.sd_setImage(with: url)
                        }
                    }
                    
                    self.logLoggedIn(uid)
                    self.misc.postToNotificationCenter("turnToMe")
                }
            }
        }
        
    }

}
