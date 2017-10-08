//
//  ViewVideoViewController.swift
//  flocal
//
//  Created by George Tang on 8/18/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation
import FirebaseAnalytics

class ViewVideoViewController: UIViewController {
    
    // MARK: - Outlets
    
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var xButton: UIButton!
    @IBAction func xButtonTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBOutlet weak var playButton: UIButton!
    @IBAction func playButtonTapped(_ sender: Any) {
        self.tappedView()
    }
    
    // MARK: - Vars
    
    var myID: String = "0"
    var parentSource: String = "default"
    
    var postID: String = "default"
    var chatID: String = "default"
    var messageID: String = "default"
    
    var vidURL: URL!
    var previewImage: UIImage!
    
    let misc = Misc()
    var player: AVPlayer?
    
    // MARK

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.playButton.isHidden = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.tappedView))
        self.videoView.addGestureRecognizer(tap)
        self.setAVPlayer()
        
        self.myID = misc.setMyID()
        if self.myID == "0" {
            self.dismiss(animated: false, completion: nil)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
        self.logViewVideo()
        self.setNotifications()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.setRotation()
        self.player?.play()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all, rotateTo: .portrait)
        self.setPortrait()
        self.removeNotifications()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Video
    
    func setAVPlayer() {
        if let url = self.vidURL {
            self.player = AVPlayer(url: url)
            let layer = AVPlayerLayer(player: self.player)
            layer.frame = self.view.bounds
            self.view.layer.addSublayer(layer)
        }
    }
    
    @objc func tappedView() {
        if self.playButton.isHidden {
            self.player?.pause()
            self.playButton.isHidden = false
        } else {
            self.playButton.isHidden = true
            self.player?.play()
        }
    }
    
    // MARK: - Rotation 
    
    func setRotation() {
        let imageSize = self.previewImage.size
        if imageSize.height < imageSize.width {
            let landscapeValue = UIDeviceOrientation.landscapeLeft.rawValue
            UIDevice.current.setValue(landscapeValue, forKey: "orientation")
        }
    }
    
    func setPortrait() {
        let portraitValue = UIDeviceOrientation.portrait.rawValue
        UIDevice.current.setValue(portraitValue, forKey: "orientation")
    }
    
    // MARK: - Notification Center
    
    func setNotifications() {
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.player?.currentItem, queue: nil, using: { (_) in
            DispatchQueue.main.async {
                self.player?.seek(to: kCMTimeZero)
                self.player?.play()
            }
        })
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self.player?.currentItem ?? self)
    }
    
    // MARK: - Analytics

    func logViewVideo() {
        let child = self.parentSource.capitalized
        
        switch self.parentSource {
        case "post", "reply":
            Analytics.logEvent("viewVideoFromPost_iOS", parameters: [
                "myID": self.myID as NSObject,
                "postID": self.postID as NSObject
                ])
        case "chat":
            Analytics.logEvent("viewVideoFromChat_iOS", parameters: [
                "myID": self.myID as NSObject,
                "chatID": self.chatID as NSObject,
                "messageID": self.messageID as NSObject
                ])
        default:
            Analytics.logEvent("viewVideoFrom\(child)_iOS", parameters: [
                "myID": self.myID as NSObject,
                ])
        }
    }
    
}
