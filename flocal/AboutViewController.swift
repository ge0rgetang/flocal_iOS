//
//  AboutViewController.swift
//  flocal
//
//  Created by George Tang on 6/15/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseAnalytics
import SideMenu

class AboutViewController: UIViewController, UIPopoverPresentationControllerDelegate{
    
    // MARK: - Outlets
    
    @IBOutlet weak var notificationLabel: UILabel!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var aboutLabel: UILabel!
    
    @IBOutlet weak var creativeCommonsButton: UIButton!
    @IBAction func creativeCommonsTapped(_ sender: Any) {
        self.linkToCC()
    }
    
    @IBOutlet weak var privacyPolicyButton: UIButton!
    @IBAction func privacyPolicyTapped(_ sender: Any) {
        self.openPrivacyPolicy()
    }
    
    @IBOutlet weak var termsButton: UIButton!
    @IBAction func termsButtonTapped(_ sender: Any) {
        self.presentTermsPop()
    }
    
    @IBOutlet weak var sideMenuLicenseLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    
    // MARK: - Vars
    
    var myID: String = "0"
    
    let misc = Misc()
    var sideMenuButton = UIButton()
    var sideMenuBarButton = UIBarButtonItem()
    var notificationButton = UIButton()
    var notificationBarButton = UIBarButtonItem()
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = "About"
        self.navigationController?.navigationBar.tintColor = misc.flocalPurple
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: misc.flocalPurple]

        self.setSideMenu()
        self.setNotificationMenu()
        
        self.aboutLabel.text = self.labelText
        self.sideMenuLicenseLabel.text = self.sideMenuText
        self.authorLabel.text = self.authorText
        
        self.myID = misc.setMyID()
        if self.myID == "0" {
            misc.postToNotificationCenter("turnToLogin")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.portrait)
        self.logViewAbout()
        misc.setSideMenuIndex(7)
        misc.observeLastNotificationType(self.notificationLabel, button: self.notificationButton, color: "purple")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
        misc.removeNotificationTypeObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        misc.removeNotificationTypeObserver()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        misc.clearWebImageCache()
    }
    
    // Label Text
    
    let labelText =
        "The following icons fall under Creative Commons and were all downloaded from thenounproject.com (The Noun Project):" + "\r\n\n" +
    
        "Location, Play, by Adrien Coquet" + "\r\n" +
        "People Group, by Aliwijaya" + "\r\n" +
        "Profile, by Anath" + "\r\n" +
        "Heart, by andriwidodo" + "\r\n" +
        "More, by Aya Sofya" + "\r\n" +
        "Home Location, by BomSymbols" + "\r\n" +
        "Check Mark, by Egidio Filippetti" + "\r\n" +
        "Chat (flipped horizontal), Send, by Gregor Cresnar" + "\r\n" +
        "Fire, by HLD" + "\r\n" +
        "Sign Up, by IconDots" + "\r\n" +
        "Camera, Chat (flipped horizontal), Search, by i cons" + "\r\n" +
        "Pencil (combined with Clock), by iconsphere" + "\r\n" +
        "Key, by il Capitano" + "\r\n" +
        "Eye Mask (combined with RSS), by Jems Mayor" + "\r\n" +
        "Tag, by Jony" + "\r\n" +
        "Clock (combined with Pencil), by Kidiladon" + "\r\n" +
        "Squircle, by Luuk Lamers" + "\r\n" +
        "Add Person, by MFRA" + "\r\n" +
        "Settings, by unlimicon" + "\r\n" +
        "Happy Face, by Mooms" + "\r\n" +
        "Down Arrow, Up Arrow, by mikicon" + "\r\n" +
        "Menu, Reply, by Numero Uno" + "\r\n" +
        "Cancel, Reply, by Pawel Glen" + "\r\n" +
        "Dead, by Rodolfo Alvarez" + "\r\n" +
        "Upload Photos, by Ryan Beck" + "\r\n" +
        "Question Mark, by Tinashe Mugayi" + "\r\n" +
        "User, by Victor Akio Zukeran" + "\r\n\n" +
            
        "Additionally, all icons were modified by filling with color. A link to the Creative Commons license is provided below." + "\r\n\n" +
    
        "The following sounds fall under Creative Commons Attribution:" + "\r\n\n" +
        "pop_drip, from rcptones.com (dev_tones)" + "\r\n\n" +
        "From freesound.org:" + "\r\n\n" +
        "UI Completed Status Alert Notification SFX001.wav, by Headphaze" + "\r\n" +
        "receiving a text.wav, by hannahj40" + "\r\n" +
        "Camera Shutter, Fast, A.wav, by InspectorJ" + "\r\n" +
        "beepbeep.wav, by leviclaassen" + "\r\n" +
        "Confirmation Downward, by original_sound" + "\r\n" +
        "Level Up 01, by rhodesmas"

    // MARK: - Navigation
    
    func linkToCC() {
        if let linkURL = URL(string: "https://creativecommons.org/licenses/by/4.0/legalcode") {
            UIApplication.shared.open(linkURL, options: [:], completionHandler: nil)
        }
    }
    
    func openPrivacyPolicy() {
        if let linkURL = URL(string: "https://www.iubenda.com/privacy-policy/7955712") {
            self.logViewPrivacyPolicy()

            UIApplication.shared.open(linkURL, options: [:], completionHandler: nil)
        }
    }
    
    func presentTermsPop() {
        let termsPopViewController = storyboard?.instantiateViewController(withIdentifier: "TermsViewController") as! TermsViewController
        termsPopViewController.modalPresentationStyle = .popover
        termsPopViewController.preferredContentSize = CGSize(width: 320, height: 320)
        
        if let popoverController = termsPopViewController.popoverPresentationController {
            popoverController.delegate = self
            popoverController.sourceView = self.termsButton
            popoverController.sourceRect = self.termsButton.bounds
        }
        
        self.present(termsPopViewController, animated: true, completion: nil)
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
            
            self.sideMenuButton.setImage(UIImage(named: "menuPurpleS"), for: .normal)
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
            
            self.notificationButton.setImage(UIImage(named: "notificationPurpleS"), for: .normal)
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
    
    // MARK: - Popover
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    // MARK: - License Text
    
    let sideMenuText =
    "SideMenu is available under the MIT license. Copyright (c) 2015 Jonathan Kent <contact@jonkent.me>" + "\r\n" +
    "Alamofire is available under the MIT license. Copyright (c) 2014-2017 Alamofire Software Foundation (http://alamofire.org/)" + "\r\n\n" +
    
    "The MIT License (MIT)" + "\r\n\n" +
    
    "Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: " + "\r\n" +
    
    "The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software." + "\r\n" +
    
    "THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE." + "\r\n\n" +

    "SwiftyCam is available under the BSD 2-clause Simplified License. Copyright (c) 2016 Andrew Walz" + "\r\n\n" +
    
    "Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:" + "\r\n" +
    
    "1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer." + "\r\n" +
    
    "2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution." + "\r\n" +
    
    "THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 'AS IS' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."
    
    let authorText =
    "There was no sudden epiphany. The idea was a series of small moments that added up over time. I wanted a community network — a platform for locals. So I made an app." + "\r\n" + "-gt"
    
    // MARK: - Analytics
    
    func logViewAbout() {
        Analytics.logEvent("viewAbout_iOS", parameters: [
            "myID": self.myID as NSObject
            ])
    }
    
    func logViewPrivacyPolicy() {
        Analytics.logEvent("viewPrivacyPolicy_iOS", parameters: [
            "myID": self.myID as NSObject
            ])
    }

}
