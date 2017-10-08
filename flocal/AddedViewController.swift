//
//  AddedViewController.swift
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
import GeoFire

class AddedViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CLLocationManagerDelegate {
    
    // MARK: - Outlets
    
    @IBOutlet weak var notificationLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var sortSegmentedControl: UISegmentedControl!
    
    // MARK: - Vars
    
    var myID: String = "0"
    var locals: [User] = []
    var added: [User] = []
    var followers: [User] = []
    var followersCount: Int = 0
    var blockedBy: [String] = []
    var addedIDs: [String] = []
    
    var userIDToPass: String = "0"
    
    var radiusMiles: Double = 1.5
    var radiusMeters: Double = 2414.02
    var locationManager: CLLocationManager!
    var longitude: Double = -122.258542
    var latitude: Double = 37.871906
    
    var scrollPosition: String = "top"
    var isRemoved: Bool = false
    var lastContentOffset: CGFloat = 0
    
    var ref = Database.database().reference()
    let storageRef = Storage.storage().reference()
    let geoFireUsers = GeoFire(firebaseRef: Database.database().reference().child("users_location"))
    
    let misc = Misc()
    var refreshControl = UIRefreshControl()
    var sideMenuButton = UIButton()
    var sideMenuBarButton = UIBarButtonItem()
    var notificationButton = UIButton()
    var notificationBarButton = UIBarButtonItem()
    var displayActivity: Bool = false
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setLocationManager()
        self.checkAuthorizationStatus()
        
