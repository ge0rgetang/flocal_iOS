//
//  SideMenuViewController.swift
//  flocal
//
//  Created by George Tang on 6/8/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseAnalytics
import FirebaseDatabase
import FirebaseStorage
import FirebaseAuth
import SDWebImage
import AVFoundation

class SideMenuViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, UISearchResultsUpdating {
    
    // MARK: - Outlets
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var locationLabelHeight: NSLayoutConstraint!
    
    // MARK: - Vars
    
    var myID: String = "0"
    var selectedIndex: Int = 0
    var searchResults: [User] = []
    var lastContentOffset: CGFloat = 0
    var blockedBy: [String] = []
    
    var userIDToPass: String = "0"
    var isSearchActive: Bool = false
    
    var ref = Database.database().reference()
    let storageRef = Storage.storage().reference()

    let misc = Misc()
    var dimView = UIView()
    var dimViewLoc = UIView()
    var searchController: UISearchController!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "flocal"
        self.navigationController?.navigationBar.tintColor = misc.flocalColor
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: misc.flocalColor]

        let tap = UITapGestureRecognizer(target: self, action: #selector(self.presentLocation))
        self.locationLabel.addGestureRecognizer(tap)
        
        self.setTableView()
        self.setSearchController()
        self.setDimView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.portrait)
        self.tableView.reloadData()
        self.logViewMenu()
        
        self.myID = self.misc.setMyID()
        if self.myID == "0" {
            self.searchController.searchBar.isHidden = true
            self.searchController.isActive = false
            self.isSearchActive = false
            self.navigationItem.titleView = nil
        } else {
            self.searchController.searchBar.isHidden = false
            if self.isSearchActive {
                self.searchController.isActive = true
                self.isSearchActive = true
            }
            
            self.setNotifications()
            self.observeBlocked()
        }
        
        self.selectedIndex = UserDefaults.standard.integer(forKey: "sideMenuIndex.flocal")
        self.setLocationLabel()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        self.removeNotifications()
        self.removeObserverForBlocked()
        self.dimBackground(false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - TableView
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.myID == "0" {
            return 2
        }
        
        if self.searchController != nil && self.searchController.isActive && self.isSearchActive {
            if self.searchResults.isEmpty {
                return 1
            }
            return self.searchResults.count
        } else {
            return 10
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if self.myID == "0" {
            let cell = tableView.dequeueReusableCell(withIdentifier: "menuCell", for: indexPath) as! MenuTableViewCell
            if indexPath.row == 0 {
                cell.menuLabel.text = "Sign Up"
                if self.selectedIndex == indexPath.row {
                    cell.backgroundColor = misc.flocalFade
                    cell.menuImageView.image = UIImage(named: "signUpS")
                } else {
                    cell.backgroundColor = .white
                    cell.menuImageView.image = UIImage(named: "signUp")
                }
            } else {
                cell.menuLabel.text = "Login"
                if self.selectedIndex == indexPath.row {
                    cell.backgroundColor = misc.flocalFade
                    cell.menuImageView.image = UIImage(named: "loginS")
                } else {
                    cell.backgroundColor = .white
                    cell.menuImageView.image = UIImage(named: "login")
                }
            }
            return cell
        }
        
        if self.searchController.isActive && self.isSearchActive {
            if self.searchResults.isEmpty {
                let cell = tableView.dequeueReusableCell(withIdentifier: "noSearchCell", for: indexPath) as! NoContentTableViewCell
                cell.noContentLabel.text = "No peeps found :("
                cell.noContentLabel.textColor = misc.flocalColor
                cell.noContentLabel.numberOfLines = 0
                cell.noContentLabel.sizeToFit()
                cell.backgroundColor = .white
                return cell
            }
            
            let result = self.searchResults[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "searchCell", for: indexPath) as! UserListTableViewCell
            
            let handle = result.handle
            cell.handleLabel.text = "@\(handle)"
            
            if let profilPicURL = result.profilePicURL {
                cell.profilePicImageView.sd_setImage(with: profilPicURL)
            } else {
                cell.profilePicImageView.image = self.misc.setDefaultPic(handle)
            }
            cell.profilePicImageView.layer.cornerRadius = cell.profilePicImageView.frame.size.width/2
            cell.profilePicImageView.clipsToBounds = true
            
            let didIAdd = result.didIAdd
            if didIAdd {
                cell.addButton.setImage(UIImage(named: "checkS"), for: .normal)
            } else {
                cell.addButton.setImage(UIImage(named: "addS"), for: .normal)
                cell.addButton.tag = indexPath.row
                cell.addButton.addTarget(self, action: #selector(self.addUser), for: .touchUpInside)
            }
            
            cell.backgroundColor = .white
            return cell
            
        } else {
            if indexPath.row <= 3 || (indexPath.row >= 5 && indexPath.row <= 7) {
                let cell = tableView.dequeueReusableCell(withIdentifier: "menuCell", for: indexPath) as! MenuTableViewCell
                switch indexPath.row {
                case 1:
                    cell.menuLabel.text = "Peeps"
                    if self.selectedIndex == indexPath.row {
                        cell.backgroundColor = misc.flocalGreenFade
                        cell.menuImageView.image = UIImage(named: "addedS")
                    } else {
                        cell.backgroundColor = .white
                        cell.menuImageView.image = UIImage(named: "added")
                    }
                    
                case 2:
                    cell.menuLabel.text = "Chats"
                    if self.selectedIndex == indexPath.row {
                        cell.backgroundColor = misc.flocalTealFade
                        cell.menuImageView.image = UIImage(named: "chatsS")
                    } else {
                        cell.backgroundColor = .white
                        cell.menuImageView.image = UIImage(named: "chats")
                    }
                    
                case 3:
                    cell.menuLabel.text = "Me"
                    if self.selectedIndex == indexPath.row {
                        cell.backgroundColor = misc.flocalBlueFade
                        cell.menuImageView.image = UIImage(named: "meBlue")
                    } else {
                        cell.backgroundColor = .white
                        cell.menuImageView.image = UIImage(named: "me")
                    }
                    
                case 5:
                    cell.menuLabel.text = "Report Bug"
                    if self.selectedIndex == indexPath.row {
                        cell.backgroundColor = misc.flocalBlueGreyFade
                        cell.menuImageView.image = UIImage(named: "reportBugS")
                    } else {
                        cell.backgroundColor = .white
                        cell.menuImageView.image = UIImage(named: "reportBug")
                    }
                    
                case 6:
                    cell.menuLabel.text = "Feedback"
                    if self.selectedIndex == indexPath.row {
                        cell.backgroundColor = misc.flocalRedFade
                        cell.menuImageView.image = UIImage(named: "feedbackS")
                    } else {
                        cell.backgroundColor = .white
                        cell.menuImageView.image = UIImage(named: "feedback")
                    }
                    
                case 7:
                    cell.menuLabel.text = "About"
                    if self.selectedIndex == indexPath.row {
                        cell.backgroundColor = misc.flocalPurpleFade
                        cell.menuImageView.image = UIImage(named: "aboutS")
                    } else {
                        cell.backgroundColor = .white
                        cell.menuImageView.image = UIImage(named: "about")
                    }
                    
                default:
                    cell.menuLabel.text = "Home"
                    if self.selectedIndex == indexPath.row {
                        cell.backgroundColor = misc.flocalFade
                        cell.menuImageView.image = UIImage(named: "homeS")
                    } else {
                        cell.backgroundColor = .white
                        cell.menuImageView.image = UIImage(named: "home")
                    }
                }
                return cell
            }
            
            if indexPath.row == 9 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "menuButtonCell", for: indexPath) as! MenuTableViewCell
                cell.backgroundColor = .white
                cell.menuButton.layer.cornerRadius = 2.5
                cell.menuButton.addTarget(self, action: #selector(self.logOut), for: .touchUpInside)
                return cell
            }
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "menuSpacerCell", for: indexPath)
            cell.backgroundColor = misc.softGreyColor
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if self.myID == "0" {
            self.misc.playSound("menu_click.wav", start: 0.002)
            let cell = tableView.cellForRow(at: indexPath) as! MenuTableViewCell
            cell.backgroundColor = misc.flocalFade
            if indexPath.row == 0 {
                self.misc.postToNotificationCenter("turnToSignUp")
            } else {
                self.misc.postToNotificationCenter("turnToLogin")
            }
            self.dismiss(animated: true, completion: nil)
            
        } else {
            if self.searchController.isActive && self.isSearchActive {
                if !self.searchResults.isEmpty {
                    let cell = tableView.cellForRow(at: indexPath) as! UserListTableViewCell
                    cell.backgroundColor = misc.flocalFade
                    
                    let result = self.searchResults[indexPath.row]
                    let userID = result.userID
                    self.prefetchUserProfilePics(userID)
                    self.userIDToPass = userID
                    if self.myID != userID {
                        self.performSegue(withIdentifier: "fromSideMenuToUserProfile", sender: self)
                        self.dismiss(animated: true, completion: nil)
                    }
                }
            }
            
            if indexPath.row == 4 || indexPath.row == 8 || indexPath.row == 9 {
                print("tapped spacer")
            }
            
            let cell = tableView.cellForRow(at: indexPath) as! MenuTableViewCell
            self.misc.playSound("menu_click.wav", start: 0.002)
            self.misc.postToNotificationCenter("cleanNavigationStack")
            switch indexPath.row {
            case 1:
                self.misc.postToNotificationCenter("turnToAdded")
                cell.backgroundColor = misc.flocalGreenFade
            case 2:
                self.misc.postToNotificationCenter("turnToChatList")
                cell.backgroundColor = misc.flocalTealFade
            case 3:
                self.misc.postToNotificationCenter("turnToMe")
                cell.backgroundColor = misc.flocalBlueFade
            case 5:
                self.misc.postToNotificationCenter("turnToReportBug")
                cell.backgroundColor = misc.flocalBlueGreyFade
            case 6:
                self.misc.postToNotificationCenter("turnToFeedback")
                cell.backgroundColor = misc.flocalRedFade
            case 7:
                self.misc.postToNotificationCenter("turnToAbout")
                cell.backgroundColor = misc.flocalPurpleFade
            default:
                self.misc.postToNotificationCenter("turnToHome")
                cell.backgroundColor = misc.flocalFade
            }
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func setTableView() {
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 56
        self.tableView.layoutMargins = UIEdgeInsets.zero
        self.tableView.separatorInset = UIEdgeInsets.zero
        self.tableView.showsVerticalScrollIndicator = false
    }
    
    // MARK: - Navigation 
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "fromSideMenuToUserProfile" {
            if let vc = segue.destination as? UserProfileViewController {
                vc.userID = self.userIDToPass
                vc.parentSource = "sideMenu"
                vc.searchResultsToPass = self.searchResults
            }
        }
    }
    
    @objc func dismissSideMenu() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func presentLocation() {
        self.performSegue(withIdentifier: "fromSideMenuToLocation", sender: self)
    }
    
    // MARK: - Search Controller
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText != "" {
            self.isSearchActive = true
            NSObject.cancelPreviousPerformRequests(withTarget: self)
            self.perform(#selector(self.search), with: self, afterDelay: 1.0)
        }
    }
    
    func updateSearchResults(for searchController: UISearchController) {}
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.searchResults = []
        self.searchController.searchBar.text = ""
        self.searchController.resignFirstResponder()
        self.isSearchActive = false
        self.isLocationLabelHidden(false)
        self.tableView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.isSearchActive = true
        self.search()
    }
    
    @objc func setSearchActiveOff() {
        self.isLocationLabelHidden(false)
        self.searchController.isActive = false
        self.isSearchActive = false
        self.dimBackground(false)
    }
    
    func setSearchController() {
        self.searchController = UISearchController(searchResultsController: nil)
        self.searchController.searchBar.delegate = self
        self.searchController.searchBar.keyboardType = .asciiCapable
        self.searchController.searchResultsUpdater = self
        self.searchController.dimsBackgroundDuringPresentation = false
        self.definesPresentationContext = true
        self.searchController.searchBar.sizeToFit()
        self.searchController.hidesNavigationBarDuringPresentation = false
        self.searchController.searchBar.placeholder = "search handle..."
        self.searchController.searchBar.inputView?.tintColor = misc.flocalColor
        self.navigationItem.titleView = self.searchController.searchBar
        self.searchController.isActive = false
        self.isSearchActive = false
    }
    
    @objc func search() {
        if self.searchController.searchBar.text != "" {
            self.dimBackground(false)
            self.logSearch(self.searchController.searchBar.text!)
            self.searchUser()
            self.isLocationLabelHidden(true)
        }
    }
    
    // MARK: - Scroll
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let results = self.searchResults
        
        // prefetch images on scroll down
        if !results.isEmpty && self.searchController.isActive && self.isSearchActive {
            if self.lastContentOffset < scrollView.contentOffset.y {
                let visibleCells = self.tableView.visibleCells
                if let lastCell = visibleCells.last {
                    let lastIndexPath = self.tableView.indexPath(for: lastCell)
                    let lastRow = lastIndexPath!.row
                    var nextLastRow = lastRow + 5
                    
                    let maxCount = results.count
                    if nextLastRow > (maxCount - 1) {
                        nextLastRow = maxCount - 1
                    }
                    
                    if nextLastRow <= lastRow {
                        nextLastRow = lastRow
                    }
                    
                    var urlsToPrefetch: [URL] = []
                    for index in lastRow...nextLastRow {
                        let result = results[index]
                        if let profilePicURL = result.profilePicURL {
                            urlsToPrefetch.append(profilePicURL)
                        }
                    }
                    SDWebImagePrefetcher.shared().prefetchURLs(urlsToPrefetch)
                }
            }
        }
        self.lastContentOffset = scrollView.contentOffset.y
    }
    
    // MARK: - Keyboard
    
    @objc func keyboardWillShow(_ notification: Notification) {
        self.dimBackground(true)
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        self.dimBackground(false)
    }
    
    // MARK: - Location Label
    
    func setLocationLabel() {
        if self.myID == "0" {
            self.isLocationLabelHidden(true)
        } else {
            if self.searchController.isActive && self.isSearchActive {
                self.isLocationLabelHidden(true)
            } else {
                self.isLocationLabelHidden(false)
            }
        }
        
        let myLocation = UserDefaults.standard.bool(forKey: "myLocation.flocal")
        let zip = UserDefaults.standard.string(forKey: "zip.flocal") ?? "0"
        let city = UserDefaults.standard.string(forKey: "city.flocal") ?? "0"
        
        if myLocation {
            if zip != "0" {
                self.locationLabel.text = "My Location \(zip)"
            } else {
                self.locationLabel.text = "My Location"
            }
        } else {
            if city != "0" {
                if zip != "0" {
                    self.locationLabel.text = "\(city) \(zip)"
                } else {
                    self.locationLabel.text = "\(city)"
                }
            } else {
                if zip != "0" {
                    self.locationLabel.text = "\(zip)"
                } else {
                    self.locationLabel.text = "Tap to set Location"
                }
            }
        }
    }
    
    func isLocationLabelHidden(_ bool: Bool) {
        if bool {
            self.locationLabelHeight.constant = 0
        } else {
            self.locationLabelHeight.constant = 42
        }
    }
    
    // MARK: - Misc
    
    func displayAlert(_ alertTitle: String, alertMessage: String) {
        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        alertController.view.tintColor = misc.flocalColor
        DispatchQueue.main.async(execute: {
            self.present(alertController, animated: true, completion: nil)
        })
    }
    
    func setDimView() {
        self.dimView.isUserInteractionEnabled = false
        self.dimView.backgroundColor = .black
        self.dimView.alpha = 0
        self.dimView.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.height)
        self.tableView.addSubview(self.dimView)
        
        self.dimViewLoc.isUserInteractionEnabled = false
        self.dimViewLoc.backgroundColor = .black
        self.dimViewLoc.alpha = 0
        self.dimViewLoc.frame = CGRect(x: 0, y: 0, width: self.locationLabel.frame.size.width, height: self.locationLabel.frame.size.height)
        self.locationLabel.addSubview(self.dimView)
    }
    
    func dimBackground(_ bool: Bool) {
        if bool {
            self.dimView.alpha = 0.25
            self.dimViewLoc.alpha = 0.25
        } else {
            self.dimView.alpha = 0
            self.dimViewLoc.alpha = 1
        }
    }
    
    // MARK: - Notification Center
    
    func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow(_:)), name: Notification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: Notification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.dismissSideMenu), name: Notification.Name("dismissSideMenu"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.setSearchActiveOff), name: Notification.Name("setSearchActiveOff"), object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("dismissSideMenu"), object: nil)
        
        NotificationCenter.default.removeObserver(self, name: Notification.Name("setSearchActiveOff"), object: nil)
    }

    // MARK: - Analytics
    
    func logViewMenu() {
        Analytics.logEvent("viewSideMenu_iOS", parameters: [
            "myID": self.myID as NSObject
            ])
    }
    
    func logSearch(_ text: String) {
        Analytics.logEvent("viewSearchResults_iOS", parameters: [
            "myID": self.myID as NSObject,
            "searchTerm": text as NSObject,
            "searchTermLower": text.lowercased() as NSObject
            ])
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
    
    func searchUser() {
        self.searchResults = []
        let searchText = self.searchController.searchBar.text
        
        if self.searchController.isActive && self.isSearchActive && self.searchController.searchBar.text != "" {
            let lowercaseText = searchText!.lowercased()
            let handleLower = misc.handlesWithoutAt(lowercaseText).first!
            let userRef = self.ref.child("users")
            
            userRef.queryOrdered(byChild: "handleLower").queryStarting(atValue: handleLower).queryEnding(atValue: handleLower + "\u{f8ff}").queryLimited(toFirst: 21).observeSingleEvent(of: .value, with: { snapshot in
                var results: [User] = []

                if let dict = snapshot.value as? [String:Any] {
                    for entry in dict {
                        let info = entry.value as? [String:Any] ?? [:]
                        
                        let userID = entry.key
                        let amIBlocked = self.misc.amIBlocked(userID, blockedBy: self.blockedBy)
                        if !amIBlocked && (userID != self.myID) {
                            var user = User()
                            let userID = entry.key
                            user.userID = userID
                            user.handle = info["handle"] as? String ?? "error"
                            let profilePicURLString = info["profilePicURLString"] as? String ?? "error"
                            if profilePicURLString != "error" {
                                user.profilePicURL = URL(string: profilePicURLString)
                            }
                            
                            self.misc.didIAdd(userID, myID: self.myID) { didIAdd in
                                user.didIAdd = didIAdd
                            }
                            
                            results.append(user)
                        }
                    }
                }
                
                self.searchResults = results
                self.tableView.reloadData()
                self.dimBackground(false)
            })
            
        }
    }
    
    @objc func addUser(sender: UIButton) {
        let tag = sender.tag
        let result = self.searchResults[tag]
        let userID = result.userID
        
        let amIBlocked = misc.amIBlocked(userID, blockedBy: self.blockedBy)
        if !amIBlocked {
            self.misc.playSound("added_sound.wav", start: 0)
            self.searchResults[tag].didIAdd = true
            self.tableView.reloadRows(at: [IndexPath(row: tag, section: 0)], with: .none)
            
            self.misc.addUser(userID, myID: self.myID)
            self.misc.writeAddedNotification(userID, myID: self.myID)
            self.logAddedUser(userID)
        } else {
            self.displayAlert("Blocked", alertMessage: "This person has blocked you. You cannot add them.")
            return
        }
    }
    
    
    @objc func logOut() {
        let auth = Auth.auth()
        do {
            try auth.signOut()
            UserDefaults.standard.removeObject(forKey: "myID.flocal")
            UserDefaults.standard.synchronize()
            misc.postToNotificationCenter("turnToLogin")
            self.dismiss(animated: true, completion: nil)
        } catch let error as NSError {
            print(error)
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

}
