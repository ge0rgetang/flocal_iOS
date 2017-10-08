//
//  Misc.swift
//  flocal
//
//  Created by George Tang on 5/26/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import Foundation
import UIKit
import FirebaseAnalytics
import FirebaseDatabase
import SDWebImage
import AVFoundation
import Alamofire

class Misc: NSObject {
    
    // MARK: - Colors
    
    let flocalColor = UIColor(red: 0, green: 96/255.0, blue: 100/255.0, alpha: 1)
    let flocalFade = UIColor(red: 0, green: 96/255.0, blue: 100/255.0, alpha: 0.15)
    let flocalSideMenu = UIColor(red: 0, green: 96/255.0, blue: 100/255.0, alpha: 0.3)
    let softGreyColor = UIColor(red: 240/255.0, green: 240/255.0, blue: 240/255.0, alpha: 1)
    
    let flocalBlue = UIColor(red: 33/255.0, green: 150/255.0, blue: 243/255.0, alpha: 1)
    let flocalBlueGrey = UIColor(red: 96/255.0, green: 125/255.0, blue: 139/255.0, alpha: 1)
    let flocalGreen = UIColor(red: 76/255.0, green: 175/255.0, blue: 80/255.0, alpha: 1)
    let flocalOrange = UIColor(red: 255/255.0, green: 70/255.0, blue: 5/255.0, alpha: 1)
    let flocalPurple = UIColor(red: 103/255.0, green: 58/255.0, blue: 183/255.0, alpha: 1)
    let flocalRed = UIColor(red: 244/255.0, green: 67/255.0, blue: 54/255.0, alpha: 1)
    let flocalTeal = UIColor(red: 0/255.0, green: 150/255.0, blue: 136/255.0, alpha: 1)
    let flocalYellow = UIColor(red: 255/255.0, green: 214/255.0, blue: 0, alpha: 1)
    
    let flocalBlueFade = UIColor(red: 33/255.0, green: 150/255.0, blue: 243/255.0, alpha: 0.15)
    let flocalBlueGreyFade = UIColor(red: 96/255.0, green: 125/255.0, blue: 139/255.0, alpha: 0.15)
    let flocalGreenFade = UIColor(red: 76/255.0, green: 175/255.0, blue: 80/255.0, alpha: 0.15)
    let flocalOrangeFade = UIColor(red: 255/255.0, green: 70/255.0, blue: 5/255.0, alpha: 0.15)
    let flocalPurpleFade = UIColor(red: 103/255.0, green: 58/255.0, blue: 183/255.0, alpha: 0.15)
    let flocalRedFade = UIColor(red: 244/255.0, green: 67/255.0, blue: 54/255.0, alpha: 0.15)
    let flocalTealFade = UIColor(red: 0/255.0, green: 150/255.0, blue: 136/255.0, alpha: 0.15)
    let flocalYellowFade = UIColor(red: 255/255.0, green: 214/255.0, blue: 0, alpha: 0.15)

    // MARK: - Navigation
    
    func setMyID() -> String {
        var myID: String
        
        if let id = UserDefaults.standard.string(forKey: "myID.flocal") {
            myID = id
        } else {
            myID = "0"
        }
        
        return myID
    }
    
    func refreshLastView() {
        self.postToNotificationCenter("addFirebaseObservers")
    }
    
    func removeObserverForLastView() {
        self.postToNotificationCenter("removeFirebaseObservers")
    }
    
    func setSideMenuIndex(_ int: Int) {
        UserDefaults.standard.set(int, forKey: "sideMenuIndex.flocal")
        UserDefaults.standard.synchronize()
    }
    
    func postToNotificationCenter(_ notName: String) {
        NotificationCenter.default.post(name: Notification.Name(notName), object: nil)
    }
    
    // MARK: - Posts
    
    func formatTimestamp(_ timestampString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let date = dateFormatter.date(from: timestampString)
        
        dateFormatter.dateFormat = "h:mm a MMM dd, yyyy"
        dateFormatter.timeZone = TimeZone.autoupdatingCurrent
        let timestamp = dateFormatter.string(from: date!)
        return timestamp
    }
    
    func getTimestamp(_ zone: String, date: Date) -> String {
        let dateFormatter = DateFormatter()
        if zone == "UTC" {
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        } else {
            dateFormatter.dateFormat = "h:mm a MMM dd, yyyy"
            dateFormatter.timeZone = TimeZone.autoupdatingCurrent
        }
        return dateFormatter.string(from: date)
    }
    
    func getCurrentReverseTimestamp() -> TimeInterval {
        return (0 - Date().timeIntervalSince1970)
    }

    func setCount(_ count: Int) -> String {
        let countDouble = Double(count)
        let countAbs = abs(countDouble)
        
        var rounded: String
        if countAbs >= 10000 && countAbs < 1000000 {
            var countThousand = countAbs/1000
            let countRounded = countThousand.roundToDecimalPlace(1)
            rounded = "\(countRounded)k"
        } else if countAbs >= 1000000 && countAbs < 1000000000 {
            var countMillion = countAbs/1000000
            let countRounded = countMillion.roundToDecimalPlace(1)
            rounded = "\(countRounded)M"
        } else if countAbs >= 1000000000 {
            var countBillion = countAbs/1000000000
            let countRounded = countBillion.roundToDecimalPlace(1)
            rounded = "\(countRounded)B"
        } else {
            rounded = "\(countAbs)"
        }
        
        if countDouble < 0 {
            rounded = "-\(rounded)"
        }
        
        return rounded 
    }
    
