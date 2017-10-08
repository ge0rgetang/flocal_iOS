//
//  SignUpViewController.swift
//  flocal
//
//  Created by George Tang on 5/10/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseAnalytics
import FirebaseDatabase
import FirebaseAuth
import FirebaseStorage
import SDWebImage
import SideMenu

class SignUpViewController: UIViewController, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPopoverPresentationControllerDelegate {
    
    // MARK: - Outlets
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var addPicLabel: UILabel!
    @IBOutlet weak var profilePicImageView: UIImageView!
    @IBOutlet weak var checkHandleLabel: UILabel!
    @IBOutlet weak var handleTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!

    @IBOutlet weak var signUpButton: UIButton!
    @IBAction func signUpButtonTapped(_ sender: Any) {
        self.signUp()
    }
    
    @IBOutlet weak var privacyButton: UIButton!
    @IBAction func privacyButtonTapped(_ sender: Any) {
        self.openPrivacyPolicy()
    }
    
    @IBOutlet weak var termsButton: UIButton!
    @IBAction func termsButtonTapped(_ sender: Any) {
        self.presentTermsPop()
    }
    
    // MARK: - Vars
    
    var isPicSet: Bool = false
    var handleExists: String = "error"
    var urlStringToPass: String = "error"
    
    var ref = Database.database().reference()
    let storageRef = Storage.storage().reference()

