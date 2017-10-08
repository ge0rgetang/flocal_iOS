//
//  CameraViewController.swift
//  flocal
//
//  Created by George Tang on 9/25/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import SwiftyCam
import AVFoundation
import MobileCoreServices
import FirebaseDatabase
import FirebaseStorage
import FirebaseAnalytics

class CameraViewController: SwiftyCamViewController, SwiftyCamViewControllerDelegate {
    
    // MARK: - Outlets
    
    @IBOutlet weak var imageVideoView: UIView!
    
    @IBOutlet weak var switchButton: UIButton!
    @IBAction func switchButtonTapped(_ sender: Any) {
        switchCamera()
    }
    
    @IBOutlet weak var captureButton: UIButton!
    @IBAction func captureButtonTapped(_ sender: Any) {
        if self.isImage {
            misc.playSound("camera_shutter.wav", start: 0)
        } else {
            misc.playSound("start_record.wav", start: 0)
        }
        self.capture()
    }
    
    @IBOutlet weak var flashButton: UIButton!
    @IBAction func flashButtonTapped(_ sender: Any) {
        self.switchFlash()
    }
    
    @IBOutlet weak var xButton: UIButton!
    @IBAction func xButtonTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBOutlet weak var spacerLabel: UILabel!
    @IBOutlet weak var keepButton: UIButton!
    @IBAction func keepButtonTapped(_ sender: Any) {
        self.keep()
    }
    @IBOutlet weak var redoButton: UIButton!
    @IBAction func redoButtonTapped(_ sender: Any) {
        self.redo()
    }
    
    // MARK: - Vars
    
    weak var camDelegate: CamDelegate?
    
    var player: AVPlayer = AVPlayer()
    var layer: AVPlayerLayer?
    var myID: String = "0"
    
    var userID: String = "0"
    var chatID: String = "0"
    var handle: String = "0"
    var myHandle: String = "0"
    var profilePicURL: URL?
    var myProfilePicURL: URL?

    var parentSource: String = "post"
    var isImage: Bool = true
    var isFront: Bool = false
    
    var imageToPass: UIImage!
    var imageView = UIImageView()
    var urlToPass: URL!
    var downloadURL: URL!
    var previewURL: URL!
    
    var ref = Database.database().reference()
    let storageRef = Storage.storage().reference()
    
    let misc = Misc()
    var themeColor: UIColor!
    var circleView: CircleView?
    var activityView = UIView()
    var activityIndicator = UIActivityIndicatorView()
    var activityLabel = UILabel()
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.myID = misc.setMyID()
        self.setup()
        self.keepButton.layer.cornerRadius = 2.5
        self.redoButton.layer.cornerRadius = 2.5
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
        self.setCam()
        self.setNotifications()
        self.logViewCam()
        
        if self.parentSource == "chat" {
            if self.profilePicURL == nil {
                self.downloadProfilePicURL()
            }
            if self.myProfilePicURL == nil {
                self.downloadMyProfilePicURL()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all, rotateTo: .portrait)
        self.removeNotifications()
        self.removeEverything()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - SwiftyCam
    
    func swiftyCam(_ swiftyCam: SwiftyCamViewController, didTake photo: UIImage) {
        self.imageToPass = photo
        self.hideKeepRedo(false)
        self.hideImageVideoView(false)
    }
    
    func swiftyCam(_ swiftyCam: SwiftyCamViewController, didBeginRecordingVideo camera: SwiftyCamViewController.CameraSelection) {
        self.addCircleView()
    }
    
    func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFinishRecordingVideo camera: SwiftyCamViewController.CameraSelection) {
        self.resetCircleAnimation()
        self.displayActivity("processing...", indicator: true)
    }
    
