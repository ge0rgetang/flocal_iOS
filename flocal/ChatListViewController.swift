//
//  ChatListViewController.swift
//  flocal
//
//  Created by George Tang on 6/15/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseDatabase
import FirebaseStorage
import FirebaseAnalytics
import SideMenu
import SDWebImage
import AVKit
import AVFoundation

class ChatListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Outlets
    
    @IBOutlet weak var notificationLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: - Vars
    
    var myID: String = "0"
    var chatList: [Chat] = []
    
    var chatIDToPass: String = "0"
    var userIDToPass: String = "0"
    
    var scrollPosition: String = "top"
    var isRemoved: Bool = false
    var lastContentOffset: CGFloat = 0
    
    var ref = Database.database().reference()
    let storageRef = Storage.storage().reference()
    
    let misc = Misc()
    var refreshControl = UIRefreshControl()
    var sideMenuButton = UIButton()
    var sideMenuBarButton = UIBarButtonItem()
    var notificationButton = UIButton()
    var notificationBarButton = UIBarButtonItem()
    var displayActivity: Bool = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = "Chats"
        self.navigationController?.navigationBar.tintColor = misc.flocalTeal
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: misc.flocalTeal]

        let tapBar = UITapGestureRecognizer(target: self, action: #selector(self.scrollToTop))
        self.navigationController?.navigationBar.addGestureRecognizer(tapBar)
        
        self.refreshControl.addTarget(self, action: #selector(self.observeChatList), for: .valueChanged)
        self.tableView.addSubview(self.refreshControl)
        
        self.setTableView()
        self.setSideMenu()
        self.setNotificationMenu()
        
        self.myID = misc.setMyID()
        
        if self.myID == "0" {
            misc.postToNotificationCenter("turnToLogin")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.portrait)
        UserDefaults.standard.set("chatList", forKey: "chatParentSource.flocal")
        UserDefaults.standard.synchronize() 
        
        self.tableView.reloadData()
        self.logViewChatList()
        misc.setSideMenuIndex(2)
        self.setNotifications()
        misc.observeLastNotificationType(self.notificationLabel, button: self.notificationButton, color: "teal")
        self.observeChatList()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
        self.removeNotifications()
        self.removeObserverForChatList()
        misc.removeNotificationTypeObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.removeObserverForChatList()
        misc.removeNotificationTypeObserver()
        self.clearArrays()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        NotificationCenter.default.removeObserver(self)
        self.removeObserverForChatList()
        misc.removeNotificationTypeObserver()
        misc.clearWebImageCache()
        self.clearArrays()
    }
    
    // MARK: - Tableview
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let chats = self.chatList
        if chats.isEmpty {
            return 1
        } else {
            let count = chats.count
            if self.displayActivity {
                return count + 1
            }
            return chats.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let chats = self.chatList
        
        if chats.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "noChatListCell", for: indexPath) as! NoContentTableViewCell
            cell.noContentLabel.text = "No chats. Start a conversation by sending someone a message in their profile."
            cell.noContentLabel.numberOfLines = 0 
            cell.noContentLabel.sizeToFit()
            cell.noContentLabel.textColor = misc.flocalTeal
            return cell
        }
        
        if self.displayActivity && (indexPath.row == chats.count) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "chatListActivityCell", for: indexPath) as! ActivityTableViewCell
            cell.activityIndicatorView.startAnimating()
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "chatListCell", for: indexPath) as! UserListTableViewCell
        let chat = chats[indexPath.row]
        
        cell.backgroundColor = .white
        
        let handle = chat.handle
        cell.handleLabel.text = "@\(handle)"
        
        if let profilPicURL = chat.profilePicURL {
            cell.profilePicImageView.sd_setImage(with: profilPicURL)
        } else {
            cell.profilePicImageView.image = self.misc.setDefaultPic(handle)
        }
        cell.profilePicImageView.layer.cornerRadius = cell.profilePicImageView.frame.size.width/2
        cell.profilePicImageView.clipsToBounds = true
        let tapPic = UITapGestureRecognizer(target: self, action: #selector(self.presentUserProfile))
        cell.profilePicImageView.addGestureRecognizer(tapPic)
        
        let userID = chat.userID
        if userID == self.myID {
            cell.infoLabel.textColor = .lightGray
        } else {
            cell.infoLabel.textColor = .black
        }
        
        let timestamp = chat.timestamp
        let type = chat.type
        switch type {
        case "image":
            cell.infoLabel.text = "picture sent \(timestamp)"
            cell.infoLabel.font = UIFont.italicSystemFont(ofSize: 14)
        case "video":
            cell.infoLabel.text = "video sent \(timestamp)"
            cell.infoLabel.font = UIFont.italicSystemFont(ofSize: 14)
        default:
            let message = chat.message
            cell.infoLabel.text = "\(message) \(timestamp)"
            cell.infoLabel.font = UIFont.systemFont(ofSize: 14)
        }
        cell.infoLabel.numberOfLines = 0
        cell.infoLabel.sizeToFit()
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let chats = self.chatList
        if !chats.isEmpty {
            let cell = tableView.cellForRow(at: indexPath) as! UserListTableViewCell
            cell.backgroundColor = misc.flocalTealFade
            
            let chat = chats[indexPath.row]
            
            let chatID = chat.chatID
            let userID = chat.userID
            let handle = chat.handle
            self.chatIDToPass = chatID
            self.userIDToPass = userID
            UserDefaults.standard.set(chatID, forKey: "chatIDToPass.flocal")
            UserDefaults.standard.set(handle, forKey: "handleToPass.flocal")
            UserDefaults.standard.set(userID, forKey: "userIDToPass.flocal")
            UserDefaults.standard.synchronize()
            
            let messageID = chat.messageID
            let type = chat.type
            self.prefetchChatPic(messageID, chatID: chatID, type: type)
            
            self.performSegue(withIdentifier: "fromChatListToChat", sender: self)
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
    
    // MARK: - Navigation 
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "fromChatListToChat" {
            if let vc = segue.destination as? ChatViewController {
                vc.chatID = self.chatIDToPass
                vc.userID = self.userIDToPass
                vc.parentSource = "chatList"
            }
        }
    }
    
    @objc func presentUserProfile(_ sender: UITapGestureRecognizer) {
        let position = sender.location(in: self.tableView)
        let indexPath: IndexPath! = self.tableView.indexPathForRow(at: position)
        let chats = self.chatList
        let chat = chats[indexPath.row]
        
        let userID = chat.userID
        self.prefetchUserProfilePics(userID)
        self.userIDToPass = userID
        
        if self.myID != userID {
            self.performSegue(withIdentifier: "fromChatListToUserProfile", sender: self)
        }
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
            
            self.sideMenuButton.setImage(UIImage(named: "menuTealS"), for: .normal)
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
            
            self.notificationButton.setImage(UIImage(named: "notificationTealS"), for: .normal)
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
    
    // MARK: - Scroll
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !self.isRemoved {
            self.removeObserverForChatList()
        }
        
        let offset = scrollView.contentOffset.y
        let frameHeight = scrollView.frame.size.height
        let contentHeight = scrollView.contentSize.height
        let bottomPoint = CGPoint(x: scrollView.contentOffset.x, y: contentHeight - frameHeight)

        let chats = self.chatList
        
        if offset <= 42 {
            self.scrollPosition = "top"
            self.observeChatList()
        } else if offset == (contentHeight - frameHeight) {
            self.scrollPosition = "bottom"
            if chats.count >= 8 {
                self.displayActivity = true
                self.tableView.reloadData()
                scrollView.setContentOffset(bottomPoint, animated: true)
                self.observeChatList()
            }
        } else {
            self.scrollPosition = "middle"
        }
        
        // prefetch images on scroll down
        if !chats.isEmpty {
            if self.lastContentOffset < scrollView.contentOffset.y {
                let visibleCells = self.tableView.visibleCells
                if let lastCell = visibleCells.last {
                    let lastIndexPath = self.tableView.indexPath(for: lastCell)
                    let lastRow = lastIndexPath!.row
                    var nextLastRow = lastRow + 5
                    
                    let maxCount = chats.count
                    if nextLastRow > (maxCount - 1) {
                        nextLastRow = maxCount - 1
                    }
                    
                    if nextLastRow <= lastRow {
                        nextLastRow = lastRow
                    }
                    
                    var urlsToPrefetch: [URL] = []
                    for index in lastRow...nextLastRow {
                        let chat = chats[index]
                        
                        if let profilePicURL = chat.profilePicURL {
                            urlsToPrefetch.append(profilePicURL)
                        }
                    }
                    SDWebImagePrefetcher.shared().prefetchURLs(urlsToPrefetch)
                }
            }
        }
        self.lastContentOffset = scrollView.contentOffset.y
    }
    
    @objc func scrollToTop() {
        self.lastContentOffset = 0
        self.scrollPosition = "top"
        self.tableView.setContentOffset(.zero, animated: false)
    }
    
    // MARK: - Misc
    
    func displayAlert(_ alertTitle: String, alertMessage: String) {
        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        alertController.view.tintColor = misc.flocalTeal
        DispatchQueue.main.async(execute: {
            self.displayActivity = false
            self.refreshControl.endRefreshing()
            self.present(alertController, animated: true, completion: nil)
        })
    }
    
    func clearArrays() {
        self.chatList = []
    }
    
    // MARK: - Notification Center
    
    func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.observeChatList), name: Notification.Name("addFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.removeObserverForChatList), name: Notification.Name("removeFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.scrollToTop), name: Notification.Name("scrollToTop"), object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name("addFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("removeFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("scrollToTop"), object: nil)
    }
        
    // MARK: - Analytics
    
    func logViewChatList() {
        Analytics.logEvent("viewChatList_iOS", parameters: [
            "myID": self.myID as NSObject
            ])
    }
    
    // MARK: - Storage
    
    func prefetchChatPic(_ messageID: String, chatID: String, type: String) {
        if type == "image" || type == "video" {
            var picRef: StorageReference
            switch type {
            case "video":
                picRef = self.storageRef.child("chatVidPreview/\(chatID)/\(messageID).jpg")
            default:
                picRef = self.storageRef.child("chatPic/\(chatID)/\(messageID).jpg")
            }
            
            picRef.downloadURL { url, error in
                if let error = error {
                    print(error.localizedDescription)
                } else {
                    SDWebImagePrefetcher.shared().prefetchURLs([url!])
                }
            }
        }
    }
        
    func prefetchUserProfilePics(_ userID: String) {
        let backgroundPicRef = self.storageRef.child("backgroundPic/\(userID).jpg")
        backgroundPicRef.downloadURL { url, error in
            if let error = error {
                print(error.localizedDescription)
            } else {
                SDWebImagePrefetcher.shared().prefetchURLs([url!])
            }
        }
    }
    
    // MARK: - Firebase
    
    @objc func observeChatList() {
        self.removeObserverForChatList()
        self.isRemoved = false
        
        let userChatListRef = self.ref.child("userChatList").child(self.myID)

        if self.scrollPosition == "middle" && !self.chatList.isEmpty {
            if let visiblePaths = self.tableView.indexPathsForVisibleRows {
                for indexPath in visiblePaths {
                    let chatID = self.chatList[indexPath.row].chatID
                    let chatIDRef = userChatListRef.child(chatID)
                    chatIDRef.observeSingleEvent(of: .value, with: { (snapshot) -> Void in
                        if let chat = snapshot.value as? [String:Any] {
                            let formattedChat = self.formatChatList(chat, chatID: chatID)
                            self.chatList[indexPath.row] = formattedChat
                        }
                    })
                }
                self.displayActivity = false
                self.tableView.reloadRows(at: visiblePaths, with: .none)
            }
            
        } else {
            var reverseTimestamp: TimeInterval
            let currentReverseTimestamp = misc.getCurrentReverseTimestamp()
            let lastChatID = self.chatList.last?.chatID
            let lastReverseTimestamp = chatList.last?.originalReverseTimestamp
            
            if self.scrollPosition == "bottom" {
                reverseTimestamp = lastReverseTimestamp ?? currentReverseTimestamp
            } else {
                reverseTimestamp = currentReverseTimestamp
            }
            
            userChatListRef.queryOrdered(byChild: "originalReverseTimestamp").queryStarting(atValue: reverseTimestamp).queryLimited(toFirst: 88).observe(.value, with: { (snapshot) -> Void in
                if let dict = snapshot.value as? [String:Any] {
                    var chats: [Chat] = []
                    for entry in dict {
                        let chatID = entry.key
                        let chat = entry.value as? [String:Any] ?? [:]
                        let formattedChat = self.formatChatList(chat, chatID: chatID)
                        chats.append(formattedChat)
                    }
                    
                    if self.scrollPosition == "bottom" {
                        if lastChatID != chats.last?.chatID {
                            self.chatList.append(contentsOf: chats)
                        }
                    } else {
                        self.chatList = chats
                    }
                    self.tableView.reloadData()
                }
            })
            self.refreshControl.endRefreshing()
        }
    }
    
    @objc func removeObserverForChatList() {
        self.isRemoved = true
        let chatRef = self.ref.child("users").child(self.myID).child("chats")
        chatRef.removeAllObservers()
    }
    
    func formatChatList(_ chat: [String:Any], chatID: String) -> Chat {
        var formattedChat = Chat()
        
        formattedChat.chatID = chatID
        formattedChat.userID = chat["userID"] as? String ?? "error"
        formattedChat.messageID = chat["messageID"] as? String ?? "error"
        
        let profilePicURLString = chat["profilePicURLString"] as? String ?? "error"
        if profilePicURLString != "error" {
            formattedChat.profilePicURL = URL(string: profilePicURLString)
        }
        
        formattedChat.handle = chat["handle"] as? String ?? "error"
        
        let type = chat["type"] as? String ?? "error"
        formattedChat.type = type
        switch type {
        case "image":
            formattedChat.message = "image sent"
        case "video":
            formattedChat.message = "video sent"
        default:
            formattedChat.message = chat["message"] as? String ?? "error"
        }
        
        let timestamp = chat["timestamp"] as? String ?? "error"
        formattedChat.timestamp = misc.formatTimestamp(timestamp)
        formattedChat.originalReverseTimestamp = chat["originalReverseTimestamp"] as? TimeInterval ?? 0

        return formattedChat
    }
}