        self.navigationItem.title = "Peeps"
        self.navigationController?.navigationBar.tintColor = misc.flocalGreen
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: misc.flocalGreen]
        self.navigationController?.hidesBarsOnSwipe = true

        let tapBar = UITapGestureRecognizer(target: self, action: #selector(self.scrollToTop))
        self.navigationController?.navigationBar.addGestureRecognizer(tapBar)
        
        self.refreshControl.addTarget(self, action: #selector(self.observePeeps), for: .valueChanged)
        self.tableView.addSubview(self.refreshControl)
        
        self.sortSegmentedControl.selectedSegmentIndex = 0
        self.sortSegmentedControl.addTarget(self, action: #selector(self.sortSegmentDidChange), for: .valueChanged)
        self.sortSegmentedControl.layer.borderWidth = 1.5
        self.sortSegmentedControl.layer.borderColor = misc.flocalGreen.cgColor
        
        self.setTableView()
        self.setSideMenu()
        self.setNotificationMenu()
        
        self.myID = misc.setMyID()
        if self.myID == "0" {
            misc.postToNotificationCenter("turnToLogin")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.portrait)
        let onfollowers = UserDefaults.standard.bool(forKey: "setToFollowers.flocal")
        if onfollowers {
            self.sortSegmentedControl.selectedSegmentIndex = 2
            UserDefaults.standard.set(false, forKey: "setToFollowers.flocal")
            UserDefaults.standard.synchronize()
        }
        
        self.tableView.reloadData()
        self.logViewPeeps()
        misc.setSideMenuIndex(1)
        self.setNotifications()
        misc.observeLastNotificationType(self.notificationLabel, button: self.notificationButton, color: "green")
        self.getMyAdded()
        
        self.setLongLat()
        if self.sortSegmentedControl.selectedSegmentIndex == 0 {
            self.checkAuthorizationStatus()
            self.locationManager.startUpdatingLocation()
        } else {
            self.observePeeps()
            self.observeBlocked()
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
        self.locationManager.stopUpdatingLocation()
        self.removeObserverForPeeps()
        self.removeObserverForBlocked()
        self.removeNotifications()
        misc.removeNotificationTypeObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.locationManager.stopUpdatingLocation()
        self.removeObserverForPeeps()
        misc.removeNotificationTypeObserver()
        self.clearArrays()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        NotificationCenter.default.removeObserver(self)
        self.removeObserverForPeeps()
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
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let peeps = self.determinePeeps()
        let count = peeps.count
        
        if peeps.isEmpty {
            return 1
        } else {
            if self.displayActivity {
                return count + 1
            }
            
            return count
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let cell = tableView.dequeueReusableCell(withIdentifier: "followerCell") as! FollowersTableViewCell
        cell.backgroundColor = .white
        cell.layer.shadowColor = UIColor.black.cgColor
        cell.layer.masksToBounds = false
        cell.layer.shadowOffset = CGSize(width: -1, height: 1)
        cell.layer.shadowOpacity = 0.42
        cell.followersLabel.text = "\(self.followersCount) followers"
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if self.sortSegmentedControl.selectedSegmentIndex == 2 {
            return UITableViewAutomaticDimension
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let peeps = self.determinePeeps()
        
        if peeps.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "noAddedCell", for: indexPath) as! NoContentTableViewCell
            switch self.sortSegmentedControl.selectedSegmentIndex {
            case 1:
                cell.noContentLabel.text = "You don't have anyone added yet. Posts from added people show up in the last section of your home page. Search for people to add in the side menu or add some popular locals in the locals sections below."
            case 2:
                cell.noContentLabel.text = "No one has added you yet. Think of your followers as your audience. Posts you make will show up in their home page. Tell your friends to add you!"
            default:
                cell.noContentLabel.text = "No locals found. Locals with the most followers show here."
            }
            cell.noContentLabel.numberOfLines = 0
            cell.noContentLabel.sizeToFit()
            cell.noContentLabel.textColor = misc.flocalGreen
            return cell
            
        }  else {
            let user = peeps[indexPath.row]
            let userID = user.userID
            var cell: UserListTableViewCell
            
            if self.displayActivity && (indexPath.row == peeps.count) {
                let cell = tableView.dequeueReusableCell(withIdentifier: "addedActivityCell", for: indexPath) as! ActivityTableViewCell
                cell.activityIndicatorView.startAnimating()
                return cell
            }
            
            if self.sortSegmentedControl.selectedSegmentIndex == 1 {
                cell = tableView.dequeueReusableCell(withIdentifier: "addedCell", for: indexPath) as! UserListTableViewCell
            } else {
                cell = tableView.dequeueReusableCell(withIdentifier: "localsCell", for: indexPath) as! UserListTableViewCell
                let didIAdd = user.didIAdd
                if self.myID == userID {
                    cell.addButton.setImage(UIImage(named: "smileyS"), for: .normal)
                } else if didIAdd {
                    cell.addButton.setImage(UIImage(named: "checkS"), for: .normal)
                } else {
                    cell.addButton.setImage(UIImage(named: "addS"), for: .normal)
                    cell.addButton.tag = indexPath.row
                    cell.addButton.addTarget(self, action: #selector(self.addUser), for: .touchUpInside)
                }
            }
            
            cell.backgroundColor = .white 
            
            let handle = user.handle
            cell.handleLabel.text = "@\(handle)"
            
            if let profilPicURL = user.profilePicURL {
                cell.profilePicImageView.sd_setImage(with: profilPicURL)
            } else {
                cell.profilePicImageView.image = self.misc.setDefaultPic(handle)
            }
            cell.profilePicImageView.layer.cornerRadius = cell.profilePicImageView.frame.size.width/2
            cell.profilePicImageView.clipsToBounds = true

            let followers = user.followersCount
            let followersFormatted = misc.setCount(followers)
            let description = user.description
            if description.lowercased() == "no description set" || description.lowercased() == "tap to add description" {
                cell.infoLabel.text = "\(followersFormatted) followers"
            } else {
                cell.infoLabel.text = "\(followersFormatted) followers" + "\r\n" + description
            }
            cell.infoLabel.numberOfLines = 0
            cell.infoLabel.sizeToFit()
            
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let peeps = self.determinePeeps()
        if !peeps.isEmpty {
            let cell = tableView.cellForRow(at: indexPath) as! UserListTableViewCell
            cell.backgroundColor = misc.flocalGreenFade
            
            let user = peeps[indexPath.row]
            let userID = user.userID
            self.userIDToPass = userID
            self.prefetchUserProfilePics(userID)
            if self.myID != userID {
                self.performSegue(withIdentifier: "fromAddedToUserProfile", sender: self)
            }
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
        if segue.identifier == "fromAddedToUserProfile" {
            if let vc = segue.destination as? UserProfileViewController {
                vc.userID = self.userIDToPass
                vc.parentSource = "added"
                let backBarButton = UIBarButtonItem()
                switch self.sortSegmentedControl.selectedSegmentIndex {
                case 0:
                    backBarButton.title = "Locals"
                case 1:
                    backBarButton.title = "Added"
                case 2:
                    backBarButton.title = "Followers"
                default:
                    backBarButton.title = "Back"
                }
                self.navigationItem.backBarButtonItem = backBarButton
            }
        }
    }
    
    // MARK: - Segmented Control
    
    @objc func sortSegmentDidChange(_ sender: UISegmentedControl) {
        self.scrollToTop()
        if self.sortSegmentedControl.selectedSegmentIndex == 0 {
            self.checkAuthorizationStatus()
            self.locationManager.startUpdatingLocation()
        } else {
            self.observePeeps()
        }
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
            
            self.sideMenuButton.setImage(UIImage(named: "menuGreenS"), for: .normal)
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
            
            self.notificationButton.setImage(UIImage(named: "notificationGreenS"), for: .normal)
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
            self.removeObserverForPeeps()
        }
        
        let offset = scrollView.contentOffset.y
        let frameHeight = scrollView.frame.size.height
        let contentHeight = scrollView.contentSize.height
        let bottomPoint = CGPoint(x: scrollView.contentOffset.x, y: contentHeight - frameHeight)

        let peeps = self.determinePeeps()
        
        if offset <= 42 {
            self.scrollPosition = "top"
            self.observePeeps()
        } else if offset == (contentHeight - frameHeight) {
            self.scrollPosition = "bottom"
            if peeps.count >= 8 {
                if self.sortSegmentedControl.selectedSegmentIndex != 0 {
                    self.displayActivity = true
                    self.tableView.reloadData()
                    scrollView.setContentOffset(bottomPoint, animated: true)
                    self.observePeeps()
                }
            }
        } else {
            self.scrollPosition = "middle"
        }
        
        // prefetch images on scroll down
        if !peeps.isEmpty {
            if self.lastContentOffset < scrollView.contentOffset.y {
                let visibleCells = self.tableView.visibleCells
                if let lastCell = visibleCells.last {
                    let lastIndexPath = self.tableView.indexPath(for: lastCell)
                    let lastRow = lastIndexPath!.row
                    var nextLastRow = lastRow + 5
                    
                    let maxCount = peeps.count
                    if nextLastRow > (maxCount - 1) {
                        nextLastRow = maxCount - 1
                    }
                    
                    if nextLastRow <= lastRow {
                        nextLastRow = lastRow
                    }
                    
                    var urlsToPrefetch: [URL] = []
                    for index in lastRow...nextLastRow {
                        let user = peeps[index]
                        
                        if let profilePicURL = user.profilePicURL{
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
            self.locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
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
        
        self.observePeeps()
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
    
    // MARK: - Misc
    
    func displayAlert(_ alertTitle: String, alertMessage: String) {
        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        alertController.view.tintColor = misc.flocalGreen
        DispatchQueue.main.async(execute: {
            self.refreshControl.endRefreshing()
            self.displayActivity = false
            self.present(alertController, animated: true, completion: nil)
        })
    }
    
    func determinePeeps() -> [User] {
        var peeps: [User]
        switch self.sortSegmentedControl.selectedSegmentIndex {
        case 1:
            peeps = self.added
        case 2:
            peeps = self.followers
        default:
            peeps = self.locals
        }
        
        return peeps
    }
    
    func didIAdd(_ userID: String) -> Bool {
        if self.addedIDs.contains(userID) {
            return true
        } else {
            return false
        }
    }
    
    func clearArrays() {
        self.locals = []
        self.added = []
        self.followers = []
    }
    
    // MARK: - Notification Center
    
    func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.observePeeps), name: Notification.Name("addFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.removeObserverForPeeps), name: Notification.Name("removeFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.scrollToTop), name: Notification.Name("scrollToTop"), object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name("addFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("removeFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("scrollToTop"), object: nil)
    }
    
    // MARK: - Analytics
    
    func logViewPeeps() {
        switch self.sortSegmentedControl.selectedSegmentIndex {
        case 1:
            Analytics.logEvent("viewAdded_iOS", parameters: [
                "myID": self.myID as NSObject
                ])
        case 2:
            Analytics.logEvent("viewFollowers_iOS", parameters: [
                "myID": self.myID as NSObject
                ])
        default:
            Analytics.logEvent("viewLocals_iOS", parameters: [
                "myID": self.myID as NSObject
                ])
        }
    }
    
    func logAddedUser(_ addedID: String) {
        Analytics.logEvent("addedUser_iOS", parameters: [
            "myID": self.myID as NSObject,
            "userID": addedID as NSObject
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
    }
    
    // MARK: - Firebase
    
    func writeMyLocation() {
        let meRef = self.ref.child("users").child(self.myID)
        meRef.child("longitude").setValue(self.longitude)
        meRef.child("latitude").setValue(self.latitude)
        
        let location = CLLocation(latitude: self.latitude, longitude: self.longitude)
        self.geoFireUsers?.setLocation(location, forKey: self.myID)
    }
    
    @objc func observePeeps() {
        self.removeObserverForPeeps()
        self.isRemoved = false
        
        let peeps = self.determinePeeps()
        let userRef = self.ref.child("users")

        if self.scrollPosition == "middle" && !peeps.isEmpty {
            if let visiblePaths = self.tableView.indexPathsForVisibleRows {
                for indexPath in visiblePaths {
                    let userID = peeps[indexPath.row].userID
                    let uidRef = userRef.child(userID)
                    uidRef.observeSingleEvent(of: .value, with: { (snapshot) -> Void in
                        if let user = snapshot.value as? [String:Any] {
                            let didIAdd = self.didIAdd(userID)
                            let formattedUser = self.formatUser(userID, didIAdd: didIAdd, dict: user)
                            switch self.sortSegmentedControl.selectedSegmentIndex {
                            case 1:
                                self.added[indexPath.row] = formattedUser
                            case 2:
                                self.followers[indexPath.row] = formattedUser
                            default:
                                self.locals[indexPath.row] = formattedUser
                            }
                        }
                    })
                }
                self.displayActivity = false
                self.tableView.reloadRows(at: visiblePaths, with: .none)
            }
            
        } else {
            var handle: String
            let alphabeticalStartRange: String = "_"
            let lastHandle = peeps.last?.handle
            
            var reverseTimestamp: TimeInterval
            let currentReverseTimestamp = misc.getCurrentReverseTimestamp()
            let lastReverseTimestamp = peeps.last?.originalReverseTimestamp
            
            if self.scrollPosition == "bottom" {
                handle = lastHandle ?? alphabeticalStartRange
                reverseTimestamp = lastReverseTimestamp ?? currentReverseTimestamp
            } else {
                handle = alphabeticalStartRange
                reverseTimestamp = currentReverseTimestamp
            }
            
            var users: [User] = []
            
            switch self.sortSegmentedControl.selectedSegmentIndex {
            case 1:
                let userAddedRef = self.ref.child("userAdded").child(self.myID)
                userAddedRef.queryOrdered(byChild: "handle").queryStarting(atValue: handle).queryLimited(toFirst: 88).observe(.value, with: { (snapshot) -> Void in
                    if let dict = snapshot.value as? [String:Any] {
                        for entry in dict {
                            let userID = entry.key
                            if let user = entry.value as? [String:Any] {
                                let formattedUser = self.formatUser(userID, didIAdd: true, dict: user)
                                users.append(formattedUser)
                            }
                        }
                        
                        if self.scrollPosition == "bottom" {
                            if lastHandle != users.last?.handle {
                                self.added.append(contentsOf: users)
                            }
                        } else {
                            self.added = users
                        }
                        self.displayActivity = false
                        self.tableView.reloadData()
                    }
                })
                
            case 2:
                let lastUserID = peeps.last?.userID
                
                let myFollowersCountRef = self.ref.child("users").child(self.myID).child("followersCount")
                myFollowersCountRef.observe(.value, with: { (snapshot) -> Void in
                    if let count = snapshot.value as? Int {
                        self.followersCount = count
                        self.tableView.reloadSections(IndexSet(integer: 0), with: .none)
                    }
                })
                
                let followersRef = self.ref.child("userFollowers").child(self.myID)
                followersRef.queryOrdered(byChild: "originalReverseTimestamp").queryStarting(atValue: reverseTimestamp).queryLimited(toFirst: 88).observe(.value, with: { (snapshot) -> Void in
                    if let dict = snapshot.value as? [String:Any] {
                        for entry in dict {
                            let userID = entry.key
                            let didIAdd = self.didIAdd(userID)
                            if let user = entry.value as? [String:Any] {
                                let formattedUser = self.formatUser(userID, didIAdd: didIAdd, dict: user)
                                users.append(formattedUser)
                            }
                        }
                        
                        if self.scrollPosition == "bottom" {
                            if lastUserID != users.last?.userID {
                                self.followers.append(contentsOf: users)
                            }
                        } else {
                            self.followers = users
                        }
                        self.displayActivity = false
                        self.tableView.reloadData()
                    }
                })
                
            default:
                var userIDs: [String] = []
                
                let center = CLLocation(latitude: self.latitude, longitude: self.longitude)
                let circleQuery = self.geoFireUsers?.query(at: center, withRadius: self.radiusMeters/1000)
                _ = circleQuery?.observe(.keyEntered, with: { (key, location) in
                    if !(userIDs.contains(key!)) {
                        userIDs.append(key!)
                    }
                })
                circleQuery?.observeReady({
                    for userID in userIDs {
                        userRef.child(userID).observeSingleEvent(of: .value, with: { (snapshot) in
                            if let dict = snapshot.value as? [String:Any] {
                                let didIAdd = self.didIAdd(userID)
                                let formattedUser = self.formatUser(userID, didIAdd: didIAdd, dict: dict)
                                users.append(formattedUser)
                            }
                        })
                    }
                    
                    users = users.sorted(by: { ($0.followersCount) > ($1.followersCount) })
                    if users.count > 100 {
                        users = Array(users[0...99])
                    }
                    
                    self.locals = users
                    self.displayActivity = false
                    self.tableView.reloadData()
                })
            }
            self.refreshControl.endRefreshing()
        }
    }
    
    @objc func removeObserverForPeeps() {
        self.isRemoved = true
        
        self.geoFireUsers?.firebaseRef.removeAllObservers()
        
        let userAddedRef = self.ref.child("userAdded").child(self.myID)
        userAddedRef.removeAllObservers()
        
        let myFollowersCountRef = self.ref.child("users").child(self.myID).child("followersCount")
        myFollowersCountRef.removeAllObservers()
        let followersRef = self.ref.child("userFollowers").child(self.myID)
        followersRef.removeAllObservers()
    }
    
    func getMyAdded() {
        let userAddedRef = self.ref.child("userAdded").child(self.myID)
        userAddedRef.observeSingleEvent(of: .value, with: { (snapshot) -> Void in
            if let dict = snapshot.value as? [String:Any] {
                self.addedIDs = Array(dict.keys)
            }
        })
    }
    
    @objc func addUser(_ sender: UIButton) {
        let tag = sender.tag
        let peeps = self.determinePeeps()
        let user = peeps[tag]
        let userID = user.userID
        let amIBlocked = misc.amIBlocked(userID, blockedBy: self.blockedBy)
        if !amIBlocked {
            misc.playSound("added_sound.wav", start: 0)
            switch self.sortSegmentedControl.selectedSegmentIndex {
            case 0:
                self.locals[tag].didIAdd = true
            case 2:
                self.followers[tag].didIAdd = true
            default:
                return
            }
            self.tableView.reloadRows(at: [IndexPath(row: tag, section: 0)], with: .none)
            
            misc.addUser(userID, myID: self.myID)
            if !self.addedIDs.contains(userID) {
                self.addedIDs.append(userID)
            }
            misc.writeAddedNotification(userID, myID: self.myID)
            self.logAddedUser(userID)
        } else {
            self.displayAlert("Blocked", alertMessage: "This person has blocked you. You cannot add them.")
            return
        }
    }
    
    func formatUser(_ userID: String, didIAdd: Bool, dict: [String:Any?]) -> User {
        var user = User()
        
        user.handle = dict["handle"] as? String ?? "error"
        user.points = dict["points"] as? Int ?? 0
        user.description = dict["description"] as? String ?? "error"
        user.followersCount = dict["followersCount"] as? Int ?? 0
        
        let profilePicURLString = dict["profilePicURLString"] as? String ?? "error"
        if profilePicURLString != "error" {
            user.profilePicURL = URL(string: profilePicURLString)
        }
        
        user.originalReverseTimestamp = dict["originalReverseTimestamp"] as? TimeInterval ?? 0
        user.didIAdd = didIAdd
        
        return user
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