    func setPointsColor(_ points: Int, source: String) -> UIColor {
        if points < 0 {
            return self.flocalBlueGrey
        } else if points == 0 {
            return UIColor.lightGray
        } else {
            if source == "profile" {
                return self.flocalOrange
            } else {
                return self.flocalColor
            }
        }
    }
    
    func stringWithColoredTags(_ string: String, time: String, fontSize: CGFloat, timeSize: CGFloat) -> NSMutableAttributedString {
        let stringArray = string.components(separatedBy: " ")
        let attributedString: NSMutableAttributedString = NSMutableAttributedString(string: string)
        
        var wordsToColor: [String] = []
        for element in stringArray {
            if element.characters.first == "@" {
                wordsToColor.append(element)
            }
        }
        for word in wordsToColor {
            let range = (string as NSString).range(of: word)
            attributedString.addAttribute(NSAttributedStringKey.foregroundColor, value: self.flocalColor, range: range)
            let key = NSAttributedStringKey("tappedWord")
            let tapAttribute = [key: word]
            attributedString.addAttributes(tapAttribute, range: range)
        }
        
        let entireRange = (string as NSString).range(of: string)
        attributedString.addAttributes([NSAttributedStringKey.font: UIFont.systemFont(ofSize: fontSize)], range: entireRange)
        
        if time != "default" {
            let range = (string as NSString).range(of: time)
            attributedString.addAttribute(NSAttributedStringKey.foregroundColor, value: UIColor.lightGray, range: range)
            attributedString.addAttribute(NSAttributedStringKey.font, value: UIFont.systemFont(ofSize: timeSize), range: range)
        }
        
        return attributedString
    }
    
    func handlesWithoutAt(_ string: String) -> [String] {
        let stringArray = string.components(separatedBy: " ")
        var handles: [String] = []
        
        for element in stringArray {
            if element.characters.first == "@" {
                handles.append(element)
            }
        }
        
        for (index, handle) in handles.enumerated() {
            let handleWithoutAt = handle.replacingOccurrences(of: "@", with: "")
            handles.remove(at: index)
            handles.insert(handleWithoutAt, at: index)
        }
        
        if handles.isEmpty {
            handles = stringArray
        }
        
        return handles
    }
    
    func setDefaultPic(_ handle: String) -> UIImage {
        let handleLower = handle.lowercased()
        let firstLetter = handleLower.characters.first!
        switch firstLetter {
        case "a", "b", "c":
            return UIImage(named: "meRed")!
        case "d", "e", "f":
            return UIImage(named: "meOrange")!
        case "h", "i", "j":
            return UIImage(named: "meYellow")!
        case "k", "l", "m":
            return UIImage(named: "meGreen")!
        case "n", "o", "p", "q":
            return UIImage(named: "meBlue")!
        case "r", "s", "u", "v":
            return UIImage(named: "meTeal")!
        case "w", "x", "y", "z":
            return UIImage(named: "mePurple")!
        default:
            return UIImage(named: "meS")!
        }
    }
    
    func setPostImageAspectRatio(_ cell: PostTableViewCell, image: UIImage?) {
        if let img = image {
            let h = img.size.height
            let w = img.size.width
            if w > h {
                cell.imagePicAspectWide.isActive = true
                cell.imagePicAspectSquare.isActive = false
                cell.imagePicAspectTall.isActive = false
            } else if w == h {
                cell.imagePicAspectWide.isActive = false
                cell.imagePicAspectSquare.isActive = true
                cell.imagePicAspectTall.isActive = false
            } else {
                cell.imagePicAspectWide.isActive = false
                cell.imagePicAspectSquare.isActive = false
                cell.imagePicAspectTall.isActive = true
            }
        } else {
            cell.imagePicAspectWide.isActive = true
            cell.imagePicAspectSquare.isActive = false
            cell.imagePicAspectTall.isActive = false
        }
    }
    
    func getColorFromHandle(_ handle: String) -> String {
        let lowercaseHandle = handle.lowercased()
        let firstLetter = lowercaseHandle.characters.first!
        switch firstLetter {
        case "a", "b", "c":
            return "red"
        case "d", "e", "f":
            return "orange"
        case "h", "i", "j":
            return "yellow"
        case "k", "l", "m":
            return "green"
        case "n", "o", "p", "q":
            return "blue"
        case "r", "s", "u", "v":
            return "teal"
        case "w", "x", "y", "z":
            return "purple"
        default:
            return "flocal"
        }
    }

    // MARK: - Profile
    
    func getSpecialHandles() -> [String] {
        let spec = ["georgetang", "george.tang", "george_tang", "gtang", "gtang42", "gtang43", "george", "georget", "tang", "native", "nativ", "dotnativ", "dotnative", ".nativ", ".native", "flocal", ".flocal", "0", "god", "buddha", "shiva", "satan", "vishnu", "hitler", "error"]
        return spec
    }
    
    func checkSpecialCharacters(_ handle: String) -> Bool {
        let set = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLKMNOPQRSTUVWXYZ0123456789._")
        if handle.rangeOfCharacter(from: set.inverted) != nil {
            return true
        } else {
            return false
        }
    }
    
