//
//  ReplyPostViewController.swift
//  flocal
//
//  Created by George Tang on 6/19/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseDatabase
import FirebaseStorage
import FirebaseAnalytics
import AVFoundation

class ReplyPostViewController: UIViewController, UITextViewDelegate {
    
    // MARK: - Outlets
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var characterCountLabel: UILabel!
    
    @IBOutlet weak var sendButton: UIButton!
    @IBAction func sendButtonTapped(_ sender: Any) {
        self.writeReply()
    }
    
    @IBOutlet weak var cancelButton: UIButton!
    @IBAction func cancelButtonTapped(_ sender: Any) {
        self.misc.postToNotificationCenter("dismissWritePostVC")
        self.dismissKeyboard()
    }
    
    // MARK: - Vars
    
    var myID: String = "0"
    var myProfilePicURL: URL?
    var postID: String = "0"
    var userID: String = "0"
    var blockedBy: [String] = []
    let misc = Misc()
    
    var width: CGFloat = 320
    var height: CGFloat = 320
    var keyboardHeight: CGFloat = 200
    
    var ref = Database.database().reference()
    let storageRef = Storage.storage().reference()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.formatTextView()
        
        self.myID = misc.setMyID()
        if self.myID == "0" {
            self.dismiss(animated: false, completion: nil)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.portrait)
        self.downloadMyProfilePicURL()
        self.observeBlocked()
        self.sendButton.isEnabled = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.textView.becomeFirstResponder()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
        self.removeObserverForBlocked()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Text View
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == .lightGray {
            textView.text = ""
            textView.textColor = .black
        }
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        
        if textView.textColor == .lightGray {
            textView.text = ""
            textView.textColor = .black
        }
        
        let currentLength = textView.text.characters.count + (text.characters.count - range.length)
        
        self.characterCountLabel.text = "\(currentLength)/255"
        self.characterCountLabel.textColor = .lightGray
        
