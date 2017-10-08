//
//  ReplyViewController.swift
//  flocal
//
//  Created by George Tang on 6/18/17.
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

class ReplyViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIPopoverPresentationControllerDelegate {
    
    // MARK: - Outlets

    @IBOutlet weak var containerBottom: NSLayoutConstraint!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var sortSegmentedControl: UISegmentedControl!
    @IBOutlet weak var notificationLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: - Vars
    
    var myID: String = "0"

    var parentPost: Post = Post()
    var postID: String = "0"
    var parentSource: String = "default"
    var parentPath: IndexPath = IndexPath(row: 0, section: 0)
    
    var orderedReplies: [Reply] = []
    var topReplies: [Reply] = []
    var newestReplies: [Reply] = []
    var blockedBy: [String] = []
    
    var userIDToPass: String = "0"
    var handleToPass: String = "0"
    var fromHandle: Bool = false
    
    var imageVideoTypeToPass: String = "image"
    var imageToPass: UIImage!
    var urlToPass: URL!
    
    var replyIDToPass: String = "0"

    var scrollPosition: String = "top"
    var isRemoved: Bool = false
    var lastContentOffset: CGFloat = 0
    
    var ref = Database.database().reference()
    let storageRef = Storage.storage().reference()
    
    let misc = Misc()
    var dimView = UIView()
    var dimViewSeg = UIView()
    var refreshControl = UIRefreshControl()
    var writeReplyVC: ReplyPostViewController?
    var sideMenuButton = UIButton()
    var sideMenuBarButton = UIBarButtonItem()
    var notificationButton = UIButton()
    var notificationBarButton = UIBarButtonItem()
    var settingsButton = UIButton()
    var settingsBarButton = UIBarButtonItem()
    var displayActivity: Bool = false

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = "Comments"
        self.navigationController?.navigationBar.tintColor = misc.flocalYellow
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: misc.flocalYellow]
        self.navigationController?.hidesBarsOnSwipe = true

        let tapBar = UITapGestureRecognizer(target: self, action: #selector(self.scrollToTop))
        self.navigationController?.navigationBar.addGestureRecognizer(tapBar)
        
        self.refreshControl.addTarget(self, action: #selector(self.observeReplies), for: .valueChanged)
        self.tableView.addSubview(self.refreshControl)
        
        self.sortSegmentedControl.addTarget(self, action: #selector(self.sortSegmentDidChange), for: .valueChanged)
        self.sortSegmentedControl.layer.borderWidth = 1.5
        self.sortSegmentedControl.layer.borderColor = misc.flocalYellow.cgColor
        
        if (self.parentSource == "home" || self.parentSource == "userProfile") && self.parentPost.postID != "0" {
            self.postID = self.parentPost.postID
            self.sortSegmentedControl.selectedSegmentIndex = 0
        } else {
            let postID = UserDefaults.standard.string(forKey: "postIDToPass.flocal") ?? self.postID
            self.postID = postID
            self.sortSegmentedControl.selectedSegmentIndex = 2 
            self.setSideMenu()
        }
        
        self.setTableView()
        self.setRightBarButtons()
        self.setDimView()
        self.setPermanentNotifications()
        self.containerView.isHidden = true
        
        self.myID = misc.setMyID()
        if self.myID == "0" {
            misc.postToNotificationCenter("turnToLogin")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.portrait)
        self.tableView.reloadData()
        self.checkIfFromPush()
        
        self.logViewReplies()
        if self.parentSource != "home" {
            misc.setSideMenuIndex(42)
        }
        self.setNotifications()
        misc.observeLastNotificationType(self.notificationLabel, button: self.notificationButton, color: "default")
        self.observeReplies()
        self.observeBlocked()
    }

    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
        self.parentSource = "default"
        self.removeNotifications()
        self.removeObserverForReplies()
        self.removeObserverForBlocked()
        misc.removeNotificationTypeObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.removeObserverForReplies()
        misc.removeNotificationTypeObserver()
        self.clearArrays()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        NotificationCenter.default.removeObserver(self)
        self.removeObserverForReplies()
        misc.removeNotificationTypeObserver()
        misc.clearWebImageCache()
        self.clearArrays()
    }
    
    override func viewDidLayoutSubviews() {
        let attr = NSDictionary(object: UIFont.systemFont(ofSize: 16), forKey: NSAttributedStringKey.font as NSCopying)
        self.sortSegmentedControl.setTitleTextAttributes(attr as [NSObject:AnyObject], for: .normal)
    }

    // MARK: - Tableview
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0, 1:
            return 1
        default:
            let replies = self.determineReplies()
            
            if replies.isEmpty {
                return 1
            } else {
                let count = replies.count
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
            if self.parentPost.postID == "0" {
                let cell = tableView.dequeueReusableCell(withIdentifier: "noReplyCell", for: indexPath) as! NoContentTableViewCell
                cell.backgroundColor = .white
                cell.noContentLabel.textColor = misc.flocalColor 
                cell.noContentLabel.text = "loading..."
                cell.noContentLabel.numberOfLines = 0
                cell.noContentLabel.sizeToFit()
                return cell
            }
            
            var cell: PostTableViewCell
            let type = self.parentPost.type
            
            switch type {
            case "image":
                cell = tableView.dequeueReusableCell(withIdentifier: "imageParentCell", for: indexPath) as! PostTableViewCell
                cell.playImageView.isHidden = true
                if let postPicURL = self.parentPost.postPicURL {
                    cell.imagePicImageView.sd_setImage(with: postPicURL) { (image, error, cache, url) in
                        self.misc.setPostImageAspectRatio(cell, image: image)
                    }
                    let tapImage = UITapGestureRecognizer(target: self, action: #selector(self.presentViewVideo))
                    cell.imagePicImageView.addGestureRecognizer(tapImage)
                }
            case "video":
                cell = tableView.dequeueReusableCell(withIdentifier: "imageParentCell", for: indexPath) as! PostTableViewCell
                cell.playImageView.isHidden = false
                if let postVidPreviewURL = self.parentPost.postVidPreviewURL {
                    cell.imagePicImageView.sd_setImage(with: postVidPreviewURL) { (image, error, cache, url) in
                        self.misc.setPostImageAspectRatio(cell, image: image)
                    }
                    let tapVid = UITapGestureRecognizer(target: self, action: #selector(self.presentViewVideo))
                    cell.imagePicImageView.addGestureRecognizer(tapVid)
                } else {
                    if let postVidURL = self.parentPost.postVidURL {
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
                cell = tableView.dequeueReusableCell(withIdentifier: "postParentCell", for: indexPath) as! PostTableViewCell
            }
            
            cell.backgroundColor = .white
            
            let handle = self.parentPost.handle
            cell.handleLabel.text = "@\(handle)"
            let tapHandle = UITapGestureRecognizer(target: self, action: #selector(self.presentUserProfile))
            cell.handleLabel.addGestureRecognizer(tapHandle)
            
            if let profilPicURL = self.parentPost.profilePicURL {
                cell.profilePicImageView.sd_setImage(with: profilPicURL)
            } else {
                cell.profilePicImageView.image = self.misc.setDefaultPic(handle)
            }
            cell.profilePicImageView.layer.cornerRadius = cell.profilePicImageView.frame.size.width/2
            cell.profilePicImageView.clipsToBounds = true
            let tapPic = UITapGestureRecognizer(target: self, action: #selector(self.presentUserProfile))
            cell.profilePicImageView.addGestureRecognizer(tapPic)
            
            let points = self.parentPost.points
            let pointsFormatted = misc.setCount(points)
            cell.pointsLabel.text = pointsFormatted
            
            let voteStatus = self.parentPost.voteStatus
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
                cell.pointsLabel.textColor = misc.setPointsColor(points, source: "post")
                cell.upvoteButton.setImage(UIImage(named: "upvote"), for: .normal)
                cell.downvoteButton.setImage(UIImage(named: "downvote"), for: .normal)
            }
            cell.upvoteButton.addTarget(self, action: #selector(self.upvote), for: .touchUpInside)
            cell.downvoteButton.addTarget(self, action: #selector(self.downvote), for: .touchUpInside)
            
            let content = self.parentPost.content
            cell.textView.attributedText = misc.stringWithColoredTags(content, time: "default", fontSize: 18, timeSize: 18)
            let tapText = UITapGestureRecognizer(target: self, action: #selector(self.textViewTapped))
            cell.addGestureRecognizer(tapText)
            cell.textView.sizeToFit()
            
            let timestamp = self.parentPost.timestamp
            cell.timestampLabel.text = timestamp
            
            let replyString = self.parentPost.replyString
            cell.replyLabel.text = replyString
            cell.replyLabel.textColor = misc.flocalYellow
            
            return cell
            
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "writeReplyCell", for: indexPath) as! WritePostTableViewCell
            cell.backgroundColor = .white
            return cell
            
        default:
            let replies = self.determineReplies()
            
            if replies.isEmpty {
                let cell = tableView.dequeueReusableCell(withIdentifier: "noReplyCell", for: indexPath) as! NoContentTableViewCell
                cell.backgroundColor = .white
                cell.noContentLabel.numberOfLines = 0
                cell.noContentLabel.sizeToFit()
                cell.noContentLabel.textColor = misc.flocalYellow
                cell.noContentLabel.text = "No comments yet. Be the first!"
                return cell
            }
            
            if self.displayActivity && (indexPath.row == replies.count) {
                let cell = tableView.dequeueReusableCell(withIdentifier: "replyActivityCell", for: indexPath) as! ActivityTableViewCell
                cell.activityIndicatorView.startAnimating()
                return cell
            }
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "replyCell", for: indexPath) as! PostTableViewCell
            cell.backgroundColor = .white
            let reply = replies[indexPath.row]
            
            let handle = reply.handle
            let timestamp = reply.timestamp
            let handleLabelText = "@\(handle) \(timestamp)"
            cell.handleLabel.attributedText = misc.stringWithColoredTags(handleLabelText, time: timestamp, fontSize: 18, timeSize: 14)
            
            let tapHandle = UITapGestureRecognizer(target: self, action: #selector(self.presentUserProfile))
            cell.handleLabel.addGestureRecognizer(tapHandle)
            
            if let profilPicURL = reply.profilePicURL {
                cell.profilePicImageView.sd_setImage(with: profilPicURL)
            } else {
                cell.profilePicImageView.image = self.misc.setDefaultPic(handle)
            }
            let tapPic = UITapGestureRecognizer(target: self, action: #selector(self.presentUserProfile))
            cell.profilePicImageView.addGestureRecognizer(tapPic)
            
            let points = reply.points
            let pointsFormatted = misc.setCount(points)
            cell.pointsLabel.text = pointsFormatted
            
            let voteStatus = reply.voteStatus
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
                cell.pointsLabel.textColor = misc.setPointsColor(points, source: "post")
                cell.upvoteButton.setImage(UIImage(named: "upvote"), for: .normal)
                cell.downvoteButton.setImage(UIImage(named: "downvote"), for: .normal)
            }
            cell.upvoteButton.addTarget(self, action: #selector(self.upvote), for: .touchUpInside)
            cell.downvoteButton.addTarget(self, action: #selector(self.downvote), for: .touchUpInside)
            
            let content = reply.content
            cell.textView.attributedText = misc.stringWithColoredTags(content, time: "default", fontSize: 18, timeSize: 18)
            let tapText = UITapGestureRecognizer(target: self, action: #selector(self.textViewTapped))
            cell.textView.addGestureRecognizer(tapText)
            cell.textView.sizeToFit()
            
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 1:
            self.presentWriteReply()
        default:
            let cell = tableView.cellForRow(at: indexPath) as! PostTableViewCell
            if indexPath.section == 0 {
                cell.backgroundColor = misc.flocalFade
            } else {
                cell.backgroundColor = misc.flocalYellowFade
            }
            self.parentPath = indexPath
            self.presentActionSheet()
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
    
    @objc func reloadTable() {
        self.tableView.reloadData()
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "fromReplyToViewImage" {
            if let vc = segue.destination as? ViewImageViewController {
                vc.postID = self.postID
                vc.parentSource = "post"
                vc.image = self.imageToPass
                vc.picURL = self.urlToPass
                misc.setRotateView(self.imageToPass)
            }
        }
        
        if segue.identifier == "fromReplyToViewVideo" {
            if let vc = segue.destination as? ViewVideoViewController {
                vc.postID = self.postID
                vc.parentSource = "post"
                vc.previewImage = self.imageToPass
                vc.vidURL = self.urlToPass
                misc.setRotateView(self.imageToPass)
            }
        }
        
        if segue.identifier == "fromReplyToUserProfile" {
            if let vc = segue.destination as? UserProfileViewController {
                if self.fromHandle {
                    vc.handle = self.handleToPass
                } else {
                    vc.userID = self.userIDToPass
                }
            }
        }
        
        if segue.identifier == "fromReplyToReportPost" {
            if let vc = segue.destination as? ReportPostViewController {
                vc.postID = self.postID
                vc.replyID = self.replyIDToPass
                if self.replyIDToPass == "0" {
                    vc.parentSource = "post"
                } else {
                    vc.parentSource = "comment"
                }
            }
        }
    }
    
    func presentViewImage(_ sender: UITapGestureRecognizer) {
        let post = self.parentPost
        
        if let postPicURL = post.postPicURL {
            let imageView = UIImageView()
            imageView.sd_setImage(with: postPicURL)
            self.imageToPass = imageView.image
            self.urlToPass = postPicURL
            self.performSegue(withIdentifier: "fromReplyToViewImage", sender: self)
        }
    }
    
    @objc func presentViewVideo(_ sender: UITapGestureRecognizer) {
        let post = self.parentPost

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
            self.performSegue(withIdentifier: "fromReplyToViewVideo", sender: self)
        }
    }
    
    func presentWriteReply() {
        misc.playSound("button_click.wav", start: 0)
        self.containerView.isHidden = false
        self.containerView.layer.cornerRadius = 10
        self.containerView.layer.masksToBounds = true
        self.writeReplyVC = storyboard?.instantiateViewController(withIdentifier: "ReplyPostViewController") as? ReplyPostViewController
        self.writeReplyVC?.view.frame = self.containerView.bounds
        self.addChildViewController(self.writeReplyVC!)
        self.containerView.addSubview(self.writeReplyVC!.view)
        self.dimBackground(true)
    }
    
    @objc func dismissWriteReplyVC() {
        self.writeReplyVC?.view.removeFromSuperview()
        self.writeReplyVC?.removeFromParentViewController()
        self.writeReplyVC = nil
        self.containerView.isHidden = true
        self.dimBackground(false)
    }
    
    @objc func presentUserProfile(_ sender: UITapGestureRecognizer) {
        let position = sender.location(in: self.tableView)
        let indexPath: IndexPath! = self.tableView.indexPathForRow(at: position)
        
        switch indexPath.section {
        case 0:
            let userID = self.parentPost.userID
            self.prefetchUserProfilePics(userID)
            self.userIDToPass = userID
            self.fromHandle = false
            if self.myID != userID {
                self.performSegue(withIdentifier: "fromReplyToUserProfile", sender: self)
            }
        case 1:
            print("waht")
        default:
            let reply = self.determineReplies()[indexPath.row]
            let userID = reply.userID
            self.prefetchUserProfilePics(userID)
            self.userIDToPass = userID
            self.fromHandle = false
            if self.myID != userID {
                self.performSegue(withIdentifier: "fromReplyToUserProfile", sender: self)
            }
        }
    }
    
    @objc func textViewTapped(_ sender: UITapGestureRecognizer) {
        if let textView = sender.view as? UITextView {
            let layoutManager = textView.layoutManager
            var position: CGPoint = sender.location(in: textView)
            position.x -= textView.textContainerInset.left
            position.y -= textView.textContainerInset.top
            
            let charIndex = layoutManager.characterIndex(for: position, in: textView.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
            if charIndex < textView.textStorage.length {
                let attributeName = "tappedWord"
                let attributeValue = textView.attributedText.attribute(NSAttributedStringKey(attributeName), at: charIndex, effectiveRange: nil) as? String
                
                if let tappedWord = attributeValue {
                    if tappedWord.characters.first == "@" {
                        let handleNoAt = misc.handlesWithoutAt(tappedWord)
                        if let handle = handleNoAt.first {
                            misc.doesUserExist(handle) { doesUserExist in
                                let handleLower = handle.lowercased()
                                if let myHandle = UserDefaults.standard.string(forKey: "handle.flocal") {
                                    if (myHandle.lowercased() != handleLower) && (doesUserExist) {
                                        self.handleToPass = handle
                                        self.fromHandle = true
                                        self.performSegue(withIdentifier: "fromReplyToUserProfile", sender: self)
                                    }
                                } else {
                                    self.misc.getHandle(self.myID) { myHandle in
                                        if (myHandle.lowercased() != handleLower) && (doesUserExist) {
                                            self.handleToPass = handle
                                            self.fromHandle = true
                                            self.performSegue(withIdentifier: "fromReplyToUserProfile", sender: self)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                } else {
                    let indexPath = self.tableView.indexPathForRow(at: position)!
                    let cell = self.tableView.cellForRow(at: indexPath) as! PostTableViewCell
                    if indexPath.section == 0 {
                        cell.backgroundColor = misc.flocalFade
                    } else {
                        cell.backgroundColor = misc.flocalYellowFade
                    }
                    self.parentPath = indexPath
                    self.presentActionSheet()
                }
            }
        }
    }
    
    func presentActionSheet() {
        let indexPath = self.parentPath
        let cell = self.tableView.cellForRow(at: indexPath) as! PostTableViewCell
        
        var type: String
        var userID: String
        var content: String
        if indexPath.section == 0 {
            self.settingsButton.isSelected = true
            type = "parent"
            userID = self.parentPost.userID
            content = self.parentPost.content
        } else {
            let reply = self.determineReplies()[indexPath.row]
            type = "reply"
            let replyID = reply.replyID
            self.replyIDToPass = replyID
            userID = reply.userID
            content = reply.content
        }
        
        let editViewController = storyboard?.instantiateViewController(withIdentifier: "EditViewController") as! EditViewController
        editViewController.modalPresentationStyle = .popover
        editViewController.preferredContentSize = CGSize(width: 320, height: 320)
        editViewController.type = type
        editViewController.textViewText = content
        editViewController.postID = self.postID
        editViewController.replyID = self.replyIDToPass

        if let popoverController = editViewController.popoverPresentationController {
            popoverController.delegate = self
            popoverController.sourceView = cell.contentView
            popoverController.sourceRect = cell.contentView.bounds
            popoverController.permittedArrowDirections = .unknown
        }
        
        let sheetController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if self.myID == userID {
            let editAction = UIAlertAction(title: "Edit", style: .default, handler: { action in
                self.settingsButton.isSelected = false
                self.present(editViewController, animated: true, completion: nil)
            })
            sheetController.addAction(editAction)
            
            let deleteAction = UIAlertAction(title: "Delete", style: .default, handler: { action in
                self.settingsButton.isSelected = false
                if type == "parent" {
                    self.deletePost(nil)
                } else {
                    self.deletePost(self.replyIDToPass)
                }
            })
            sheetController.addAction(deleteAction)
            
        } else {
            let reportAction = UIAlertAction(title: "Report", style: .default, handler: { action in
                self.settingsButton.isSelected = false
                self.performSegue(withIdentifier: "fromReplyToReportPost", sender: self)
            })
            sheetController.addAction(reportAction)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
            self.settingsButton.isSelected = false
        })
        sheetController.addAction(cancelAction)
        
        sheetController.view.tintColor = misc.flocalColor
        DispatchQueue.main.async(execute: {
            self.present(sheetController, animated: true, completion: nil)
        })
    }
        
    // MARK: - Popover
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        self.tableView.reloadData()
        self.observeReplies()
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
            
            self.sideMenuButton.setImage(UIImage(named: "menuYellowS"), for: .normal)
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
            
            self.notificationButton.setImage(UIImage(named: "notificationYellowS"), for: .normal)
            self.notificationButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            self.notificationButton.addTarget(self, action: #selector(self.presentNotificationMenu), for: .touchUpInside)
            self.notificationBarButton.customView = self.notificationButton
            
            self.settingsButton.setImage(UIImage(named: "settingsYellowS"), for: .normal)
            self.settingsButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            self.settingsButton.addTarget(self, action: #selector(self.presentParentOptions), for: .touchUpInside)
            self.settingsBarButton.customView = self.settingsButton
            
            self.navigationItem.setRightBarButtonItems([self.notificationBarButton, self.settingsBarButton], animated: false)
        }
    }
    
    @objc func presentNotificationMenu() {
        misc.playSound("menu_swish.wav", start: 0.322)
        self.present(SideMenuManager.menuRightNavigationController!, animated: true, completion: nil)
    }
    
    @objc func presentParentOptions() {
        self.parentPath = IndexPath(row: 0, section: 0)
        self.presentActionSheet()
    }
    
    // MARK: - Scroll
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !self.isRemoved {
            self.observeReplies()
        }
        
        let offset = scrollView.contentOffset.y
        let frameHeight = scrollView.frame.size.height
        let contentHeight = scrollView.contentSize.height
        let bottomPoint = CGPoint(x: scrollView.contentOffset.x, y: contentHeight - frameHeight)
        
        let replies = self.determineReplies()
        
        if offset <= 42 {
            self.scrollPosition = "top"
            self.observeReplies()
        } else if offset == (contentHeight - frameHeight) {
            self.scrollPosition = "bottom"
            if replies.count >= 8 {
                self.displayActivity = true
                self.reloadTable()
                scrollView.setContentOffset(bottomPoint, animated: true)
                self.observeReplies()
            }
        } else {
            self.scrollPosition = "middle"
        }
        
        // prefetch images on scroll down
        if !replies.isEmpty {
            if self.lastContentOffset < scrollView.contentOffset.y {
                let visibleCells = self.tableView.visibleCells
                if let lastCell = visibleCells.last {
                    let lastIndexPath = self.tableView.indexPath(for: lastCell)
                    let lastRow = lastIndexPath!.row
                    var nextLastRow = lastRow + 5
                    
                    let maxCount = replies.count
                    if nextLastRow > (maxCount - 1) {
                        nextLastRow = maxCount - 1
                    }
                    
                    if nextLastRow <= lastRow {
                        nextLastRow = lastRow
                    }
                    
                    var urlsToPrefetch: [URL] = []
                    for index in lastRow...nextLastRow {
                        let reply = replies[index]
                        
                        if let profilePicURL = reply.profilePicURL {
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
    
    // MARK: - Segmented Controls
    
    @objc func sortSegmentDidChange(_ sender: UISegmentedControl) {
        self.scrollToTop()
        self.observeReplies()
    }
    
    @objc func setReplySegment() {
        self.sortSegmentedControl.selectedSegmentIndex = 0
        self.scrollToTop()
    }
    
    // MARK: - Keyboard
    
    @objc func keyboardWillShow(_ notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            let keyboardHeight = keyboardSize.height
            self.containerBottom.constant = 8 - 35 + keyboardHeight
            UIView.animate(withDuration: 1.0, animations: {
                self.view.layoutIfNeeded()
            })
        }
    }
    
    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            let keyboardHeight = keyboardSize.height
            self.containerBottom.constant = 8 - 35 + keyboardHeight
        }
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        self.containerBottom.constant = 8
        UIView.animate(withDuration: 1.0, animations: {
            self.view.layoutIfNeeded()
        })
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
        self.orderedReplies = []
        self.topReplies = []
        self.newestReplies = []
    }
    
    func determineReplies() -> [Reply] {
        switch self.sortSegmentedControl.selectedSegmentIndex {
        case 1:
            return self.topReplies
        case 2:
            return self.newestReplies
        default:
            return self.orderedReplies
        }
    }
    
    func setDimView() {
        self.dimView.isUserInteractionEnabled = false
        self.dimView.backgroundColor = .black
        self.dimView.alpha = 0
        self.dimView.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.height)
        self.tableView.addSubview(self.dimView)
        
        self.dimViewSeg.isUserInteractionEnabled = false
        self.dimViewSeg.backgroundColor = .black
        self.dimViewSeg.alpha = 0
        self.dimViewSeg.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: 35)
        self.sortSegmentedControl.addSubview(self.dimViewSeg)
    }
    
    func dimBackground(_ bool: Bool) {
        if bool {
            self.dimView.alpha = 0.25
            self.dimViewSeg.alpha = 0.25
        } else {
            self.dimView.alpha = 0
            self.dimViewSeg.alpha = 0
        }
    }
    
    // MARK: - Notification Center
    
    func setPermanentNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.dismissVC), name: Notification.Name("cleanNavigationStack"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.setReplySegment), name: Notification.Name("setReplySegment"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.dismissWriteReplyVC), name: Notification.Name("dismissWriteReplyVC"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow(_:)), name: Notification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillChangeFrame(_:)), name: Notification.Name.UIKeyboardWillChangeFrame, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: Notification.Name.UIKeyboardWillHide, object: nil)
    }
    
    func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.observeReplies), name: Notification.Name("addFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.removeObserverForReplies), name: Notification.Name("removeFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.scrollToTop), name: Notification.Name("scrollToTop"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadTable), name: Notification.Name("reloadTable"), object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name("addFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("removeFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("scrollToTop"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("reloadTable"), object: nil)
    }
    
    func checkIfFromPush() {
        let fromPush = UserDefaults.standard.bool(forKey: "fromPush.flocal")
        if fromPush {
            UserDefaults.standard.set(false, forKey: "fromPush.flocal")
            UserDefaults.standard.synchronize()
            let postID = UserDefaults.standard.string(forKey: "postIDToPass.flocal") ?? "0"
            if postID == "0" {
                self.displayAlert("Post Error", alertMessage: "We could not retrieve the post. Please report this bug.")
                return
            } else {
                self.postID = postID
            }
        }
    }
    
    @objc func dismissVC() {
        self.navigationController?.dismiss(animated: false, completion: nil)
        self.dismiss(animated: true, completion: nil)
        self.navigationController?.popToRootViewController(animated: false)
    }
    
    // MARK: - Analytics
    
    func logViewReplies() {
        var child = "viewOrderedReplies_iOS"
        switch self.sortSegmentedControl.selectedSegmentIndex {
        case 1:
            child = "viewTopReplies_iOS"
        case 2:
            child = "viewNewestReplies_iOS"
        default:
            child = "viewOrderedReplies_iOS"
        }
        Analytics.logEvent(child, parameters: [
            "myID": self.myID as NSObject,
            "postID": self.postID as NSObject
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
    
    func logUpvotedReply(_ userID: String, postID: String, replyID: String) {
        Analytics.logEvent("upvotedReply_iOS", parameters: [
            "myID": self.myID as NSObject,
            "userID": userID as NSObject,
            "postID": postID as NSObject,
            "replyID": replyID as NSObject
            ])
    }
    
    func logDownvotedReply(_ userID: String, postID: String, replyID: String) {
        Analytics.logEvent("downvotedReply_iOS", parameters: [
            "myID": self.myID as NSObject,
            "userID": userID as NSObject,
            "postID": postID as NSObject,
            "replyID": replyID as NSObject
            ])
    }
    
    // MARK: - Storage
    
    func prefetchUserProfilePics(_ userID: String) {
        let backgroundPicRef = self.storageRef.child("backgroundPic/\(userID).jpg")
        backgroundPicRef.downloadURL { url, error in
            if let error = error {
                print(error.localizedDescription)
            } else {
                SDWebImagePrefetcher.shared().prefetchURLs([url!])
            }
        }
        
        let profilePicRef = self.storageRef.child("profilePic/\(userID)_large.jpg")
        profilePicRef.downloadURL { url, error in
            if let error = error {
                print(error.localizedDescription)
            } else {
                SDWebImagePrefetcher.shared().prefetchURLs([url!])
            }
        }
    }
    
    // MARK: - Firebase
    
    @objc func observeReplies() {
        self.removeObserverForReplies()
        self.isRemoved = false
        let postRef = self.ref.child("posts").child(self.postID)
        postRef.observe(.value, with: { (snapshot) -> Void in
            if let post = snapshot.value as? [String:Any] {
                self.misc.getVoteStatus(self.postID, replyID: nil, myID: self.myID) { voteStatus in
                    let formattedPost = self.misc.formatPost(self.postID, voteStatus: voteStatus, post: post)
                    self.parentPost = formattedPost
                    self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
                }
            }
        })
        
        let replies = self.determineReplies()
        
        if self.scrollPosition == "middle" && !replies.isEmpty {
            if let visiblePaths = self.tableView.indexPathsForVisibleRows {
                for indexPath in visiblePaths {
                    let replyID = replies[indexPath.row].replyID
                    let replyRef = self.ref.child("replies").child(replyID)
                    replyRef.observeSingleEvent(of: .value, with: { (snapshot) -> Void in
                        if let reply = snapshot.value as? [String:Any] {
                            let isDeleted = reply["isDeleted"] as? Bool ?? false
                            let reports = reply["reports"] as? Int ?? 0
                            
                            if reports < 3 && !isDeleted {
                                self.misc.getVoteStatus(self.postID, replyID: replyID, myID: self.myID) { voteStatus in
                                    let formattedReply = self.formatReply(replyID, voteStatus: voteStatus, reply: reply)
                                    switch self.sortSegmentedControl.selectedSegmentIndex {
                                    case 1:
                                        self.topReplies[indexPath.row] = formattedReply
                                    case 2:
                                        self.newestReplies[indexPath.row] = formattedReply
                                    default:
                                        self.orderedReplies[indexPath.row] = formattedReply
                                    }
                                }
                            }
                        }
                    })
                }
                self.displayActivity = false
                self.tableView.reloadRows(at: visiblePaths, with: .none)
            }
            
        } else {
            let lastReplyID = replies.last?.replyID
            var repliesArray: [Reply] = []
            let replyRef = self.ref.child("replies").child(self.postID)
            
            switch self.sortSegmentedControl.selectedSegmentIndex {
            case 1:
                if self.scrollPosition == "bottom" {
                    let lastReverseScore = -1*(replies.last?.score ?? 0.0)
                    replyRef.queryOrdered(byChild: "reverseScore").queryStarting(atValue: lastReverseScore).queryLimited(toFirst: 88).observe(.value, with: { (snapshot) -> Void in
                        if let dict = snapshot.value as? [String:Any] {
                            for entry in dict {
                                let replyID = entry.key
                                if let reply = entry.value as? [String:Any] {
                                    let isDeleted = reply["isDeleted"] as? Bool ?? false
                                    let reports = reply["reports"] as? Int ?? 0
                                    
                                    self.misc.getVoteStatus(self.postID, replyID: replyID, myID: self.myID) { voteStatus in
                                        if reports < 3 && !isDeleted {
                                            let formattedReply = self.formatReply(replyID, voteStatus: voteStatus, reply: reply)
                                            repliesArray.append(formattedReply)
                                        }
                                    }
                                }
                            }
                            
                            if lastReplyID != repliesArray.last?.replyID {
                                self.topReplies.append(contentsOf: repliesArray)
                            }
                            self.displayActivity = false
                            self.tableView.reloadData()
                        }
                    })
                } else {
                    replyRef.queryOrdered(byChild: "reverseScore").queryLimited(toFirst: 88).observe(.value, with: { (snapshot) -> Void in
                        if let dict = snapshot.value as? [String:Any] {
                            for entry in dict {
                                let replyID = entry.key
                                if let reply = entry.value as? [String:Any] {
                                    let isDeleted = reply["isDeleted"] as? Bool ?? false
                                    let reports = reply["reports"] as? Int ?? 0
                                    
                                    self.misc.getVoteStatus(self.postID, replyID: replyID, myID: self.myID) { voteStatus in
                                        if reports < 3 && !isDeleted {
                                            let formattedReply = self.formatReply(replyID, voteStatus: voteStatus, reply: reply)
                                            repliesArray.append(formattedReply)
                                        }
                                    }
                                }
                            }
                          
                            self.topReplies = repliesArray
                            self.displayActivity = false
                            self.tableView.reloadData()
                        }
                    })
                }
               
                
            case 2:
                var reverseTimestamp: TimeInterval
                let currentReverseTimestamp = misc.getCurrentReverseTimestamp()
                let lastReverseTimestamp = replies.last?.originalReverseTimestamp
                
                if self.scrollPosition == "bottom" {
                    reverseTimestamp = lastReverseTimestamp ?? currentReverseTimestamp
                } else {
                    reverseTimestamp = currentReverseTimestamp
                }
                
                replyRef.queryOrdered(byChild: "originalReverseTimestamp").queryStarting(atValue: reverseTimestamp).queryLimited(toFirst: 88).observe(.value, with: { (snapshot) -> Void in
                    if let dict = snapshot.value as? [String:Any] {
                        for entry in dict {
                            let replyID = entry.key
                            if let reply = entry.value as? [String:Any] {
                                let isDeleted = reply["isDeleted"] as? Bool ?? false
                                let reports = reply["reports"] as? Int ?? 0
                                
                                self.misc.getVoteStatus(self.postID, replyID: replyID, myID: self.myID) { voteStatus in
                                    if reports < 3 && !isDeleted {
                                        let formattedReply = self.formatReply(replyID, voteStatus: voteStatus, reply: reply)
                                        repliesArray.append(formattedReply)
                                    }
                                }
                            }
                        }
                        
                        if self.scrollPosition == "bottom" {
                            if lastReplyID != repliesArray.last?.replyID {
                                self.newestReplies.append(contentsOf: repliesArray)
                            }
                        } else {
                            self.newestReplies = repliesArray
                        }
                        self.displayActivity = false
                        self.tableView.reloadData()
                    }
                })
                
            default:
                var timestamp: TimeInterval
                let firstReverseTimestamp = self.parentPost.originalReverseTimestamp
                let firstTimestamp = -1*firstReverseTimestamp
                let lastReverseTimestamp = replies.last?.originalReverseTimestamp
                let lastTimestamp = -1*(lastReverseTimestamp ?? firstReverseTimestamp)
                
                if self.scrollPosition == "bottom" {
                    timestamp = lastTimestamp
                } else {
                    timestamp = firstTimestamp
                }
                
                replyRef.queryOrdered(byChild: "originalTimestamp").queryStarting(atValue: timestamp).queryLimited(toFirst: 88).observe(.value, with: { (snapshot) -> Void in
                    if let dict = snapshot.value as? [String:Any] {
                        for entry in dict {
                            let replyID = entry.key
                            if let reply = entry.value as? [String:Any] {
                                let isDeleted = reply["isDeleted"] as? Bool ?? false
                                let reports = reply["reports"] as? Int ?? 0
                                
                                self.misc.getVoteStatus(self.postID, replyID: replyID, myID: self.myID) { voteStatus in
                                    if reports < 3 && !isDeleted {
                                        let formattedReply = self.formatReply(replyID, voteStatus: voteStatus, reply: reply)
                                        repliesArray.append(formattedReply)
                                    }
                                }
                            }
                        }
                        
                        if self.scrollPosition == "bottom" {
                            if lastReplyID != repliesArray.last?.replyID {
                                self.orderedReplies.append(contentsOf: repliesArray)
                            }
                        } else {
                            self.orderedReplies = repliesArray
                        }
                        self.displayActivity = false
                        self.tableView.reloadData()
                    }
                })
            }
            self.refreshControl.endRefreshing()
        }
    }
    
    @objc func removeObserverForReplies() {
        self.isRemoved = true
        
        let postRef = self.ref.child("posts").child(self.postID)
        postRef.removeAllObservers()
        
        let replyRef = self.ref.child("replies").child(self.postID)
        replyRef.removeAllObservers()
    }
    
    @objc func upvote(_ sender: UIButton) {
        if let cell = sender.superview?.superview as? PostTableViewCell {
            let indexPath = self.tableView.indexPath(for: cell)!
            
            var replyID: String
            var userID: String
            var content: String
            var voteStatus: String
            var points: Int
            
            if indexPath.section == 0 {
                replyID = "0"
                userID = self.parentPost.userID
                content = self.parentPost.content
                voteStatus = self.parentPost.voteStatus
                points = self.parentPost.points
            } else {
                let reply = self.determineReplies()[indexPath.row]
                replyID = reply.replyID
                userID = reply.userID
                content = reply.content
                voteStatus = reply.voteStatus
                points = reply.points
            }
            
            switch voteStatus {
            case "up":
                 points -= 1
            case "down":
                points += 2
            default:
                points += 1
            }
            if indexPath.section == 0 {
                self.parentPost.points = points
                self.parentPost.voteStatus = "up"
            } else {
                misc.playSound("pop_drip.wav", start: 0)
                switch self.sortSegmentedControl.selectedSegmentIndex {
                case 1:
                    self.topReplies[indexPath.row].points = points
                    self.topReplies[indexPath.row].voteStatus = "up"
                case 2:
                    self.newestReplies[indexPath.row].points = points
                    self.newestReplies[indexPath.row].voteStatus = "up"
                default:
                    self.orderedReplies[indexPath.row].points = points
                    self.orderedReplies[indexPath.row].voteStatus = "up"
                }
            }
            self.tableView.reloadRows(at: [indexPath], with: .none)

            let amIBlocked = misc.amIBlocked(userID, blockedBy: self.blockedBy)
            if !amIBlocked {
                var postRef: DatabaseReference
                var voteHistoryRef: DatabaseReference
                let postVoteHistoryRef = self.ref.child("postVoteHistory").child(self.postID)
                var type: String
                if indexPath.section == 0 {
                    postRef = self.ref.child("posts").child(self.postID)
                    voteHistoryRef = postVoteHistoryRef.child(self.myID)
                    type = "post"
                } else {
                    postRef = self.ref.child("replies").child(self.postID).child(replyID)
                    voteHistoryRef = postVoteHistoryRef.child("replies").child(replyID).child(self.myID)
                    type = "comment"
                }
                
                postRef.runTransactionBlock({ (currentData:MutableData) -> TransactionResult in
                    if var post = currentData.value as? [String:Any] {
                        var upvotes = post["upvotes"] as? Int ?? 0
                        var downvotes = post["downvotes"] as? Int ?? 0
                        switch voteStatus {
                        case "up":
                            upvotes -= 1
                            voteHistoryRef.removeValue()
                        case "down":
                            upvotes += 1
                            downvotes -= 1
                            voteHistoryRef.setValue(true)
                        default:
                            upvotes += 1
                            voteHistoryRef.setValue(true)
                        }
                        
                        post["upvotes"] = upvotes as AnyObject?
                        post["downvotes"] = downvotes as AnyObject?
                        post["points"] = (upvotes - downvotes) as AnyObject?
                        currentData.value = post
                        if indexPath.section == 0 {
                            self.logUpvoted(userID, postID: self.postID)
                        } else {
                            self.logUpvotedReply(userID, postID: self.postID, replyID: replyID)
                        }
                        return TransactionResult.success(withValue: currentData)
                    }
                    return TransactionResult.success(withValue: currentData)
                    
                }) { (error, committed, snapshot) in
                    if let error = error {
                        print(error.localizedDescription)
                    }
                }
                
                self.misc.hasUpvoteNotified(postID, replyID: replyID, myID: self.myID) { notified in
                    if (self.myID != userID) && !notified {
                        var hasUpvoteNotifiedRef: DatabaseReference
                        if replyID != "0" {
                            hasUpvoteNotifiedRef = postVoteHistoryRef.child("replies").child(replyID).child("upvoteNotified").child(self.myID)
                        } else {
                            hasUpvoteNotifiedRef = postVoteHistoryRef.child("upvoteNotified").child(self.myID)
                        }
                        hasUpvoteNotifiedRef.setValue(true)
                        self.misc.writePointNotification(userID, myID: self.myID, postID: self.postID, content: content, type: type)
                    }
                }
                
                let userRef = self.ref.child("users").child(userID)
                userRef.runTransactionBlock({ (currentData:MutableData) -> TransactionResult in
                    if var userInfo = currentData.value as? [String:Any] {
                        var postPoints = userInfo["postPoints"] as? Int ?? 0
                        var replyPoints = userInfo["replyPoints"] as? Int ?? 0
                        
                        switch voteStatus {
                        case "up":
                            if indexPath.section == 0 {
                                postPoints -= 1
                            } else {
                                replyPoints -= 1
                            }
                        case "down":
                            if indexPath.section == 0 {
                                postPoints += 2
                            } else {
                                replyPoints += 2
                            }
                        default:
                            if indexPath.section == 0 {
                                postPoints += 1
                            } else {
                                replyPoints += 1
                            }
                        }
                        
                        let updatedPoints = postPoints + replyPoints
                        userInfo["points"] = updatedPoints as AnyObject?
                        userInfo["postPoints"] = postPoints as AnyObject?
                        userInfo["replyPoints"] = replyPoints as AnyObject?
                        currentData.value = userInfo
                        
                        self.misc.getFollowers(userID) { userFollowers in
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
                
                if indexPath.section == 0 {
                    let userPostHistoryRef = self.ref.child("userPostHistory").child(userID).child(self.postID)
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
                
            } else {
                if indexPath.section == 0 {
                    self.parentPost.voteStatus = "none"
                } else {
                    switch self.sortSegmentedControl.selectedSegmentIndex {
                    case 1:
                        self.topReplies[indexPath.row].voteStatus = "none"
                    case 2:
                        self.newestReplies[indexPath.row].voteStatus = "none"
                    default:
                        self.orderedReplies[indexPath.row].voteStatus = "none"
                    }
                }
                self.tableView.reloadRows(at: [indexPath], with: .none)
                self.displayAlert("Blocked", alertMessage: "This person has blocked you. You cannot vote on their posts.")
                return
            }
        }
    }
    
    @objc func downvote(_ sender: UIButton) {
        if let cell = sender.superview?.superview as? PostTableViewCell {
            let indexPath = self.tableView.indexPath(for: cell)!
            
            var replyID: String
            var userID: String
            var voteStatus: String
            var points: Int
            
            if indexPath.section == 0 {
                replyID = "0"
                userID = self.parentPost.userID
                voteStatus = self.parentPost.voteStatus
                points = self.parentPost.points
            } else {
                let reply = self.determineReplies()[indexPath.row]
                replyID = reply.replyID
                userID = reply.userID
                voteStatus = reply.voteStatus
                points = reply.points
            }
            
            switch voteStatus {
            case "up":
                points -= 2
            case "down":
                points += 1
            default:
                points -= 1
            }
            if indexPath.section == 0 {
                self.parentPost.points = points
                self.parentPost.voteStatus = "down"
            } else {
                switch self.sortSegmentedControl.selectedSegmentIndex {
                case 1:
                    self.topReplies[indexPath.row].points = points
                    self.topReplies[indexPath.row].voteStatus = "down"
                case 2:
                    self.newestReplies[indexPath.row].points = points
                    self.newestReplies[indexPath.row].voteStatus = "down"
                default:
                    self.orderedReplies[indexPath.row].points = points
                    self.orderedReplies[indexPath.row].voteStatus = "down"
                }
            }
            self.tableView.reloadRows(at: [indexPath], with: .none)
            
            let amIBlocked = misc.amIBlocked(userID, blockedBy: self.blockedBy)
            if !amIBlocked {
                var postRef: DatabaseReference
                var voteHistoryRef: DatabaseReference
                let postVoteHistoryRef = self.ref.child("postVoteHistory").child(self.postID)
                if indexPath.section == 0 {
                    postRef = self.ref.child("posts").child(self.postID)
                    voteHistoryRef = postVoteHistoryRef.child(self.myID)
                } else {
                    postRef = self.ref.child("replies").child(self.postID).child(replyID)
                    voteHistoryRef = postVoteHistoryRef.child("replies").child(replyID).child(self.myID)
                }
                
                postRef.runTransactionBlock({ (currentData:MutableData) -> TransactionResult in
                    if var post = currentData.value as? [String:Any] {
                        var upvotes = post["upvotes"] as? Int ?? 0
                        var downvotes = post["downvotes"] as? Int ?? 0
                        switch voteStatus {
                        case "up":
                            upvotes -= 1
                            downvotes += 1
                            voteHistoryRef.setValue(false)
                        case "down":
                            downvotes -= 1
                            voteHistoryRef.removeValue()
                        default:
                            downvotes += 1
                            voteHistoryRef.setValue(false)
                        }
                        
                        post["upvotes"] = upvotes as AnyObject?
                        post["downvotes"] = downvotes as AnyObject?
                        post["points"] = (upvotes - downvotes) as AnyObject?
                        currentData.value = post
                        if indexPath.section == 0 {
                            self.logDownvoted(userID, postID: self.postID)
                        } else {
                            self.logDownvotedReply(userID, postID: self.postID, replyID: replyID)
                        }
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
                        var replyPoints = userInfo["replyPoints"] as? Int ?? 0
                        
                        switch voteStatus {
                        case "up":
                            if indexPath.section == 0 {
                                postPoints -= 2
                            } else {
                                replyPoints -= 2
                            }
                        case "down":
                            if indexPath.section == 0 {
                                postPoints += 1
                            } else {
                                replyPoints += 1
                            }
                        default:
                            if indexPath.section == 0 {
                                postPoints -= 1
                            } else {
                                replyPoints -= 1
                            }
                        }
                        
                        let updatedPoints = postPoints + replyPoints
                        userInfo["points"] = updatedPoints as AnyObject?
                        userInfo["postPoints"] = postPoints as AnyObject?
                        userInfo["replyPoints"] = replyPoints as AnyObject?
                        currentData.value = userInfo
                        
                        self.misc.getFollowers(userID) { userFollowers in
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
                
                if indexPath.section == 0 {
                    let userPostHistoryRef = self.ref.child("userPostHistory").child(userID).child(self.postID)
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
               
            } else {
                if indexPath.section == 0 {
                    self.parentPost.voteStatus = "none"
                } else {
                    switch self.sortSegmentedControl.selectedSegmentIndex {
                    case 1:
                        self.topReplies[indexPath.row].voteStatus = "none"
                    case 2:
                        self.newestReplies[indexPath.row].voteStatus = "none"
                    default:
                        self.orderedReplies[indexPath.row].voteStatus = "none"
                    }
                }
                self.tableView.reloadRows(at: [indexPath], with: .none)
                self.displayAlert("Blocked", alertMessage: "This person has blocked you. You cannot vote on their posts.")
                return
            }
        }
    }
    
    func deletePost(_ replyID: String?) {
        let postRef = self.ref.child("posts").child(self.postID)

        if let id = replyID {
            switch self.sortSegmentedControl.selectedSegmentIndex {
            case 1:
                self.topReplies[self.parentPath.row].content = "[deleted]"
            case 2:
                self.newestReplies[self.parentPath.row].content = "[deleted]"
            default:
                self.orderedReplies[self.parentPath.row].content = "[deleted]"
            }
            self.tableView.reloadRows(at: [self.parentPath], with: .none)
            
            let replyRef = self.ref.child("replies").child(self.postID).child(id)
            replyRef.child("isDeleted").setValue(true)
            postRef.runTransactionBlock({ (currentData:MutableData) -> TransactionResult in
                if var postInfo = currentData.value as? [String:Any] {
                    if var replyCount = postInfo["replyCount"] as? Int {
                        replyCount -= 1
                        postInfo["replyCount"] = replyCount as AnyObject?
                        currentData.value = postInfo
                    }
                    return TransactionResult.success(withValue: currentData)
                }
                return TransactionResult.success(withValue: currentData)
            })
        } else {
            self.parentPost.content = "[deleted]"
            self.tableView.reloadRows(at: [self.parentPath], with: .none)
            postRef.child("isDeleted").setValue(true)
        }
    }
    
    func formatReply(_ replyID: String, voteStatus: String, reply: [String:Any]) -> Reply {
        var formattedReply = Reply()
        
        formattedReply.userID = reply["userID"] as? String ?? "error"
        
        let profilePicURLString = reply["profilePicURLString"] as? String ?? "error"
        if profilePicURLString != "error" {
            formattedReply.profilePicURL = URL(string: profilePicURLString)
        }
        
        formattedReply.handle = reply["handle"] as? String ?? "error"
        formattedReply.content = reply["content"] as? String ?? "error"
        
        let timestamp = reply["timestamp"] as? String ?? "error"
        let isEdited = reply["isEdited"] as? Bool ?? false
        let formattedTimestamp = misc.formatTimestamp(timestamp)
        if isEdited {
            formattedReply.timestamp = "edited \(formattedTimestamp)"
        } else {
            formattedReply.timestamp = formattedTimestamp
        }
        formattedReply.originalReverseTimestamp = reply["originalReverseTimestamp"] as? TimeInterval ?? 0

        let upvotes = reply["upvotes"] as? Int ?? 0
        let downvotes = reply["downvotes"] as? Int ?? 0
        formattedReply.points = upvotes - downvotes
        formattedReply.score = reply["score"] as? Double ?? 0

        formattedReply.voteStatus = voteStatus
     
        return formattedReply
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