    let misc = Misc()
    var imagePicker = UIImagePickerController()
    var activityView = UIView()
    var activityIndicator = UIActivityIndicatorView()
    var activityLabel = UILabel()
    var sideMenuButton = UIButton()
    var sideMenuBarButton = UIBarButtonItem()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "Sign Up"
        self.navigationController?.navigationBar.tintColor = misc.flocalColor
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: misc.flocalColor]

        self.handleTextField.delegate = self
        self.emailTextField.delegate = self
        self.passwordTextField.delegate = self
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
        tap.cancelsTouchesInView = false
        
        let tapPic: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.selectPicSource))
        self.profilePicImageView.addGestureRecognizer(tapPic)
        
        self.signUpButton.layer.cornerRadius = 2.5
        self.setImagePicker()
        self.setSideMenu()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.portrait)
        self.logViewSignUp()

        misc.setSideMenuIndex(0)
        self.setNotifications()
        self.signUpButton.isEnabled = true
        self.profilePicImageView.isUserInteractionEnabled = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
        self.activityView.removeFromSuperview()
        self.removeNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        misc.clearWebImageCache()
    }
    
    // MARK: - Navigation
    
    func presentTermsPop() {
        let termsPopViewController = storyboard?.instantiateViewController(withIdentifier: "TermsViewController") as! TermsViewController
        termsPopViewController.modalPresentationStyle = .popover
        termsPopViewController.preferredContentSize = CGSize(width: 320, height: 320)
        
        if let popoverController = termsPopViewController.popoverPresentationController {
            popoverController.delegate = self
            popoverController.sourceView = self.termsButton
            popoverController.sourceRect = self.termsButton.bounds
        }
        
        self.present(termsPopViewController, animated: true, completion: nil)
    }
    
    func openPrivacyPolicy() {
        if let linkURL = URL(string: "https://www.iubenda.com/privacy-policy/7955712") {
            self.logViewPrivacyPolicy()
            UIApplication.shared.open(linkURL, options: [:], completionHandler: nil)
        }
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
    
    // MARK: - ImagePicker
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
        
        if let selectedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
            self.profilePicImageView.image = selectedImage
            self.isPicSet = true
            self.setUserImage()
        }
        
        self.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
        if !self.isPicSet {
            self.profilePicImageView.image = UIImage(named: "addPic")
        }
    }
    
    @objc func selectPicSource() {
        DispatchQueue.main.async(execute: {
            self.dismissKeyboard()
            if !self.isPicSet {
                self.profilePicImageView.image = UIImage(named: "addPicS")
            }
            
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let takeSelfieAction = UIAlertAction(title: "Take a Selfie!", style: .default, handler: { action in
                    self.imagePicker.sourceType = .camera
                    self.imagePicker.cameraCaptureMode = .photo
                    self.imagePicker.cameraDevice = .front
                    if !self.isPicSet {
                        self.profilePicImageView.image = UIImage(named: "addPic")
                    }
                    self.present(self.imagePicker, animated: true, completion: nil)
                })
                alertController.addAction(takeSelfieAction)
            }
            
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                let choosePhotoLibraryAction = UIAlertAction(title: "Choose from Photo Library", style: .default, handler: { action in
                    self.imagePicker.sourceType = .photoLibrary
                    if !self.isPicSet {
                        self.profilePicImageView.image = UIImage(named: "addPic")
                    }
                    self.present(self.imagePicker, animated: true, completion: nil)
                })
                alertController.addAction(choosePhotoLibraryAction)
            }
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: {
                action in
                if !self.isPicSet {
                    self.profilePicImageView.image = UIImage(named: "addPic")
                }
            })
            )
            alertController.view.tintColor = self.misc.flocalColor
            self.misc.playSound("button_click.wav", start: 0)
            self.present(alertController, animated: true, completion: nil)
        })
    }
    
    func setImagePicker() {
        self.imagePicker.delegate = self
        self.imagePicker.allowsEditing = true
        self.imagePicker.modalPresentationStyle = .fullScreen
    }
    
    // MARK: - TextField
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField.tag == 0 {
            guard let text = textField.text else { return true }
            let length = text.characters.count + string.characters.count - range.length
            return length <= 15
        }
        
        guard let text = textField.text else { return true }
        let length = text.characters.count + string.characters.count - range.length
        return length <= 255
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.tag == 0 {
            if textField.text != "" {
                self.checkHandle(textField.text!.trimSpace())
            }  else {
                self.checkHandleLabel.text = ""
                self.checkHandleLabel.textColor = .lightGray
            }
        }
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
    
    // MARK: - Popover
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
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
            self.signUpButton.isEnabled = true
            self.profilePicImageView.isUserInteractionEnabled = true
            self.present(alertController, animated: true, completion: nil)
        })
    }
    
    func setUserImage() {
        self.view.layoutIfNeeded()
        if self.isPicSet {
            self.profilePicImageView.layer.cornerRadius = profilePicImageView.frame.size.width/2
            self.profilePicImageView.clipsToBounds = true
        } else {
            self.profilePicImageView.layer.cornerRadius = 0
            self.profilePicImageView.clipsToBounds = false
        }
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
    
    func setHandleLabel() {
        DispatchQueue.main.async(execute: {
            switch self.handleExists {
            case "no":
                let spec = self.misc.getSpecialHandles()
                if let handle = self.handleTextField.text?.trimSpace().lowercased() {
                    if spec.contains(handle) {
                        self.checkHandleLabel.text = "Sorry, this handle is unavailable."
                        self.checkHandleLabel.textColor = .red
                    } else {
                        self.checkHandleLabel.text = "This handle is available!"
                        self.checkHandleLabel.textColor = .green 
                    }
                }
            case "yes":
                self.checkHandleLabel.text = "Sorry, this handle is unavailable."
                self.checkHandleLabel.textColor = .red
            case "special":
                self.checkHandleLabel.text = "Only a-z, A-Z, 0-9, . and _ are allowed."
                self.checkHandleLabel.textColor = .red
            case "internet":
                self.checkHandleLabel.text = "No internet. Please try again once you have connected to the web."
                self.checkHandleLabel.textColor = .lightGray
            default:
                self.checkHandleLabel.text = "An error occurred. Please try again later"
                self.checkHandleLabel.textColor = .red
            }
        })
    }
    
    func resetSignUp() {
        self.checkHandleLabel.text = ""
        self.handleTextField.text = ""
        self.emailTextField.text = ""
        self.passwordTextField.text = ""
        self.profilePicImageView.image = UIImage(named: "addPic")
        self.isPicSet = false
        self.setUserImage()
    }
    
    // MARK: - Analytics
    
    func logViewSignUp() {
        Analytics.logEvent("viewSignUp_iOS", parameters: nil)
    }
    
    func logSignedUp(_ userID: String, email: String) {
        Analytics.logEvent("signedUp_iOS", parameters: [
            "userID": userID as NSObject,
            "email": email as NSObject
            ])
    }
    
    func logViewPrivacyPolicy() {
        Analytics.logEvent("viewPrivacyPolicy_iOS", parameters: nil)
    }
    
    // MARK: - Storage 
    
    func uploadPic(_ userID: String, size: String) {
        var picSized: UIImage!
        let picImage = self.profilePicImageView.image
        let sourceWidth = picImage!.size.width
        let sourceHeight = picImage!.size.height
        
        var scaleFactor: CGFloat!
        switch size {
        case "small":
            if sourceWidth > sourceHeight {
                scaleFactor = 100/sourceWidth
            } else {
                scaleFactor = 100/sourceHeight
            }
        default:
            if sourceWidth > sourceHeight {
                scaleFactor = 300/sourceWidth
            } else {
                scaleFactor = 300/sourceHeight
            }
        }
        
        let newWidth = scaleFactor*sourceWidth
        let newHeight = scaleFactor*sourceHeight
        let newSize = CGSize(width: newWidth, height: newHeight)
        
        UIGraphicsBeginImageContext(newSize)
        picImage?.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        picSized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if let newPicData = UIImageJPEGRepresentation(picSized, 1) {
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            let profilePicRef = self.storageRef.child("profilePic/\(userID)_\(size).jpg")
            profilePicRef.putData(newPicData, metadata: metadata) { metadata, error in
                if let error = error {
                    self.displayAlert("Upload Error", alertMessage: "Your profile pic may not have been uploaded. Please try again or report the bug if it persists.")
                    print(error.localizedDescription)
                    return
                } else {
                    print("upload success")
                    if size == "large" {
                        let downloadURL = metadata!.downloadURL()
                        let urlString = downloadURL!.absoluteString
                        self.ref.child("users").child(userID).child("profilePicURLString").setValue(urlString)
                    }
                }
            }
        }
    }
    
    // MARK: - Firebase
    
    func checkHandle(_ handle: String) {
        let handleLower = handle.lowercased()
        let userRef = self.ref.child("users")
        userRef.queryOrdered(byChild: "handleLower").queryEqual(toValue: handleLower).observeSingleEvent(of: .value, with: {(snapshot) in
            if snapshot.exists() {
                self.handleExists = "yes"
                self.setHandleLabel()
            } else {
                let spec = self.misc.getSpecialHandles()
                if spec.contains(handleLower) {
                    self.handleExists = "yes"
                } else {
                    self.handleExists = "no"
                }
                self.setHandleLabel()
            }
        })        
    }
    
    func signUp() {
        self.displayActivity("creating profile...", indicator: true)
        misc.playSound("button_click.wav", start: 0)
        self.dismissKeyboard()
        self.signUpButton.isEnabled = false
        self.profilePicImageView.isUserInteractionEnabled = false
        
        let email: String = self.emailTextField.text!.trimSpace()
        let password: String = self.passwordTextField.text!
        let handle: String = self.handleTextField.text!.trimSpace()
        
        if email.isEmpty || password.isEmpty || handle.isEmpty {
            self.displayAlert("Incomplete Info", alertMessage: "Please fill the empty fields.")
            return
        }
        
        let atSet = CharacterSet(charactersIn: "@")
        if email.rangeOfCharacter(from: atSet) == nil {
            self.displayAlert("Invalid Email", alertMessage: "Please enter a valid email.")
            return
        }
        
        if password.characters.count < 6 {
            self.displayAlert("Password Too Short", alertMessage: "Your pass needs to be at least 6 characters.")
            return
        }
        
        let hasSpecialChars = misc.checkSpecialCharacters(handle)
        if hasSpecialChars {
            self.displayAlert("Special Characters", alertMessage: "Please remove any special characters from your handle. Only a-z, A-Z, 0-9, periods and underscores are allowed.")
            return
        }
        
        let handleLower = handle.lowercased()
        let spec = misc.getSpecialHandles()
        if spec.contains(handleLower) {
            self.displayAlert(":(", alertMessage: "Sorry, this handle is unavailable. Please choose another.")
            return
        }
        
        if self.handleExists != "no" {
            self.displayAlert("Invalid Handle", alertMessage: "Sorry, this handle is invalid or we can't check our server right now. Please try again.")
            return
        }
        
        let spaceCharacter = CharacterSet.whitespaces
        if handle.rangeOfCharacter(from: spaceCharacter) != nil {
            self.displayAlert("Space Found", alertMessage: "Please remove any spaces in your handle.")
            return
        }
        
        var deviceToken: String
        if let token = UserDefaults.standard.string(forKey: "deviceToken.flocal") {
            deviceToken = token
        } else {
            deviceToken = "n/a"
        }
        
        Auth.auth().createUser(withEmail: email, password: password) { (user, error) in
            if error != nil {
                self.displayAlert("Oops", alertMessage: error!.localizedDescription)
                return
            } else {
                let uid = user!.uid
                self.logSignedUp(uid, email: email)
                UserDefaults.standard.removeObject(forKey: "myID.flocal")
                UserDefaults.standard.set(uid, forKey: "myID.flocal")
                UserDefaults.standard.set(handle, forKey: "handle.flocal")
                UserDefaults.standard.synchronize()
                self.loginFirstTime(email, password: password, userID: uid, handle: handle, deviceToken: deviceToken)
            }
        }
    }
    
    func loginFirstTime(_ email: String, password: String, userID: String, handle: String, deviceToken: String) {
        Auth.auth().signIn(withEmail: email, password: password) { (user, error) in
            if error != nil {
                self.displayAlert("waht. How did that happen?", alertMessage: "We seem to have come across a rare error and can't sign you in automatically. Try logging in through the login page. If you still can't login or sign up, please email us at flocalApp@gmail.com.")
                UserDefaults.standard.set(true, forKey: "loginFirstTime.flocal")
                UserDefaults.standard.synchronize()
                print(error!.localizedDescription)
                return
            } else {
                let userRef = self.ref.child("users").child(userID)
                userRef.child("email").setValue(email)
                userRef.child("handle").setValue(handle)
                userRef.child("handleLower").setValue(handle.lowercased())
                userRef.child("name").setValue("no name set")
                userRef.child("description").setValue("no description set")
                userRef.child("birthday").setValue("no bday set")
                userRef.child("phoneNumber").setValue("no phone set")
                userRef.child("deviceToken").setValue(deviceToken)
                userRef.child("OS").setValue("iOS")
                userRef.child("longitude").setValue(420)
                userRef.child("latitude").setValue(420)
                userRef.child("followersCount").setValue(0)
                userRef.child("points").setValue(0)
                userRef.child("postPoints").setValue(0)
                userRef.child("replyPoints").setValue(0)
                userRef.child("lastNotificationType").setValue("clear")
                userRef.child("notificationBadge").setValue(0)
                
                if self.isPicSet {
                    self.uploadPic(userID, size: "large")
                    self.uploadPic(userID, size: "small")
                }
                
                DispatchQueue.main.async(execute: {
                    self.activityView.removeFromSuperview()
                    let alertController = UIAlertController(title: "Sign Up Complete", message: "Welcome to flocal :) Tell your friends to check us out!", preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "Ok", style: .default) { action in
                        self.misc.postToNotificationCenter("turnToMe")
                        self.resetSignUp()
                    }
                    alertController.addAction(okAction)
                    alertController.view.tintColor = self.misc.flocalColor
                    self.signUpButton.isEnabled = true
                    self.misc.clearWebImageCache()
                    self.profilePicImageView.isUserInteractionEnabled = true
                    self.present(alertController, animated: true, completion: nil)
                })
            }
        }
    }

}