    func formatPhoneNumber(_ phoneNumber: String) -> String {
        let numbersOnly = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let length = numbersOnly.characters.count
        let isLeadOne = numbersOnly.hasPrefix("1")
        
        guard length == 7 || length == 10 || (length == 11 && isLeadOne) else {
            return phoneNumber
        }
        
        let hasAreaCode = length >= 10
        var sourceIndex = 0
        
        var leadingOne = ""
        if isLeadOne {
            leadingOne = "1 "
            sourceIndex += 1
        }
        
        var areaCode = ""
        if hasAreaCode {
            let areaCodeLength = 3
            guard let areaCodeSubstring = numbersOnly.characters.substring(start: sourceIndex, offsetBy: areaCodeLength) else {
                return phoneNumber
            }
            areaCode = String(format: "(%@)", areaCodeSubstring)
            sourceIndex += areaCodeLength
        }
        
        let prefixLength = 3
        guard let prefix = numbersOnly.characters.substring(start: sourceIndex, offsetBy: prefixLength) else {
            return phoneNumber
        }
        sourceIndex += prefixLength
        
        let suffixLength = 4
        guard let suffix = numbersOnly.characters.substring(start: sourceIndex, offsetBy: suffixLength) else {
            return phoneNumber
        }
        
        return leadingOne + areaCode + prefix + "-" + suffix
    }
    
    func setChatID(_ myID: String, userID: String) -> String {
        if myID < userID {
            return "\(myID)_\(userID)"
        } else {
            return "\(userID)_\(myID)"
        }
    }
    
    func getProfPicHeight() -> [CGFloat] {
        let model = UIDevice.current.modelName
        if model.contains("iPhone") {
            if model.contains("4") || model.contains("5") {
                return [75, -37.5, 4]
            } else {
                return [100, -50, 8]
            }
        } else {
            return [125, -62.5, 12]
        }
    }
    
    func setFollowersColor(_ followers: Int) -> UIColor {
        if followers <= 0 {
            return UIColor.lightGray
        } else {
            return flocalGreen
        }
    }
    
    // MARK: Memory
    
    func clearTempDirectory() {
        let fileManager = FileManager.default
        let tempPath = NSTemporaryDirectory()
        do {
            let filePaths = try fileManager.contentsOfDirectory(atPath: tempPath)
            for path in filePaths {
                try fileManager.removeItem(atPath: NSTemporaryDirectory() + path)
            }
        } catch let error as NSError {
            print(error.localizedDescription)
        }
    }
    
    func clearWebImageCache() {
        let imageCache = SDImageCache.shared()
        imageCache.clearMemory()
        imageCache.clearDisk()
    }
    
    
    // MARK: - Other 
    
    var audioPlayer: AVAudioPlayer?
    func playSound(_ name: String, start: Double) {
        let session = AVAudioSession.sharedInstance()
        let path = Bundle.main.path(forResource: name, ofType: nil)!
        let url = URL(fileURLWithPath: path)
        do {
            try session.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
            self.audioPlayer = try AVAudioPlayer(contentsOf: url)
            self.audioPlayer?.currentTime = start 
            self.audioPlayer?.play()
        } catch let error as NSError {
            print(error.localizedDescription)
        }
    }
    
    func setChatImageAspectRatio(_ cell: ChatTableViewCell, image: UIImage?) {
        if let img = image {
            let h = img.size.height
            let w = img.size.width
            if w > h {
                cell.imagePicAspectWide.isActive = true
                cell.imagePicAspectSquare.isActive = false
                cell.imagePicAspectTall.isActive = false
            } else if w == h {
                cell.imagePicAspectWide.isActive = false
                cell.imagePicAspectSquare.isActive = true
                cell.imagePicAspectTall.isActive = false
            } else {
                cell.imagePicAspectWide.isActive = false
                cell.imagePicAspectSquare.isActive = false
                cell.imagePicAspectTall.isActive = true
            }
        } else {
            cell.imagePicAspectWide.isActive = true
            cell.imagePicAspectSquare.isActive = false
            cell.imagePicAspectTall.isActive = false
        }
    }
    
    func setRotateView(_ image: UIImage) {
        let h = image.size.height
        let w = image.size.width
        
        if w > h {
            AppUtility.lockOrientation(.all, rotateTo: .landscapeLeft)
        } else {
            AppUtility.lockOrientation(.all, rotateTo: .portrait)
        }
    }
    
    // MARK: - Firebase
    
    var ref = Database.database().reference()
    
    func observeLastNotificationType(_ label: UILabel, button: UIButton, color: String) {
        self.removeNotificationTypeObserver()   
        
        if let myID = UserDefaults.standard.string(forKey: "myID.flocal") {
            let typeRef = self.ref.child("users").child(myID).child("lastNotificationType")
            typeRef.observe(.value, with: {(snapshot) in
                
                if let type = snapshot.value as? String {
                    switch type {
                    case "upvote":
                        label.backgroundColor = self.flocalOrange
                        self.animateColorAlpha(label)
                        button.setImage(UIImage(named: "upvoteNotification"), for: .normal)
                    case "reply":
                        label.backgroundColor =  self.flocalYellow
                        self.animateColorAlpha(label)
                        button.setImage(UIImage(named: "replyS"), for: .normal)
                    case "tagged":
                        label.backgroundColor = self.flocalYellow
                        self.animateColorAlpha(label)
                        button.setImage(UIImage(named: "taggedS"), for: .normal)
                    case "chat":
                        label.backgroundColor = self.flocalTeal
                        self.animateColorAlpha(label)
                        button.setImage(UIImage(named: "chatCS"), for: .normal)
                    case "added":
                        label.backgroundColor = self.flocalGreen
                        self.animateColorAlpha(label)
                        button.setImage(UIImage(named: "addNotification"), for: .normal)
                    default:
                        label.backgroundColor = .clear
                        label.layer.removeAllAnimations()
                        switch color {
                        case "red":
                            button.setImage(UIImage(named: "notificationRedS"), for: .normal)
                        case "orange":
                            button.setImage(UIImage(named: "notificationOrangeS"), for: .normal)
                        case "yellow":
                            button.setImage(UIImage(named: "notificationYellowS"), for: .normal)
                        case "green":
                            button.setImage(UIImage(named: "notificationGreenS"), for: .normal)
                        case "blue":
                            button.setImage(UIImage(named: "notificationBlueS"), for: .normal)
                        case "blueGrey":
                            button.setImage(UIImage(named: "notificationBlueGreyS"), for: .normal)
                        case "teal":
                            button.setImage(UIImage(named: "notificationTealS"), for: .normal)
                        case "purple":
                            button.setImage(UIImage(named: "notificationPurpleS"), for: .normal)
                        default:
                            button.setImage(UIImage(named: "notificationS"), for: .normal)
                        }
                    }
                }
                
            })
        }
    }
    