    func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFinishProcessVideoAt url: URL) {
        self.urlToPass = url
        self.hideKeepRedo(false)
        self.hideImageVideoView(false)

        self.activityView.removeFromSuperview()
    }
    
    // MARK: - Camera
    
    func setup() {
        cameraDelegate = self
        flashEnabled = false
        doubleTapCameraSwitch = true
        pinchToZoom = true
        swipeToZoom = true
        swipeToZoomInverted = false
        maximumVideoDuration = 10.0
        videoQuality = .resolution1280x720
        tapToFocus = true
        shouldUseDeviceOrientation = true
        allowBackgroundAudio = true
        lowLightBoost = true 
        
        if self.isFront {
            defaultCamera = .front
        } else {
            defaultCamera = .rear
        }
        
        self.imageVideoView.isHidden = true
        self.hideKeepRedo(true)
        self.flashButton.setImage(UIImage(named: "flashOutline"), for: .normal)
        
        switch self.parentSource {
        case "background":
            self.themeColor = misc.flocalBlue
            self.keepButton.setTitle("KEEP", for: .normal)
        case "chat":
            self.themeColor = misc.flocalTeal
            self.keepButton.setTitle("SEND", for: .normal)
        default:
            self.themeColor = misc.flocalColor
            self.keepButton.setTitle("KEEP", for: .normal)
        }
        self.xButton.titleLabel?.textColor = .white
        self.keepButton.backgroundColor = self.themeColor
    }
    
    func setCam() {
        self.activityView.removeFromSuperview()
        self.imageVideoView.isHidden = true

        self.hideKeepRedo(true)
        flashEnabled = false
        self.flashButton.setImage(UIImage(named: "flashOutline"), for: .normal)
    }
    
    func hideKeepRedo(_ bool: Bool) {
        self.xButton.isHidden = false
        if bool {
            self.keepButton.isHidden = true
            self.redoButton.isHidden = true
            self.hideImageVideoView(true)
            
            self.switchButton.isHidden = false
            self.captureButton.isHidden = false
            self.flashButton.isHidden = false
        } else {
            self.keepButton.isHidden = false
            self.redoButton.isHidden = false
            
            self.switchButton.isHidden = true
            self.captureButton.isHidden = true
            self.flashButton.isHidden = true
        }
    }
    
    func hideImageVideoView(_ bool: Bool) {
        if bool {
            self.imageView.removeFromSuperview()
            self.imageVideoView.isHidden = true
        } else {
            self.imageVideoView.isHidden = false
            if self.isImage {
                self.imageView.image = self.imageToPass
                self.imageView.frame = self.imageVideoView.bounds
                self.imageView.contentMode = .scaleAspectFill
                self.imageVideoView.addSubview(self.imageView)
            } else {
                self.player = AVPlayer(url: self.urlToPass)
                self.layer = AVPlayerLayer(player: self.player)
                self.layer?.frame = self.imageVideoView.bounds
                self.imageVideoView.layer.addSublayer(self.layer!)
                self.player.play()
            }
        }
    }
    
    func switchFlash() {
        if flashEnabled {
            flashEnabled = false
            self.flashButton.setImage(UIImage(named: "flashOutline"), for: .normal)
        } else {
            flashEnabled = true
            self.flashButton.setImage(UIImage(named: "flash"), for: .normal)
        }
    }
    
    func capture() {
        if self.isImage {
            takePhoto()
        } else {
            if !isVideoRecording {
                startVideoRecording()
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 10, execute: {
                    self.stopVideoRecording()
                })
            }
        }
    }
    
    func redo() {
        self.hideKeepRedo(true)
    }
    
    func keep() {
        if self.parentSource != "chat" {
            misc.playSound("button_click.wav", start: 0)
            if self.isImage {
                self.camDelegate?.passImage(self.imageToPass)
            } else {
                self.camDelegate?.passVideo(self.urlToPass)
            }
        } else {
            if self.isImage {
                self.sendImage()
            } else {
                self.sendVideo()
            }
        }
        
        self.dismiss(animated: true, completion: nil)
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
    
    // MARK: - Misc
    
    func displayAlert(_ alertTitle: String, alertMessage: String) {
        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        alertController.view.tintColor = self.themeColor
        DispatchQueue.main.async(execute: {
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
    
    func addCircleView() {
        self.circleView = CircleView(frame: CGRect(x: self.captureButton.frame.minX, y: self.captureButton.frame.minY, width: 65, height: 65))
        self.view.addSubview(self.circleView!)
        self.circleView?.animateCircle(10.0)
        
        self.xButton.isHidden = true
        self.switchButton.isHidden = true
        self.flashButton.isHidden = true
    }
    
    func resetCircleAnimation() {
        self.circleView?.layer.removeAllAnimations()
        self.circleView?.removeFromSuperview()
        
        self.xButton.isHidden = false
        self.switchButton.isHidden = false
        self.flashButton.isHidden = false
    }
    
    func removeEverything() {
        self.resetCircleAnimation()
        self.layer?.removeFromSuperlayer()
        self.imageView.removeFromSuperview()
        self.imageVideoView.isHidden = true
    }
    
    // MARK: - Notification Center
    
    func setNotifications() {
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.player.currentItem, queue: nil, using: { (_) in
            DispatchQueue.main.async {
                self.player.seek(to: kCMTimeZero)
                self.player.play()
            }
        })
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self.player.currentItem ?? self)
    }
    
    // MARK: - Analytics
    
    func logViewCam() {
        switch self.parentSource {
        case "background":
            Analytics.logEvent("viewCameraFromMe_iOS", parameters: [
                "myID": self.myID as NSObject,
                "chatID": self.chatID as NSObject
                ])
        case "chat":
            Analytics.logEvent("viewCameraFromChat_iOS", parameters: [
                "myID": self.myID as NSObject,
                "chatID": self.chatID as NSObject
                ])
        default:
            Analytics.logEvent("viewCameraFromWritePost_iOS", parameters: [
                "myID": self.myID as NSObject
                ])
        }
    }
    
    func logChatVideoSent(_ messageID: String) {
        Analytics.logEvent("sentChatVideo_iOS", parameters: [
            "myID": self.myID as NSObject,
            "userID": self.userID as NSObject,
            "chatID": self.chatID as NSObject,
            "messageID": messageID as NSObject
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
    
    typealias CompletionHandler = (_ success:Bool) -> Void
    
    func uploadPic(_ messageID: String?, completionHandler: @escaping CompletionHandler) {
        if let newPicData = UIImageJPEGRepresentation(self.imageToPass, 1) {
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            let picRef = self.storageRef.child("chatPic/\(self.chatID)/\(messageID!).jpg")
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
    
    func uploadVidPreview(_ messageID: String?)  {
        if let newPicData = UIImageJPEGRepresentation(self.imageToPass, 1) {
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            let picRef = self.storageRef.child("chatVidPreview/\(self.chatID)/\(messageID!).jpg")
            picRef.putData(newPicData, metadata: metadata) { metadata, error in
                if let error = error {
                    print(error.localizedDescription)
                } else {
                    print("upload success")
                    self.previewURL = metadata!.downloadURL()
                }
            }
        }
    }
    
    func uploadVid(_ url: URL, messageID: String?, completionHandler: @escaping CompletionHandler) {
        if let mp4URL = self.encodeVideo(url) {
            let metadata = StorageMetadata()
            metadata.contentType = "video/mp4"
            
            let vidRef = self.storageRef.child("chatVid/\(self.chatID)/\(messageID!).mp4")
            vidRef.putFile(from: mp4URL, metadata: metadata) { metadata, error in
                if let error = error {
                    print(error.localizedDescription)
                    completionHandler(false)
                } else {
                    print("upload success")
                    self.downloadURL = metadata!.downloadURL()
                    completionHandler(true)
                }
            }
        } else {
            completionHandler(false)
            self.displayAlert("Encoding Error", alertMessage: "Sorry, we encountered an error trying to encode your video. Please report this bug.")
            return
        }
    }
    
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
    
    // MARK: - Firebase
    
    func writeChat(_ messageID: String) {
        var message: String
        var type: String
        var chatPicURLString = "n/a"
        var chatVidURLString = "n/a"
        var chatVidPreviewURLString = "n/a"
        if self.isImage {
            message = "image sent"
            type = "image"
            if let url = self.downloadURL {
                chatPicURLString = url.absoluteString
            }
            self.logChatImageSent(messageID)
        } else {
            message = "video sent"
            type = "video"
            if let url = self.downloadURL {
                chatVidURLString = url.absoluteString
            }
            if let url = self.previewURL {
                chatVidPreviewURLString = url.absoluteString
            }
            self.logChatVideoSent(messageID)
        }
        
        let timestamp = misc.getTimestamp("UTC", date: Date())
        let originalReverseTimestamp = misc.getCurrentReverseTimestamp()
        let originalTimestamp = -1*originalReverseTimestamp

        var chat: [String:Any] = ["userID": self.myID, "handle": self.myHandle, "timestamp": timestamp, "originalReverseTimestamp": originalReverseTimestamp, "originalTimestamp": originalTimestamp, "message": message, "type": type, "chatPicURLString": chatPicURLString, "chatVidURLString": chatVidURLString, "chatVidPreviewURLString": chatVidPreviewURLString]
        
        let chatRef = self.ref.child("chats").child(self.chatID)
        let messageRef = chatRef.child("messages").child(messageID)
        
        messageRef.setValue(chat)
        misc.writeAmITyping(false, chatID: self.chatID, myID: self.myID)
        
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
                self.misc.writeChatNotification(self.userID, myID: self.myID, message: message, type: type)
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
    }
    
    func sendImage() {
        let chatRef = self.ref.child("chats").child(self.chatID)
        let messageRef = chatRef.child("messages").childByAutoId()
        let messageID = messageRef.key
        
        self.displayActivity("uploading pic...", indicator: true)
        self.uploadPic(messageID, completionHandler: { (success) -> Void in
            if success {
                self.misc.playSound("sent_chat.wav", start: 0)
                self.writeChat(messageID)
                self.activityView.removeFromSuperview()
                self.misc.postToNotificationCenter("addFirebaseObservers")
                self.dismiss(animated: true, completion: nil)
            } else {
                self.displayAlert("Upload Error", alertMessage: "Your pic may not have been uploaded. Please try again or report the bug if it persists.")
                return
            }
        })
    }
    
    func sendVideo() {
        let chatRef = self.ref.child("chats").child(self.chatID)
        let messageRef = chatRef.child("messages").childByAutoId()
        let messageID = messageRef.key
        
        self.displayActivity("uploading vid...", indicator: true)
        self.uploadVidPreview(messageID)
        self.uploadVid(self.urlToPass, messageID: messageID, completionHandler: { (success) -> Void in
            if success {
                self.misc.playSound("sent_chat.wav", start: 0)
                self.writeChat(messageID)
                self.activityView.removeFromSuperview()
                self.misc.postToNotificationCenter("addFirebaseObservers")
                self.dismiss(animated: true, completion: nil)
            } else {
                self.displayAlert("Upload Error", alertMessage: "Your vid may not have been uploaded. Please try again or report the bug if it persists.")
                return
            }
        })
    }
    
}

protocol CamDelegate: class {
    func passImage(_ image: UIImage)
    func passVideo(_ url: URL)
}

class CircleView: UIView {
    var circleLayer: CAShapeLayer!
    
    override init(frame: CGRect) {
        
        super.init(frame: frame)
        self.backgroundColor = UIColor.clear
        
        let circlePath = UIBezierPath(arcCenter: CGPoint(x: frame.size.width / 2.0, y: frame.size.height / 2.0), radius: 35.0, startAngle: CGFloat(-0.5*Double.pi), endAngle: CGFloat(2*Double.pi - 0.5*Double.pi), clockwise: true)
        
        circleLayer = CAShapeLayer()
        circleLayer.path = circlePath.cgPath
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = UIColor.red.cgColor
        circleLayer.lineWidth = 5.0
        circleLayer.strokeEnd = 0.0
        layer.addSublayer(circleLayer)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func animateCircle(_ duration: TimeInterval) {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.duration = duration
        animation.fromValue = 0
        animation.toValue = 1
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        circleLayer.strokeEnd = 1.0
        circleLayer.add(animation, forKey: "animateCircle")
    }
}
