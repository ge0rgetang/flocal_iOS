//
//  LocationViewController.swift
//  flocal
//
//  Created by George Tang on 7/22/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import FirebaseAnalytics
import FirebaseDatabase
import DTMHeatmap
import GeoFire
import Alamofire

class LocationViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, UITextFieldDelegate {
    
    // MARK: - Outlets
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var confirmButton: UIButton!
    @IBAction func confirmButtonTapped(_ sender: Any) {
        self.saveLocation()
    }
    
    @IBOutlet weak var myLocationButton: UIButton!
    @IBAction func myLocationButtonTapped(_ sender: Any) {
        self.checkAuthorizationStatus()
        let status =  CLLocationManager.authorizationStatus()
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            self.textField.text = "My Location"
            self.locationManager.startUpdatingLocation()
        }
    }
    
    @IBOutlet weak var xButton: UIButton!
    @IBAction func xButtonTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Vars
    
    var myID: String = "0"
    var coordinates: [[String:Any?]] = []
    var newPostIDs: [String] = []
    
    var width: CGFloat = 320
    var locationText: String = "Berkeley 94720"
    
    var radiusMiles: Double = 1.5
    var radiusMeters: Double = 2404.02
    var locationManager: CLLocationManager!
    var longitude: Double = -122.258542
    var latitude: Double = 37.871906
    
    var city: String = "Berkeley"
    var zip: String = "94720"
    
    var ref = Database.database().reference()
    let geoFireUsers = GeoFire(firebaseRef: Database.database().reference().child("users_location"))
    let geoFirePosts = GeoFire(firebaseRef: Database.database().reference().child("posts_location"))

    let misc = Misc()
    var heatMap = DTMHeatmap()
    var centerPin = MKPointAnnotation()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.textField.delegate = self 
        self.setLocationManager()
        self.checkAuthorizationStatus()
        self.setMapCenter()
        self.mapView.delegate = self
        
        self.myID = misc.setMyID()
        if self.myID == "0" {
            misc.postToNotificationCenter("turnToLogin")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.portrait)
        self.logViewLocation()
        self.setLongLat()
        let status = CLLocationManager.authorizationStatus()
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            self.locationManager.startUpdatingLocation()
        } else {
            self.observePosts()
        }
        
        self.navigationController?.navigationBar.isHidden = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.setHeatMapData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
        self.removeObserverForPosts()
        self.locationManager.stopUpdatingLocation()
    }
    
    deinit {
        self.removeObserverForPosts()
        NotificationCenter.default.removeObserver(self)
        self.locationManager.stopUpdatingLocation()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        NotificationCenter.default.removeObserver(self)
        misc.removeNotificationTypeObserver()
    }

    // MARK: - MapView
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        
        let reuseID = "skinnyDip"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseID) as? MKPinAnnotationView
        if annotationView == nil {
            annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseID)
            annotationView?.pinTintColor = misc.flocalColor
            annotationView?.canShowCallout = false
            annotationView?.isEnabled = false
            annotationView?.isUserInteractionEnabled = false
            annotationView?.animatesDrop = true
        } else {
            annotationView?.annotation = annotation
        }
        
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        return DTMHeatmapRenderer.init(overlay: overlay)
    }
    
    func setMapCenter() {
        let center = CLLocationCoordinate2DMake(self.latitude, self.longitude)
        let region = MKCoordinateRegionMakeWithDistance(center, self.radiusMeters, self.radiusMeters)
        self.mapView.setRegion(region, animated: true)
        
        self.mapView.removeAnnotation(self.centerPin)
        self.centerPin = MKPointAnnotation()
        self.centerPin.coordinate = center
        self.mapView.addAnnotation(self.centerPin)
    }
    
    func setHeatMapData() {
        let coordinates = self.coordinates
        
        self.heatMap = DTMHeatmap()
        var dict: [AnyHashable:Any] = [:]
        for coor in coordinates {
            let longitude = coor["longitude"] as? Double ?? 0
            let latitude = coor["latitude"] as? Double ?? 0
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            var mapPoint = MKMapPointForCoordinate(coordinate)
            
            let type = "{MKMapPoint=dd}"
            let value = NSValue(bytes: &mapPoint, objCType: type)
            dict[value] = 1
        }
        
        self.mapView.remove(self.heatMap)
        self.heatMap.setData(dict)
        self.mapView.add(self.heatMap)
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
            self.textField.text = "My Location"
            self.locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        var text = self.textField.text?.lowercased()
        if text == "" {
            text = "my location"
        }
        
        let geocoder = CLGeocoder()

        if text!.contains("my location") {
            var location = self.locationManager.location!.coordinate
            let long = location.longitude.roundToDecimalPlace(8)
            let lat = location.latitude.roundToDecimalPlace(8)
            self.longitude = long
            self.latitude = lat
            self.setMapCenter()
            self.writeMyLocation()
            self.textField.text = "My Location"
            
            geocoder.reverseGeocodeLocation(self.locationManager.location!, completionHandler: {(placemarks, error) -> Void in
                if error != nil {
                    self.displayLocationError(error!)
                    return
                }
                if let placemark = placemarks?.first {
                    if let city = placemark.locality {
                        self.city = city
                    }
                    if let zip = placemark.postalCode {
                        self.zip = zip
                    }
                }
            })
            
        } else {
            geocoder.geocodeAddressString(text!, completionHandler: {(placemarks, error) -> Void in
                if error != nil {
                    self.displayLocationError(error!)
                    return
                }
                if let placemark = placemarks?.first {
                    var text = ""
                    if let city = placemark.locality {
                        self.city = city
                        text.append(city)
                    }
                    if let zip = placemark.postalCode {
                        self.zip = zip
                        text.append(" \(zip)")
                    }
                    self.textField.text = text
                    self.locationText = text 
                    
                    let coordinate = placemark.location?.coordinate
                    let longitude = coordinate?.longitude
                    let latitude = coordinate?.latitude
                    self.longitude = longitude!
                    self.latitude = latitude!
                    self.setMapCenter()
                }
            })
        }
        
        self.observePosts()
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
        let myLocation = UserDefaults.standard.bool(forKey: "myLocation.flocal")
        if myLocation {
            self.textField.text = "My Location"
        } else {
            var text: String
            let city = UserDefaults.standard.string(forKey: "city.flocal") ?? "Berkeley"
            self.city = city
            text = city
            
            let zip = UserDefaults.standard.string(forKey: "zip.flocal")
            if let z = zip {
                self.zip = z
                text = city + " \(z)"
            }
            self.textField.text = text
        }
        
        let long = UserDefaults.standard.double(forKey: "longitude.flocal")
        let lat = UserDefaults.standard.double(forKey: "latitude.flocal")
        if long != 0 {
            self.longitude = long
        }
        if lat != 0 {
            self.latitude = lat
        }
    }
    
    func getMinMaxLongLat(_ distanceMiles: Double) -> [Double] {
        let delta = (distanceMiles*5280)/(364173*cos(self.longitude))
        let scaleFactor = 0.01447315953478432289213674551561
        let minLong = self.longitude - delta
        let maxLong = self.longitude + delta
        let minLat = self.latitude - (distanceMiles*scaleFactor)
        let maxLat = self.latitude + (distanceMiles*scaleFactor)
        return [minLong, maxLong, minLat, maxLat]
    }
    
    func saveLocation() {
        self.dismissKeyboard()
        
        let text = self.textField.text!
        if text == "" {
            self.displayAlert("Empty Field", alertMessage: "Please enter in a location or type in My Location")
            return
        }
        
        misc.playSound("button_click.wav", start: 0)
        var myLocation: Bool
        if text.lowercased().contains("my location") {
            myLocation = true
            self.logSetMyLocation()
        } else {
            myLocation = false
            self.logSetOtherLocation()
        }
        
        UserDefaults.standard.set(self.longitude, forKey: "longitude.flocal")
        UserDefaults.standard.set(self.latitude, forKey: "latitude.flocal")
        UserDefaults.standard.set(myLocation, forKey: "myLocation.flocal")
        UserDefaults.standard.set(self.city, forKey: "city.flocal")
        UserDefaults.standard.set(self.zip, forKey: "zip.flocal")
        UserDefaults.standard.synchronize()
        
        _ = self.navigationController?.popViewController(animated: true)
    }
    
    // MARK: - TextField
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }
        let length = text.characters.count + string.characters.count - range.length
        return length <= 255
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.text == "" {
            textField.text = self.locationText
        }
        
        self.locationManager.startUpdatingLocation()
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
    
    func dismissKeyboard() {
        self.view.endEditing(true)
    }

    // MARK: - Analytics
    
    func logViewLocation() {
        Analytics.logEvent("viewLocation_iOS", parameters: [
            "myID": self.myID as NSObject
            ])
    }
    
    func logSetMyLocation() {
        Analytics.logEvent("setMyLocation_iOS", parameters: [
            "myID": self.myID as NSObject,
            "longitude": self.latitude as NSObject,
            "latitude": self.latitude as NSObject,
            "city": self.city as NSObject,
            "zip": self.zip as NSObject
            ])
    }
    
    func logSetOtherLocation() {
        Analytics.logEvent("setOtherLocation_iOS", parameters: [
            "myID": self.myID as NSObject,
            "city": self.city as NSObject,
            "zip": self.zip as NSObject
            ])
    }
    
    // MARK: - Firebase
    
    func writeMyLocation() {
        let meRef = self.ref.child("users").child(self.myID)
        meRef.child("longitude").setValue(self.longitude)
        meRef.child("latitude").setValue(self.latitude)
        
        let location = CLLocation(latitude: self.latitude, longitude: self.longitude)
        self.geoFireUsers?.setLocation(location, forKey: self.myID)
    }
    
    func observePosts() {
        self.removeObserverForPosts()
        
        let center = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let circleQuery = self.geoFirePosts?.query(at: center, withRadius: self.radiusMeters/1000)
        _ = circleQuery?.observe(.keyEntered, with: { (key, location) in
        })
        circleQuery?.observeReady({
            self.getPostIDs()
            
            let postRef = self.ref.child("posts")
            
            var coor: [[String:Any?]] = []
            for id in self.newPostIDs {
                let newRef = postRef.child(id)
                newRef.observeSingleEvent(of: .value, with: { (snapshot) -> Void in
                    if let post = snapshot.value as? [String:Any] {
                        let longitude = post["longitude"] as? Double ?? 0
                        let latitude = post["latitude"] as? Double ?? 0
                        let coordinate: [String:Any?] = ["longitude": longitude, "latitude": latitude]
                        coor.append(coordinate)
                    }
                })
            }
            
            self.coordinates = coor
            self.mapView.remove(self.heatMap)
            self.setHeatMapData()
        })
    }
    
    func removeObserverForPosts() {
        self.geoFirePosts?.firebaseRef.removeAllObservers()
    }
    
    // MARK: - Alamofire
    
    func getPostIDs() {
        let param: Parameters = ["longitude": self.longitude, "latitude": self.latitude, "sort": "new", "action": "search"]
        
        Alamofire.request("https://flocalApp.us-west-1.elasticbeanstalk.com", method: .post, parameters: param, encoding: JSONEncoding.default).responseJSON { response in
            if let json = response.result.value {
                self.newPostIDs = json as? [String] ?? []
            }
        }
    }

}
