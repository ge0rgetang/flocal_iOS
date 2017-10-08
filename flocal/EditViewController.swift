//
//  EditViewController.swift
//  flocal
//
//  Created by George Tang on 5/23/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseAnalytics
import FirebaseDatabase

class EditViewController: UIViewController, UITextViewDelegate {
    
    // MARK: - Outlets
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var characterCountLabel: UILabel!
    
    @IBOutlet weak var confirmButton: UIButton!
    @IBAction func confirmButtonTapped(_ sender: Any) {
        self.editInfo()
    }
    
    // MARK: - Vars
    
    var myID: String = "0"
    var type: String = "error"
    var textViewText: String = "error"
    var postID: String = "0"
    var replyID: String = "0"
    
    var ref = Database.database().reference()
    
    let misc = Misc()
    
    // MARK: - Lifecycle 
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setTitleAndText()
        self.formatTextView()
        self.confirmButton.layer.cornerRadius = 2.5

        self.myID = misc.setMyID()
        if self.myID == "0" {
            let alertController = UIAlertController(title: "Oops", message: "We messed up and can't edit at this time. Please report this bug if it persists", preferredStyle: .alert)
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
        self.logViewEdit()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let titleLabelHeight = self.titleLabel.frame.size.height
        let textViewHeight = self.textView.frame.size.height
        let confirmButtonHeight = self.confirmButton.frame.size.height
        
        let preferredHeight = titleLabelHeight + textViewHeight + confirmButtonHeight + 48
        self.preferredContentSize = CGSize(width: 320, height: preferredHeight)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        self.dismiss(animated: false, completion: nil)
    }
    