    func animateColorAlpha(_ label: UILabel) {
        UIView.animateKeyframes(withDuration: 2.0, delay: 0.0, options: [.repeat, .autoreverse], animations: {
            label.alpha = 0.1
        }, completion: nil)
    }
    
    func removeNotificationTypeObserver() {
        if let myID = UserDefaults.standard.string(forKey: "myID.flocal") {
            let typeRef = self.ref.child("users").child(myID).child("lastNotificationType")
            typeRef.removeAllObservers()
        }
    }
    
    func addNotificationBadge(_ userID: String) {
        let badgeNumberRef = self.ref.child("users").child(userID)
        badgeNumberRef.runTransactionBlock({ (currentData:MutableData) -> TransactionResult in
            if var userInfo = currentData.value as? [String:Any] {
                if var badgeNumber = userInfo["notificationBadge"] as? Int {
                    badgeNumber += 1
                    userInfo["notificationBadge"] = badgeNumber as AnyObject?
                    currentData.value = userInfo
                }
                return TransactionResult.success(withValue: currentData)
            }
            return TransactionResult.success(withValue: currentData)
        })
    }
    
    func writePointNotification(_ userID: String, myID: String, postID: String, content: String, type: String) {
        let userRef = self.ref.child("users").child(userID)
        userRef.child("lastNotificationType").setValue("upvote")
        
        if let handle = UserDefaults.standard.string(forKey: "handle.flocal") {
            let notification = "@\(handle) has upvoted your \(type): \(content)"
            self.setNotification(postID, myID: myID, userID: userID, handle: handle, notification: notification, type: "upvote")
        } else {
            self.getHandle(myID) { handle in
                var notification: String
                if handle == "error" {
                    notification = "Your \(type) has been upvoted: \(content)"
                } else {
                    notification = "@\(handle) has upvoted your \(type): \(content)"
                    UserDefaults.standard.set(handle, forKey: "handle.flocal")
                    UserDefaults.standard.synchronize()
                }
                self.setNotification(postID, myID: myID, userID: userID, handle: handle, notification: notification, type: "upvote")
            }
        }
    }
    
    func writeTaggedNotification(_ userID: String, postID: String, content: String, myID: String, type: String) {
        let userRef = self.ref.child("users").child(userID)
        userRef.child("lastNotificationType").setValue("tagged")
        
        if let handle = UserDefaults.standard.string(forKey: "handle.flocal") {
            let notification = "@\(handle) tagged you in a \(type): \(content)"
            self.setNotification(postID, myID: myID, userID: userID, handle: handle, notification: notification, type: "tagged")
        } else {
            self.getHandle(myID) { handle in
                var notification: String
                if handle == "error" {
                    notification = "You've been tagged you in a \(type): \(content)"
                } else {
                    notification = "@\(handle) tagged you in a \(type): \(content)"
                    UserDefaults.standard.set(handle, forKey: "handle.flocal")
                    UserDefaults.standard.synchronize()
                }
                self.setNotification(postID, myID: myID, userID: userID, handle: handle, notification: notification, type: "tagged")
            }
        }
    }
    
    func writeAddedNotification(_ userID: String, myID: String) {
        let userRef = self.ref.child("users").child(userID)
        userRef.child("lastNotificationType").setValue("added")
        
        if let handle = UserDefaults.standard.string(forKey: "handle.flocal") {
            let notification = "@\(handle) has added you! :)"
            self.setNotification("0", myID: myID, userID: userID, handle: handle, notification: notification, type: "added")
        } else {
            self.getHandle(myID) { handle in
                var notification: String
                if handle == "error" {
                    notification = "You have a new follower! :)"
                } else {
                    notification = "@\(handle) has added you! :)"
                    UserDefaults.standard.set(handle, forKey: "handle.flocal")
                    UserDefaults.standard.synchronize()
                }
                self.setNotification("0", myID: myID, userID: userID, handle: handle, notification: notification, type: "added")
            }
        }
    }
    
    func writeAmITyping(_ bool: Bool, chatID: String, myID: String) {
        let chatRef = self.ref.child("chats").child(chatID)
        chatRef.child("info").child("\(myID)_typing").setValue(bool)
    }
    
    func writeAmInChat(_ bool: Bool, chatID: String, myID: String) {
        let chatRef = self.ref.child("chats").child(chatID)
        chatRef.child("info").child(myID).setValue(bool)
    }
    
