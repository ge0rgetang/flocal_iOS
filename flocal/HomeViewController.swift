//
//  HomeViewController.swift
//  flocal
//
//  Created by George Tang on 6/15/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import CoreLocation
import FirebaseDatabase
import FirebaseStorage
import FirebaseAnalytics
import SideMenu
import SDWebImage
import AVKit
import AVFoundation
import MobileCoreServices
import GeoFire
import Alamofire
import FirebaseMessaging

class HomeViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate, CLLocationManagerDelegate, CamDelegate {
    
    // MARK: - Outlets
    
    @IBOutlet weak var containerBottom: NSLayoutConstraint!
    @IBOutlet weak var containerView: UIView!
    
    @IBOutlet weak var sortSegmentedControl: UISegmentedControl!
    @IBOutlet weak var notificationLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: - Vars
    
    var myID: String = "0"
    var newPosts: [Post] = []
    var newPostIDs: [String] = []
    var hotPosts: [Post] = []
    var hotPostIDs: [String] = []
    var addedPosts: [Post] = []
    var blockedBy: [String] = []
    
    var postToPass: Post = Post()
    
    var postIDToPass: String = "0"
    var userIDToPass: String = "0"
    var handleToPass: String = "0"
    var fromHandle: Bool = false
    
    var imageVideoTypeToPass: String = "image"
    var imageToPass: UIImage!
    var urlToPass: URL!
    
    var radiusMiles: Double = 1.5
    var radiusMeters: Double = 2404.02
    var locationManager: CLLocationManager!
    var longitude: Double = -122.258542
    var latitude: Double = 37.871906
    
    var scrollPosition: String = "top"
    var isRemoved: Bool = false
    var lastContentOffset: CGFloat = 0

    var ref = Database.database().reference()
    let storageRef = Storage.storage().reference()
    let geoFireUsers = GeoFire(firebaseRef: Database.database().reference().child("users_location"))
    let geoFirePosts = GeoFire(firebaseRef: Database.database().reference().child("posts_location"))

    let misc = Misc()
    var imagePicker = UIImagePickerController()
    var dimView = UIView()
    var dimViewWrite = UIView()
    var dimViewSeg = UIView()
    var writePostVC: PostViewController?
    var sideMenuButton = UIButton()
    var sideMenuBarButton = UIBarButtonItem()
    var notificationButton = UIButton()
    var notificationBarButton = UIBarButtonItem()
    var refreshControl = UIRefreshControl()
    var displayActivity: Bool = false

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.setLocationManager()
        self.checkAuthorizationStatus()
        
