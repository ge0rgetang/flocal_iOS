//
//  NotificationViewController.swift
//  flocal
//
//  Created by George Tang on 6/8/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseDatabase
import FirebaseAnalytics

class NotificationViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Outlets
    
    @IBOutlet weak var tableView: UITableView!
    
    // MARK - Vars
    
    var myID: String = "0"
    var notifications: [NotificationStruct] = []
    
    var scrollPosition: String = "top"
    var isRemoved: Bool = false
    var lastContentOffset: CGFloat = 0
    
    var ref = Database.database().reference()

    let misc = Misc()
    var refreshControl = UIRefreshControl()
    var displayActivity: Bool = false

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = "Notifications"
        self.navigationController?.navigationBar.tintColor = misc.flocalColor
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: misc.flocalColor]

        let tapBar = UITapGestureRecognizer(target: self, action: #selector(self.scrollToTop))
        self.navigationController?.navigationBar.addGestureRecognizer(tapBar)
        
        self.refreshControl.addTarget(self, action: #selector(self.observeNotifications), for: .valueChanged)
        self.tableView.addSubview(self.refreshControl)
        
        self.setTableView()
        
        self.myID = self.misc.setMyID()
        if self.myID == "0" {
            misc.postToNotificationCenter("turnToLogin")
            self.dismiss(animated: true, completion: nil)
        }
        
        misc.playSound("menu_swish.wav", start: 0.322)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.portrait)
        self.logViewNotifications()
        misc.postToNotificationCenter("dismissSideMenu")
        self.clearLastNotificationType()
        self.observeNotifications()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
        self.removeObserverForNotifications()
        self.clearLastNotificationType()
    }
    
    deinit {
        self.removeObserverForNotifications()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        misc.clearWebImageCache()
    }
    
    // MARK: - TableView
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.notifications.isEmpty {
            return 1
        }
        
        let count = self.notifications.count
        if self.displayActivity {
            return count + 1
        }
        return count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if self.notifications.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "noNotificationCell", for: indexPath) as! NoContentTableViewCell
            cell.backgroundColor = .white
            cell.noContentLabel.textColor = misc.flocalColor
            cell.noContentLabel.text = "You don't have any notifications."
            cell.noContentLabel.numberOfLines = 0
            cell.noContentLabel.sizeToFit()
            return cell
        }
        
        if self.displayActivity && (indexPath.row == notifications.count) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "notificationActivityCell", for: indexPath) as! ActivityTableViewCell
            cell.activityIndicatorView.startAnimating()
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "notificationCell", for: indexPath) as! NotificationTableViewCell
        let notification = self.notifications[indexPath.row]
        
        let timestamp = notification.timestamp
        let message = notification.message
        let text = "\(message) \(timestamp)"
        cell.notificationLabel.attributedText = misc.stringWithColoredTags(text, time: timestamp, fontSize: 18, timeSize: 18)
        cell.notificationLabel.numberOfLines = 0
        cell.notificationLabel.sizeToFit()
        
        let type = notification.type
        switch type {
        case "upvote":
            cell.notificationLabel.backgroundColor = misc.flocalOrangeFade
            cell.notificationImageView.image = UIImage(named:"upvoteS")
        case "reply":
            cell.notificationLabel.backgroundColor = misc.flocalYellowFade
            cell.notificationImageView.image = UIImage(named:"replyS")
        case "tagged":
            cell.notificationLabel.backgroundColor = misc.flocalYellowFade
            cell.notificationImageView.image = UIImage(named:"taggedS")
        case "chat":
            cell.notificationLabel.backgroundColor = misc.flocalTealFade
            cell.notificationImageView.image = UIImage(named:"chatCS")
        case "added":
            cell.notificationLabel.backgroundColor = misc.flocalGreenFade
            cell.notificationImageView.image = UIImage(named:"addS")
        default:
            cell.backgroundColor = .white
//            cell.notificationImageView.image = UIImage(named:"appIcon")
        }
        cell.notificationLabel.numberOfLines = 0
        cell.notificationLabel.sizeToFit()

        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if !self.notifications.isEmpty {
            let notification = self.notifications[indexPath.row]
            let type = notification.type
            
            switch type {
            case "upvote", "reply", "tagged":
                let postID = notification.postID
                UserDefaults.standard.set(postID, forKey: "postIDToPass.flocal")
                UserDefaults.standard.synchronize()
                self.misc.postToNotificationCenter("turnToReply")
            case "chat":
                let handle = notification.handle
                let userID = notification.userID
                let chatID = self.misc.setChatID(self.myID, userID: userID)
                UserDefaults.standard.set("notification", forKey: "chatParentSource.flocal")
                UserDefaults.standard.set(chatID, forKey: "chatIDToPass.flocal")
                UserDefaults.standard.set(handle, forKey: "handleToPass.flocal")
                UserDefaults.standard.set(userID, forKey: "userIDToPass.flocal")
                UserDefaults.standard.synchronize()
                self.misc.postToNotificationCenter("turnToChat")
            case "added":
                UserDefaults.standard.set(true, forKey: "setToFollowers.flocal")
                UserDefaults.standard.synchronize()
                self.misc.postToNotificationCenter("turnToAdded")
            default:
                print(type)
            }
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func setTableView() {
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 100
        self.tableView.layoutMargins = UIEdgeInsets.zero
        self.tableView.separatorInset = UIEdgeInsets.zero
        self.tableView.showsVerticalScrollIndicator = false
    }
    
    // MARK: - Scroll
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !self.isRemoved {
            self.removeObserverForNotifications()
        }
        
        let offset = scrollView.contentOffset.y
        let frameHeight = scrollView.frame.size.height
        let contentHeight = scrollView.contentSize.height
        let bottomPoint = CGPoint(x: scrollView.contentOffset.x, y: contentHeight - frameHeight)

        let notifications = self.notifications
        
        if offset <= 42 {
            self.scrollPosition = "top"
            self.observeNotifications()
        } else if offset == (contentHeight - frameHeight) {
            self.scrollPosition = "bottom"
            if notifications.count >= 8 {
                self.displayActivity = true
                self.tableView.reloadData()
                scrollView.setContentOffset(bottomPoint, animated: true)
                self.observeNotifications()
            }
        } else {
            self.scrollPosition = "middle"
        }
        
        self.lastContentOffset = scrollView.contentOffset.y
    }
    
    @objc func scrollToTop() {
        self.lastContentOffset = 0
        self.scrollPosition = "top"
        self.tableView.setContentOffset(.zero, animated: false)
    }
    
    // MARK: - Analytics 
    
    func logViewNotifications() {
        Analytics.logEvent("viewNotifications_iOS", parameters: [
            "myID": self.myID as NSObject
            ])
    }
    
    // MARK: - Firebase 
    
    func clearLastNotificationType() {
        self.ref.child("users").child(self.myID).child("notificationBadge").setValue(0)
        self.ref.child("users").child(self.myID).child("lastNotificationType").setValue("clear")
        UserDefaults.standard.removeObject(forKey: "badgeNumber.flocal")
        UserDefaults.standard.synchronize()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    @objc func observeNotifications() {
        self.removeObserverForNotifications()
        self.isRemoved = false
        
        let lastID = self.notifications.last?.notificationID
        
        var reverseTimestamp: TimeInterval
        let currentReverseTimestamp = misc.getCurrentReverseTimestamp()
        let notifications = self.notifications
        let lastReverseTimestamp = notifications.last?.originalReverseTimestamp
        
        if self.scrollPosition == "bottom" {
            reverseTimestamp = lastReverseTimestamp ?? currentReverseTimestamp
        } else {
            reverseTimestamp = currentReverseTimestamp
        }

        let notificationRef = self.ref.child("userNotifications").child(self.myID)
        notificationRef.queryOrdered(byChild: "originalReverseTimestamp").queryStarting(atValue: reverseTimestamp).queryLimited(toFirst: 88).observe(.value, with: { snapshot in
            if let dict = snapshot.value as? [String:Any] {
                var notificationArray: [NotificationStruct] = []
                
                for entry in dict {
                    var notification = NotificationStruct()
                    let info = entry.value as? [String:Any] ?? [:]
                    
                    notification.notificationID = entry.key
                    notification.type = info["type"] as? String ?? "error"
                    notification.postID = info["postID"] as? String ?? "error"
                    notification.userID = info["userID"] as? String ?? "error"
                    notification.handle = info["handle"] as? String ?? "error"
                    notification.message = info["notification"] as? String ?? "error"

                    let timestamp = info["timestamp"] as? String ?? "error"
                    notification.timestamp = self.misc.formatTimestamp(timestamp)
                    notification.originalReverseTimestamp = info["originalReverseTimestamp"] as? TimeInterval ?? 0
                
                    notificationArray.append(notification)
                }
                
                if self.scrollPosition == "bottom" {
                    if (lastID != notificationArray.last?.notificationID) {
                        self.notifications.append(contentsOf: notificationArray)
                    }
                } else {
                    self.notifications = notificationArray
                }
                self.tableView.reloadData()
            }
        })
        self.refreshControl.endRefreshing()
    }
    
    func removeObserverForNotifications() {
        self.isRemoved = true
        
        let notificationRef = self.ref.child("userNotifications").child(self.myID)
        notificationRef.removeAllObservers()
    }

}
