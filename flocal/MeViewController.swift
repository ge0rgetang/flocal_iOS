//
//  MeViewController.swift
//  flocal
//
//  Created by George Tang on 5/22/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseAnalytics
import FirebaseAuth
import FirebaseDatabase
import FirebaseStorage
import SDWebImage
import SideMenu

class MeViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPopoverPresentationControllerDelegate, CamDelegate {
    
    // MARK: - Outlets
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var notificationLabel: UILabel!
    
    @IBOutlet weak var profilePicImageView: UIImageView!
    @IBOutlet weak var profilePicHeight: NSLayoutConstraint!
    @IBOutlet weak var profilePicTopOffsetFromBackground: NSLayoutConstraint!
    @IBOutlet weak var handleTopOffset: NSLayoutConstraint!
    
    @IBOutlet weak var backgroundPicImageView: UIImageView!
    @IBOutlet weak var addBackgroundLabel: UILabel!
    
    @IBOutlet weak var handleLabel: UILabel!
    @IBOutlet weak var followersLabel: UILabel!
    @IBOutlet weak var pointsLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var privateInfoLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var phoneLabel: UILabel!
    @IBOutlet weak var birthdayLabel: UILabel!
    
    // MARK: - Vars
    
    var myID: String = "0"
    var imagePickerType: String = "background"
    
    var ref = Database.database().reference()
    let storageRef = Storage.storage().reference()

    let misc = Misc()
    var imagePicker = UIImagePickerController()
    var sideMenuButton = UIButton()
    var sideMenuBarButton = UIBarButtonItem()
    var notificationButton = UIButton()
    var notificationBarButton = UIBarButtonItem()
    