        return currentLength <= 255
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text == "" {
            textView.text = "write a comment... (tag others or respond to repliers with @theirHandle)"
            textView.textColor = .lightGray
        }
    }
    
    func formatTextView() {
        self.textView.delegate = self
        self.textView.textColor = .lightGray
        self.textView.text = "write a comment... (tag others or respond to repliers with @theirHandle)"
        self.textView.isScrollEnabled = true
        self.textView.layer.cornerRadius = 5
        self.textView.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.5).cgColor
        self.textView.layer.borderWidth = 0.5
        self.textView.clipsToBounds = true
        self.textView.layer.masksToBounds = true
        self.textView.autocorrectionType = .default
        self.textView.spellCheckingType = .default
    }
    
    // MARK: - Misc

    func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    func displayAlert(_ alertTitle: String, alertMessage: String) {
        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        alertController.view.tintColor = misc.flocalYellow
        DispatchQueue.main.async(execute: {
            self.sendButton.isEnabled = true
            self.present(alertController, animated: true, completion: nil)
        })
    }
    
    // MARK: - Analytics 
    
    func logViewWriteReply() {
        Analytics.logEvent("viewWriteReply_iOS", parameters: [
            "myID": self.myID as NSObject
            ])
    }
    
    func logReplySent(_ postID: String, replyID: String) {
        let myLocation = UserDefaults.standard.bool(forKey: "myLocation.flocal")
        let longitude = UserDefaults.standard.double(forKey: "longitude.flocal")
        let latitude = UserDefaults.standard.double(forKey: "latitude.flocal")

        Analytics.logEvent("sentReply_iOS", parameters: [
            "myID": self.myID as NSObject,
            "postID": postID as NSObject,
            "replyID": replyID as NSObject,
            "atMyLocation": myLocation as NSObject,
            "lastKnownLongitude": longitude as NSObject,
            "lastKnownLatitude": latitude as NSObject
            ])
    }
    
    func logUserTagged(_ replyID: String, userID: String, handle: String) {
        Analytics.logEvent("taggedUserInReply_iOS", parameters: [
            "postID": self.postID as NSObject,
            "replyID": replyID as NSObject,
            "myID": self.myID as NSObject,
            "userID": userID as NSObject,
            "userHandle": handle as NSObject
            ])
    }
    
    // MARK: - Storage
    
    func downloadMyProfilePicURL() {
        let myProfilePicRef = self.storageRef.child("profilePic/\(self.myID)_small.jpg")
        myProfilePicRef.downloadURL { url, error in
            if let error = error {
                print(error.localizedDescription)
                self.myProfilePicURL = nil
            } else {
                self.myProfilePicURL = url
            }
        }
    }
    
    // MARK: - Firebase 
    
    func writeReply() {
        self.dismissKeyboard()
        self.sendButton.isEnabled = false

        let text = self.textView.text
        if text == "" || self.textView.textColor == .lightGray {
            self.displayAlert("Empty Post Content", alertMessage: "Please add some text to your post.")
            return
        }
        
        if let handle = UserDefaults.standard.string(forKey: "handle.flocal") {
            self.setReply(text!, handle: handle)
        } else {
            misc.getHandle(self.myID) { handle in
                UserDefaults.standard.set(handle, forKey: "handle.flocal")
                UserDefaults.standard.synchronize()
                self.setReply(text!, handle: handle)
            }
        }
    }
    
    func setReply(_ content: String, handle: String) {
        let isDeleted: Bool = false
        let isEdited: Bool = false
        let reports: Int = 0
        let userID = self.myID
        let upvotes: Int = 0
        let downvotes: Int = 0
        let points: Int = 0
        let score: Double = 0
        let timestamp = misc.getTimestamp("UTC", date: Date())
        
        let originalReverseTimestamp = misc.getCurrentReverseTimestamp()
        let originalTimestamp = -1*originalReverseTimestamp
        
        var profilePicURLString = "error"
        if self.myProfilePicURL != nil {
            profilePicURLString = self.myProfilePicURL!.absoluteString
        }
        
        let reply: [String:Any?] = ["isDeleted": isDeleted, "isEdited": isEdited, "reports": reports, "userID": userID, "profilePicURLString": profilePicURLString, "handle": handle, "upvotes": upvotes, "downvotes": downvotes, "points": points, "score": score, "reverseScore": score, "originalContent": content, "content": content, "timestamp": timestamp, "originalReverseTimestamp": originalReverseTimestamp, "originalTimestamp": originalTimestamp]
        
        let replyRef = self.ref.child("replies").child(self.postID).childByAutoId()
        let replyID = replyRef.key
        replyRef.setValue(reply)
        self.logReplySent(self.postID, replyID: replyID)
        
        if self.myID != self.userID {
            self.writeReplyNotification(self.userID, postID: self.postID, replyID: replyID, content: content)
        }
        self.writeTagged(replyID, content: content)
        
        let postRef = self.ref.child("posts").child(self.postID)
        postRef.runTransactionBlock({ (currentData:MutableData) -> TransactionResult in
            if var postInfo = currentData.value as? [String:Any] {
                if var replyCount = postInfo["replyCount"] as? Int {
                    replyCount += 1
                    postInfo["replyCount"] = replyCount as AnyObject?
                    currentData.value = postInfo
                }
                return TransactionResult.success(withValue: currentData)
            }
            return TransactionResult.success(withValue: currentData)
        })
        self.misc.playSound("send_post.wav", start: 0)
        self.misc.postToNotificationCenter("dismissWriteReplyVC")
        self.misc.postToNotificationCenter("setReplySegment")
        self.misc.postToNotificationCenter("addFirebaseObservers")
        self.dismiss(animated: true, completion: nil)
    }
    
    func writeTagged(_ replyID: String, content: String) {
        let tagged = misc.handlesWithoutAt(content)
        for tag in tagged {
            let tagLower = tag.lowercased()
            let userRef = self.ref.child("users")
            userRef.queryOrdered(byChild: "handleLower").queryEqual(toValue: tagLower).observeSingleEvent(of: .value, with: { (snapshot) -> Void in
                if snapshot.exists() {
                    if let users = snapshot.value as? [String:Any] {
                        let firstUser = users.first!
                        let userID = firstUser.key
                        let amIBlocked = self.misc.amIBlocked(userID, blockedBy: self.blockedBy)
                        if userID != self.myID && !amIBlocked {
                            self.misc.writeTaggedNotification(userID, postID: self.postID, content: content, myID: self.myID, type: "comment")
                            self.logUserTagged(replyID, userID: userID, handle: tag)
                        }
                    }
                }
            })
        }
    }
    
    func writeReplyNotification(_ userID: String, postID: String, replyID: String, content: String) {
        let userRef = self.ref.child("users").child(userID)
        userRef.child("lastNotificationType").setValue("reply")
        
        if let handle = UserDefaults.standard.string(forKey: "handle.flocal") {
            let notification = "@\(handle) commented on your post: \(content)"
            
            let timestamp = misc.getTimestamp("UTC", date: Date())
            let originalReverseTimestamp = misc.getCurrentReverseTimestamp()
            
            let userNotificationRef = self.ref.child("userNotifications").child(userID)
            userNotificationRef.childByAutoId().setValue(["postID": postID, "replyID": replyID, "userID": self.myID, "handle": handle, "type": "reply", "timestamp": timestamp, "originalReverseTimestamp": originalReverseTimestamp, "notification": notification])
            misc.addNotificationBadge(userID)
            
        } else {
            misc.getHandle(self.myID) { handle in
                var notification: String
                
                if handle == "error" {
                    notification = "Your post was commented on: \(content)"
                } else {
                    notification = "@\(handle) commented on your post: \(content)"
                    UserDefaults.standard.set(handle, forKey: "handle.flocal")
                    UserDefaults.standard.synchronize()
                }
                
                let timestamp = self.misc.getTimestamp("UTC", date: Date())
                let originalReverseTimestamp = self.misc.getCurrentReverseTimestamp()
                
                let userNotificationRef = self.ref.child("userNotifications").child(userID)
                userNotificationRef.childByAutoId().setValue(["postID": postID, "replyID": replyID, "userID": self.myID, "handle": handle, "type": "reply", "timestamp": timestamp, "originalReverseTimestamp": originalReverseTimestamp, "notification": notification])
                self.misc.addNotificationBadge(userID)
            }
        }
    }
    
    func observeBlocked() {
        let userBlockedRef = self.ref.child("userBlocked").child(self.myID)
        userBlockedRef.observe(.value, with: { (snapshot) in
            if let blocked = snapshot.value as? [String:Any] {
                let blockedByDict = blocked["blockedBy"] as? [String:Bool] ?? [:]
                self.blockedBy = Array(blockedByDict.keys)
            }
        })
    }
    
    func removeObserverForBlocked() {
        let userBlockedRef = self.ref.child("userBlocked").child(self.myID)
        userBlockedRef.removeAllObservers()
    }

}
