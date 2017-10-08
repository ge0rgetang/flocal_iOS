//
//  ViewImageViewController.swift
//  flocal
//
//  Created by George Tang on 8/18/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseAnalytics
import SDWebImage

class ViewImageViewController: UIViewController {
    
    // MARK: - Outlets
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var xButton: UIButton!
    @IBAction func xButtonTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Vars
    
    var myID: String = "0"
    var parentSource: String = "default"
    
    var postID: String = "default"
    var chatID: String = "default"
    var messageID: String = "default"
    
    var picURL: URL!
    var image: UIImage!
    
    let misc = Misc()
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let i = self.image {
            self.imageView.image = i
        }
        
        if let url = picURL {
            self.imageView.sd_setImage(with: url)
        }
        
        self.myID = misc.setMyID()
        if self.myID == "0" {
            self.dismiss(animated: false, completion: nil)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
        self.logViewImage()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.setRotation()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all, rotateTo: .portrait)
        self.setPortrait()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Rotation 
    
    func setRotation() {
        let imageSize = self.image.size
        if imageSize.height < imageSize.width {
            let landscapeValue = UIDeviceOrientation.landscapeLeft.rawValue
            UIDevice.current.setValue(landscapeValue, forKey: "orientation")
        }
    }
    
    func setPortrait() {
        let portraitValue = UIDeviceOrientation.portrait.rawValue
        UIDevice.current.setValue(portraitValue, forKey: "orientation")
    }
    
    // MARK: - Analytics
    
    
    func logViewImage() {
        let child = self.parentSource.capitalized
        
        switch self.parentSource {
        case "post", "reply":
            Analytics.logEvent("viewImageFromPost_iOS", parameters: [
                "myID": self.myID as NSObject,
                "postID": self.postID as NSObject
                ])
        case "chat":
            Analytics.logEvent("viewImageFromChat_iOS", parameters: [
                "myID": self.myID as NSObject,
                "chatID": self.chatID as NSObject,
                "messageID": self.messageID as NSObject
                ])
        default:
            Analytics.logEvent("viewImageFrom\(child)_iOS", parameters: [
                "myID": self.myID as NSObject,
                ])
        }
    }

}