    func removeChatID() {
        UserDefaults.standard.removeObject(forKey: "chatIDToPass.flocal")
        UserDefaults.standard.synchronize()
    }
    
    func writeChatNotification(_ userID: String, myID: String, message: String?, type: String) {
        let userRef = self.ref.child("users").child(userID)
        userRef.child("lastNotificationType").setValue("chat")
        
        var chatMessage: String
        switch type {
        case "image":
            chatMessage = "image sent"
        case "video":
            chatMessage = "video sent"
        default:
            chatMessage = message!
        }
        
        if let handle = UserDefaults.standard.string(forKey: "handle.flocal") {
            let notification = "@\(handle): \(chatMessage)"
            self.setNotification("0", myID: myID, userID: userID, handle: handle, notification: notification, type: "chat")
        } else {
            self.getHandle(myID) { handle in
                var notification: String
                if handle == "error" {
                    notification = "You've received a message: \(chatMessage)"
                } else {
                    notification = "@\(handle): \(chatMessage)"
                    UserDefaults.standard.set(handle, forKey: "handle.flocal")
                    UserDefaults.standard.synchronize()
                }
                self.setNotification("0", myID: myID, userID: userID, handle: handle, notification: notification, type: "chat")
            }
        }
    }
    
    func setNotification(_ postID: String, myID: String, userID: String, handle: String, notification: String, type: String) {
        let timestamp = self.getTimestamp("UTC", date: Date())
        let originalReverseTimestamp = self.getCurrentReverseTimestamp()
        
        let userNotificationRef = self.ref.child("userNotifications").child(userID)
        userNotificationRef.childByAutoId().setValue(["postID": postID, "userID": myID, "handle": handle, "type": type, "timestamp": timestamp, "originalReverseTimestamp": originalReverseTimestamp, "notification": notification])
        self.addNotificationBadge(userID)
        
        if type == "tagged" || type == "chat" {
            self.postNotification(notification, category: type, userID: userID)
        }
    }
    
    func getVoteStatus(_ postID: String, replyID: String?, myID: String, completionHandler: @escaping (String) -> ()) {
        var voteHistoryRef: DatabaseReference
        let postVoteHistoryRef = self.ref.child("postVoteHistory").child(postID)
        if replyID == nil {
            voteHistoryRef = postVoteHistoryRef.child(myID)
        } else {
            voteHistoryRef = postVoteHistoryRef.child("replies").child(replyID!).child(myID)
        }
        voteHistoryRef.observeSingleEvent(of: .value, with: { (snapshot) -> Void in
            if snapshot.exists() {
                let vote = snapshot.value as? Bool ?? true
                if vote {
                    completionHandler("up")
                } else {
                    completionHandler("down")
                }
            } else {
                completionHandler("none")
            }
        })
    }
    
    func getFollowers(_ userID: String, completionHandler: @escaping ([String]) -> ()) {
        let userFollowersRef = self.ref.child("userFollowers").child(userID)
        userFollowersRef.observeSingleEvent(of: .value, with: { (snapshot) -> Void in
            let dict = snapshot.value as? [String:Any] ?? [:]
            completionHandler(Array(dict.keys))
        })
    }
    
    func amIBlocked(_ userID: String, blockedBy: [String]) -> Bool {
        if blockedBy.contains(userID) {
            return true
        } else {
            return false
        }
    }
    
    func didIBlock(_ userID: String, blocked: [String]) -> Bool {
        if blocked.contains(userID) {
            return true
        } else {
            return false
        }
    }
    
    func didIAdd(_ userID: String, myID: String, completionHandler: @escaping (Bool) -> ()) {
        let userAddedRef = self.ref.child("userAdded").child(myID).child(userID)
        userAddedRef.observeSingleEvent(of: .value, with: { (snapshot) -> Void in
            if snapshot.exists() {
                completionHandler(true)
            } else {
                completionHandler(false)
            }
        })
    }
    
    func getHandle(_ userID: String, completionHandler: @escaping (String) -> ()) {
        let userRef = self.ref.child("users").child(userID)
        userRef.observeSingleEvent(of: .value, with: { (snapshot) -> Void in
            if let dict = snapshot.value as? [String:Any] {
                let handle = dict["handle"] as? String ?? "error"
                completionHandler(handle)
            } else {
                completionHandler("error")
            }
        })
    }
    
    func doesUserExist(_ handle: String, completionHandler: @escaping (Bool) -> ()) {
        let handleLower = handle.lowercased()
        let userRef = self.ref.child("users")
        
        userRef.queryOrdered(byChild: "handleLower").queryEqual(toValue: handleLower).observeSingleEvent(of: .value, with: { snapshot in
            if snapshot.exists() {
                completionHandler(true)
            } else {
                completionHandler(false)
            }
        })
    }
    