    // MARK: - Lifecycle 
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = "Me"
        self.navigationController?.navigationBar.tintColor = misc.flocalBlue
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: misc.flocalBlue]

        self.addBackgroundLabel.isHidden = true
        self.addTapGestures()
        self.setSideMenu()
        self.setNotificationMenu()
        self.setImagePicker()
        
        let profConstraints = misc.getProfPicHeight()
        self.profilePicHeight.constant = profConstraints[0]
        self.profilePicTopOffsetFromBackground.constant = profConstraints[1]
        self.handleTopOffset.constant = profConstraints[2]
        
        self.myID = misc.setMyID()
        if self.myID == "0" {
            misc.postToNotificationCenter("turnToLogin")
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.portrait)
        self.logViewMe()
        misc.setSideMenuIndex(3)
        self.setNotifications()
        self.downloadProfilePic()
        self.downloadBackgroundPic()
        self.observeMe()
        misc.observeLastNotificationType(self.notificationLabel, button: self.notificationButton, color: "blue")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
        self.removeNotifications()
        self.removeObserverForMe()
        misc.removeNotificationTypeObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.removeObserverForMe()
        misc.removeNotificationTypeObserver()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        misc.clearWebImageCache()
    }
    
    override func viewWillLayoutSubviews() {
        self.profilePicImageView.layer.cornerRadius = self.profilePicImageView.frame.size.width/2
        self.profilePicImageView.clipsToBounds = true
        self.profilePicImageView.layer.borderWidth = 2.5
        self.profilePicImageView.layer.borderColor = UIColor.white.cgColor
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "fromMeToCamera" {
            if let vc = segue.destination as? CameraViewController {
                vc.isImage = true
                vc.parentSource = "background"
                vc.isFront = false
            }
        }
    }
    
    func addTapGestures() {
        let tapPic: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.selectPicSource))
        self.profilePicImageView.addGestureRecognizer(tapPic)
        tapPic.cancelsTouchesInView = false
        
        let tapBackground: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.selectBackgroundSource))
        self.backgroundPicImageView.addGestureRecognizer(tapBackground)
        tapBackground.cancelsTouchesInView = false
        
        let tapHandle: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.presentEditInfo))
        self.handleLabel.addGestureRecognizer(tapHandle)
        
        let tapDescription: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.presentEditInfo))
        self.descriptionLabel.addGestureRecognizer(tapDescription)
        
        let tapEmail: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.presentEditLogin))
        self.emailLabel.addGestureRecognizer(tapEmail)
        
        let tapName: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.presentEditInfo))
        self.nameLabel.addGestureRecognizer(tapName)
        
        let tapPhone: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.presentEditInfo))
        self.phoneLabel.addGestureRecognizer(tapPhone)
        
        let tapBirthday: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.presentEditInfo))
        self.birthdayLabel.addGestureRecognizer(tapBirthday)
    }
    
    @objc func presentEditInfo(sender: UITapGestureRecognizer) {
        let editInfoViewController = storyboard?.instantiateViewController(withIdentifier: "EditViewController") as! EditViewController
        editInfoViewController.modalPresentationStyle = .popover
        editInfoViewController.preferredContentSize = CGSize(width: 320, height: 320)
        
        if let tag = sender.view?.tag {
            let infoToPass = self.getStringForTag(tag)
            editInfoViewController.type = infoToPass.first!
            editInfoViewController.textViewText = infoToPass.last!
        }
    
        if let popoverController = editInfoViewController.popoverPresentationController {
            popoverController.delegate = self
            popoverController.permittedArrowDirections = .any
            popoverController.sourceView = sender.view
            popoverController.sourceRect = sender.view!.bounds
        }
        
        self.present(editInfoViewController, animated: true, completion: nil)
    }
    
    @objc func presentEditLogin(sender: UITapGestureRecognizer) {
        let editLoginViewController = storyboard?.instantiateViewController(withIdentifier: "EditLoginViewController") as! EditLoginViewController
        editLoginViewController.modalPresentationStyle = .popover
        editLoginViewController.preferredContentSize = CGSize(width: 320, height: 320)
        
        if let emailToPass = self.emailLabel.text {
            editLoginViewController.currentEmailText = emailToPass
        }
        
        if let popoverController = editLoginViewController.popoverPresentationController {
            popoverController.delegate = self
            popoverController.permittedArrowDirections = .any
            popoverController.sourceView = self.emailLabel
            popoverController.sourceRect = self.emailLabel.bounds
        }
        
        self.present(editLoginViewController, animated: true, completion: nil)

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
            
            self.sideMenuButton.setImage(UIImage(named: "menuBlueS"), for: .normal)
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
            
            self.notificationButton.setImage(UIImage(named: "notificationBlueS"), for: .normal)
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
    
    // MARK: - CamDelegate
    
    func passImage(_ image: UIImage) {
        self.backgroundPicImageView.image = image
        self.logBackgroundPicEdited()
        self.uploadBackgroundPic()
    }
    
    func passVideo(_ url: URL) {}
    
    // MARK: - Image Picker
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info:[String: Any]) {
        if let selectedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
            
            switch self.imagePickerType {
            case "background":
                self.backgroundPicImageView.image = selectedImage
                self.logBackgroundPicEdited()
                self.uploadBackgroundPic()
              
            default:
                self.profilePicImageView.image = selectedImage
                self.logProfPicEdited()
                self.view.layoutIfNeeded()
                self.profilePicImageView.layer.cornerRadius = self.profilePicImageView.frame.size.width/2
                self.profilePicImageView.clipsToBounds = true
                self.profilePicImageView.layer.borderWidth = 2.5
                self.profilePicImageView.layer.borderColor = UIColor.white.cgColor
                
                self.uploadPic("small")
                self.uploadPic("large")
            }
            
        }
        
        self.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func selectPicSource() {
        DispatchQueue.main.async(execute: {
            self.imagePickerType = "profile"
            
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let takeSelfieAction = UIAlertAction(title: "Take a Selfie!", style: .default, handler: { action in
                    self.imagePicker.sourceType = .camera
                    self.imagePicker.cameraCaptureMode = .photo
                    self.imagePicker.cameraDevice = .front
                    self.present(self.imagePicker, animated: true, completion: nil)
                })
                alertController.addAction(takeSelfieAction)
            }
            
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                let choosePhotoLibraryAction = UIAlertAction(title: "Choose from Photo Library", style: .default, handler: { action in
                    self.imagePicker.sourceType = .photoLibrary
                    self.present(self.imagePicker, animated: true, completion: nil)
                })
                alertController.addAction(choosePhotoLibraryAction)
            }
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            alertController.view.tintColor = self.misc.flocalBlue
            self.misc.playSound("button_click.wav", start: 0)
            self.present(alertController, animated: true, completion: nil)
        })
    }
    
    @objc func selectBackgroundSource() {
        DispatchQueue.main.async(execute: {
            self.imagePickerType = "background"
            
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let takePicAction = UIAlertAction(title: "Use Camera", style: .default, handler: { action in
                    self.performSegue(withIdentifier: "fromMeToCamera", sender: self)
                })
                alertController.addAction(takePicAction)
            }
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                let choosePhotoLibraryAction = UIAlertAction(title: "Choose from Photo Library", style: .default, handler: { action in
                    self.imagePicker.sourceType = .photoLibrary
                    self.present(self.imagePicker, animated: true, completion: nil)
                })
                alertController.addAction(choosePhotoLibraryAction)
            }
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            alertController.view.tintColor = self.misc.flocalBlue
            self.misc.playSound("button_click.wav", start: 0)
            self.present(alertController, animated: true, completion: nil)
        })
    }
    
    func setImagePicker() {
        self.imagePicker.delegate = self
        self.imagePicker.allowsEditing = true
        self.imagePicker.modalPresentationStyle = .fullScreen
    }

    // MARK: - Popover
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }

    // MARK: - Notification Center
    
    func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.observeMe), name: Notification.Name("addFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.removeObserverForMe), name: Notification.Name("removeFirebaseObservers"), object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name("addFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("removeFirebaseObservers"), object: nil)
    }
    
    // MARK: - Misc
    
    func displayAlert(_ alertTitle: String, alertMessage: String) {
        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        alertController.view.tintColor = misc.flocalBlue
        DispatchQueue.main.async(execute: {
            self.present(alertController, animated: true, completion: nil)
        })
    }
    
    func getStringForTag(_ tag: Int) -> [String] {
        switch tag {
        case 1:
            return ["handle", self.handleLabel.text!]
        case 2:
            return ["description", self.descriptionLabel.text!]
        case 3:
            return ["email", self.emailLabel.text!]
        case 4:
            return ["name", self.nameLabel.text!]
        case 5:
            return ["phone", self.phoneLabel.text!]
        case 6:
            return ["birthday", self.birthdayLabel.text!]
        default:
            return ["error", "error"]
        }
    }
    
    // MARK: - Analytics
    
    func logViewMe() {
        Analytics.logEvent("viewMe_iOS", parameters: [
            "myID": self.myID as NSObject
            ])
    }
    
    func logProfPicEdited() {
        Analytics.logEvent("editedProfilePic_iOS", parameters: [
            "myID": self.myID as NSObject
            ])
    }
    
    func logBackgroundPicEdited() {
        Analytics.logEvent("editedBackgroundPic_iOS", parameters: [
            "myID": self.myID as NSObject
            ])
    }
    
    // MARK: - Storage
    
    func uploadPic(_ size: String) {
        var picSized: UIImage!
        let picImage = self.profilePicImageView.image
        let sourceWidth = picImage!.size.width
        let sourceHeight = picImage!.size.height
        
        var scaleFactor: CGFloat!
        switch size {
        case "small":
            if sourceWidth > sourceHeight {
                scaleFactor = 100/sourceWidth
            } else {
                scaleFactor = 100/sourceHeight
            }
        default:
            if sourceWidth > sourceHeight {
                scaleFactor = 300/sourceWidth
            } else {
                scaleFactor = 300/sourceHeight
            }
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
            let profilePicRef = self.storageRef.child("profilePic/\(self.myID)_\(size).jpg")
            profilePicRef.putData(newPicData, metadata: metadata) { metadata, error in
                if let error = error {
                    self.displayAlert("Upload Error", alertMessage: "Your profile pic may not have been uploaded. Please try again or report the bug if it persists.")
                    print(error.localizedDescription)
                    return
                } else {
                    if size == "large" {
                        let downloadURL = metadata!.downloadURL()
                        let urlString = downloadURL!.absoluteString
                        self.ref.child("users").child(self.myID).child("profilePicURLString").setValue(urlString)
                        self.profilePicImageView.sd_setImage(with: downloadURL, placeholderImage: nil, options: SDWebImageOptions.refreshCached)
                    }
                    print("upload success")
                }
            }
        }
    }
    
    func uploadBackgroundPic() {
        var picSized: UIImage!
        let picImage = self.backgroundPicImageView.image
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
            let backgroundPicRef = self.storageRef.child("backgroundPic/\(self.myID).jpg")
            backgroundPicRef.putData(newPicData, metadata: metadata) { metadata, error in
                if let error = error {
                    self.displayAlert("Upload Error", alertMessage: "Your background pic may not have been uploaded. Please try again or report the bug if it persists.")
                    print(error.localizedDescription)
                    return
                } else {
                    print("upload success")
                    let downLoadURL = metadata!.downloadURL()
                    self.backgroundPicImageView.sd_setImage(with: downLoadURL, placeholderImage: nil, options: SDWebImageOptions.refreshCached)
                }
            }
        }
    }
    
    func downloadProfilePic() {
        let profilePicRefLarge = self.storageRef.child("profilePic/\(self.myID)_large.jpg")
        profilePicRefLarge.downloadURL { url, error in
            if let error = error {
                print(error.localizedDescription)
                if let handle = UserDefaults.standard.string(forKey: "handle.flocal") {
                    self.profilePicImageView.image = self.misc.setDefaultPic(handle)
                } else {
                    self.profilePicImageView.image = UIImage(named: "me")
                }
            } else {
                self.profilePicImageView.sd_setImage(with: url)
            }
        }
    }
    
    func downloadBackgroundPic() {
        let backgroundPicRef = self.storageRef.child("backgroundPic/\(self.myID).jpg")
        backgroundPicRef.downloadURL { url, error in
            if let error = error {
                print(error.localizedDescription)
                self.addBackgroundLabel.isHidden = false
            } else {
                self.addBackgroundLabel.isHidden = true
                self.backgroundPicImageView.sd_setImage(with: url)
            }
        }
    }
    
    // MARK: - Firebase
    
    @objc func observeMe() {
        self.removeObserverForMe()
        
        let meRef = self.ref.child("users").child(self.myID)
        meRef.observeSingleEvent(of: .value, with: { (snapshot) -> Void in
            if let dict = snapshot.value as? [String:Any] {
                let postPoints = dict["postPoints"] as? Int ?? 0
                let replyPoints = dict["replyPoints"] as? Int ?? 0
                let points = postPoints + replyPoints
                self.pointsLabel.text = "\(points) points"
                self.pointsLabel.textColor = self.misc.setPointsColor(points, source: "profile")
                
                let followersCount = dict["followersCount"] as? Int ?? 0
                self.followersLabel.text = "\(followersCount) followers"
                self.followersLabel.textColor = self.misc.setFollowersColor(followersCount)
                
                let handle = dict["handle"] as? String ?? "error"
                self.handleLabel.text = "@\(handle)"
                
                self.descriptionLabel.text = dict["description"] as? String ?? "error"
                self.emailLabel.text = dict["email"] as? String ?? "error"
                self.nameLabel.text = dict["name"] as? String ?? "error"
                self.phoneLabel.text = dict["phoneNumber"] as? String ?? "error"
                self.birthdayLabel.text = dict["birthday"] as? String ?? "error"
            }
        })
    }
    
    @objc func removeObserverForMe() {
        let meRef = self.ref.child("users").child(self.myID)
        meRef.removeAllObservers()
    }
}