        self.navigationItem.title = "Home"
        self.navigationController?.navigationBar.tintColor = misc.flocalColor
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: misc.flocalColor]
        self.navigationController?.hidesBarsOnSwipe = true
        self.containerView.isHidden = true
        
        let tapBar = UITapGestureRecognizer(target: self, action: #selector(self.scrollToTop))
        self.navigationController?.navigationBar.addGestureRecognizer(tapBar)
        
        self.sortSegmentedControl.selectedSegmentIndex = 0
        self.sortSegmentedControl.addTarget(self, action: #selector(self.sortSegmentDidChange), for: .valueChanged)
        self.sortSegmentedControl.layer.borderWidth = 1.5
        self.sortSegmentedControl.layer.borderColor = misc.flocalColor.cgColor
        
        self.refreshControl.addTarget(self, action: #selector(self.observePosts), for: .valueChanged)
        self.tableView.addSubview(self.refreshControl)
        
        self.setTableView()
        self.setDimView()
        self.setSideMenu()
        self.setImagePicker()
        self.setNotificationMenu()
        self.setPermenantNotifications()
        
        self.myID = misc.setMyID()
        if self.myID == "0" {
            misc.postToNotificationCenter("turnToLogin")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.portrait)
        self.tableView.reloadData()
        self.logViewPosts()
        misc.setSideMenuIndex(0)
        self.setNotifications()
        self.observeBlocked()
        misc.observeLastNotificationType(self.notificationLabel, button: self.notificationButton, color: "default")
        
        self.setLongLat()
        let status = CLLocationManager.authorizationStatus()
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            self.locationManager.startUpdatingLocation()
        } else {
            self.observePosts()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
        self.removeObserverForPosts()
        self.removeNotifications()
        self.removeObserverForBlocked()
        misc.removeNotificationTypeObserver()
        self.locationManager.stopUpdatingLocation()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.locationManager.stopUpdatingLocation()
        self.removeObserverForPosts()
        misc.removeNotificationTypeObserver()
        self.clearArrays()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        NotificationCenter.default.removeObserver(self)
        self.removeObserverForPosts()
        misc.removeNotificationTypeObserver()
        misc.clearWebImageCache()
        self.clearArrays()
    }
    
    // MARK: - Tableview
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let posts = self.determinePosts()
        let count = posts.count
        
        if posts.isEmpty {
            return 1
        } else {
            if self.displayActivity {
                return count + 1
            }
            return count
        }
    }
    
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let cell = tableView.dequeueReusableCell(withIdentifier: "writePostCell") as! WritePostTableViewCell
        cell.backgroundColor = .white
        cell.layer.shadowColor = UIColor.black.cgColor
        cell.layer.masksToBounds = false
        cell.layer.shadowOffset = CGSize(width: -1, height: 1)
        cell.layer.shadowOpacity = 0.42
        cell.addSubview(self.dimViewWrite)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.presentWriteTextPost))
        cell.addGestureRecognizer(tap)
        cell.cameraButton.addTarget(self, action: #selector(self.selectPicSource), for: .touchUpInside)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 51
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let posts = self.determinePosts()
        
        if posts.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "noPostCell", for: indexPath) as! NoContentTableViewCell
            switch self.sortSegmentedControl.selectedSegmentIndex {
            case 1:
                cell.noContentLabel.text = "No hot posts found :( Be the first ↑"
            case 2:
                cell.noContentLabel.text = "No one added yet. Posts from people you add show here!"
            default:
                cell.noContentLabel.text = "No posts found :( Be the first ↑"
            }
            cell.backgroundColor = .white
            cell.noContentLabel.textColor = misc.flocalColor
            cell.noContentLabel.numberOfLines = 0
            cell.noContentLabel.sizeToFit()
            return cell
            
        } else {
            if self.displayActivity && (indexPath.row == posts.count) {
                let cell = tableView.dequeueReusableCell(withIdentifier: "postActivityCell", for: indexPath) as! ActivityTableViewCell
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
            let tapHandle = UITapGestureRecognizer(target: self, action: #selector(self.presentUserProfile))
            cell.handleLabel.addGestureRecognizer(tapHandle)
            
            if let profilPicURL = post.profilePicURL {
                cell.profilePicImageView.sd_setImage(with: profilPicURL)
            } else {
                cell.profilePicImageView.image = self.misc.setDefaultPic(handle)
            }
            cell.profilePicImageView.layer.cornerRadius = cell.profilePicImageView.frame.size.width/2
            cell.profilePicImageView.clipsToBounds = true
            let tapPic = UITapGestureRecognizer(target: self, action: #selector(self.presentUserProfile))
            cell.profilePicImageView.addGestureRecognizer(tapPic)
            
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
                cell.pointsLabel.textColor = misc.setPointsColor(points, source: "post")
                cell.upvoteButton.setImage(UIImage(named: "upvote"), for: .normal)
                cell.downvoteButton.setImage(UIImage(named: "downvote"), for: .normal)
            }
            cell.upvoteButton.addTarget(self, action: #selector(self.upvote), for: .touchUpInside)
            cell.downvoteButton.addTarget(self, action: #selector(self.downvote), for: .touchUpInside)
            
            let content = post.content
            cell.textView.attributedText = misc.stringWithColoredTags(content, time: "default", fontSize: 18, timeSize: 18)
            let tapText = UITapGestureRecognizer(target: self, action: #selector(self.textViewTapped))
            cell.textView.addGestureRecognizer(tapText)
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
        let posts = self.determinePosts()
        if !posts.isEmpty {
            let cell = tableView.cellForRow(at: indexPath) as! PostTableViewCell
            cell.replyLabel.textColor = misc.flocalYellow
            
            let post = posts[indexPath.row]
            self.postToPass = post
            self.presentReply()
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
        if segue.identifier == "fromHomeToViewImage" {
            if let vc = segue.destination as? ViewImageViewController {
                vc.postID = self.postIDToPass
                vc.parentSource = "post"
                vc.image = self.imageToPass
                vc.picURL = self.urlToPass
                misc.setRotateView(self.imageToPass)
            }
        }
        
        if segue.identifier == "fromHomeToViewVideo" {
            if let vc = segue.destination as? ViewVideoViewController {
                vc.postID = self.postIDToPass
                vc.parentSource = "post"
                vc.previewImage = self.imageToPass
                vc.vidURL = self.urlToPass
                misc.setRotateView(self.imageToPass)
            }
        }
        
        if segue.identifier == "fromHomeToCamera" {
            if let vc = segue.destination as? CameraViewController {
                if self.imageVideoTypeToPass == "image" {
                    vc.isImage = true
                } else {
                    vc.isImage = false
                }
                vc.parentSource = "post"
                vc.isFront = false 
            }
        }
        
        if segue.identifier == "fromHomeToUserProfile" {
            if let vc = segue.destination as? UserProfileViewController {
                if self.fromHandle {
                    vc.handle = self.handleToPass
                } else {
                    vc.userID = self.userIDToPass
                }
            }
        }
        
        if segue.identifier == "fromHomeToReply" {
            if let vc = segue.destination as? ReplyViewController {
                vc.parentPost = self.postToPass
                vc.parentSource = "home"
            }
        }
    }
    
    @objc func presentViewImage(_ sender: UITapGestureRecognizer) {
        let position = sender.location(in: self.tableView)
        let indexPath: IndexPath! = self.tableView.indexPathForRow(at: position)
        let posts = self.determinePosts()
        let post = posts[indexPath.row]
        
        if let postPicURL = post.postPicURL {
            let imageView = UIImageView()
            imageView.sd_setImage(with: postPicURL)
            self.imageToPass = imageView.image
            self.urlToPass = postPicURL
            self.postIDToPass = post.postID
            self.performSegue(withIdentifier: "fromHomeToViewImage", sender: self)
        }
    }
    
    @objc func presentViewVideo(_ sender: UITapGestureRecognizer) {
        let position = sender.location(in: self.tableView)
        let indexPath: IndexPath! = self.tableView.indexPathForRow(at: position)
        let posts = self.determinePosts()
        let post = posts[indexPath.row]
        
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
            self.performSegue(withIdentifier: "fromHomeToViewVideo", sender: self)
        }
    }
    
    func presentWritePost() {
        self.containerView.isHidden = false
        self.containerView.layer.cornerRadius = 10
        self.containerView.layer.masksToBounds = true 
        self.writePostVC = storyboard?.instantiateViewController(withIdentifier: "PostViewController") as? PostViewController
        self.writePostVC?.imageVideoType = self.imageVideoTypeToPass
        self.writePostVC?.image = self.imageToPass
        self.writePostVC?.imageVideoURL = self.urlToPass
        self.writePostVC?.view.frame = self.containerView.bounds
        self.addChildViewController(self.writePostVC!)
        self.containerView.addSubview(self.writePostVC!.view)
        self.dimBackground(true)
    }
    
    @objc func dismissWritePostVC() {
        self.writePostVC?.view.removeFromSuperview()
        self.writePostVC?.removeFromParentViewController()
        self.writePostVC = nil
        self.containerView.isHidden = true
        self.dimBackground(false)
    }
    
    @objc func presentWriteTextPost() {
        misc.playSound("button_click.wav", start: 0)
        self.imageVideoTypeToPass = "text"
        self.presentWritePost()
    }
    
    @objc func presentUserProfile(_ sender: UITapGestureRecognizer) {
        let position = sender.location(in: self.tableView)
        let indexPath: IndexPath! = self.tableView.indexPathForRow(at: position)
        let posts = self.determinePosts()
        let post = posts[indexPath.row]
        
        let userID = post.userID
        self.prefetchUserProfilePics(userID)
        self.userIDToPass = userID
        self.fromHandle = false
        
        if self.myID != userID {
            self.performSegue(withIdentifier: "fromHomeToUserProfile", sender: self)
        }
    }
    
    func presentReply() {
        self.performSegue(withIdentifier: "fromHomeToReply", sender: self)
    }
    
    @objc func textViewTapped(_ sender: UITapGestureRecognizer) {
        let position = sender.location(in: self.tableView)
        let indexPath: IndexPath! = self.tableView.indexPathForRow(at: position)
        let posts = self.determinePosts()
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
                            misc.doesUserExist(handle) { doesUserExist in
                                let handleLower = handle.lowercased()
                                if let myHandle = UserDefaults.standard.string(forKey: "handle.flocal") {
                                    if (myHandle.lowercased() != handleLower) && (doesUserExist) {
                                        self.handleToPass = handle
                                        self.fromHandle = true
                                        self.performSegue(withIdentifier: "fromHomeToUserProfile", sender: self)
                                    }
                                } else {
                                    self.misc.getHandle(self.myID) { myHandle in
                                        if (myHandle.lowercased() != handleLower) && (doesUserExist) {
                                            self.handleToPass = handle
                                            self.fromHandle = true
                                            self.performSegue(withIdentifier: "fromHomeToUserProfile", sender: self)
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
    
    // MARK - CamDelegate
    
    func passImage(_ image: UIImage) {
        self.imageToPass = image
        self.imageVideoTypeToPass = "image"
        self.presentWritePost()
    }
    
    func passVideo(_ url: URL) {
        self.imageToPass = self.generatePreviewImage(url).0
        self.imageVideoTypeToPass = "video"
        self.urlToPass = url
        if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(url.path) {
            UISaveVideoAtPathToSavedPhotosAlbum(url.path, self, nil, nil)
        }
        self.presentWritePost()
    }
    
    // MARK: - Image Picker
    
    func imagePickerController(_ picker:UIImagePickerController, didFinishPickingMediaWithInfo info:[String: Any]) {
        if let selectedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
            self.imageToPass = selectedImage
            self.imageVideoTypeToPass = "image"
            self.presentWritePost()
        }
     
        self.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func selectPicSource() {
        DispatchQueue.main.async(execute: {
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let takeVideoAction = UIAlertAction(title: "Record Video", style: .default, handler: { action in
                    self.imageVideoTypeToPass = "video"
                    self.performSegue(withIdentifier: "fromHomeToCamera", sender: self)
                })
                alertController.addAction(takeVideoAction)
                
                let takePhotoAction = UIAlertAction(title: "Take Photo", style: .default, handler: { action in
                    self.imageVideoTypeToPass = "image"
                    self.performSegue(withIdentifier: "fromHomeToCamera", sender: self)
                })
                alertController.addAction(takePhotoAction)
            }
            
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                let choosePhotoLibraryAction = UIAlertAction(title: "Choose from Photo Library", style: .default, handler: { action in
                    self.imageVideoTypeToPass = "image"
                    self.imagePicker.sourceType = .photoLibrary
                    self.present(self.imagePicker, animated: true, completion: nil)
                })
                alertController.addAction(choosePhotoLibraryAction)
            }
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            alertController.view.tintColor = self.misc.flocalColor
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
    
    // MARK: - Segmented Controls
    
    @objc func sortSegmentDidChange(_ sender: UISegmentedControl) {
        self.scrollToTop()
        self.observePosts()
    }
    
    @objc func setHomeSegment() {
        self.sortSegmentedControl.selectedSegmentIndex = UserDefaults.standard.integer(forKey: "homeSegment.flocal")
        self.scrollToTop()
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
            
            self.notificationButton.setImage(UIImage(named: "notificationS"), for: .normal)
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
            self.removeObserverForPosts()
        }
        
        let offset = scrollView.contentOffset.y
        let frameHeight = scrollView.frame.size.height
        let contentHeight = scrollView.contentSize.height
        let bottomPoint = CGPoint(x: scrollView.contentOffset.x, y: contentHeight - frameHeight)

        let posts = self.determinePosts()
        
        if offset <= 42 {
            self.scrollPosition = "top"
            self.observePosts()
        } else if offset == contentHeight - frameHeight {
            self.scrollPosition = "bottom"
            if posts.count >= 8 {
                self.displayActivity = true
                self.tableView.reloadData()
                scrollView.setContentOffset(bottomPoint, animated: true)
                self.observePosts()
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
                            if let postVidPreviewURL = post.postVidPreviewURL {
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
    
    // MARK: - Location Manager
    
    func checkAuthorizationStatus() {
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            self.locationManager.requestWhenInUseAuthorization()
            
        case .restricted, .denied :
            let alertController = UIAlertController(title: "Location Access Disabled", message: "Please enable location so we can bring you nearby posts and locals. Thanks!", preferredStyle: .alert)
            
            let openSettingsAction = UIAlertAction(title: "Settings", style: .default) { action in
                if let settingsURL = URL(string: UIApplicationOpenSettingsURLString) {
                    UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
                }
            }
            alertController.addAction(openSettingsAction)
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: nil)
            alertController.addAction(cancelAction)
            
            self.present(alertController, animated: true, completion: nil)
            
        default:
            return
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            UserDefaults.standard.set(true, forKey: "myLocation.flocal")
            UserDefaults.standard.synchronize()
            self.locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let myLocation = UserDefaults.standard.bool(forKey: "myLocation.flocal")
        if myLocation {
            var location = self.locationManager.location!.coordinate
            let long = location.longitude.roundToDecimalPlace(8)
            let lat = location.latitude.roundToDecimalPlace(8)
            self.longitude = long
            self.latitude = lat
            UserDefaults.standard.set(long, forKey: "longitude.flocal")
            UserDefaults.standard.set(lat, forKey: "latitude.flocal")
            UserDefaults.standard.synchronize()
            self.writeMyLocation()
            
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(self.locationManager.location!, completionHandler: {(placemarks, error) -> Void in
                if error != nil {
                    self.displayLocationError(error!)
                    return
                }
                if let placemark = placemarks?.first {
                    if let city = placemark.locality {
                        UserDefaults.standard.set(city, forKey: "city.flocal")
                        UserDefaults.standard.synchronize()
                    }
                    if let zip = placemark.postalCode {
                        UserDefaults.standard.set(zip, forKey: "zip.flocal")
                        UserDefaults.standard.synchronize()
                    }
                }
            })
        }
        
        self.observePosts()
    }
    
    func displayLocationError(_ error: Error) {
        if let clerror = error as? CLError {
            let errorCode = clerror.errorCode
            switch errorCode {
            case 1:
                self.displayAlert("Oops", alertMessage: "Location services denied. Please enable them if you want to see different locations.")
            case 2:
                self.displayAlert("uhh, Houston, we have a problem", alertMessage: "Sorry, could not connect to le internet or you've made too many location requests in a short amount of time. Please wait and try again. :(")
            case 3, 4, 5, 6, 7, 11, 12, 13, 14, 15, 16, 17:
                self.displayAlert("Oops", alertMessage: clerror.localizedDescription)
            default:
                self.displayAlert("Oops", alertMessage: "Invalid Location. Please try another zip, city, or tap the right button for this location.")
            }
        } else {
            self.displayAlert("Oops", alertMessage: "Invalid Location. Please try another zip, city, or tap the right button for this location.")
        }
        return
    }
    
    func setLocationManager() {
        self.locationManager = CLLocationManager()
        self.locationManager.delegate = self
        self.locationManager.distanceFilter = 402.336
        self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }
    
    func setLongLat() {
        let long = UserDefaults.standard.double(forKey: "longitude.flocal")
        let lat = UserDefaults.standard.double(forKey: "latitude.flocal")
        if long != 0 {
            self.longitude = long
        }
        if lat != 0 {
            self.latitude = lat
        }
    }
    
    func getMinMaxLongLat(_ distanceMiles: Double) -> [Double] {
        let delta = (distanceMiles*5280)/(364173*cos(self.longitude))
        let scaleFactor = 0.01447315953478432289213674551561
        let minLong = self.longitude - delta
        let maxLong = self.longitude + delta
        let minLat = self.latitude - (distanceMiles*scaleFactor)
        let maxLat = self.latitude + (distanceMiles*scaleFactor)
        return [minLong, maxLong, minLat, maxLat]
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
            self.refreshControl.endRefreshing()
            self.displayActivity = false
            self.present(alertController, animated: true, completion: nil)
        })
    }

    func determinePosts() -> [Post] {
        var posts: [Post]
        switch self.sortSegmentedControl.selectedSegmentIndex {
        case 1:
            posts = self.hotPosts
        case 2:
            posts = self.addedPosts
        default:
            posts = self.newPosts
        }
        
        return posts
    }
    
    func clearArrays() {
        self.newPosts = []
        self.hotPosts = []
        self.addedPosts = []
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
        
        self.dimViewWrite.isUserInteractionEnabled = false
        self.dimViewWrite.backgroundColor = .black
        self.dimViewWrite.alpha = 0
        self.dimViewWrite.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: 51)
    }
    
    func dimBackground(_ bool: Bool) {
        if bool {
            self.dimView.alpha = 0.25
            self.dimViewSeg.alpha = 0.25
            self.dimViewWrite.alpha = 0.25
        } else {
            self.dimView.alpha = 0
            self.dimViewSeg.alpha = 0
            self.dimViewWrite.alpha = 0
        }
    }

    // MARK: - Notification Center
    
    func setPermenantNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.setHomeSegment), name: Notification.Name("setHomeSegment"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.dismissWritePostVC), name: Notification.Name("dismissWritePostVC"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow(_:)), name: Notification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillChangeFrame(_:)), name: Notification.Name.UIKeyboardWillChangeFrame, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: Notification.Name.UIKeyboardWillHide, object: nil)
    }
    
    func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.observePosts), name: Notification.Name("addFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.removeObserverForPosts), name: Notification.Name("removeFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.scrollToTop), name: Notification.Name("scrollToTop"), object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name("addFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("removeFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("scrollToTop"), object: nil)
    }
    
    // MARK: - Analytics 
    
    func logViewPosts() {
        switch self.sortSegmentedControl.selectedSegmentIndex {
        case 1:
            Analytics.logEvent("viewPostsHot_iOS", parameters: [
                "myID": self.myID as NSObject
                ])
        case 2:
            Analytics.logEvent("viewPostsAdded_iOS", parameters: [
                "myID": self.myID as NSObject
                ])
        default:
            Analytics.logEvent("viewPostsNew_iOS", parameters: [
                "myID": self.myID as NSObject
                ])
        }
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
    
    func writeMyLocation() {
        let meRef = self.ref.child("users").child(self.myID)
        meRef.child("longitude").setValue(self.longitude)
        meRef.child("latitude").setValue(self.latitude)
        
        let location = CLLocation(latitude: self.latitude, longitude: self.longitude)
        self.geoFireUsers?.setLocation(location, forKey: self.myID)
    }
    
    @objc func observePosts() {
        self.removeObserverForPosts()
        self.isRemoved = false
        
        let posts = self.determinePosts()
        let lastPostID = posts.last?.postID
        let postRef = self.ref.child("posts")
        
        if self.scrollPosition == "middle" && !posts.isEmpty {
            if let visiblePaths = self.tableView.indexPathsForVisibleRows {
                for indexPath in visiblePaths {
                    let postID = posts[indexPath.row].postID
                    let middleRef = postRef.child(postID)
                    middleRef.observeSingleEvent(of: .value, with: { (snapshot) -> Void in
                        if let post = snapshot.value as? [String:Any] {
                            let isDeleted = post["isDeleted"] as? Bool ?? false
                            let reports = post["reports"] as? Int ?? 0
                            
                            self.misc.getVoteStatus(postID, replyID: nil, myID: self.myID) { voteStatus in
                                if reports < 3 && !isDeleted {
                                    let formattedPost = self.misc.formatPost(postID, voteStatus: voteStatus, post: post)
                                    switch self.sortSegmentedControl.selectedSegmentIndex {
                                    case 1:
                                        self.hotPosts[indexPath.row] = formattedPost
                                    case 2:
                                        self.addedPosts[indexPath.row] = formattedPost
                                    default:
                                        self.newPosts[indexPath.row] = formattedPost
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
            var postsArray: [Post] = []
            
            switch self.sortSegmentedControl.selectedSegmentIndex {
            case 1:
                var score: Double
                let lastScore = posts.last?.score
                let firstScore = -1.0
                if self.scrollPosition == "bottom" {
                    score = lastScore ?? firstScore
                } else {
                    score = firstScore
                }
                self.getPostIDs("hot", lastTimestamp: misc.getTimestamp("UTC", date: Date()), lastScore: score)
                
                for postID in self.hotPostIDs {
                    let hotRef = postRef.child(postID)
                    hotRef.observeSingleEvent(of: .value, with: { (snapshot) -> Void in
                        if let post = snapshot.value as? [String:Any] {
                            let isDeleted = post["isDeleted"] as? Bool ?? false
                            let reports = post["reports"] as? Int ?? 0
                            
                            self.misc.getVoteStatus(postID, replyID: nil, myID: self.myID) { voteStatus in
                                if reports < 3 && !isDeleted {
                                    let formattedPost = self.misc.formatPost(postID, voteStatus: voteStatus, post: post)
                                    postsArray.append(formattedPost)
                                }
                            }
                        }
                    })
                }
                
                if self.scrollPosition == "bottom" {
                    if lastPostID != postsArray.last?.postID {
                        self.hotPosts.append(contentsOf: postsArray)
                    }
                } else {
                    self.hotPosts = postsArray
                }
                self.displayActivity = false
                self.tableView.reloadData()
                
            case 2:
                var reverseTimestamp: TimeInterval
                let currentReverseTimestamp = misc.getCurrentReverseTimestamp()
                let lastReverseTimestamp = posts.last?.originalReverseTimestamp
                if self.scrollPosition == "bottom" {
                    reverseTimestamp = lastReverseTimestamp ?? currentReverseTimestamp
                } else {
                    reverseTimestamp = currentReverseTimestamp
                }
                
                let userAddedPostsRef = self.ref.child("userAddedPosts").child(self.myID)
                userAddedPostsRef.queryOrdered(byChild: "originalReverseTimestamp").queryStarting(atValue: reverseTimestamp).queryLimited(toFirst: 88).observe(.value, with: { (snapshot) -> Void in
                    let dict = snapshot.value as? [String:Any] ?? [:]
                    let postIDs: [String] = Array(dict.keys)
                    
                    for postID in postIDs {
                        let postRef = self.ref.child("posts").child(postID)
                        postRef.observeSingleEvent(of: .value, with: { (snapshot) in
                            if let post = snapshot.value as? [String:Any] {
                                let isDeleted = post["isDeleted"] as? Bool ?? false
                                
                                self.misc.getVoteStatus(postID, replyID: nil, myID: self.myID) { voteStatus in
                                    if !isDeleted {
                                        let formattedPost = self.misc.formatPost(postID, voteStatus: voteStatus, post: post)
                                        postsArray.append(formattedPost)
                                    }
                                }
                            }
                        })
                    }
                    
                    if self.scrollPosition == "bottom" {
                        if lastPostID != postsArray.last?.postID {
                            self.addedPosts.append(contentsOf: postsArray)
                        }
                    } else {
                        self.addedPosts = postsArray
                    }
                    self.displayActivity = false
                    self.tableView.reloadData()
                })
                
            default:
                let center = CLLocation(latitude: self.latitude, longitude: self.longitude)
                let circleQuery = self.geoFirePosts?.query(at: center, withRadius: self.radiusMeters/1000)
                _ = circleQuery?.observe(.keyEntered, with: { (key, location) in
                })
                circleQuery?.observeReady({
                    var timestamp: String
                    let lastTime = posts.last?.timestampUTC
                    let firstTime = self.misc.getTimestamp("UTC", date: Date())
                    if self.scrollPosition == "bottom" {
                        timestamp = lastTime ?? firstTime
                    } else {
                        timestamp = firstTime
                    }
                    self.getPostIDs("new", lastTimestamp: timestamp, lastScore: -1.0)
                    
                    for postID in self.newPostIDs {
                        let newRef = postRef.child(postID)
                        newRef.observeSingleEvent(of: .value, with: { (snapshot) -> Void in
                            if let post = snapshot.value as? [String:Any] {
                                let isDeleted = post["isDeleted"] as? Bool ?? false
                                let reports = post["reports"] as? Int ?? 0
                                
                                self.misc.getVoteStatus(postID, replyID: nil, myID: self.myID) { voteStatus in
                                    if reports < 3 && !isDeleted {
                                        let formattedPost = self.misc.formatPost(postID, voteStatus: voteStatus, post: post)
                                        postsArray.append(formattedPost)
                                    }
                                }
                            }
                        })
                    }
                    
                    if self.scrollPosition == "bottom" {
                        if lastPostID != postsArray.last?.postID {
                            self.newPosts.append(contentsOf: postsArray)
                        }
                    } else {
                        self.newPosts = postsArray
                    }
                    self.displayActivity = false
                    self.tableView.reloadData()
                })
            }
            self.refreshControl.endRefreshing()
        }
    }
    
    @objc func removeObserverForPosts() {
        self.isRemoved = true
        
        self.geoFirePosts?.firebaseRef.removeAllObservers()
        
        let userAddedPostsRef = self.ref.child("userAddedPosts").child(self.myID)
        userAddedPostsRef.removeAllObservers()
    }
    
    @objc func upvote(_ sender: UIButton) {
        if let cell = sender.superview?.superview as? PostTableViewCell {
            let indexPath = self.tableView.indexPath(for: cell)!
            let posts = self.determinePosts()
            
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
            misc.playSound("pop_drip.wav", start: 0)
            individualPost.voteStatus = "up"
            switch self.sortSegmentedControl.selectedSegmentIndex {
            case 1:
                self.hotPosts[indexPath.row] = individualPost
            case 2:
                self.addedPosts[indexPath.row] = individualPost
            default:
                self.newPosts[indexPath.row] = individualPost
            }
            self.tableView.reloadRows(at: [indexPath], with: .none)

            let amIBlocked = misc.amIBlocked(userID, blockedBy: self.blockedBy)
            if !amIBlocked {
                self.misc.upvote(postID, myID: self.myID, userID: userID, voteStatus: voteStatus, content: content)
                self.logUpvoted(userID, postID: postID)
            } else {
                individualPost.voteStatus = "none"
                switch self.sortSegmentedControl.selectedSegmentIndex {
                case 1:
                    self.hotPosts[indexPath.row] = individualPost
                case 2:
                    self.addedPosts[indexPath.row] = individualPost
                default:
                    self.newPosts[indexPath.row] = individualPost
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
            let posts = self.determinePosts()
            
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
            switch self.sortSegmentedControl.selectedSegmentIndex {
            case 1:
                self.hotPosts[indexPath.row] = individualPost
            case 2:
                self.addedPosts[indexPath.row] = individualPost
            default:
                self.newPosts[indexPath.row] = individualPost
            }
            self.tableView.reloadRows(at: [indexPath], with: .none)
            
            let amIBlocked = misc.amIBlocked(userID, blockedBy: self.blockedBy)
            if !amIBlocked {
                self.misc.downvote(postID, myID: self.myID, userID: userID, voteStatus: voteStatus)
                self.logDownvoted(userID, postID: postID)
            } else {
                individualPost.voteStatus = "none"
                switch self.sortSegmentedControl.selectedSegmentIndex {
                case 1:
                    self.hotPosts[indexPath.row] = individualPost
                case 2:
                    self.addedPosts[indexPath.row] = individualPost
                default:
                    self.newPosts[indexPath.row] = individualPost
                }
                self.tableView.reloadRows(at: [indexPath], with: .none)
                self.displayAlert("Blocked", alertMessage: "This person has blocked you. You cannot vote on their posts.")
                return
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
    
    // MARK: - Alamofire
    
    func getPostIDs(_ type: String, lastTimestamp: String, lastScore: Double) {
        let param: Parameters = ["longitude": self.longitude, "latitude": self.latitude, "lastTimestamp": lastTimestamp, "lastScore": lastScore, "sort": type, "action": "search"]

        Alamofire.request("https://flocalApp.us-west-1.elasticbeanstalk.com", method: .post, parameters: param, encoding: JSONEncoding.default).responseJSON { response in
            if let json = response.result.value {
                print(json)
                if (type == "hot") {
                    self.hotPostIDs = json as? [String] ?? []
                } else {
                    self.newPostIDs = json as? [String] ?? []
                }
            }
        }
    }
    
}