    func addUser(_ userID: String, myID: String) {
        let originalReverseTimestamp = self.getCurrentReverseTimestamp()
        
        let userRef = self.ref.child("users").child(userID)
        let meRef = self.ref.child("users").child(myID)
        let userAddedRef = self.ref.child("userAdded")
        let userFollowersRef = self.ref.child("userFollowers")
        
        var updatedFollowersCount: Int = 0
        userRef.runTransactionBlock({ (currentData:MutableData) -> TransactionResult in
            if var user = currentData.value as? [String:Any] {
                var followersCount = user["followersCount"] as? Int ?? 0
                followersCount += 1
                updatedFollowersCount = followersCount
                user["followersCount"] = followersCount as AnyObject?
                currentData.value = user
                return TransactionResult.success(withValue: currentData)
            }
            return TransactionResult.success(withValue: currentData)
        })
        
        userRef.observeSingleEvent(of: .value, with: { (snapshot) -> Void in
            if let dict = snapshot.value as? [String:Any] {
                let handle = dict["handle"] as? String ?? "error"
                let description = dict["description"] as? String ?? "error"
                let points = dict["points"] as? Int ?? 0
                let profilePicURLString = dict["profilePicURLString"] as? String ?? "error"
                let user: [String:Any] = ["handle": handle, "description": description, "points": points, "followersCount": updatedFollowersCount, "profilePicURLString": profilePicURLString, "originalReverseTimestamp": originalReverseTimestamp]
                userAddedRef.child(myID).child(userID).setValue(user)
            }
        })
        
        meRef.observeSingleEvent(of: .value, with: { (snapshot) -> Void in
            if let dict = snapshot.value as? [String:Any] {
                let handle = dict["handle"] as? String ?? "error"
                let description = dict["description"] as? String ?? "error"
                let points = dict["points"] as? Int ?? 0
                let followersCount = dict["followersCount"] as? Int ?? 0
                let profilePicURLString = dict["profilePicURLString"] as? String ?? "error"
                let me: [String:Any] = ["handle": handle, "description": description, "points": points, "followersCount": followersCount, "profilePicURLString": profilePicURLString, "originalReverseTimestamp": originalReverseTimestamp]
                userFollowersRef.child(userID).child(myID).setValue(me)
            }
        })
        
        self.getFollowers(userID) { userFollowers in
            if !userFollowers.isEmpty {
                var fanoutObject: [String:Any] = [:]
                for followerID in userFollowers {
                    fanoutObject["/\(followerID)/\(userID)/followersCount"] = updatedFollowersCount
                }
                userAddedRef.updateChildValues(fanoutObject)
            }
        }
    }
    
    func hasUpvoteNotified(_ postID: String, replyID: String?, myID: String, completionHandler: @escaping (Bool) -> ()) {
        var hasUpvoteNotifiedRef: DatabaseReference
        let postVoteHistoryRef = self.ref.child("postVoteHistory").child(postID)
        if replyID != nil && replyID != "0" {
            hasUpvoteNotifiedRef = postVoteHistoryRef.child("replies").child(replyID!).child("upvoteNotified").child(myID)
        } else {
            hasUpvoteNotifiedRef = postVoteHistoryRef.child("upvoteNotified").child(myID)
        }
        hasUpvoteNotifiedRef.observeSingleEvent(of: .value, with: { snapshot in
            if snapshot.exists() {
               completionHandler(true)
            } else {
                completionHandler(false)
            }
        })
    }
    
    func upvote(_ postID: String, myID: String, userID: String, voteStatus: String, content: String) {
        let postVoteHistoryRef = self.ref.child("postVoteHistory").child(postID).child(myID)
        let postRef = self.ref.child("posts").child(postID)
        postRef.runTransactionBlock({ (currentData:MutableData) -> TransactionResult in
            if var post = currentData.value as? [String:Any] {
                var upvotes = post["upvotes"] as? Int ?? 0
                var downvotes = post["downvotes"] as? Int ?? 0
                switch voteStatus {
                case "up":
                    upvotes -= 1
                    postVoteHistoryRef.removeValue()
                case "down":
                    upvotes += 1
                    downvotes -= 1
                    postVoteHistoryRef.setValue(true)
                default:
                    upvotes += 1
                    postVoteHistoryRef.setValue(true)
                }
                
                post["upvotes"] = upvotes as AnyObject?
                post["downvote"] = downvotes as AnyObject?
                post["points"] = (upvotes - downvotes) as AnyObject?
                currentData.value = post
                return TransactionResult.success(withValue: currentData)
            }
            return TransactionResult.success(withValue: currentData)
        }) { (error, committed, snapshot) in
            if let error = error {
                print(error.localizedDescription)
            }
        }
        
        self.hasUpvoteNotified(postID, replyID: nil, myID: myID) { notified in
            if myID != userID && !notified {
                let hasUpvoteNotifiedRef = self.ref.child("postVoteHistory").child(postID).child("upvoteNotified").child(myID)
                hasUpvoteNotifiedRef.setValue(true)
                self.writePointNotification(userID, myID: myID, postID: postID, content: content, type: "post")
            }
        }
        
        let userRef = self.ref.child("users").child(userID)
        userRef.runTransactionBlock({ (currentData:MutableData) -> TransactionResult in
            if var userInfo = currentData.value as? [String:Any] {
                var postPoints = userInfo["postPoints"] as? Int ?? 0
                var points = userInfo["points"] as? Int ?? 0
                switch voteStatus {
                case "up":
                    postPoints -= 1
                    points -= 1
                case "down":
                    postPoints += 2
                    points += 2
                default:
                    postPoints += 1
                    points += 1
                }
                userInfo["postPoints"] = postPoints as AnyObject?
                userInfo["points"] = points as AnyObject?
                currentData.value = userInfo
                
                let updatedPoints = points
                self.getFollowers(userID) { userFollowers in
                    if updatedPoints != 0 && !userFollowers.isEmpty {
                        var fanoutObject: [String:Any] = [:]
                        for followerID in userFollowers {
                            fanoutObject["/\(followerID)/\(userID)/points"] = updatedPoints
                        }
                        let userAddedRef = self.ref.child("userAdded")
                        userAddedRef.updateChildValues(fanoutObject)
                    }
                }
                
                return TransactionResult.success(withValue: currentData)
            }
            return TransactionResult.success(withValue: currentData)
        })
        
        let userPostHistoryRef = self.ref.child("userPostHistory").child(userID).child(postID)
        userPostHistoryRef.runTransactionBlock({ (currentData:MutableData) -> TransactionResult in
            if var postInfo = currentData.value as? [String:Any] {
                if var points = postInfo["points"] as? Int {
                    switch voteStatus {
                    case "up":
                        points -= 1
                    case "down":
                        points += 2
                    default:
                        points += 1
                    }
                    postInfo["points"] = points as AnyObject?
                    currentData.value = postInfo
                }
                return TransactionResult.success(withValue: currentData)
            }
            return TransactionResult.success(withValue: currentData)
        })
    }
    
