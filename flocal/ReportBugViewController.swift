//
//  ReportBugViewController.swift
//  flocal
//
//  Created by George Tang on 6/15/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseAnalytics
import FirebaseDatabase
import SideMenu

class ReportBugViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate, UIPickerViewDelegate {
    
    // MARK: - Outlets
    
    @IBOutlet weak var notificationLabel: UILabel!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var confirmButton: UIButton!
    @IBAction func confirmButtonTapped(_ sender: Any) {
        self.writeReportBug()
    }
    
    // MARK: - Vars
    
    var myID: String = "0"
    
    var pickerOptions = ["Post issue", "Profile issue", "Peeps issue", "Chat issue", "Other"]
    var oldText: String = "Post issue"
    var oldRow: Int = 0
    var newText: String = "Post issue"
    var newRow: Int = 0
    
    var ref = Database.database().reference()
    
    let misc = Misc()
    var pickerView = UIPickerView()
    var sideMenuButton = UIButton()
    var sideMenuBarButton = UIBarButtonItem()
    var notificationButton = UIButton()
    var notificationBarButton = UIBarButtonItem()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = "Report Bug"
        self.navigationController?.navigationBar.tintColor = misc.flocalBlueGrey
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: misc.flocalBlueGrey]

        self.textField.text = self.oldText
        
        self.setTextView()
        self.setPicker()
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
        self.logViewReportBug()
        misc.setSideMenuIndex(5)
        self.setNotifications()
        misc.observeLastNotificationType(self.notificationLabel, button: self.notificationButton, color: "blueGrey")
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
            
            self.sideMenuButton.setImage(UIImage(named: "menuBlueGreyS"), for: .normal)
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
            
            self.notificationButton.setImage(UIImage(named: "notificationBlueGreyS"), for: .normal)
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
    
    // MARK: - Picker View
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.pickerOptions.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return self.pickerOptions[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.textField.text = self.pickerOptions[row]
        self.newText = self.pickerOptions[row]
        self.newRow = row
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment  = NSTextAlignment.center
        label.numberOfLines = 0 
        label.sizeToFit()
        label.text = self.pickerOptions[row]
        
        return label
    }
    
    @objc func cancelPicker() {
        self.textField.text = self.oldText
        self.pickerView.selectRow(self.oldRow, inComponent: 0, animated: false)
        self.newRow = self.oldRow
        self.newText = self.oldText
        self.dismissKeyboard()
    }
    
    func donePicking() {
        self.oldText = self.newText
        self.oldRow = self.newRow
    }
    
    func setPicker() {
        let toolbar = UIToolbar()
        toolbar.barStyle = .default
        toolbar.isTranslucent = true
        toolbar.sizeToFit()
        
        toolbar.tintColor = misc.flocalColor
        let done = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(self.dismissKeyboard))
        let space = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)
        let cancel = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(self.cancelPicker))
        
        toolbar.setItems([cancel, space, done], animated: false)
        toolbar.isUserInteractionEnabled = true
        
        self.pickerView.backgroundColor = UIColor.white
        self.pickerView.delegate = self
        self.textView.inputView = self.pickerView
        self.textView.inputAccessoryView = toolbar
        self.pickerView.tag = 0
        self.pickerView.selectRow(self.oldRow, inComponent: 0, animated: false)
    }
    
    // MARK: - Text Field
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.donePicking()
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
            textView.text = "describe the bug..."
            textView.textColor = .lightGray
        }
    }
    
    func setTextView() {
        self.textView.text = "describe the bug..."
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
        alertController.view.tintColor = misc.flocalBlueGrey
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
    
    func logViewReportBug() {
        Analytics.logEvent("viewReportBug_iOS", parameters: [
            "myID": self.myID as NSObject
            ])
    }
    
    func logWroteReportBug() {
        Analytics.logEvent("wroteReportBug_iOS", parameters: [
            "myID": self.myID as NSObject
            ])
    }
    
    // MARK: - Firebase
    
    func writeReportBug() {
        misc.playSound("button_click.wav", start: 0)
        self.dismissKeyboard()

        let reason = self.textField.text

        var text: String
        if self.textView.text.isEmpty || self.textView.textColor != .black {
            self.displayAlert("Empty Field", alertMessage: "Please enter text in the text field.")
            return
        } else {
            text = self.textView.text!
        }
        
        self.ref.child("bugs").childByAutoId().setValue(["myID": self.myID, "OS": "iOS", "reason": reason, "description": text])
        
        self.logWroteReportBug()
        self.displayAlert("Thank you :)", alertMessage: "Your bug report has been received. We'll try to resolve the issue in the next update!")
        self.textView.text = ""
    }

}
