//
//  PostViewController.swift
//  flocal
//
//  Created by George Tang on 6/18/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseDatabase
import FirebaseStorage
import FirebaseAnalytics
import GeoFire
import SDWebImage
import AVKit
import AVFoundation
import MobileCoreServices
import Alamofire

class PostViewController: UIViewController, UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, CamDelegate {
    
    // MARK: - Outlets
    
    @IBOutlet weak var postPicAspectSquare: NSLayoutConstraint!
    @IBOutlet weak var postPicAspectWide: NSLayoutConstraint!
    @IBOutlet weak var postPicTop: NSLayoutConstraint!
    @IBOutlet weak var postPicImageView: UIImageView!
    @IBOutlet weak var playImageView: UIImageView!
    
    @IBOutlet weak var textView: UITextView!
    
    @IBOutlet weak var characterCountLabel: UILabel!
    
    @IBOutlet weak var cameraButton: UIButton!
    @IBAction func cameraButtonTapped(_ sender: Any) {
        self.selectPicSource()
    }
    
    @IBOutlet weak var sendButton: UIButton!
    @IBAction func sendButtonTapped(_ sender: Any) {
        self.writePost()
    }
    
    @IBOutlet weak var cancelButton: UIButton!
    @IBAction func cancelButtonTapped(_ sender: Any) {
        self.misc.postToNotificationCenter("dismissWritePostVC")
        self.dismissKeyboard()
    }
    
    // MARK: - Vars 
    
    var myID: String = "0"
    var myProfilePicURL: URL?
    var homeSegment: Int = 0
    var blockedBy: [String] = []
    let misc = Misc()
    
    var width: CGFloat = 320
    var height: CGFloat = 320
    var keyboardHeight: CGFloat = 200
    var postPicURL: URL!
    var postVidURL: URL!
    var postVidPreviewURL: URL!

    var imageVideoType: String = "text"
    var image: UIImage!
    var imageVideoURL: URL!
    var imagePicker = UIImagePickerController()
    
    var longitude: Double = -122.258542
    var latitude: Double = 37.871906
    
    var ref = Database.database().reference()
    let storageRef = Storage.storage().reference()
    let geoFirePosts = GeoFire(firebaseRef: Database.database().reference().child("posts_location"))

    var activityView = UIView()
    var activityIndicator = UIActivityIndicatorView()
    var activityLabel = UILabel()
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.playImageView.isHidden = true
        self.formatTextView()
        self.setImageTap()
        self.setImagePicker()
        
        self.myID = misc.setMyID()
        if self.myID == "0" {
            self.dismiss(animated: false, completion: nil)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.portrait)
        switch self.imageVideoType {
        case "image":
            self.hidePostPic(false)
            self.postPicImageView.image = self.image
            if let url = self.imageVideoURL {
                self.postPicImageView.sd_setImage(with: url)
            }
        case "video":
            self.hidePostPic(false)
            self.postPicImageView.image = self.image
        default:
            self.hidePostPic(true)
        }
        
        self.downloadMyProfilePicURL()
        self.observeBlocked()
        self.sendButton.isEnabled = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if self.imageVideoType == "text" {
            self.textView.becomeFirstResponder()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
        self.removeObserverForBlocked()
        self.activityView.removeFromSuperview()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "fromPostToViewImage" {
            if let vc = segue.destination as? ViewImageViewController {
                vc.parentSource = "writePost"
                vc.image = self.image
                vc.picURL = self.imageVideoURL
                misc.setRotateView(self.image)
            }
        }
        
        if segue.identifier == "fromPostToViewVideo" {
            if let vc = segue.destination as? ViewVideoViewController {
                vc.parentSource = "writePost"
                vc.previewImage = self.image
                vc.vidURL = self.imageVideoURL
                misc.setRotateView(self.image)
            }
        }
        
        if segue.identifier == "fromPostToCamera" {
            if let vc = segue.destination as? CameraViewController {
                if self.imageVideoType == "image" {
                    vc.isImage = true
                } else {
                    vc.isImage = false
                }
                vc.parentSource = "post"
                vc.isFront = false
            }
        }
    }
    