    func downvote(_ postID: String, myID: String, userID: String, voteStatus: String) {
        let postVoteHistoryRef = self.ref.child("postVoteHistory").child(postID).child(myID)
        let postRef = self.ref.child("posts").child(postID)
        postRef.runTransactionBlock({ (currentData:MutableData) -> TransactionResult in
            if var post = currentData.value as? [String:Any] {
                var upvotes = post["upvotes"] as? Int ?? 0
                var downvotes = post["downvotes"] as? Int ?? 0
                switch voteStatus {
                case "up":
                    upvotes -= 1
                    downvotes += 1
                    postVoteHistoryRef.setValue(false)
                case "down":
                    downvotes -= 1
                    postVoteHistoryRef.removeValue()
                default:
                    downvotes += 1
                    postVoteHistoryRef.setValue(false)
                }
                
                post["upvotes"] = upvotes as AnyObject?
                post["downvotes"] = downvotes as AnyObject?
                post["points"] = (upvotes - downvotes) as AnyObject?
                currentData.value = post
                return TransactionResult.success(withValue: currentData)
            }
            return TransactionResult.success(withValue: currentData)
        }) { (error, committed, snapshot) in
            if let error = error {
                print(error.localizedDescription)
            }
        }
        
        let userRef = self.ref.child("users").child(userID)
        userRef.runTransactionBlock({ (currentData:MutableData) -> TransactionResult in
            if var userInfo = currentData.value as? [String:Any] {
                var postPoints = userInfo["postPoints"] as? Int ?? 0
                var points = userInfo["points"] as? Int ?? 0
                switch voteStatus {
                case "up":
                    postPoints -= 2
                    points -= 2
                case "down":
                    postPoints += 1
                    points += 1
                default:
                    postPoints -= 1
                    points -= 1
                }
                userInfo["points"] = points as AnyObject?
                userInfo["postPoints"] = postPoints as AnyObject?
                currentData.value = userInfo
                
                let updatedPoints = points
                self.getFollowers(userID) { userFollowers in
                    if updatedPoints != 0 && !userFollowers.isEmpty {
                        let userAddedRef = self.ref.child("userAdded")
                        var fanoutObject: [String:Any] = [:]
                        for followerID in userFollowers {
                            fanoutObject["/\(followerID)/\(userID)/points"] = updatedPoints
                        }
                        userAddedRef.updateChildValues(fanoutObject)
                    }
                }
                
                return TransactionResult.success(withValue: currentData)
            }
            return TransactionResult.success(withValue: currentData)
        })
        
        let userPostHistoryRef = self.ref.child("userPostHistory").child(userID).child(postID)
        userPostHistoryRef.runTransactionBlock({ (currentData:MutableData) -> TransactionResult in
            if var postInfo = currentData.value as? [String:Any] {
                if var points = postInfo["points"] as? Int {
                    switch voteStatus {
                    case "up":
                        points -= 2
                    case "down":
                        points += 1
                    default:
                        points -= 1
                    }
                    postInfo["points"] = points as AnyObject?
                    currentData.value = postInfo
                }
                return TransactionResult.success(withValue: currentData)
            }
            return TransactionResult.success(withValue: currentData)
        })
    }
    
    func updateDeviceToken(_ deviceToken: String) {
        let myID = self.setMyID()
        if myID != "0" {
            let tokenRef = self.ref.child("users").child(myID).child("deviceToken")
            tokenRef.setValue(deviceToken)
        }
    }
    
    // MARK: - DataTypes
    