    // MARK: - TextView
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        self.resizeView()
    }
    
    func textViewDidChange(_ textView: UITextView) {
        self.resizeView()
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {        
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        
        let currentLength = textView.text.characters.count + (text.characters.count - range.length)
        var charactersLeft = 255 - currentLength
        if charactersLeft < 0 {
            charactersLeft = 0
        }
        
        if currentLength >= 213 {
            self.characterCountLabel.isHidden = false
            self.characterCountLabel.text = "\(charactersLeft)"
            self.characterCountLabel.textColor = UIColor.lightGray
        } else {
            self.characterCountLabel.isHidden = true
        }
        
        return currentLength <= 255
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if !textView.text.isEmpty {
            let text = textView.text!.trimSpace()
            
            if self.type == "handle" {
                let userRef = self.ref.child("users")
                userRef.queryOrdered(byChild: "handle").queryEqual(toValue: text).observeSingleEvent(of: .value, with: {(snapshot) in
                    if snapshot.exists() {
                        self.titleLabel.text = "Handle Available!"
                        self.titleLabel.textColor = .green
                    } else {
                        if text != self.textViewText {
                            self.titleLabel.text = "Handle Taken :("
                            self.titleLabel.textColor = .red 
                        }
                    }
                })
            }
            
            if self.type == "phone" {
                textView.text = misc.formatPhoneNumber(text)
            }
        }
    }
    
    func formatTextView() {
        self.textView.delegate = self
        self.textView.textColor = .lightGray
        if self.textViewText != "error" {
            self.textView.text = self.textViewText
        }
        self.textView.isScrollEnabled = false
        self.textView.layer.cornerRadius = 5
        self.textView.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.5).cgColor
        self.textView.layer.borderWidth = 0.5
        self.textView.clipsToBounds = true
        self.textView.layer.masksToBounds = true
        self.textView.autocorrectionType = .default
        self.textView.spellCheckingType = .default
    }
    
    // MARK: - Keyboard
    
    func dismissKeyboard() {
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
    
    func setTitleAndText() {
        self.textView.text = self.textViewText
        
        if self.type == "phone" {
            self.textView.keyboardType = .phonePad
        } else {
            self.textView.keyboardType = .default
        }
        
        switch self.type {
        case "handle":
            self.titleLabel.textColor = misc.flocalBlue
            self.confirmButton.backgroundColor = misc.flocalBlue
            self.titleLabel.text = "Change Handle"
            self.textView.textContainer.maximumNumberOfLines = 1
            self.textView.textAlignment = .center
        case "description":
            self.titleLabel.textColor = misc.flocalBlue
            self.confirmButton.backgroundColor = misc.flocalBlue
            self.titleLabel.text = "Edit Description"
            self.textView.textContainer.maximumNumberOfLines = 0
            self.textView.textAlignment = .natural
        case "name":
            self.titleLabel.textColor = misc.flocalBlue
            self.confirmButton.backgroundColor = misc.flocalBlue
            self.titleLabel.text = "Change Name"
            self.textView.textContainer.maximumNumberOfLines = 1
            self.textView.textAlignment = .center
        case "phone":
            self.titleLabel.textColor = misc.flocalBlue
            self.confirmButton.backgroundColor = misc.flocalBlue
            self.titleLabel.text = "Change Phone"
            self.textView.textContainer.maximumNumberOfLines = 1
            self.textView.textAlignment = .center
        case "birthday":
            self.titleLabel.textColor = misc.flocalBlue
            self.confirmButton.backgroundColor = misc.flocalBlue
            self.titleLabel.text = "Change Bday"
            self.textView.textContainer.maximumNumberOfLines = 1
            self.textView.textAlignment = .center
        case "parent":
            self.titleLabel.textColor = misc.flocalColor
            self.confirmButton.backgroundColor = misc.flocalColor
            self.titleLabel.text = "Edit Post"
            self.textView.textContainer.maximumNumberOfLines = 0
            self.textView.textAlignment = .natural
        case "reply":
            self.titleLabel.textColor = misc.flocalYellow
            self.confirmButton.backgroundColor = misc.flocalYellow
            self.titleLabel.text = "Edit Comment"
            self.textView.textContainer.maximumNumberOfLines = 0
            self.textView.textAlignment = .natural
        default:
            self.titleLabel.textColor = misc.flocalRed
            self.confirmButton.backgroundColor = misc.flocalRed
            self.titleLabel.text = "Error"
            let alertController = UIAlertController(title: "Oops", message: "We encountered an error and can't edit right now. Please report the bug if it persists.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "Ok", style: .default) { action in
                self.dismiss(animated: true, completion: nil)
            }
            alertController.addAction(okAction)
            alertController.view.tintColor = self.misc.flocalColor
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func resizeView() {
        let maxHeight: CGFloat = UIScreen.main.bounds.size.height
        let fixedWidth: CGFloat = self.textView.frame.size.width
        let newSize = self.textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat(MAXFLOAT)))
        var newFrame = self.textView.frame
        newFrame.size = CGSize(width: max(newSize.width, fixedWidth), height: min(newSize.height, maxHeight))
        self.textView.frame = newFrame
        UIView.animate(withDuration: 0.1, animations: {
            let titleLabelHeight = self.titleLabel.frame.size.height
            let textViewHeight = self.textView.frame.size.height
            let confirmButtonHeight = self.confirmButton.frame.size.height
            
            let preferredHeight = titleLabelHeight + textViewHeight + confirmButtonHeight + 48
            self.preferredContentSize = CGSize(width: 320, height: preferredHeight)
            self.view.layoutIfNeeded()
        })
    }
    
    // MARK: - Analytics
    
    func logViewEdit() {
        Analytics.logEvent("viewEdit\(self.type.capitalized)_iOS", parameters: [
            "myID": self.myID as NSObject
            ])
    }
    
    func logEdited() {
        Analytics.logEvent("edited\(self.type.capitalized)_iOS", parameters: [
            "myID": self.myID as NSObject
            ])
    }
    
    func logViewEditPost() {
        Analytics.logEvent("viewEditPost_iOS", parameters: [
            "myID": self.myID as NSObject,
            "postID": self.postID as NSObject
            ])
    }
    
    func logEditedPost() {
        Analytics.logEvent("editedPost_iOS", parameters: [
            "myID": self.myID as NSObject,
            "postID": self.postID as NSObject
            ])
    }
    
    func logViewEditReply() {
        Analytics.logEvent("viewEditReply_iOS", parameters: [
            "myID": self.myID as NSObject,
            "postID": self.postID as NSObject,
            "replyID": self.replyID as NSObject
            ])
    }
    
    func logEditedReply() {
        Analytics.logEvent("editedReply_iOS", parameters: [
            "myID": self.myID as NSObject,
            "postID": self.postID as NSObject,
            "replyID": self.replyID as NSObject
            ])
    }
    
    // MARK: - Firebase
 
    func editInfo() {
        self.logEdited()
        self.confirmButton.isEnabled = false
        misc.playSound("button_click.wav", start: 0)
        self.dismissKeyboard()
        
        if self.textView.text.isEmpty {
            self.displayAlert("Empty Field", alertMessage: "Please fill in the empty fill.")
            return
        }
        
        let text = self.textView.text!.trimSpace()
        let meRef = self.ref.child("users").child(self.myID)

        switch self.type {
        case "handle":
            let userRef = self.ref.child("users")
            userRef.queryOrdered(byChild: "handleLower").queryEqual(toValue: text.lowercased()).observeSingleEvent(of: .value, with: {(snapshot) in
                if snapshot.exists() {
                    self.displayAlert("Handle Exists", alertMessage: "This handle is already taken. Please pick a new one or cancel to keep your old one.")
                    return
                    
                } else {
                    let spec = self.misc.getSpecialHandles()
                    if !spec.contains(text.lowercased()) {
                        meRef.child("handle").setValue(text)
                        meRef.child("handleLower").setValue(text.lowercased())
                        
                        self.misc.postToNotificationCenter("addFirebaseObservers")
                        self.dismiss(animated: true, completion: {
                            self.misc.getFollowers(self.myID) { userFollowers in
                                if !userFollowers.isEmpty {
                                    var fanoutObject: [String:Any] = [:]
                                    for followerID in userFollowers {
                                        fanoutObject["/\(followerID)/\(self.myID)/handle"] = text
                                    }
                                    let userAddedRef = self.ref.child("userAdded")
                                    userAddedRef.updateChildValues(fanoutObject)
                                }
                            }
                        })
                        
                    } else {
                        self.displayAlert(":(", alertMessage: "This handle is unavailable Please pick a new one or cancel to keep your old one.")
                        return
                    }
                    
                }
            })

        case "description":
            meRef.child("description").setValue(text)
            self.misc.postToNotificationCenter("addFirebaseObservers")
            self.dismiss(animated: true, completion: {
                self.misc.getFollowers(self.myID) { userFollowers in
                    if !userFollowers.isEmpty {
                        let userAddedRef = self.ref.child("userAdded")
                        var fanoutObject: [String:Any] = [:]
                        for followerID in userFollowers {
                            fanoutObject["/\(followerID)/\(self.myID)/description"] = text
                        }
                        userAddedRef.updateChildValues(fanoutObject)
                    }
                }
            })
            
        case "name":
            meRef.child("name").setValue(text)
            self.misc.postToNotificationCenter("addFirebaseObservers")
            self.dismiss(animated: true, completion: nil)
            
        case "phone":
            let phoneFormatted = misc.formatPhoneNumber(text)
            meRef.child("phoneNumber").setValue(phoneFormatted)
            self.misc.postToNotificationCenter("addFirebaseObservers")
            self.dismiss(animated: true, completion: nil)
            
        case "birthday":
            meRef.child("birthday").setValue(text)
            self.misc.postToNotificationCenter("addFirebaseObservers")
            self.dismiss(animated: true, completion: nil)
            
        case "parent":
            let postRef = self.ref.child("posts").child(self.postID)
            let timestamp = self.misc.getTimestamp("UTC", date: Date())
            postRef.child("content").setValue(text)
            postRef.child("isEdited").setValue(true)
            postRef.child("timestamp").setValue(timestamp)
            self.misc.postToNotificationCenter("reloadTable")
            self.misc.postToNotificationCenter("addFirebaseObservers")
            self.dismiss(animated: true, completion: nil)

        case "reply":
            let replyRef = self.ref.child("replies").child(self.postID).child(self.replyID)
            let timestamp = self.misc.getTimestamp("UTC", date: Date())
            replyRef.child("content").setValue(text)
            replyRef.child("isEdited").setValue(true)
            replyRef.child("timestamp").setValue(timestamp)
            self.misc.postToNotificationCenter("reloadTable")
            self.misc.postToNotificationCenter("addFirebaseObservers")
            self.dismiss(animated: true, completion: nil)
            
        default:
            let alertController = UIAlertController(title: "Oops", message: "We encountered an error and can't edit right now. Please report the bug if it persists.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "Ok", style: .default) { action in
                self.dismiss(animated: true, completion: nil)
            }
            alertController.addAction(okAction)
            alertController.view.tintColor = self.misc.flocalColor
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
}