    @objc func presentImageVideo() {
        if self.imageVideoType == "image" {
            self.performSegue(withIdentifier: "fromPostToViewImage", sender: self)
        } else {
            self.performSegue(withIdentifier: "fromPostToViewVideo", sender: self)
        }
    }
    
    func setImageTap() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.presentImageVideo))
        self.postPicImageView.addGestureRecognizer(tap)
    }
    
    func writeHomeSegment() {
        if self.homeSegment == 1 {
            self.homeSegment = 0
        }
        
        UserDefaults.standard.set(self.homeSegment, forKey: "homeSegment.flocal")
        UserDefaults.standard.synchronize()
        
        self.misc.postToNotificationCenter("setHomeSegment")
    }
    
    // MARK - CamDelegate
    
    func passImage(_ image: UIImage) {
        self.postPicImageView.image = image
        self.image = image
        self.imageVideoType = "image"
        self.playImageView.isHidden = true
        self.hidePostPic(false)
    }
    
    func passVideo(_ url: URL) {
        self.image = self.generatePreviewImage(url).0
        self.imageVideoType = "video"
        self.imageVideoURL = url
        if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(url.path) {
            UISaveVideoAtPathToSavedPhotosAlbum(url.path, self, nil, nil)
        }
        self.playImageView.isHidden = false
        self.hidePostPic(false)
    }
    
    // MARK: - Image Picker
    
    func imagePickerController(_ picker:UIImagePickerController, didFinishPickingMediaWithInfo info:[String: Any]) {
        if let selectedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
            self.postPicImageView.image = selectedImage
            self.image = selectedImage
            self.imageVideoType = "image"
            self.playImageView.isHidden = true
            self.hidePostPic(false)
        }
        
        self.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        if self.imageVideoType == "text" {
            self.hidePostPic(true)
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    func selectPicSource() {
        DispatchQueue.main.async(execute: {
            self.dismissKeyboard()
            
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let takeVideoAction = UIAlertAction(title: "Record Video", style: .default, handler: { action in
                    self.imageVideoType = "video"
                    self.performSegue(withIdentifier: "fromPostToCamera", sender: self)
                })
                alertController.addAction(takeVideoAction)
                
                let takePhotoAction = UIAlertAction(title: "Take Photo", style: .default, handler: { action in
                    self.imageVideoType = "image"
                    self.performSegue(withIdentifier: "fromPostToCamera", sender: self)
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
    
    // MARK: - MP4/Video
    
    func encodeVideo(_ videoURL: URL) -> URL? {
        let avAsset = AVURLAsset(url: videoURL)
        let startDate = Date()
        let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetPassthrough)
        
        let docDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let myDocPath = NSURL(fileURLWithPath: docDir).appendingPathComponent("temp.mp4")?.absoluteString
        
        let docDir2 = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] as NSURL
        
        let filePath = docDir2.appendingPathComponent("rendered-Video.mp4")
        deleteFile(filePath!)
        
        if FileManager.default.fileExists(atPath: myDocPath!){
            do{
                try FileManager.default.removeItem(atPath: myDocPath!)
            }catch let error{
                print(error)
            }
        }
        
        exportSession?.outputURL = filePath
        exportSession?.outputFileType = AVFileType.mp4
        exportSession?.shouldOptimizeForNetworkUse = true
        
        let start = CMTimeMakeWithSeconds(0.0, 0)
        let range = CMTimeRange(start: start, duration: avAsset.duration)
        exportSession?.timeRange = range
        
        var outputURL: URL? = nil
        exportSession!.exportAsynchronously{() -> Void in
            switch exportSession!.status{
            case .failed:
                print("\(exportSession!.error!)")
            case .cancelled:
                print("Export cancelled")
            case .completed:
                let endDate = Date()
                let time = endDate.timeIntervalSince(startDate)
                print(time)
                print("Successfull")
                outputURL = exportSession?.outputURL
            default:
                break
            }
        }
        
        return outputURL
    }
    
    func deleteFile(_ filePath:URL) {
        guard FileManager.default.fileExists(atPath: filePath.path) else{
            return
        }
        do {
            try FileManager.default.removeItem(atPath: filePath.path)
        }catch{
            fatalError("Unable to delete file: \(error) : \(#function).")
        }
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
            textView.text = "Post for the peeps around you... (tag others with @theirHandle)"
            textView.textColor = .lightGray
        }
    }

    func formatTextView() {
        self.textView.delegate = self
        self.textView.textColor = .lightGray
        self.textView.text = "Post for the peeps around you... (tag others with @theirHandle)"
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
        alertController.view.tintColor = misc.flocalColor
        DispatchQueue.main.async(execute: {
            self.sendButton.isEnabled = true
            self.activityView.removeFromSuperview()
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
    
    func hidePostPic(_ bool: Bool) {
        if bool {
            self.postPicImageView.isHidden = true
            self.postPicTop.constant = -self.postPicImageView.frame.height - 8
        } else {
            self.postPicImageView.isHidden = false
            self.postPicTop.constant = 8
            let img = self.postPicImageView.image
            let w = img!.size.height
            let h = img!.size.width
            if w > h {
                self.postPicAspectWide.isActive = true
                self.postPicAspectSquare.isActive = false
            } else {
                self.postPicAspectWide.isActive = false
                self.postPicAspectSquare.isActive = true
            }
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: - Analytics
    
    func logViewWritePost() {
        Analytics.logEvent("viewWritePost_iOS", parameters: [
            "myID": self.myID as NSObject
            ])
    }
    
    func logPostSent(_ postID: String) {
        let myLocation = UserDefaults.standard.bool(forKey: "myLocation.flocal")

        Analytics.logEvent("sentPost_iOS", parameters: [
            "myID": self.myID as NSObject,
            "postID": postID as NSObject,
            "type": self.imageVideoType as NSObject,
            "atMyLocation": myLocation as NSObject,
            "longitude": self.longitude as NSObject,
            "latitude": self.latitude as NSObject
            ])
    }
    
    func logUserTagged(_ postID: String, userID: String, handle: String) {
        Analytics.logEvent("taggedUserInPost_iOS", parameters: [
            "postID": postID as NSObject,
            "myID": self.myID as NSObject,
            "userID": userID as NSObject,
            "userHandle": handle as NSObject
            ])
    }
    
    // MARK: - Storage
    
    typealias CompletionHandler = (_ success:Bool) -> Void
    
    func uploadPostPic(_ postID: String, completionHandler: @escaping CompletionHandler) {
        var picSized: UIImage!
        let picImage = self.image
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
            let postPicRef = self.storageRef.child("postPic/\(postID).jpg")
            postPicRef.putData(newPicData, metadata: metadata) { metadata, error in
                if let error = error {
                    print(error.localizedDescription)
                    completionHandler(false)
                } else {
                    print("upload success")
                    self.postPicURL = metadata!.downloadURL()
                    completionHandler(true)
                }
            }
        }
    }
    
    func uploadPostVidPreview(_ postID: String) {
        if let picImage = self.image {
            var picSized: UIImage!
            let sourceWidth = picImage.size.width
            let sourceHeight = picImage.size.height
            
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
            picImage.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
            picSized = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            if let newPicData = UIImageJPEGRepresentation(picSized, 1) {
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                let postPicRef = self.storageRef.child("postVidPreview/\(postID).jpg")
                postPicRef.putData(newPicData, metadata: metadata) { metadata, error in
                    if let error = error {
                        print(error.localizedDescription)
                    } else {
                        print("upload success")
                        self.postVidPreviewURL = metadata!.downloadURL()
                    }
                }
            }
        }
    }
    
    func uploadPostVid(_ url: URL, postID: String, completionHandler: @escaping CompletionHandler) {
        if let mp4URL = self.encodeVideo(url) {
            let metadata = StorageMetadata()
            metadata.contentType = "video/mp4"
            
            let postVidRef = self.storageRef.child("postVid/\(postID).mp4")
            postVidRef.putFile(from: mp4URL, metadata: metadata) { metadata, error in
                if let error = error {
                    print(error.localizedDescription)
                    completionHandler(false)
                } else {
                    print("upload success")
                    self.postVidURL = metadata!.downloadURL()
                    completionHandler(true)
                }
            }
        } else {
            completionHandler(false)
            self.displayAlert("Encoding Error", alertMessage: "Sorry, we encountered an error trying to encode your video. Please report this bug.")
            return
        }
    }
    
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
    
    func writePost() {
        self.dismissKeyboard()
        self.sendButton.isEnabled = false
        
        let text = self.textView.text
        if text == "" || self.textView.textColor == .lightGray {
            self.displayAlert("Empty Post Content", alertMessage: "Please write some text to your post.")
            return
        }

        if let handle = UserDefaults.standard.string(forKey: "handle.flocal") {
            self.setPost(handle, content: text!)
        } else {
            misc.getHandle(self.myID) { handle in
                UserDefaults.standard.set(handle, forKey: "handle.flocal")
                UserDefaults.standard.synchronize()
                self.setPost(handle, content: text!)
            }
        }
    }
    
    func setPost(_ handle: String, content: String) {
        let type: String = self.imageVideoType
        let longitude = self.longitude
        let latitude = self.latitude
        let isDeleted: Bool = false
        let isEdited: Bool = false
        let reports: Int = 0
        let userID = self.myID
        let upvotes: Int = 0
        let downvotes: Int = 0
        let points: Int = 0
        let score: Double = 0
        let timestamp = misc.getTimestamp("UTC", date: Date())
        let replyCount: Int = 0
        
        let originalReverseTimestamp = misc.getCurrentReverseTimestamp()
        let originalTimestamp = -1*originalReverseTimestamp
        
        var profilePicURLString = "error"
        if self.myProfilePicURL != nil {
            profilePicURLString = self.myProfilePicURL!.absoluteString
        }
        
        var postPicURLString = "n/a"
        var postVidURLString = "n/a"
        var postVidPreviewURLString = "n/a"
        
        let postRef = self.ref.child("posts").childByAutoId()
        let postID = postRef.key
        
        var post: [String:Any?] = ["longitude": longitude, "latitude": latitude, "isDeleted": isDeleted, "isEdited": isEdited, "reports": reports, "userID": userID, "profilePicURLString": profilePicURLString, "type": type, "handle": handle, "upvotes": upvotes, "downvotes": downvotes, "points": points, "score": score, "originalContent": content, "content": content, "timestamp": timestamp, "replyCount": replyCount, "originalReverseTimestamp": originalReverseTimestamp, "originalTimestamp": originalTimestamp]
        
        switch type {
        case "image":
            self.displayActivity("uploading pic...", indicator: true)
            self.uploadPostPic(postID, completionHandler: { (success) -> Void in
                if success {
                    postPicURLString = self.postPicURL.absoluteString
                    post["postPicURLString"] = postPicURLString
                    self.completePost(postRef, post: post, postID: postID, timestamp: timestamp, longitude: longitude, latitude: latitude, originalReverseTimestamp: originalReverseTimestamp, originalTimestamp: originalTimestamp, content: content)
                } else {
                    self.displayAlert("Upload Error", alertMessage: "Your pic may not have been uploaded. Please try again or report the bug if it persists.")
                    return
                }
            })
            
        case "video":
            self.displayActivity("uploading vid...", indicator: true)
            self.uploadPostVidPreview(postID)
            self.uploadPostVid(self.imageVideoURL, postID: postID, completionHandler: { (success) -> Void in
                if success {
                    postVidURLString = self.postVidURL.absoluteString
                    postVidPreviewURLString = self.postVidPreviewURL.absoluteString
                    post["postVidURLString"] = postVidURLString
                    post["postVidPreviewURLString"] = postVidPreviewURLString
                    self.completePost(postRef, post: post, postID: postID, timestamp: timestamp, longitude: longitude, latitude: latitude, originalReverseTimestamp: originalReverseTimestamp, originalTimestamp: originalTimestamp, content: content)
                } else {
                    self.displayAlert("Upload Error", alertMessage: "Your vid may not have been uploaded. Please try again or report the bug if it persists.")
                    return
                }
            })
            
        default:
            self.completePost(postRef, post: post, postID: postID, timestamp: timestamp, longitude: longitude, latitude: latitude, originalReverseTimestamp: originalReverseTimestamp, originalTimestamp: originalTimestamp, content: content)
        }
    }
    
    func completePost(_ postRef: DatabaseReference, post: [String:Any?], postID: String, timestamp: String, longitude: Double, latitude: Double, originalReverseTimestamp: TimeInterval, originalTimestamp: TimeInterval, content: String) {
        postRef.setValue(post)
        self.postPostID(postID, timestamp: timestamp)
        self.setGeofirePost(postID, longitude: longitude, latitude: latitude)
        self.logPostSent(postID)
        self.activityView.removeFromSuperview()
        self.writeHomeSegment()
        self.misc.playSound("send_post.wav", start: 0)
        self.misc.postToNotificationCenter("dismissWritePostVC")
        self.misc.postToNotificationCenter("addFirebaseObservers")
        self.writeToAddedAndHistory(postID, originalReverseTimestamp: originalReverseTimestamp, originalTimestamp: originalTimestamp)
        self.writeTagged(postID, content: content)
        self.dismiss(animated: true, completion: nil)
    }
    
    func setGeofirePost(_ postID: String, longitude: Double, latitude: Double) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        self.geoFirePosts?.setLocation(location, forKey: postID)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5), execute: {
            self.geoFirePosts?.removeKey(postID)
        })
    }
    
    func writeToAddedAndHistory(_ postID: String, originalReverseTimestamp: TimeInterval, originalTimestamp: TimeInterval) {
        
        let userPostHistoryRef = self.ref.child("userPostHistory").child(self.myID).child(postID)
        userPostHistoryRef.child("originalReverseTimestamp").setValue(originalReverseTimestamp)
        userPostHistoryRef.child("originalTimestamp").setValue(originalTimestamp)
        userPostHistoryRef.child("points").setValue(0)
        
        let userAddedPostsRef = self.ref.child("userAddedPosts")
        userAddedPostsRef.child(self.myID).child(postID).child("originalReverseTimestamp").setValue(originalReverseTimestamp)
        userAddedPostsRef.child(self.myID).child(postID).child("originalTimestamp").setValue(originalTimestamp)

        misc.getFollowers(self.myID) { userFollowers in
            var fanoutObject: [String:Any] = [:]
            for followerID in userFollowers {
                fanoutObject["/\(followerID)/\(postID)/originalReverseTimestamp"] = originalReverseTimestamp
                fanoutObject["/\(followerID)/\(postID)/originalTimestamp"] = originalTimestamp
            }
            userAddedPostsRef.updateChildValues(fanoutObject)
        }
    }

    func writeTagged(_ postID: String, content: String) {
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
                            self.misc.writeTaggedNotification(userID, postID: postID, content: content, myID: self.myID, type: "post")
                            self.logUserTagged(postID, userID: userID, handle: tag)
                        }
                    }
                }
            })
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
    
    func postPostID(_ postID: String, timestamp: String) {
        let param: Parameters = ["longitude": self.longitude, "latitude": self.latitude, "postID": postID, "timestamp": timestamp, "userID": self.myID, "action": "post"]
        
        Alamofire.request("https://flocalApp.us-west-1.elasticbeanstalk.com", method: .post, parameters: param, encoding: JSONEncoding.default).responseJSON { response in
            if let json = response.result.value {
                print(json)
            }
        }
    }

}
