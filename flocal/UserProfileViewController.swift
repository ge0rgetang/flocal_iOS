//
//  UserProfileViewController.swift
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

class UserProfileViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    // MARK: - Outlets
    
    @IBOutlet weak var notificationLabel: UILabel!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    @IBAction func sendButtonTapped(_ sender: Any) {
        self.writeMessage()
    }
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var topConstraint: NSLayoutConstraint!
    
    // MARK: - Vars
    
    var myID: String = "0"
    var userID: String = "0"
    var handle: String = "0"
    var didIAdd: Bool = false
    
    var profilePicURL: URL?
    var myProfilePicURL: URL?
    var userProfilePicImageView: UIImageView?
    var userBackgroundPicImageView: UIImageView?
    
    var parentSource: String = "default"
    var searchResultsToPass: [User] = []
    
    var postToPass: Post = Post()
    var userInfo: User = User()
    var amIBlocked: Bool = false
    var didIBlock: Bool = false
    var posts: [Post] = []
    
    var postIDToPass: String = "0"
    var imageToPass: UIImage!
    var urlToPass: URL!
    
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
    var settingsButton = UIButton()
    var settingsBarButton = UIBarButtonItem()
    var displayActivity: Bool = false
    var dimView = UIView()

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "Profile"
        self.navigationController?.navigationBar.tintColor = misc.flocalColor
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: misc.flocalColor]
        self.navigationController?.hidesBarsOnSwipe = true

        self.textField.delegate = self
        
        let tapBar = UITapGestureRecognizer(target: self, action: #selector(self.scrollToTop))
        self.navigationController?.navigationBar.addGestureRecognizer(tapBar)
        
        self.refreshControl.addTarget(self, action: #selector(self.observeUserProfile), for: .valueChanged)
        self.tableView.addSubview(self.refreshControl)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.dismissVC), name: Notification.Name("cleanNavigationStack"), object: nil)
        
        self.setDimView()
        self.setTableView()
        self.setRightBarButtons()
        if !(self.parentSource == "added" || self.parentSource == "chatList") {
            self.setSideMenu()
        }
        
        self.myID = misc.setMyID()
        if self.myID == "0" {
            misc.postToNotificationCenter("turnToLogin")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.portrait)
        self.tableView.reloadData()
        
        if !(self.parentSource == "added" || self.parentSource == "chatList") {
            misc.setSideMenuIndex(42)
        }
        if self.userID != "0" {
            self.downloadUserProfilePic()
            self.downloadUserBackgroundPic()
            self.downloadProfilePicURL()
            self.downloadMyProfilePicURL()
        } else {
            self.navigationController?.popViewController(animated: false)
        }
        self.logViewUserProfile()
        self.setNotifications()
        self.setInfo()
        self.observeBlocked()
        misc.observeLastNotificationType(self.notificationLabel, button: self.notificationButton, color: "default")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.setTableTop(self.amIBlocked)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
        let chatID = misc.setChatID(self.myID, userID: self.userID)
        misc.writeAmITyping(false, chatID: chatID, myID: self.myID)
        self.removeNotifications()
        self.removeObserverForUserProfile()
        self.removeObserverForBlocked()
        misc.removeNotificationTypeObserver()
        self.dimBackground(false)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.removeObserverForUserProfile()
        misc.removeNotificationTypeObserver()
        self.clearArrays()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        NotificationCenter.default.removeObserver(self)
        self.removeObserverForUserProfile()
        misc.removeNotificationTypeObserver()
        misc.clearWebImageCache()
        self.clearArrays()
    }
    
    // MARK: - Tableview
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        default:
            if self.amIBlocked {
                return 0
            } else if self.posts.isEmpty {
                return 1
            } else {
                let count = self.posts.count
                if self.displayActivity {
                    return count + 1
                }
                return count
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            if self.userInfo.userID == "0" {
                let cell = tableView.dequeueReusableCell(withIdentifier: "noUserCell", for: indexPath) as! NoContentTableViewCell
                if self.amIBlocked {
                    cell.noContentLabel.text = "You have been blocked by this person."
                } else {
                    cell.noContentLabel.text = "loading..."
                }
                cell.noContentLabel.numberOfLines = 0
                cell.noContentLabel.sizeToFit()
                cell.noContentLabel.textColor = misc.flocalColor
                return cell
            }
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "userInfoCell", for: indexPath) as! UserInfoTableViewCell
            cell.backgroundColor = .white
            let userInfo = self.userInfo
            
            let handle = userInfo.handle
            cell.handleLabel.text = "@\(handle)"
            
            if let background = self.userBackgroundPicImageView {
                cell.backgroundPicImageView = background
            }
            
            let profConstraints = misc.getProfPicHeight()
            cell.profilePicHeight.constant = profConstraints[0]
            cell.profilePicTopOffsetFromBackground.constant = profConstraints[1]
            cell.handleTopOffset.constant = profConstraints[2]
            
            if let profile = self.userProfilePicImageView {
                cell.profilePicImageView = profile
            } else {
                cell.profilePicImageView.image = self.misc.setDefaultPic(handle)
            }
            cell.profilePicImageView.layer.cornerRadius = cell.profilePicImageView.frame.size.width/2
            cell.profilePicImageView.clipsToBounds = true
            cell.profilePicImageView.layer.borderWidth = 2.5
            cell.profilePicImageView.layer.borderColor = UIColor.white.cgColor
            
            let points = userInfo.points
            let pointsFormatted = misc.setCount(points)
            cell.pointsLabel.text = "\(pointsFormatted) points"
            cell.pointsLabel.textColor = misc.setPointsColor(points, source: "profile")
            
            let followers = userInfo.followersCount
            let followersFormatted = misc.setCount(followers)
            cell.followersLabel.text = "\(followersFormatted) followers"
            cell.followersLabel.textColor = misc.setFollowersColor(followers)
            
            if self.didIAdd {
                cell.addButton.setImage(UIImage(named: "checkS"), for: .normal)
            } else {
                cell.addButton.setImage(UIImage(named: "addS"), for: .normal)
                cell.addButton.tag = indexPath.row
                cell.addButton.addTarget(self, action: #selector(self.addUser), for: .touchUpInside)
            }
            
            let description = userInfo.description
            cell.descriptionLabel.text = description
            cell.descriptionLabel.numberOfLines = 0
            cell.descriptionLabel.sizeToFit()
            
            return cell
            
        default:
            if self.posts.isEmpty {
                let cell = tableView.dequeueReusableCell(withIdentifier: "noUserCell", for: indexPath) as! NoContentTableViewCell
                cell.noContentLabel.text = "This user has no posts."
                cell.noContentLabel.numberOfLines = 0
                cell.noContentLabel.sizeToFit()
                cell.noContentLabel.textColor = misc.flocalColor
                return cell
            }
            
            if self.displayActivity && (indexPath.row == self.posts.count) {
                let cell = tableView.dequeueReusableCell(withIdentifier: "userProfileActivityCell", for: indexPath) as! ActivityTableViewCell
                cell.activityIndicatorView.startAnimating()
                return cell
            }
            
            let post = posts[indexPath.row]
            let type = post.type
            
            var cell: PostTableViewCell
            switch type {
            case "image":
                cell = tableView.dequeueReusableCell(withIdentifier: "imageCell", for: indexPath) as! PostTableViewCell
                cell.playImageView.isHidden = true
                if let postPicURL = post.postPicURL {
                    cell.imagePicImageView.sd_setImage(with: postPicURL) { (image, error, cache, url) in
                        self.misc.setPostImageAspectRatio(cell, image: image)
                    }
                    cell.imagePicImageView.contentMode = .scaleAspectFill
                    let tapImage = UITapGestureRecognizer(target: self, action: #selector(self.presentViewImage))
                    cell.imagePicImageView.addGestureRecognizer(tapImage)
                }
            case "video":
                cell = tableView.dequeueReusableCell(withIdentifier: "imageCell", for: indexPath) as! PostTableViewCell
                cell.playImageView.isHidden = false
                if let postVidPreviewURL = post.postVidPreviewURL {
                    cell.imagePicImageView.sd_setImage(with: postVidPreviewURL) { (image, error, cache, url) in
                        self.misc.setPostImageAspectRatio(cell, image: image)
                    }
                    let tapVid = UITapGestureRecognizer(target: self, action: #selector(self.presentViewVideo))
                    cell.imagePicImageView.addGestureRecognizer(tapVid)
                } else {
                    if let postVidURL = post.postVidURL {
                        let imageTuple = self.generatePreviewImage(postVidURL)
                        cell.imagePicImageView.image = imageTuple.0
                        if imageTuple.1 {
                            cell.imagePicImageView.contentMode = .scaleAspectFill
                        } else {
                            cell.imagePicImageView.contentMode = .scaleAspectFit
                        }
                        self.misc.setPostImageAspectRatio(cell, image: imageTuple.0)
                        let tapVid = UITapGestureRecognizer(target: self, action: #selector(self.presentViewVideo))
                        cell.imagePicImageView.addGestureRecognizer(tapVid)
                    }
                }
            default:
                cell = tableView.dequeueReusableCell(withIdentifier: "postCell", for: indexPath) as! PostTableViewCell
            }
            
            let handle = post.handle
            cell.handleLabel.text = "@\(handle)"
            
            if let profilPicURL = post.profilePicURL {
                cell.profilePicImageView.sd_setImage(with: profilPicURL)
            } else {
                cell.profilePicImageView.image = self.misc.setDefaultPic(handle)
            }
            cell.profilePicImageView.layer.cornerRadius = cell.profilePicImageView.frame.size.width/2
            cell.profilePicImageView.clipsToBounds = true
            
            let points = post.points
            let pointsFormatted = misc.setCount(points)
            cell.pointsLabel.text = pointsFormatted
            
            let voteStatus = post.voteStatus
            switch voteStatus {
            case "up":
                cell.pointsLabel.textColor = misc.flocalOrange
                cell.upvoteButton.setImage(UIImage(named: "upvoteS"), for: .normal)
                cell.downvoteButton.setImage(UIImage(named: "downvote"), for: .normal)
            case "down":
                cell.pointsLabel.textColor = misc.flocalBlueGrey
                cell.upvoteButton.setImage(UIImage(named: "upvote"), for: .normal)
                cell.downvoteButton.setImage(UIImage(named: "downvoteS"), for: .normal)
            default:
                cell.pointsLabel.textColor = misc.flocalColor
                cell.upvoteButton.setImage(UIImage(named: "upvote"), for: .normal)
                cell.downvoteButton.setImage(UIImage(named: "downvote"), for: .normal)
            }
            cell.upvoteButton.addTarget(self, action: #selector(self.upvote), for: .touchUpInside)
            cell.downvoteButton.addTarget(self, action: #selector(self.downvote), for: .touchUpInside)
            
            let content = post.content
            cell.textView.attributedText = misc.stringWithColoredTags(content, time: "default", fontSize: 18, timeSize: 18)
            let tapText = UITapGestureRecognizer(target: self, action: #selector(self.textViewTapped))
            cell.addGestureRecognizer(tapText)
            cell.textView.sizeToFit()
            
            let timestamp = post.timestamp
            cell.timestampLabel.text = timestamp
            
            let replyString = post.replyString
            cell.replyLabel.text = replyString
            cell.replyLabel.textColor = .lightGray
            
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            let cell = tableView.cellForRow(at: indexPath) as! UserInfoTableViewCell
            if self.userInfo.userID != "0" {
                cell.backgroundColor = misc.flocalFade
                self.presentUserSheet()
            }
        default:
            if !self.posts.isEmpty {
                let cell = tableView.cellForRow(at: indexPath) as! PostTableViewCell
                cell.replyLabel.textColor = misc.flocalYellow
                
                let post = posts[indexPath.row]
                self.postToPass = post
                self.presentReply()
            }
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
    
    func setTableTop(_ amIBlocked: Bool) {
        if amIBlocked {
            self.topConstraint.constant = 0
        } else {
            self.topConstraint.constant = 46
        }
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "fromUserProfileToViewImage" {
            if let vc = segue.destination as? ViewImageViewController {
                vc.postID = self.postIDToPass
                vc.parentSource = "post"
                vc.image = self.imageToPass
                vc.picURL = self.urlToPass
                misc.setRotateView(self.imageToPass)
            }
        }
        
        if segue.identifier == "fromUserProfileToViewVideo" {
            if let vc = segue.destination as? ViewVideoViewController {
                vc.postID = self.postIDToPass
                vc.parentSource = "post"
                vc.previewImage = self.imageToPass
                vc.vidURL = self.urlToPass
                misc.setRotateView(self.imageToPass)
            }
        }
        
        if segue.identifier == "fromUserProfileToReply" {
            if let vc = segue.destination as? ReplyViewController {
                vc.parentPost = self.postToPass
                vc.parentSource = "userProfile"
            }
        }
        
        if segue.identifier == "fromUserProfileToReportUser" {
            if let vc = segue.destination as? ReportUserViewController {
                vc.userID = self.userID
            }
        }
    }
    
    @objc func presentViewImage(_ sender: UITapGestureRecognizer) {
        let position = sender.location(in: self.tableView)
        let indexPath: IndexPath! = self.tableView.indexPathForRow(at: position)
        let post = self.posts[indexPath.row]
        
        if let postPicURL = post.postPicURL {
            let imageView = UIImageView()
            imageView.sd_setImage(with: postPicURL)
            self.imageToPass = imageView.image
            self.urlToPass = postPicURL
            self.postIDToPass = post.postID
            self.performSegue(withIdentifier: "fromUserProfileToViewImage", sender: self)
        }
    }
    
    @objc func presentViewVideo(_ sender: UITapGestureRecognizer) {
        let position = sender.location(in: self.tableView)
        let indexPath: IndexPath! = self.tableView.indexPathForRow(at: position)
        let post = self.posts[indexPath.row]
        
        if let postVidURL = post.postVidURL {
            if let postVidPreviewURL = post.postVidPreviewURL {
                let imageView = UIImageView()
                imageView.sd_setImage(with: postVidPreviewURL)
                self.imageToPass = imageView.image
            } else {
                let previewTuple = self.generatePreviewImage(postVidURL)
                self.imageToPass = previewTuple.0
            }
            self.urlToPass = postVidURL
            self.postIDToPass = post.postID
            self.performSegue(withIdentifier: "fromUserProfileToViewVideo", sender: self)
        }
    }
    
    func presentReply() {
        self.performSegue(withIdentifier: "fromUserProfileToReply", sender: self)
    }
    
    @objc func textViewTapped(_ sender: UITapGestureRecognizer) {
        let position = sender.location(in: self.tableView)
        let indexPath: IndexPath! = self.tableView.indexPathForRow(at: position)
        let post = posts[indexPath.row]
        
        if let textView = sender.view as? UITextView {
            let layoutManager = textView.layoutManager
            var position: CGPoint = sender.location(in: textView)
            position.x -= textView.textContainerInset.left
            position.y -= textView.textContainerInset.top
            
            let charIndex = layoutManager.characterIndex(for: position, in: textView.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
            if charIndex < textView.textStorage.length {
                let attributeName = "tappedWord"
                let attributeValue = textView.attributedText.attribute(NSAttributedStringKey(rawValue: attributeName), at: charIndex, effectiveRange: nil) as? String
                
                if let tappedWord = attributeValue {
                    if tappedWord.characters.first == "@" {
                        let handleNoAt = misc.handlesWithoutAt(tappedWord)
                        if let handle = handleNoAt.first {
                            self.misc.doesUserExist(handle) { doesUserExist in
                                let handleLower = handle.lowercased()
                                if let myHandle = UserDefaults.standard.string(forKey: "handle.flocal") {
                                    if (myHandle.lowercased() != handleLower) && (self.handle.lowercased() != handleLower) && (doesUserExist) {
                                        self.removeObserverForUserProfile()
                                        self.handle = handle
                                        self.userID = "0"
                                        self.setInfo()
                                    }
                                } else {
                                    self.misc.getHandle(self.myID) { myHandle in
                                        if (myHandle.lowercased() != handleLower) && (self.handle.lowercased() != handleLower) && (doesUserExist) {
                                            self.removeObserverForUserProfile()
                                            self.handle = handle
                                            self.userID = "0"
                                            self.setInfo()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    if tappedWord.characters.first == "." {
                        print(".nativ")
                    }
                    
                } else {
                    self.postToPass = post
                    self.presentReply()
                }
            }
        }
    }
    
    @objc func presentUserSheet() {
        self.settingsButton.isSelected = true 
        let indexPath = IndexPath(row: 0, section: 0)
        let cell = self.tableView.cellForRow(at: indexPath) as! UserInfoTableViewCell
        
        let sheetController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        if self.didIBlock {
            let unblockAction = UIAlertAction(title: "Unblock", style: .default, handler: { action in
                self.settingsButton.isSelected = false
                cell.backgroundColor = .white
                self.unblockUser()
            })
            sheetController.addAction(unblockAction)
            
        } else {
            if !self.amIBlocked {
                if self.didIAdd {
                    let unfollowAction = UIAlertAction(title: "Remove from Added", style: .default, handler: { action in
                        self.settingsButton.isSelected = false
                        cell.backgroundColor = .white
                        self.removeAddedUser()
                    })
                    sheetController.addAction(unfollowAction)
                }
                
                let blockAction = UIAlertAction(title: "Block", style: .default, handler: { action in
                    self.settingsButton.isSelected = false
                    cell.backgroundColor = .white
                    self.blockUser()
                })
                sheetController.addAction(blockAction)
            }
        }
        
        let reportUserAction = UIAlertAction(title: "Report User", style: .default, handler: { action in
            self.settingsButton.isSelected = false
            self.performSegue(withIdentifier: "fromUserProfileToReportUser", sender: self)
        })
        sheetController.addAction(reportUserAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
            self.settingsButton.isSelected = false
            cell.backgroundColor = .white
        })
        sheetController.addAction(cancelAction)
        
        sheetController.view.tintColor = misc.flocalColor
        DispatchQueue.main.async(execute: {
            self.present(sheetController, animated: true, completion: nil)
        })
    }

    // MARK: - Side Menus
    
    func setSideMenu() {
        if let sideMenuNavigationController = storyboard?.instantiateViewController(withIdentifier: "SideMenuNavigationController") as? UISideMenuNavigationController {
            if let vc = sideMenuNavigationController.topViewController as? SideMenuViewController {
                if self.parentSource == "sideMenu" {
                    vc.searchResults = self.searchResultsToPass
                    vc.isSearchActive = true 
                }
            }
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
            
            self.notificationButton.setImage(UIImage(named: "notificationS"), for: .normal)
            self.notificationButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            self.notificationButton.addTarget(self, action: #selector(self.presentNotificationMenu), for: .touchUpInside)
            self.notificationBarButton.customView = self.notificationButton
            
            self.settingsButton.setImage(UIImage(named: "settingsS"), for: .normal)
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
        if !self.isRemoved {
            self.removeObserverForUserProfile()
        }
        
        let offset = scrollView.contentOffset.y
        let frameHeight = scrollView.frame.size.height
        let contentHeight = scrollView.contentSize.height
        let bottomPoint = CGPoint(x: scrollView.contentOffset.x, y: contentHeight - frameHeight)

        let posts = self.posts
        
        if offset <= 42 {
            self.scrollPosition = "top"
            self.observeUserProfile()
        } else if offset == (contentHeight - frameHeight) {
            self.scrollPosition = "bottom"
            if posts.count >= 8 {
                self.displayActivity = true
                self.tableView.reloadData()
                scrollView.setContentOffset(bottomPoint, animated: true)
                self.observeUserProfile()
            }
        } else {
            self.scrollPosition = "middle"
        }
        
        // prefetch images on scroll down
        if !posts.isEmpty {
            if self.lastContentOffset < scrollView.contentOffset.y {
                let visibleCells = self.tableView.visibleCells
                if let lastCell = visibleCells.last {
                    let lastIndexPath = self.tableView.indexPath(for: lastCell)
                    let lastRow = lastIndexPath!.row
                    var nextLastRow = lastRow + 5
                    
                    let maxCount = posts.count
                    if nextLastRow > (maxCount - 1) {
                        nextLastRow = maxCount - 1
                    }
                    
                    if nextLastRow <= lastRow {
                        nextLastRow = lastRow
                    }
                    
                    var urlsToPrefetch: [URL] = []
                    for index in lastRow...nextLastRow {
                        let post = posts[index]
                        let type = post.type
                        
                        if let profilePicURL = post.profilePicURL {
                            urlsToPrefetch.append(profilePicURL)
                        }
                        
                        if type == "image" {
                            if let postPicURL = post.postPicURL {
                                urlsToPrefetch.append(postPicURL)
                            }
                        }
                        
                        if type == "video" {
                            if let postVidPreviewURL = post.postVidPreviewURL{
                                urlsToPrefetch.append(postVidPreviewURL)
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
    
    // MARK: - TextField
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        let chatID = misc.setChatID(self.myID, userID: self.userID)
        misc.writeAmITyping(true, chatID: chatID, myID: self.myID)
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }
        let length = text.characters.count + string.characters.count - range.length
        return length <= 255
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        let chatID = misc.setChatID(self.myID, userID: self.userID)
        misc.writeAmITyping(false, chatID: chatID, myID: self.myID)
    }

    // MARK: - Keyboard
    
    func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    @objc func keyboardWillShow(_ notification: Notification) {
        self.scrollToTop()
        self.dimBackground(true)
    }
    
    @objc func keyboardDidHide(_ notification: Notification) {
        self.dimBackground(false)
    }
    
    // MARK: - Misc
    
    func displayAlert(_ alertTitle: String, alertMessage: String) {
        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        alertController.view.tintColor = misc.flocalColor
        DispatchQueue.main.async(execute: {
            self.displayActivity = false
            self.refreshControl.endRefreshing()
            self.present(alertController, animated: true, completion: nil)
        })
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
    
    func clearArrays() {
        self.posts = []
    }
    
    func setDimView() {
        self.dimView.isUserInteractionEnabled = false
        self.dimView.backgroundColor = .black
        self.dimView.alpha = 0
        self.dimView.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.height)
        self.view.addSubview(self.dimView)
    }
    
    func dimBackground(_ bool: Bool) {
        if bool {
            self.dimView.alpha = 0.25
        } else {
            self.dimView.alpha = 0
        }
    }
    
    // MARK: - Notification Center
    
    func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.observeUserProfile), name: Notification.Name("addFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.removeObserverForUserProfile), name: Notification.Name("removeFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.scrollToTop), name: Notification.Name("scrollToTop"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow(_:)), name: Notification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardDidHide(_:)), name: Notification.Name.UIKeyboardDidHide, object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name("addFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("removeFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("scrollToTop"), object: nil)
        
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIKeyboardDidHide, object: nil)
    }
    
    @objc func dismissVC() {
        self.navigationController?.dismiss(animated: true, completion: nil)
        self.dismiss(animated: true, completion: nil)
        self.navigationController?.popToRootViewController(animated: false)
    }
    
    // MARK: - Analytics
    
    func logViewUserProfile() {
        Analytics.logEvent("viewUserProfile_iOS", parameters: [
            "myID": self.myID as NSObject,
            "userID": self.userID as NSObject
            ])
    }
    
    func logChatSent(_ userID: String) {
        let chatID = misc.setChatID(self.myID, userID: userID)
        Analytics.logEvent("sentChatText_iOS", parameters: [
            "myID": self.myID as NSObject,
            "userID": userID as NSObject,
            "chatID": chatID as NSObject
            ])
    }
    
    func logAddedUser(_ addedID: String) {
        Analytics.logEvent("addedUser_iOS", parameters: [
            "myID": self.myID as NSObject,
            "userID": addedID as NSObject
            ])
    }
    
    func logRemovedAddedUser(_ addedID: String) {
        Analytics.logEvent("removedAddedUser_iOS", parameters: [
            "myID": self.myID as NSObject,
            "userID": addedID as NSObject
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
    
    func logUpvoted(_ userID: String, postID: String) {
        Analytics.logEvent("upvotedPost_iOS", parameters: [
            "myID": self.myID as NSObject,
            "userID": userID as NSObject,
            "postID": postID as NSObject
            ])
    }
    
    func logDownvoted(_ userID: String, postID: String) {
        Analytics.logEvent("downvotedPost_iOS", parameters: [
            "myID": self.myID as NSObject,
            "userID": userID as NSObject,
            "postID": postID as NSObject
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
                let imageView = UIImageView()
                imageView.sd_setImage(with: url, placeholderImage: nil, options: SDWebImageOptions.refreshCached)
            }
        }
    }
    
    func downloadMyProfilePicURL() {
        let myProfilePicRef = self.storageRef.child("profilePic/\(self.myID)_large.jpg")
        myProfilePicRef.downloadURL { url, error in
            if let error = error {
                print(error.localizedDescription)
            } else {
                self.myProfilePicURL = url
            }
        }
    }
    
    func downloadUserProfilePic() {
        let profilePicRef = self.storageRef.child("profilePic/\(self.userID)_large.jpg")
        profilePicRef.downloadURL { url, error in
            if let error = error {
                print(error.localizedDescription)
            } else {
                self.userProfilePicImageView?.sd_setImage(with: url, placeholderImage: nil, options: SDWebImageOptions.refreshCached)
                self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
            }
        }
    }
    
    func downloadUserBackgroundPic() {
        let backgroundPicRef = self.storageRef.child("backgroundPic/\(self.userID).jpg")
        backgroundPicRef.downloadURL { url, error in
            if let error = error {
                print(error.localizedDescription)
            } else {
                self.userBackgroundPicImageView?.sd_setImage(with: url, placeholderImage: nil, options: SDWebImageOptions.refreshCached)
                self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
            }
        }
    }

    // MARK - Firebase
    
    func setInfo() {
        self.setIDFromHandle()
        misc.didIAdd(self.userID, myID: self.myID) { didIAdd in
            self.didIAdd = didIAdd
        }
        self.observeUserProfile()
    }
    
    func setIDFromHandle() {
        if self.userID == "0" && self.handle != "0" {
            let handleLower = self.handle.lowercased()
            let userRef = self.ref.child("users")
            
            userRef.queryOrdered(byChild: "handleLower").queryEqual(toValue: handleLower).observeSingleEvent(of: .value, with: { snapshot in
                if let dict = snapshot.value as? [String:Any] {
                    if let uid = dict.first?.key  {
                        self.userID = uid
                        self.downloadUserProfilePic()
                        self.downloadUserBackgroundPic()
                        self.downloadProfilePicURL()
                        self.downloadMyProfilePicURL()
                    }
                } else {
                    self.displayAlert("Wrong Handle", alertMessage: "This handle does not exist.")
                }
            })
        }
    }
    
    @objc func observeUserProfile() {
        self.removeObserverForUserProfile()
        self.isRemoved = false

        let userRef = self.ref.child("users").child(self.userID)
        userRef.observe(.value, with: { (snapshot) -> Void in
            if let dict = snapshot.value as? [String:Any] {
                let formattedInfo = self.formatUserInfo(dict)
                self.userInfo = formattedInfo
                self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
            }
        })
        
        if self.scrollPosition == "middle" && !self.posts.isEmpty {
            if let visiblePaths = self.tableView.indexPathsForVisibleRows {
                for indexPath in visiblePaths {
                    let postID = self.posts[indexPath.row].postID
                    let postRef = self.ref.child("posts").child(postID)
                    postRef.observeSingleEvent(of: .value, with: { (snapshot) -> Void in
                        if let post = snapshot.value as? [String:Any] {
                            let isDeleted = post["isDeleted"] as? Bool ?? false
                            
                            self.misc.getVoteStatus(postID, replyID: nil, myID: self.myID) { voteStatus in
                                if !isDeleted {
                                    let formattedPost = self.misc.formatPost(postID, voteStatus: voteStatus, post: post)
                                    self.posts[indexPath.row] = formattedPost
                                }
                            }
                        }
                    })
                }
                self.displayActivity = false
                self.tableView.reloadRows(at: visiblePaths, with: .none)
            }
            
        } else {
            var reverseTimestamp: TimeInterval
            let currentReverseTimestamp = misc.getCurrentReverseTimestamp()
            let lastReverseTimestamp = self.posts.last?.originalReverseTimestamp
            let lastPostID = self.posts.last?.postID
            
            if self.scrollPosition == "bottom" {
                reverseTimestamp = lastReverseTimestamp ?? currentReverseTimestamp
            } else {
                reverseTimestamp = currentReverseTimestamp
            }
            
            let userPostHistoryRef = self.ref.child("userPostHistory").child(self.userID)
            userPostHistoryRef.queryOrderedByValue().queryStarting(atValue: reverseTimestamp).queryLimited(toFirst: 88).observe(.value, with: { (snapshot) -> Void in
                
                let dict = snapshot.value as? [String:Double] ?? [:]
                let postIDs: [String] = Array(dict.keys)
                
                var uPosts: [Post] = []
                for postID in postIDs {
                    let postRef = self.ref.child("posts").child(postID)
                    postRef.observeSingleEvent(of: .value, with: { (snapshot) in
                        if let post = snapshot.value as? [String:Any] {
                            let isDeleted = post["isDeleted"] as? Bool ?? false
                            
                            self.misc.getVoteStatus(postID, replyID: nil, myID: self.myID) { voteStatus in
                                if !isDeleted {
                                    let formattedPost = self.misc.formatPost(postID, voteStatus: voteStatus, post: post)
                                    uPosts.append(formattedPost)
                                }
                            }
                        }
                    })
                }
                
                if self.scrollPosition == "bottom" {
                    if (lastPostID != uPosts.last?.postID) {
                        self.posts.append(contentsOf: uPosts)
                    }
                } else {
                    self.posts = uPosts
                }
                self.displayActivity = false
                self.tableView.reloadData()
            })
            self.refreshControl.endRefreshing()
        }
    }
    
    @objc func removeObserverForUserProfile() {
        self.isRemoved = true
        
        let userRef = self.ref.child("users").child(self.userID)
        userRef.removeAllObservers()
        
        
        let userPostHistoryRef = self.ref.child("userPostHistory").child(self.userID)
        userPostHistoryRef.removeAllObservers()
    }
    
    func writeMessage() {
        self.dismissKeyboard()
        
        if self.amIBlocked {
            self.displayAlert("Blocked", alertMessage: "You cannot send messages to this person.")
            return
        }
        
        if self.userID != "0" {
            let text = self.textField.text
            if text == "" {
                self.displayAlert("Empty Message", alertMessage: "Please type in text to send.")
                return
            }
            
            if let handle = UserDefaults.standard.string(forKey: "handle.flocal") {
                self.setChat(handle, content: text!)
            } else {
                self.misc.getHandle(self.myID) { myHandle in
                    UserDefaults.standard.set(myHandle, forKey: "handle.flocal")
                    UserDefaults.standard.synchronize()
                    self.setChat(myHandle, content: text!)
                }
            }
            
        } else {
            self.displayAlert("Message Error", alertMessage: "We encountered an error trying to send your message. Please report this bug if it continues.")
            return
        }
    }
    
    func setChat(_ handle: String, content: String) {
        let timestamp = misc.getTimestamp("UTC", date: Date())
        let originalReverseTimestamp = misc.getCurrentReverseTimestamp()
        let originalTimestamp = -1*originalReverseTimestamp
        
        var chat: [String:Any] = ["userID": self.myID, "handle": handle, "timestamp": timestamp, "originalReverseTimestamp": originalReverseTimestamp, "originalTimestamp": originalTimestamp, "message": content, "type": "text"]
        
        let chatID = misc.setChatID(self.myID, userID: self.userID)
        let chatRef = self.ref.child("chats").child(chatID)
        let messageRef = chatRef.child("messages").childByAutoId()
        let messageID = messageRef.key
        
        messageRef.setValue(chat)
        misc.playSound("sent_chat.wav", start: 0)
        misc.writeAmITyping(false, chatID: chatID, myID: self.myID)
        
        chat["messageID"] = messageID
        
        let userChatListRef = self.ref.child("userChatList").child(self.userID).child(chatID)
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
                self.misc.writeChatNotification(self.userID, myID: self.myID, message: content, type: "text")
            }
        })
        
        let myChatListRef = self.ref.child("userChatList").child(self.myID).child(chatID)
        var profilePicURLString = "error"
        if self.profilePicURL != nil {
            profilePicURLString = self.profilePicURL!.absoluteString
        }
        chat["profilePicURLString"] = profilePicURLString
        chat["userID"] = self.userID
        chat["handle"] = self.userInfo.handle
        myChatListRef.setValue(chat)
        
        self.logChatSent(self.userID)
        self.textField.text = ""
    }
    
    @objc func addUser() {
        if !self.amIBlocked {
            misc.playSound("added_sound.wav", start: 0)
            self.didIAdd = true
            self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
            
            misc.addUser(self.userID, myID: self.myID)
            misc.writeAddedNotification(self.userID, myID: self.myID)
            self.logAddedUser(self.userID)
        } else {
            self.displayAlert("Blocked", alertMessage: "This person has blocked you. You cannot add them.")
            return
        }
    }
    
    func removeAddedUser() {
        let userRef = self.ref.child("users")
        let userAddedRef = self.ref.child("userAdded")
        let userFollowersRef = self.ref.child("userFollowers")
        
        userAddedRef.child(self.myID).child(self.userID).removeValue()
        userFollowersRef.child(self.userID).child(self.myID).removeValue()
        
        self.didIAdd = false
        self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
        
        var updatedFollowersCount: Int = 0
        userRef.runTransactionBlock({ (currentData:MutableData) -> TransactionResult in
            if var user = currentData.value as? [String:Any] {
                var followersCount = user["followersCount"] as? Int ?? 0
                followersCount -= 1
                updatedFollowersCount = followersCount
                user["followersCount"] = followersCount as AnyObject?
                currentData.value = user
                return TransactionResult.success(withValue: currentData)
            }
            return TransactionResult.success(withValue: currentData)
        })
        
        self.misc.getFollowers(self.userID) { userFollowers in
            if !userFollowers.isEmpty {
                var fanoutObject: [String:Any] = [:]
                for followerID in userFollowers {
                    fanoutObject["/\(followerID)/\(self.userID)/followersCount"] = updatedFollowersCount
                }
                userAddedRef.updateChildValues(fanoutObject)
            }
        }
        
        self.logRemovedAddedUser(self.userID)
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
        
        let chatID = misc.setChatID(self.myID, userID: self.userID)
        let userChatListRef = self.ref.child("userChatList")
        userChatListRef.child(self.myID).child(chatID).removeValue()
        userChatListRef.child(self.userID).child(chatID).removeValue()

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
    
    @objc func upvote(_ sender: UIButton) {
        if let cell = sender.superview?.superview as? PostTableViewCell {
            let indexPath = self.tableView.indexPath(for: cell)!
            let posts = self.posts
            var individualPost = posts[indexPath.row]
            
            let postID = individualPost.postID
            let userID = individualPost.userID
            let content = individualPost.content
            let voteStatus = individualPost.voteStatus
            
            switch voteStatus {
            case "up":
                individualPost.points -= 1
            case "down":
                individualPost.points += 2
            default:
                individualPost.points += 1
            }
            individualPost.voteStatus = "up"
            misc.playSound("pop_drip.wav", start: 0)
            self.posts[indexPath.row] = individualPost
            self.tableView.reloadRows(at: [indexPath], with: .none)

            if !self.amIBlocked {
                misc.upvote(postID, myID: self.myID, userID: userID, voteStatus: voteStatus, content: content)
                self.logUpvoted(userID, postID: postID)
            } else {
                individualPost.voteStatus = "none"
                self.posts[indexPath.row] = individualPost
                self.tableView.reloadRows(at: [indexPath], with: .none)
                self.displayAlert("Blocked", alertMessage: "This person has blocked you. You cannot vote on their posts.")
                return
            }
        }
    }
    
    @objc func downvote(_ sender: UIButton) {
        if let cell = sender.superview?.superview as? PostTableViewCell {
            let indexPath = self.tableView.indexPath(for: cell)!
            let posts = self.posts
            var individualPost = posts[indexPath.row]
            
            let postID = individualPost.postID
            let userID = individualPost.userID
            let voteStatus = individualPost.voteStatus
            
            switch voteStatus {
            case "up":
                individualPost.points -= 2
            case "down":
                individualPost.points += 1
            default:
                individualPost.points -= 1
            }
            individualPost.voteStatus = "down"
            self.posts[indexPath.row] = individualPost
            self.tableView.reloadRows(at: [indexPath], with: .none)
            
            if !self.amIBlocked {
                misc.downvote(postID, myID: self.myID, userID: userID, voteStatus: voteStatus)
                self.logDownvoted(userID, postID: postID)
            } else {
                individualPost.voteStatus = "none"
                self.posts[indexPath.row] = individualPost
                self.tableView.reloadRows(at: [indexPath], with: .none)
                self.displayAlert("Blocked", alertMessage: "This person has blocked you. You cannot vote on their posts.")
                return
            }
        }
    }
    
    func formatUserInfo(_ userInfo: [String:Any]) -> User {
        var user = User()
        
        user.handle = userInfo["handle"] as? String ?? "error"
        user.points = userInfo["points"] as? Int ?? 0
        user.followersCount = userInfo["followersCount"] as? Int ?? 0
        user.description = userInfo["description"] as? String ?? "error"
        
        return user
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