    func formatPost(_ postID: String, voteStatus: String, post: [String:Any]) -> Post {
        var formattedPost = Post()
        
        formattedPost.postID = post["userID"] as? String ?? "0"
        formattedPost.type = post["type"] as? String ?? "error"
        
        let profilePicURLString = post["profilePicURLString"] as? String ?? "error"
        if profilePicURLString != "error" {
            formattedPost.profilePicURL = URL(string: profilePicURLString)
        }
        
        let postPicURLString = post["postPicURLString"] as? String ?? "error"
        if postPicURLString != "error" {
            formattedPost.postPicURL = URL(string: postPicURLString)
        }
        
        let postVidURLString = post["postVidURLString"] as? String ?? "error"
        if postVidURLString != "error" {
            formattedPost.postVidURL = URL(string: postPicURLString)
        }
        
        let postVidPreviewURLString = post["postVidPreviewURLString"] as? String ?? "error"
        if postVidPreviewURLString != "error" {
            formattedPost.postVidPreviewURL = URL(string: postVidPreviewURLString)
        }
        
        formattedPost.handle = post["handle"] as? String ?? "error"
        formattedPost.content = post["content"] as? String ?? "error"
        
        let timestamp = post["timestamp"] as? String ?? "error"
        formattedPost.timestampUTC = timestamp 
        
        let isEdited = post["isEdited"] as? Bool ?? false
        let formattedTimestamp = self.formatTimestamp(timestamp)
        if isEdited {
            formattedPost.timestamp = "edited \(formattedTimestamp)"
        } else {
            formattedPost.timestamp = formattedTimestamp
        }
        formattedPost.originalReverseTimestamp = post["originalReverseTimestamp"] as? TimeInterval ?? 0
        
        let upvotes = post["upvotes"] as? Int ?? 0
        let downvotes = post["downvotes"] as? Int ?? 0
        formattedPost.points = upvotes - downvotes
        formattedPost.score = post["score"] as? Double ?? 0
        
        let replyCount = post["replyCount"] as? Int ?? 0
        formattedPost.replyString = "\(self.setCount(replyCount)) replies"
        
        formattedPost.voteStatus = voteStatus
        
        return formattedPost
    }
    
    // MARK: - Alamofire
    
    func postNotification(_ message: String, category: String, userID: String) {
        let userRef = self.ref.child("users").child(userID)
        userRef.observeSingleEvent(of: .value, with: { (snapshot) -> Void in
            if let userInfo = snapshot.value as? [String:Any] {
                let badge = userInfo["notificationBadge"] as? Int ?? 0
                let endpointToken = userInfo["deviceToken"] as? String ?? "error"
                let param: Parameters = ["body": message, "category": category, "badge": badge, "endpointToken": endpointToken, "action": "message"]
                
                Alamofire.request("https://flocalApp.us-west-1.elasticbeanstalk.com", method: .post, parameters: param, encoding: JSONEncoding.default).responseJSON { response in
                    if let json = response.result.value {
                        print(json)
                    }
                }
            }
        })
    }

}

struct AppUtility {
    static func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
        if let delegate = UIApplication.shared.delegate as? AppDelegate {
            delegate.orientationLock = orientation
        }
    }
    
    static func lockOrientation(_ orientation: UIInterfaceOrientationMask, rotateTo: UIInterfaceOrientation) {
        self.lockOrientation(orientation)
        UIDevice.current.setValue(rotateTo.rawValue, forKey: "orientation")
    }
}

extension String {
    func trimSpace() -> String {
        return self.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}

extension String.CharacterView {
    internal func substring(start: Int, offsetBy: Int) -> String? {
        guard let substringStartIndex = self.index(startIndex, offsetBy: start, limitedBy: endIndex) else {
            return nil
        }
        
        guard let substringEndIndex = self.index(startIndex, offsetBy: start + offsetBy, limitedBy: endIndex) else {
            return nil
        }
        
        return String(self[substringStartIndex ..< substringEndIndex])
    }
}

extension Double {
    mutating func roundToDecimalPlace(_ place: Int) -> Double {
        let divisor = pow(10.0, Double(place))
        return (self*divisor).rounded()/divisor
    }
}

extension UIImage {
    convenience init(view: UIView) {
        UIGraphicsBeginImageContextWithOptions(view.frame.size, true, 0.0)
        view.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.init(cgImage: (image?.cgImage)!)
    }
}

public extension UIDevice {
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        switch identifier {
        case "iPod5,1":                                 return "iPod Touch 5"
        case "iPod7,1":                                 return "iPod Touch 6"
        case "iPhone3,1", "iPhone3,2", "iPhone3,3":     return "iPhone 4"
        case "iPhone4,1":                               return "iPhone 4s"
        case "iPhone5,1", "iPhone5,2":                  return "iPhone 5"
        case "iPhone5,3", "iPhone5,4":                  return "iPhone 5c"
        case "iPhone6,1", "iPhone6,2":                  return "iPhone 5s"
        case "iPhone7,2":                               return "iPhone 6"
        case "iPhone7,1":                               return "iPhone 6 Plus"
        case "iPhone8,1":                               return "iPhone 6s"
        case "iPhone8,2":                               return "iPhone 6s Plus"
        case "iPhone9,1", "iPhone9,3":                  return "iPhone 7"
        case "iPhone9,2", "iPhone9,4":                  return "iPhone 7 Plus"
        case "iPhone8,4":                               return "iPhone SE"
        case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":return "iPad 2"
        case "iPad3,1", "iPad3,2", "iPad3,3":           return "iPad 3"
        case "iPad3,4", "iPad3,5", "iPad3,6":           return "iPad 4"
        case "iPad4,1", "iPad4,2", "iPad4,3":           return "iPad Air"
        case "iPad5,3", "iPad5,4":                      return "iPad Air 2"
        case "iPad2,5", "iPad2,6", "iPad2,7":           return "iPad Mini"
        case "iPad4,4", "iPad4,5", "iPad4,6":           return "iPad Mini 2"
        case "iPad4,7", "iPad4,8", "iPad4,9":           return "iPad Mini 3"
        case "iPad5,1", "iPad5,2":                      return "iPad Mini 4"
        case "iPad6,3", "iPad6,4", "iPad6,7", "iPad6,8":return "iPad Pro"
        case "AppleTV5,3":                              return "Apple TV"
        case "i386", "x86_64":                          return "Simulator"
        default:                                        return identifier
        }
    }
}
