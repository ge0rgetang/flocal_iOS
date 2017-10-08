//
//  FeedbackViewController.swift
//  flocal
//
//  Created by George Tang on 6/15/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseDatabase
import FirebaseAnalytics
import SideMenu

class FeedbackViewController: UIViewController, UITextViewDelegate {
    
    // MARK: - Outlets
    
    @IBOutlet weak var notificationLabel: UILabel!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var textView: UITextView!
    
    @IBOutlet weak var confirmButton: UIButton!
    @IBAction func confirmButtonTapped(_ sender: Any) {
        self.writeFeedback()
    }
    
    // MARK: - Vars
    
    var myID: String = "0"
    
    var ref = Database.database().reference()
    
    let misc = Misc()
    var sideMenuButton = UIButton()
    var sideMenuBarButton = UIBarButtonItem()
    var notificationButton = UIButton()
    var notificationBarButton = UIBarButtonItem()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = "Feedback"
        self.navigationController?.navigationBar.tintColor = misc.flocalRed
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: misc.flocalRed]

        self.setTextView()
        self.setSideMenu()
        self.setNotificationMenu()
        self.confirmButton.layer.cornerRadius = 2.5

        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
        
        self.myID = misc.setMyID()
        if self.myID == "0" {
            misc.postToNotificationCenter("turnToLogin")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.portrait)
        self.logViewFeedback()
        misc.setSideMenuIndex(6)
        self.setNotifications()
        misc.observeLastNotificationType(self.notificationLabel, button: self.notificationButton, color: "red")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
        self.removeNotifications()
        misc.removeNotificationTypeObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        misc.removeNotificationTypeObserver()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        misc.clearWebImageCache()
    }
    
    // MARK: - Side Menus
    
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
            
            self.sideMenuButton.setImage(UIImage(named: "menuRedS"), for: .normal)
            self.sideMenuButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            self.sideMenuButton.addTarget(self, action: #selector(self.presentSideMenu), for: .touchUpInside)
            self.sideMenuBarButton.customView = self.sideMenuButton
            self.navigationItem.setLeftBarButton(self.sideMenuBarButton, animated: false)
        }
    }
    
    @objc func presentSideMenu() {
        misc.playSound("menu_swish.wav", start: 0.322)
        self.present(SideMenuManager.menuLeftNavigationController!, animated: true, completion: nil)
    }
    
    func setNotificationMenu() {
        if let notificationNavigationController = storyboard?.instantiateViewController(withIdentifier: "NotificationNavigationController") as? UISideMenuNavigationController {
            notificationNavigationController.leftSide = false
            SideMenuManager.menuRightNavigationController = notificationNavigationController
            SideMenuManager.menuPresentMode = .menuSlideIn
            SideMenuManager.menuAnimationBackgroundColor = misc.flocalSideMenu
            SideMenuManager.menuAnimationFadeStrength = 0.35
            SideMenuManager.menuAnimationTransformScaleFactor = 1.0
            SideMenuManager.menuAddPanGestureToPresent(toView: self.navigationController!.navigationBar)
            SideMenuManager.menuAddScreenEdgePanGesturesToPresent(toView: self.navigationController!.view, forMenu: UIRectEdge.right)
            
            self.notificationButton.setImage(UIImage(named: "notificationRedS"), for: .normal)
            self.notificationButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            self.notificationButton.addTarget(self, action: #selector(self.presentNotificationMenu), for: .touchUpInside)
            self.notificationBarButton.customView = self.notificationButton
            self.navigationItem.setRightBarButton(self.notificationBarButton, animated: false)
        }
    }
    
    @objc func presentNotificationMenu() {
        misc.playSound("menu_swish.wav", start: 0.322)
        self.present(SideMenuManager.menuRightNavigationController!, animated: true, completion: nil)
    }
    
    // MARK: - Text View
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == .lightGray {
            textView.text = ""
            textView.textColor = .black
        }
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let currentLength = textView.text.characters.count + (text.characters.count - range.length)
        return currentLength <= 1000
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text == "" {
            textView.text = "Type feedback here..."
            textView.textColor = .lightGray
        }
    }
    
    func setTextView() {
        self.textView.text = "Type feedback here..."
        self.textView.textColor = .lightGray
        self.textView.delegate = self
        self.textView.layer.cornerRadius = 5
        self.textView.layer.borderColor = UIColor.lightGray.withAlphaComponent(1).cgColor
        self.textView.layer.borderWidth = 0.5
        self.textView.clipsToBounds = true
        self.textView.autocorrectionType = .default
        self.textView.spellCheckingType = .default
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
    
    // MARK: - Misc
    
    func displayAlert(_ alertTitle: String, alertMessage: String) {
        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        alertController.view.tintColor = misc.flocalRed
        DispatchQueue.main.async(execute: {
            self.present(alertController, animated: true, completion: nil)
        })
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

    // MARK: - Analytics
    
    func logViewFeedback() {
        Analytics.logEvent("viewFeedback_iOS", parameters: [
            "myID": self.myID as NSObject
            ])
    }
    
    func logWroteFeedback() {
        Analytics.logEvent("wroteFeedback_iOS", parameters: [
            "myID": self.myID as NSObject
            ])
    }
    
    // MARK: - Firebase
    
    func writeFeedback() {
        misc.playSound("button_click.wav", start: 0)
        self.dismissKeyboard()

        var text: String
        if self.textView.text.isEmpty || self.textView.textColor != .black {
            self.displayAlert("Empty Field", alertMessage: "Please enter text in the text field.")
            return
        } else {
            text = self.textView.text!
        }
        
        self.ref.child("feedback").childByAutoId().setValue(["myID": self.myID, "feedback": text])
        
        self.logWroteFeedback()
        self.displayAlert("Thank you :)", alertMessage: "Your feedback has been received. This app is made for people like you, and we'll continue to shape it towards what you guys want!")
        self.textView.text = ""
    }
    
}
