//
//  ChatViewController.swift
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
import MobileCoreServices

class ChatViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // MARK: - Outlets
    
    @IBOutlet weak var notificationLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var typingLabel: UILabel!
    @IBOutlet weak var typingLabelHeight: NSLayoutConstraint!
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var characterCountLabel: UILabel!
    
    @IBOutlet weak var cameraButton: UIButton!
    @IBAction func cameraButtonTapped(_ sender: Any) {
        self.selectPicSource()
    }
    
    @IBOutlet weak var sendButton: UIButton!
    @IBAction func sendButtonTapped(_ sender: Any) {
        self.imageVideoType = "text"
        self.setChat()
    }
    
    // MARK: - Vars
    
    var myID: String = "0"
    var userID: String = "0"
    var chatID: String = "0"
    var handle: String = "0"
    var myHandle: String = "0"
    var parentSource: String = "default"
    var amIBlocked: Bool = false
    var didIBlock: Bool = false
    
    var isTyping: Bool = false {
        didSet {
            if self.isTyping != oldValue {
                self.showTyping()
            }
        }
    }
    var messages: [Chat] = []
    var firstLoad: Bool = true
    
    var profilePicURL: URL?
    var myProfilePicURL: URL?
    var messageIDToPass: String = "0"
    var imageToPass: UIImage!
    var urlToPass: URL!
    var imageVideoType: String = "image"
    var downloadURL: URL?
    
    var scrollPosition: String = "top"
    var lastContentOffset: CGFloat = 0
    
    var ref = Database.database().reference()
    let storageRef = Storage.storage().reference()
    
    let misc = Misc()
    var refreshControl = UIRefreshControl()
    var imagePicker = UIImagePickerController()
    var activityView = UIView()
    var activityIndicator = UIActivityIndicatorView()
    var activityLabel = UILabel()
    var sideMenuButton = UIButton()
    var sideMenuBarButton = UIBarButtonItem()
    var settingsButton = UIButton()
    var settingsBarButton = UIBarButtonItem()
    var notificationButton = UIButton()
    var notificationBarButton = UIBarButtonItem()
    var displayActivity: Bool = false

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.dismissVC), name: Notification.Name("cleanNavigationStack"), object: nil)
        
        let chatID = UserDefaults.standard.string(forKey: "chatIDToPass.flocal") ?? self.chatID
        self.chatID = chatID
        let userID = UserDefaults.standard.string(forKey: "userIDToPass.flocal") ?? "0"
        self.userID = userID
        let source = UserDefaults.standard.string(forKey: "chatParentSource.flocal") ?? "default"
        self.parentSource = source
        
        self.navigationController?.navigationBar.tintColor = misc.flocalTeal
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: misc.flocalTeal]

        let handle = UserDefaults.standard.string(forKey: "handleToPass.flocal") ?? "0"
        if handle != "0" {
            self.navigationItem.title = "@\(handle)"
            self.handle = handle
        } else {
            self.navigationItem.title = "chat"
            misc.getHandle(self.userID) { handle in
                self.handle = handle
            }
        }
        
        if let hand = UserDefaults.standard.string(forKey: "handle.flocal") {
            self.myHandle = hand
        } else {
            misc.getHandle(myID) { handle in
                self.myHandle = handle
            }
        }
        
        let tapBar = UITapGestureRecognizer(target: self, action: #selector(self.scrollToTop))
        self.navigationController?.navigationBar.addGestureRecognizer(tapBar)
        
        self.refreshControl.addTarget(self, action: #selector(self.observeChat), for: .valueChanged)
        self.tableView.addSubview(self.refreshControl)

        if source != "chatList" {
            self.setSideMenu()
        }
        self.setRightBarButtons()
        self.formatTextView()
        self.setImagePicker()
        self.setTableView()
        
        self.myID = misc.setMyID()
        if self.myID == "0" {
            misc.postToNotificationCenter("turnToLogin")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.portrait)
        self.firstLoad = true
        self.checkIfFromPush()
        
        if self.chatID == "0" {
            self.dismiss(animated: false, completion: nil)
            _ = self.navigationController?.popViewController(animated: false)
        }
       
        self.tableView.reloadData()
        self.logViewChat()
        if self.parentSource != "chatList" {
            misc.setSideMenuIndex(42)
        }
        misc.writeAmInChat(true, chatID: self.chatID, myID: self.myID)
        self.setNotifications()
        misc.observeLastNotificationType(self.notificationLabel, button: self.notificationButton, color: "teal")
        self.downloadProfilePicURL()
        self.downloadMyProfilePicURL()
        self.observeBlocked()
        self.observeChat()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
        misc.writeAmInChat(false, chatID: self.chatID, myID: self.myID)
        misc.writeAmITyping(false, chatID: self.chatID, myID: self.myID)
        misc.removeChatID()
        self.removeNotifications()
        self.removeObserverForBlocked()
        self.removeObserverForChat()
        misc.removeNotificationTypeObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        misc.writeAmInChat(false, chatID: self.chatID, myID: self.myID)
        misc.writeAmITyping(false, chatID: self.chatID, myID: self.myID)
        self.removeObserverForChat()
        misc.removeNotificationTypeObserver()
        self.clearArrays()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        NotificationCenter.default.removeObserver(self)
        self.removeObserverForChat()
        misc.removeNotificationTypeObserver()
        misc.clearWebImageCache()
        self.clearArrays()
    }
    
    // MARK: - Tableview
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let messages = self.messages
        if messages.isEmpty {
            return 1
        } else {
            if self.displayActivity {
                return messages.count + 1
            }
            return messages.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let messages = self.messages
        
        if messages.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "noChatCell", for: indexPath) as! NoContentTableViewCell
            cell.transform = CGAffineTransform(scaleX: 1, y: -1)
            cell.noContentLabel.text = "Start a conversation by sending a message!"
            cell.noContentLabel.numberOfLines = 0
            cell.noContentLabel.sizeToFit()
            cell.noContentLabel.textColor = misc.flocalTeal
            return cell
        }
        
        if self.displayActivity && (indexPath.row == self.messages.count) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "chatActivityCell", for: indexPath) as! ActivityTableViewCell
            cell.transform = CGAffineTransform(scaleX: 1, y: -1)
            cell.activityIndicatorView.startAnimating()
            return cell
        }
        
        var cell: ChatTableViewCell
        let message = messages[indexPath.row]
        let userID = message.userID
        let type = message.type
        
        if userID == self.myID {
            switch type {
            case "image":
                cell = tableView.dequeueReusableCell(withIdentifier: "myChatImageCell", for: indexPath) as! ChatTableViewCell
                cell.playImageView.isHidden = true
                if let chatPicURL = message.chatPicURL {
                    cell.imagePicImageView.sd_setImage(with: chatPicURL) { (image, error, cache, url) in
                        self.misc.setChatImageAspectRatio(cell, image: image)
                    }
                    let tapImage = UITapGestureRecognizer(target: self, action: #selector(self.presentViewImage))
                    cell.imagePicImageView.addGestureRecognizer(tapImage)
                }
                
            case "video":
                cell = tableView.dequeueReusableCell(withIdentifier: "myChatImageCell", for: indexPath) as! ChatTableViewCell
                cell.playImageView.isHidden = false
                if let chatVidPreviewURL = message.chatVidPreviewURL {
                    cell.imagePicImageView.sd_setImage(with: chatVidPreviewURL) { (image, error, cache, url) in
                        self.misc.setChatImageAspectRatio(cell, image: image)
                    }
                    let tapVid = UITapGestureRecognizer(target: self, action: #selector(self.presentViewVideo))
                    cell.imagePicImageView.addGestureRecognizer(tapVid)
                } else {
                    if let chatVidURL = message.chatVidURL {
                        let imageTuple = self.generatePreviewImage(chatVidURL)
                        cell.imagePicImageView.image = imageTuple.0
                        if imageTuple.1 {
                            cell.imagePicImageView.contentMode = .scaleAspectFill
                        } else {
                            cell.imagePicImageView.contentMode = .scaleAspectFit
                        }
                        self.misc.setChatImageAspectRatio(cell, image: imageTuple.0)
                        let tapVid = UITapGestureRecognizer(target: self, action: #selector(self.presentViewVideo))
                        cell.imagePicImageView.addGestureRecognizer(tapVid)
                    }
                }

            default:
                cell = tableView.dequeueReusableCell(withIdentifier: "myChatCell", for: indexPath) as! ChatTableViewCell
                let text = message.message
                cell.chatLabel.text = text
                cell.chatLabel.numberOfLines = 0
                cell.chatLabel.sizeToFit()
            }
            
        } else {
            switch type {
            case "image":
                cell = tableView.dequeueReusableCell(withIdentifier: "chatImageCell", for: indexPath) as! ChatTableViewCell
                cell.playImageView.isHidden = true
                if let chatPicURL = message.chatPicURL{
                    cell.imagePicImageView.sd_setImage(with: chatPicURL) { (image, error, cache, url) in
                        self.misc.setChatImageAspectRatio(cell, image: image)
                    }
                    let tapImage = UITapGestureRecognizer(target: self, action: #selector(self.presentViewImage))
                    cell.imagePicImageView.addGestureRecognizer(tapImage)
                }
                
            case "video":
                cell = tableView.dequeueReusableCell(withIdentifier: "chatImageCell", for: indexPath) as! ChatTableViewCell
                cell.playImageView.isHidden = false
                if let chatVidPreviewURL = message.chatVidPreviewURL {
                    cell.imagePicImageView.sd_setImage(with: chatVidPreviewURL) { (image, error, cache, url) in
                        self.misc.setChatImageAspectRatio(cell, image: image)
                    }
                    let tapVid = UITapGestureRecognizer(target: self, action: #selector(self.presentViewVideo))
                    cell.imagePicImageView.addGestureRecognizer(tapVid)
                } else {
                    if let chatVidURL = message.chatVidURL {
                        let imageTuple = self.generatePreviewImage(chatVidURL)
                        cell.imagePicImageView.image = imageTuple.0
                        if imageTuple.1 {
                            cell.imagePicImageView.contentMode = .scaleAspectFill
                        } else {
                            cell.imagePicImageView.contentMode = .scaleAspectFit
                        }
                        self.misc.setChatImageAspectRatio(cell, image: imageTuple.0)
                        let tapVid = UITapGestureRecognizer(target: self, action: #selector(self.presentViewVideo))
                        cell.imagePicImageView.addGestureRecognizer(tapVid)
                    }
                }

            default:
                cell = tableView.dequeueReusableCell(withIdentifier: "chatCell", for: indexPath) as! ChatTableViewCell
                let text = message.message
                cell.chatLabel.text = text
                cell.chatLabel.numberOfLines = 0
                cell.chatLabel.sizeToFit()
            }
            
            let handle = message.handle
            if let profilePicURL = self.profilePicURL {
                cell.profilePicImageView.sd_setImage(with: profilePicURL)
            } else {
                cell.profilePicImageView.image = self.misc.setDefaultPic(handle)
            }
            cell.profilePicImageView.layer.cornerRadius = cell.profilePicImageView.frame.size.width/2
            cell.profilePicImageView.clipsToBounds = true
        }

        let timestamp = message.timestamp
        let originalTimestamp = message.originalTimestamp
        if indexPath.row > 0 {
            let lastOriginalTimestamp = self.messages[indexPath.row - 1].originalTimestamp
            let delay = lastOriginalTimestamp + 300
            if originalTimestamp > delay {
                cell.timestampLabel.text = timestamp
                cell.timestampLabelHeight.constant = 15
            } else {
                cell.timestampLabelHeight.constant = 0
            }
        } else {
            cell.timestampLabel.text = timestamp
            cell.timestampLabelHeight.constant = 15
        }
        
        cell.backgroundColor = .white
        cell.transform = CGAffineTransform(scaleX: 1, y: -1)
        
        return cell
    }

    func setTableView() {
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 100
        self.tableView.layoutMargins = UIEdgeInsets.zero
        self.tableView.separatorInset = UIEdgeInsets.zero
        self.tableView.showsVerticalScrollIndicator = false
        self.tableView.transform = CGAffineTransform(scaleX: 1, y: -1)
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "fromChatToViewImage" {
            if let vc = segue.destination as? ViewImageViewController {
                vc.chatID = self.chatID
                vc.messageID = self.messageIDToPass
                vc.parentSource = "chat"
                vc.image = self.imageToPass
                vc.picURL = self.urlToPass
                misc.setRotateView(self.imageToPass)
            }
        }
        
        if segue.identifier == "fromChatToViewVideo" {
            if let vc = segue.destination as? ViewVideoViewController {
                vc.chatID = self.chatID
                vc.messageID = self.messageIDToPass
                vc.parentSource = "chat"
                vc.previewImage = self.imageToPass
                vc.vidURL = self.urlToPass
                misc.setRotateView(self.imageToPass)
            }
        }
        
        if segue.identifier == "fromChatToCamera" {
            if let vc = segue.destination as? CameraViewController {
                if self.imageVideoType == "image" {
                    vc.isImage = true
                } else {
                    vc.isImage = false
                }
                vc.parentSource = "chat"
                vc.isFront = false
                vc.userID = self.userID
                vc.chatID = self.chatID
                vc.handle = self.handle
                vc.myHandle = self.myHandle
                vc.profilePicURL = self.profilePicURL
                vc.myProfilePicURL = self.myProfilePicURL
            }
        }

        if segue.identifier == "fromChatToReportUser" {
            if let vc = segue.destination as? ReportUserViewController {
                vc.userID = self.userID
            }
        }
    }
    
    @objc func presentViewImage(_ sender: UITapGestureRecognizer) {
        let position = sender.location(in: self.tableView)
        let indexPath: IndexPath! = self.tableView.indexPathForRow(at: position)
        let message = self.messages[indexPath.row]
        
        let messageID = message.messageID
        self.messageIDToPass = messageID
        
        if let chatPicURL = message.chatPicURL {
            let imageView = UIImageView()
            imageView.sd_setImage(with: chatPicURL)
            self.imageToPass = imageView.image
            self.urlToPass = chatPicURL
            self.performSegue(withIdentifier: "fromChatToViewImage", sender: self)
        }
    }
    
    @objc func presentViewVideo(_ sender: UITapGestureRecognizer) {
        let position = sender.location(in: self.tableView)
        let indexPath: IndexPath! = self.tableView.indexPathForRow(at: position)
        let message = self.messages[indexPath.row]
        
        let messageID = message.messageID
        self.messageIDToPass = messageID
        
        if let chatVidURL = message.chatVidURL {
            if let chatVidPreviewURL = message.chatVidPreviewURL {
                let imageView = UIImageView()
                imageView.sd_setImage(with: chatVidPreviewURL)
                self.imageToPass = imageView.image
            } else {
                let previewTuple = self.generatePreviewImage(chatVidURL)
                self.imageToPass = previewTuple.0
            }
            self.urlToPass = chatVidURL
            self.performSegue(withIdentifier: "fromChatToViewVideo", sender: self)
        }
    }
    
    @objc func presentUserSheet() {
        self.settingsButton.isSelected = true
        
        let sheetController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let reportUserAction = UIAlertAction(title: "Report User", style: .default, handler: { action in
            self.settingsButton.isSelected = false
            self.performSegue(withIdentifier: "fromChatToReportUser", sender: self)
        })
        sheetController.addAction(reportUserAction)

        if self.didIBlock {
            let unblockAction = UIAlertAction(title: "Unblock", style: .default, handler: { action in
                self.settingsButton.isSelected = false
                self.unblockUser()
            })
            sheetController.addAction(unblockAction)
            
        } else {
            let blockAction = UIAlertAction(title: "Block", style: .default, handler: { action in
                self.settingsButton.isSelected = false
                self.blockUser()
            })
            sheetController.addAction(blockAction)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
            self.settingsButton.isSelected = false
        })
        sheetController.addAction(cancelAction)
        
        sheetController.view.tintColor = misc.flocalTeal
        DispatchQueue.main.async(execute: {
            self.present(sheetController, animated: true, completion: nil)
        })
    }
    
    // MARK: - Image Picker
    
    func imagePickerController(_ picker:UIImagePickerController, didFinishPickingMediaWithInfo info:[String: Any]) {
        if let selectedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
            self.imageToPass = selectedImage
            self.imageVideoType = "image"
            self.setChat()
        }
        
        self.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func selectPicSource() {
        DispatchQueue.main.async(execute: {
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let takeVideoAction = UIAlertAction(title: "Record Video", style: .default, handler: { action in
                    self.imageVideoType = "video"
                    self.performSegue(withIdentifier: "fromChatToCamera", sender: self)
                })
                alertController.addAction(takeVideoAction)
                
                let takePhotoAction = UIAlertAction(title: "Take Photo", style: .default, handler: { action in
                    self.imageVideoType = "image"
                    self.performSegue(withIdentifier: "fromChatToCamera", sender: self)
                })
                alertController.addAction(takePhotoAction)
            }
            
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                let choosePhotoLibraryAction = UIAlertAction(title: "Choose from Photo Library", style: .default, handler: { action in
                    self.imagePicker.sourceType = .photoLibrary
                    self.present(self.imagePicker, animated: true, completion: nil)
                })
                alertController.addAction(choosePhotoLibraryAction)
            }
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            alertController.view.tintColor = self.misc.flocalTeal
            self.misc.playSound("button_click.wav", start: 0)
            self.present(alertController, animated: true, completion: nil)
        })
    }
    
    func setImagePicker() {
        self.imagePicker.delegate = self
        self.imagePicker.allowsEditing = true
        self.imagePicker.modalPresentationStyle = .fullScreen
    }
    
    func generatePreviewImage(_ url: URL) -> (UIImage, Bool) {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let timestamp = CMTime(seconds: 1.0, preferredTimescale: 1)
        
        do {
            let imageRef = try generator.copyCGImage(at: timestamp, actualTime: nil)
            return (UIImage(cgImage: imageRef), true)
        } catch let error as NSError {
            print("\(error)")
            return (UIImage(named: "playS")!, false)
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
    
    func setRightBarButtons() {
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
            
            self.settingsButton.setImage(UIImage(named: "settingsTealS"), for: .normal)
            self.settingsButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            self.settingsButton.addTarget(self, action: #selector(self.presentUserSheet), for: .touchUpInside)
            self.settingsBarButton.customView = self.settingsButton
            
            self.navigationItem.setRightBarButtonItems([self.notificationBarButton, self.settingsBarButton], animated: false)
        }
    }
    
    @objc func presentNotificationMenu() {
        misc.playSound("menu_swish.wav", start: 0.322)
        self.present(SideMenuManager.menuRightNavigationController!, animated: true, completion: nil)
    }
    
    // MARK: - Scroll
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y
        let frameHeight = scrollView.frame.size.height
        let contentHeight = scrollView.contentSize.height
        let bottomPoint = CGPoint(x: scrollView.contentOffset.x, y: contentHeight - frameHeight)

        let messages = self.messages
        
        if offset <= 42 {
            self.scrollPosition = "top"
            self.observeChat()
        } else if offset == (contentHeight - frameHeight) {
            self.scrollPosition = "bottom"
            if messages.count >= 8 {
                self.displayActivity = true
                self.tableView.reloadData()
                scrollView.setContentOffset(bottomPoint, animated: true)
                self.observeChat()
            }
        } else {
            self.scrollPosition = "middle"
        }
        
        // prefetch images on scroll down
        if !messages.isEmpty {
            if self.lastContentOffset < scrollView.contentOffset.y {
                let visibleCells = self.tableView.visibleCells
                if let lastCell = visibleCells.last {
                    let lastIndexPath = self.tableView.indexPath(for: lastCell)
                    let lastRow = lastIndexPath!.row
                    var nextLastRow = lastRow + 5
                    
                    let maxCount = messages.count
                    if nextLastRow > (maxCount - 1) {
                        nextLastRow = maxCount - 1
                    }
                    
                    if nextLastRow <= lastRow {
                        nextLastRow = lastRow
                    }
                    
                    var urlsToPrefetch: [URL] = []
                    for index in lastRow...nextLastRow {
                        let message = messages[index]
                        let type = message.type
                        
                        if type == "image" {
                            if let chatPicURL = message.chatPicURL{
                                urlsToPrefetch.append(chatPicURL)
                            }
                        }
                        
                        if type == "video" {
                            if let chatVidPreviewURL = message.chatVidPreviewURL {
                                urlsToPrefetch.append(chatVidPreviewURL)
                            }
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
        
    // MARK: - TextView
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == .lightGray {
            textView.text = ""
            textView.textColor = .black
            misc.writeAmITyping(true, chatID: self.chatID, myID: self.myID)
        }
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
        if textView.text == "" {
            textView.text = "send a message..."
            textView.textColor = .lightGray
            self.characterCountLabel.isHidden = true
            misc.writeAmITyping(false, chatID: self.chatID, myID: self.myID)
        }
    }
    
    func formatTextView() {
        self.textView.delegate = self
        self.textView.textColor = .lightGray
        self.textView.text = "send a message..."
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
    
    @objc func keyboardWillShow(_ notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            if self.view.frame.origin.y == 0 {
                self.view.frame.origin.y -= keyboardSize.height
            }
        }
    }
    
    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            self.view.frame.origin.y = -keyboardSize.height
        }
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        if self.view.frame.origin.y != 0 {
            self.view.frame.origin.y = 0
        }
    }
    
    @objc func keyboardDidHide(_ notification: Notification) {
        if self.view.frame.origin.y != 0 {
            self.view.frame.origin.y = 0
        }
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
    
    func showTyping() {
        if self.isTyping {
            UIView.animate(withDuration: 0.25, animations: {
                self.typingLabel.alpha = 1
                self.typingLabelHeight.constant = 30
                self.typingLabel.layoutIfNeeded()
                self.tableView.layoutIfNeeded()
            })
            
        } else {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveLinear, animations: {
                self.typingLabel.alpha = 0
                self.typingLabel.layoutIfNeeded()
            }, completion: { (finished:Bool) in
                if finished {
                    UIView.animate(withDuration: 0.25, animations: {
                        self.typingLabelHeight.constant = 0
                        self.tableView.layoutIfNeeded()
                        self.typingLabel.layoutIfNeeded()
                    })
                }
            })
        }
    }
    
    func clearArrays() {
        self.messages = []
    }
    
    // MARK: - Notification Center
    
    func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.observeChat), name: Notification.Name("addFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.removeObserverForChat), name: Notification.Name("removeFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.scrollToTop), name: Notification.Name("scrollToTop"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow(_:)), name: Notification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillChangeFrame(_:)), name: Notification.Name.UIKeyboardWillChangeFrame, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: Notification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardDidHide(_:)), name: Notification.Name.UIKeyboardDidHide, object: nil)

    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name("addFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("removeFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("scrollToTop"), object: nil)
        
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIKeyboardWillChangeFrame, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIKeyboardDidHide, object: nil)
    }
    
    func checkIfFromPush() {
        let fromPush = UserDefaults.standard.bool(forKey: "fromPush.flocal")
        if fromPush {
            UserDefaults.standard.set(false, forKey: "fromPush.flocal")
            UserDefaults.standard.synchronize()
            let chatID = UserDefaults.standard.string(forKey: "chatIDToPass.flocal") ?? "0"
            if chatID == "0" {
                self.displayAlert("Post Error", alertMessage: "We could not retrieve the chat. Please report this bug.")
                return
            } else {
                self.chatID = chatID
            }
        }
    }
    
    @objc func dismissVC() {
        self.navigationController?.dismiss(animated: true, completion: nil)
        self.dismiss(animated: true, completion: nil)
        self.navigationController?.popToRootViewController(animated: false)
    }
    
    // MARK: - Analytics
    
    func logViewChat() {
        Analytics.logEvent("viewChat_iOS", parameters: [
            "myID": self.myID as NSObject,
            "userID": self.userID as NSObject,
            "chatID": self.chatID as NSObject
            ])
    }
    
    func logChatSent(_ messageID: String) {
        Analytics.logEvent("sentChatText_iOS", parameters: [
            "myID": self.myID as NSObject,
            "userID": self.userID as NSObject,
            "chatID": self.chatID as NSObject,
            "messageID": messageID as NSObject
            ])
    }
    
    func logBlockedUser() {
        Analytics.logEvent("blockedUser_iOS", parameters: [
            "myID": self.myID as NSObject,
            "userID": self.userID as NSObject
            ])
    }
    
    func logUnblockedUser() {
        Analytics.logEvent("unblockedUser_iOS", parameters: [
            "myID": self.myID as NSObject,
            "userID": self.userID as NSObject
            ])
    }
    
    func logChatImageSent(_ messageID: String) {
        Analytics.logEvent("sentChatImage_iOS", parameters: [
            "myID": self.myID as NSObject,
            "userID": self.userID as NSObject,
            "chatID": self.chatID as NSObject,
            "messageID": messageID as NSObject
            ])
    }
    
    // MARK: - Storage
    
    func downloadProfilePicURL() {
        let profilePicRef = self.storageRef.child("profilePic/\(self.userID)_large.jpg")
        profilePicRef.downloadURL { url, error in
            if let error = error {
                print(error.localizedDescription)
                self.profilePicURL = nil
            } else {
                self.profilePicURL = url
            }
        }
    }
    
    func downloadMyProfilePicURL() {
        let myProfilePicRef = self.storageRef.child("profilePic/\(self.myID)_large.jpg")
        myProfilePicRef.downloadURL { url, error in
            if let error = error {
                print(error.localizedDescription)
                self.myProfilePicURL = nil
            } else {
                self.myProfilePicURL = url
            }
        }
    }
    
    typealias CompletionHandler = (_ success:Bool) -> Void
    
    func uploadPic(_ messageID: String, completionHandler: @escaping CompletionHandler) {
        var picSized: UIImage!
        let picImage = self.imageToPass
        let sourceWidth = picImage!.size.width
        let sourceHeight = picImage!.size.height
        
        var scaleFactor: CGFloat!
        if sourceWidth > sourceHeight {
            scaleFactor = 1280/sourceWidth
        } else {
            scaleFactor = 1280/sourceHeight
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
            
            let picRef = self.storageRef.child("chatPic/\(self.chatID)/\(messageID).jpg")
            picRef.putData(newPicData, metadata: metadata) { metadata, error in
                if let error = error {
                    print(error.localizedDescription)
                    completionHandler(false)
                } else {
                    print("upload success")
                    self.downloadURL = metadata!.downloadURL()
                    completionHandler(true)
                }
            }
        }
    }
    
    // MARK: - Firebase
    
    func setChat() {
        self.dismissKeyboard()
        
        if self.amIBlocked {
            self.displayAlert("Blocked", alertMessage: "You cannot send messages to this person.")
            return
        }
        
        let chatRef = self.ref.child("chats").child(self.chatID)
        let messageRef = chatRef.child("messages").childByAutoId()
        let messageID = messageRef.key
        
        if self.imageVideoType == "image" {
            self.displayActivity("uploading pic...", indicator: true)
            self.uploadPic(messageID, completionHandler: { (success) -> Void in
                if success {
                    self.writeMessage(messageID)
                    self.activityView.removeFromSuperview()
                } else {
                    self.displayAlert("Upload Error", alertMessage: "Your pic may not have been uploaded. Please try again or report the bug if it persists.")
                    return
                }
            })
        } else {
            self.writeMessage(messageID)
        }
    }
    
    func writeMessage(_ messageID: String ) {
        let text = self.textView.text
        if text == "" {
            self.displayAlert("Empty Field", alertMessage: "Please type in text to send.")
            return
        }
        
        var message: String = text!
        var chatPicURLString = "n/a"
        let chatVidURLString = "n/a"
        let chatVidPreviewURLString = "n/a"
        if self.imageVideoType == "image" {
            message = "image sent"
            if let url = self.downloadURL {
                chatPicURLString = url.absoluteString
            }
        }
        
        let timestamp = misc.getTimestamp("UTC", date: Date())
        let originalReverseTimestamp = misc.getCurrentReverseTimestamp()
        let originalTimestamp = -1*originalReverseTimestamp

        var chat: [String:Any] = ["userID": self.myID, "handle": self.myHandle, "timestamp": timestamp, "originalReverseTimestamp": originalReverseTimestamp, "originalTimestamp": originalTimestamp, "message": message, "type": self.imageVideoType, "chatPicURLString": chatPicURLString, "chatVidURLString": chatVidURLString, "chatVidPreviewURLString": chatVidPreviewURLString]
        
        var chatStruct = Chat()
        chatStruct.userID = self.myID
        chatStruct.handle = self.myHandle
        chatStruct.timestamp = timestamp
        chatStruct.originalReverseTimestamp = originalReverseTimestamp
        chatStruct.originalTimestamp = originalTimestamp
        chatStruct.message = text!
        chatStruct.type = imageVideoType
        misc.playSound("sent_chat.wav", start: 0)
        self.messages.insert(chatStruct, at: 0)
        self.tableView.reloadData()

        if self.userID != "0" {
            let chatRef = self.ref.child("chats").child(self.chatID)
            let messageRef = chatRef.child("messages").child(messageID)
            messageRef.setValue(chat)
            misc.writeAmITyping(false, chatID: chatID, myID: self.myID)
            
            chat["messageID"] = messageID
            
            let userChatListRef = self.ref.child("userChatList").child(self.userID).child(self.chatID)
            var myProfilePicURLString = "error"
            if self.myProfilePicURL != nil {
                myProfilePicURLString = self.myProfilePicURL!.absoluteString
            }
            chat["profilePicURLString"] = myProfilePicURLString
            userChatListRef.setValue(chat)
            
            let isUserInChatRef = chatRef.child("info").child(self.userID)
            isUserInChatRef.observeSingleEvent(of: .value, with: { (snapshot) -> Void in
                let isUserInChat = snapshot.value as? Bool ?? false
                if !isUserInChat {
                    self.misc.writeChatNotification(self.userID, myID: self.myID, message: text!, type: "text")
                }
            })
            
            let myChatListRef = self.ref.child("userChatList").child(self.myID).child(chatID)
            var profilePicURLString = "error"
            if self.profilePicURL != nil {
                profilePicURLString = self.profilePicURL!.absoluteString
            }
            chat["profilePicURLString"] = profilePicURLString
            chat["userID"] = self.userID
            chat["handle"] = self.handle
            myChatListRef.setValue(chat)
            self.downloadURL = nil

            if self.imageVideoType == "image" {
                self.logChatImageSent(messageID)
            } else {
                self.logChatSent(messageID)
                self.textView.text = "send a message..."
                self.textView.textColor = .lightGray
            }
        } else {
            self.displayAlert("Message Error", alertMessage: "We encountered an error trying to send your message. Please report this bug if it continues.")
            return
        }
    }
    
    @objc func observeChat() {
        self.removeObserverForChat()
        
        var reverseTimestamp: TimeInterval
        let currentReverseTimestamp = misc.getCurrentReverseTimestamp()
        let lastReverseTimestamp = self.messages.last?.originalReverseTimestamp
        let lastMessageID = self.messages.last?.messageID
        
        if self.scrollPosition == "bottom" {
            reverseTimestamp = lastReverseTimestamp ?? currentReverseTimestamp
        } else {
            reverseTimestamp = currentReverseTimestamp
        }
        
        let chatRef = self.ref.child("chats").child(self.chatID)

        let messageRef = chatRef.child("messages")
        messageRef.queryOrdered(byChild: "originalReverseTimestamp").queryStarting(atValue: reverseTimestamp).queryLimited(toFirst: 88).observe(.value, with: { (snapshot) -> Void in
            if let dict = snapshot.value as? [String:Any] {
                var messagesArray: [Chat] = []
                for entry in dict {
                    let messageID = entry.key
                    let message = entry.value as? [String:Any] ?? [:]
                    let formattedMessage = self.formatChat(messageID, chat: message)
                    messagesArray.append(formattedMessage)
                }
                
                if self.scrollPosition == "bottom" {
                    if lastMessageID != messagesArray.last?.messageID {
                        self.messages.append(contentsOf: messagesArray)
                    }
                } else {
                    self.messages = messagesArray
                    if self.firstLoad {
                        self.firstLoad = false
                    } else {
                        if self.myID != messagesArray.last?.userID {
                            self.misc.playSound("received_chat.wav", start: 0)
                        }
                    }
                }
                self.tableView.reloadData()
            }
        })
        
        let typingRef = chatRef.child("info").child("\(self.userID)_typing")
        typingRef.observe(.value, with: { (snapshot) -> Void in
            if let isUserTyping = snapshot.value as? Bool {
                self.isTyping = isUserTyping
            }
        })
        
        self.refreshControl.endRefreshing()
    }
    
    @objc func removeObserverForChat() {
        let chatRef = self.ref.child("chats").child(self.chatID)
        
        let messageRef = chatRef.child("messages")
        messageRef.removeAllObservers()
        
        let typingRef = chatRef.child("info").child("\(self.userID)_typing")
        typingRef.removeAllObservers()
    }
    
    func blockUser() {
        let blockedRef = self.ref.child("userBlocked")
        
        let userBlockedRef = blockedRef.child(self.userID)
        userBlockedRef.child("blockedBy").child(self.myID).setValue(true)
        
        let myBlockedRef = blockedRef.child(self.myID)
        myBlockedRef.child("blocked").child(self.userID).setValue(true)
        
        let userAddedRef = self.ref.child("userAdded")
        userAddedRef.child(self.myID).child(self.userID).removeValue()
        userAddedRef.child(self.userID).child(self.myID).removeValue()
        
        let userFollowersRef = self.ref.child("userFollowers")
        userFollowersRef.child(self.myID).child(self.userID).removeValue()
        userFollowersRef.child(self.userID).child(self.myID).removeValue()
        
        let userChatListRef = self.ref.child("userChatList")
        userChatListRef.child(self.myID).child(self.chatID).removeValue()
        userChatListRef.child(self.userID).child(self.chatID).removeValue()
        
        self.logBlockedUser()
        self.displayAlert("Blocked", alertMessage: "Sorry that some people are jerks. Please don't let it ruin your day!")
    }
    
    func unblockUser() {
        let blockedRef = self.ref.child("userBlocked")
        
        let userBlockedRef = blockedRef.child(self.userID)
        userBlockedRef.child("blockedBy").child(self.myID).removeValue()
        
        let myBlockedRef = blockedRef.child(self.myID)
        myBlockedRef.child("blocked").child(self.userID).removeValue()
        
        self.logUnblockedUser()
        self.displayAlert("Unblocked", alertMessage: "You have unblocked this person.")
    }
    
    func formatChat(_ messageID: String, chat: [String:Any]) -> Chat {
        var formattedMessage = Chat()
        
        formattedMessage.chatID = self.chatID
        formattedMessage.messageID = messageID
        formattedMessage.userID = chat["userID"] as? String ?? "error"
        
        formattedMessage.handle = chat["handle"] as? String ?? "error"
        
        let type = chat["type"] as? String ?? "error"
        formattedMessage.type = type
        if type == "text" {
            formattedMessage.message = chat["message"] as? String ?? "error"
        }
        
        let chatPicURLString = chat["chatPicURLString"] as? String ?? "error"
        if chatPicURLString != "error" {
            formattedMessage.chatPicURL = URL(string: chatPicURLString)
        }
        
        let chatVidURLString = chat["chatVidURLString"] as? String ?? "error"
        if chatVidURLString != "error" {
            formattedMessage.chatVidURL = URL(string: chatPicURLString)
        }
        
        let chatVidPreviewURLString = chat["chatVidPreviewURLString"] as? String ?? "error"
        if chatVidPreviewURLString != "error" {
            formattedMessage.chatVidPreviewURL = URL(string: chatVidPreviewURLString)
        }
        
        let timestamp = chat["timestamp"] as? String ?? "error"
        formattedMessage.timestamp = misc.formatTimestamp(timestamp)
        let originalReverseTimestamp = chat["originalReverseTimestamp"] as? TimeInterval ?? 0
        formattedMessage.originalReverseTimestamp = originalReverseTimestamp
        formattedMessage.originalTimestamp = -1*originalReverseTimestamp
  
        return formattedMessage
    }
    
    func observeBlocked() {
        let userBlockedRef = self.ref.child("userBlocked").child(self.myID)
        userBlockedRef.observe(.value, with: { (snapshot) in
            if let userBlocked = snapshot.value as? [String:Any] {
                let blockedByDict = userBlocked["blockedBy"] as? [String:Bool] ?? [:]
                let blockedBy = Array(blockedByDict.keys)
                self.amIBlocked = blockedBy.contains(self.userID)
                
                let blockedDict = userBlocked["blocked"] as? [String:Bool] ?? [:]
                let blocked = Array(blockedDict.keys)
                self.didIBlock = blocked.contains(self.userID)
            }
        })
    }
    
    func removeObserverForBlocked() {
        let userBlockedRef = self.ref.child("userBlocked").child(self.myID)
        userBlockedRef.removeAllObservers()
    }

}
