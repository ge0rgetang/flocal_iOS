//
//  MasterPageViewController.swift
//  flocal
//
//  Created by George Tang on 5/24/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit

class MasterPageViewController: UIPageViewController, UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    
    // MARK: - Vars
    
    let misc = Misc()

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let myID = misc.setMyID()
        if myID == "0" {
            let vc = self.orderedViewControllers[0] 
            setViewControllers([vc], direction: .forward, animated: true, completion: nil)
        } else {
            let vc = self.orderedViewControllers[2]
            setViewControllers([vc], direction: .forward, animated: true, completion: nil)
        }
        
        self.addTurnToPageObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Navigation
    
    func addTurnToPageObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToSignUp), name: Notification.Name("turnToSignUp"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToLogin), name: Notification.Name("turnToLogin"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToHome), name: Notification.Name("turnToHome"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToReply), name: Notification.Name("turnToReply"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToAdded), name: Notification.Name("turnToAdded"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToChatList), name: Notification.Name("turnToChatList"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToChat), name: Notification.Name("turnToChat"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToMe), name: Notification.Name("turnToMe"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToReportBug), name: Notification.Name("turnToReportBug"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToFeedback), name: Notification.Name("turnToFeedback"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.turnToAbout), name: Notification.Name("turnToAbout"), object: nil)
    }
    
    @objc func turnToSignUp() {
        let vc = self.orderedViewControllers[0]
        setViewControllers([vc], direction: .forward, animated: false, completion: nil)
        misc.postToNotificationCenter("scrollToTop")
    }
    
    @objc func turnToLogin() {
        let vc = self.orderedViewControllers[1]
        setViewControllers([vc], direction: .forward, animated: false, completion: nil)
        misc.postToNotificationCenter("scrollToTop")
    }
    
    @objc func turnToHome() {
        let vc = self.orderedViewControllers[2]
        setViewControllers([vc], direction: .forward, animated: false, completion: nil)
        misc.postToNotificationCenter("scrollToTop")
    }
    
    @objc func turnToReply() {
        let vc = self.orderedViewControllers[3]
        setViewControllers([vc], direction: .forward, animated: false, completion: nil)
        misc.postToNotificationCenter("scrollToTop")
    }
    
    @objc func turnToAdded(){
        let vc = self.orderedViewControllers[4]
        setViewControllers([vc], direction: .forward, animated: false, completion: nil)
        misc.postToNotificationCenter("scrollToTop")
    }
    
    @objc func turnToChatList() {
        let vc = self.orderedViewControllers[5]
        setViewControllers([vc], direction: .forward, animated: false, completion: nil)
        misc.postToNotificationCenter("scrollToTop")
    }
    
    @objc func turnToChat() {
        let vc = self.orderedViewControllers[6]
        setViewControllers([vc], direction: .forward, animated: false, completion: nil)
        misc.postToNotificationCenter("scrollToTop")
    }
    
    @objc func turnToMe() {
        let vc = self.orderedViewControllers[7]
        setViewControllers([vc], direction: .forward, animated: false, completion: nil)
        misc.postToNotificationCenter("scrollToTop")
    }
    
    @objc func turnToReportBug() {
        let vc = self.orderedViewControllers[8]
        setViewControllers([vc], direction: .forward, animated: false, completion: nil)
        misc.postToNotificationCenter("scrollToTop")
    }
    
    @objc func turnToFeedback() {
        let vc = self.orderedViewControllers[9]
        setViewControllers([vc], direction: .forward, animated: false, completion: nil)
        misc.postToNotificationCenter("scrollToTop")
    }
    
    @objc func turnToAbout() {
        let vc = self.orderedViewControllers[10]
        setViewControllers([vc], direction: .forward, animated: false, completion: nil)
        misc.postToNotificationCenter("scrollToTop")
    }

    // MARK: - PageView
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        
        guard let viewControllerIndex = self.orderedViewControllers.index(of: viewController) else {
            return nil
        }
        
        let previousIndex = viewControllerIndex - 1
        
        guard previousIndex >= 0 else {
            return nil
        }
        
        guard self.orderedViewControllers.count > previousIndex else {
            return nil
        }
        
        return self.orderedViewControllers[previousIndex]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        
        guard let viewControllerIndex = self.orderedViewControllers.index(of: viewController) else {
            return nil
        }
        
        let nextIndex = viewControllerIndex + 1
        
        let orderedViewControllersCount = self.orderedViewControllers.count
        
        guard orderedViewControllersCount != nextIndex else {
            return nil
        }
        
        guard orderedViewControllersCount > nextIndex else {
            return nil
        }
        
        return self.orderedViewControllers[nextIndex]
    }
    
    // MARK: - Views in container
    
    lazy var orderedViewControllers: [UIViewController] = {
        return [self.newViewController("SignUpNavigationController"),
                self.newViewController("LoginNavigationController"),
                self.newViewController("HomeNavigationController"),
                self.newViewController("ReplyNavigationController"),
                self.newViewController("AddedNavigationController"),
                self.newViewController("ChatListNavigationController"),
                self.newViewController("ChatNavigationController"),
                self.newViewController("MeNavigationController"),
                self.newViewController("ReportBugNavigationController"),
                self.newViewController("FeedbackNavigationController"),
                self.newViewController("AboutNavigationController")]
    } ()
    
    func newViewController(_ storyboardID: String) -> UIViewController {
        switch storyboardID {
        default:
            return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "\(storyboardID)")
        }
    }

}
