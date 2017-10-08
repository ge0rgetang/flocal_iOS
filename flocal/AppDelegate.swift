//
//  AppDelegate.swift
//  flocal
//
//  Created by George Tang on 5/8/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import UserNotifications
import Firebase
import SDWebImage

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var orientationLock = UIInterfaceOrientationMask.all
    let gcmMessageIDKey = "gcm.message_id"
    
    override init() {
        super.init()
        
        FirebaseApp.configure()
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
            
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: {_, _ in })
        } else {
            let settings: UIUserNotificationSettings =
                UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
        application.registerForRemoteNotifications()
        
        let misc = Misc()
        UINavigationBar.appearance().barTintColor = misc.softGreyColor
        UINavigationBar.appearance().isTranslucent = false
        
        SDWebImageDownloader.shared().maxConcurrentDownloads = 10
        SDWebImagePrefetcher.shared().maxConcurrentDownloads = 10
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        self.window?.endEditing(true)
        
        let misc = Misc()
        let chatID = UserDefaults.standard.string(forKey: "chatIDToPass.flocal") ?? "0"
        let myID = misc.setMyID()
        if chatID != "0" && myID != "0" {
            misc.writeAmInChat(false, chatID: chatID, myID: myID)
            misc.writeAmITyping(false, chatID: chatID, myID: myID)
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        let misc = Misc()
        misc.postToNotificationCenter("removeFirebaseObservers")
        misc.postToNotificationCenter("setSearchActiveOff")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        let misc = Misc()
        let chatID = UserDefaults.standard.string(forKey: "chatIDToPass.flocal") ?? "0"
        let myID = misc.setMyID()
        if chatID != "0" && myID != "0" {
            misc.writeAmInChat(true, chatID: chatID, myID: myID)
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        let misc = Misc()
        misc.postToNotificationCenter("addFirebaseObservers")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        let misc = Misc()
        misc.clearWebImageCache()
    }
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return self.orientationLock
    }
    
    // MARK: Push notifications
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("apnsToken: \(deviceToken)")
        Messaging.messaging().apnsToken = deviceToken
        
        if let token = Messaging.messaging().fcmToken {
            Misc().updateDeviceToken(token)
        }

//        var tokenString = ""
//        for i in 0..<deviceToken.count {
//            tokenString += String(format: "%02.2hhx", arguments: [deviceToken[i]])
//        }
//
//        UserDefaults.standard.removeObject(forKey: "deviceToken.flocal")
//        UserDefaults.standard.set(tokenString, forKey: "deviceToken.flocal")
//        UserDefaults.standard.synchronize()
//
//        let misc = Misc()
//        let myID = misc.setMyID()
//        if myID != "0" {
//            let ref = Database.database().reference()
//            ref.child("users").child(myID).child("deviceToken").setValue(tokenString)
//        }
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        Messaging.messaging().appDidReceiveMessage(userInfo)
        
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        print(userInfo)
        
        let aps = userInfo["aps"] as? NSDictionary ?? [:]
        let badgeNumber = aps["badge"] as? Int ?? 0
        UserDefaults.standard.set(badgeNumber, forKey: "badgeNumber.flocal")
        UserDefaults.standard.synchronize()
        UIApplication.shared.applicationIconBadgeNumber = badgeNumber

        let misc = Misc()
        if application.applicationState == .inactive || application.applicationState == .background {
            if let category = userInfo["category"] as? String {
                switch category {
                case "post", "tagged":
                    if let postID = userInfo["postID"] as? String {
                        UserDefaults.standard.set(true, forKey: "fromPush.flocal")
                        UserDefaults.standard.set(postID, forKey: "postIDToPass.flocal")
                        UserDefaults.standard.synchronize()
                        misc.postToNotificationCenter("turnToReply")
                    }
                case "chat":
                    if let chatID = userInfo["chatID"] as? String {
                        UserDefaults.standard.set(true, forKey: "fromPush.flocal")
                        UserDefaults.standard.set(chatID, forKey: "chatIDToPass.flocal")
                        UserDefaults.standard.synchronize()
                        misc.postToNotificationCenter("turnToChat")
                    }
                default:
                   print(userInfo)
                }
            }
        }
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Messaging.messaging().appDidReceiveMessage(userInfo)
        
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        print(userInfo)
        
        completionHandler(UIBackgroundFetchResult.newData)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Unable to register for remote notifications: \(error.localizedDescription)")
    }
    
}

@available(iOS 10, *)
extension AppDelegate : UNUserNotificationCenterDelegate {
        func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        Messaging.messaging().appDidReceiveMessage(userInfo)
            
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        print(userInfo)
        
        completionHandler([])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        print(userInfo)
        
        completionHandler()
    }
}

extension AppDelegate : MessagingDelegate {
    func messaging(_ messaging: Messaging, didRefreshRegistrationToken fcmToken: String) {
        print("Firebase registration token: \(fcmToken)")
        Misc().updateDeviceToken(fcmToken)
    }
    func messaging(_ messaging: Messaging, didReceive remoteMessage: MessagingRemoteMessage) {
        print("Received data message: \(remoteMessage.appData)")
    }
}


