//
//  NavRushTracker.swift
//  NavRushSDK
//
//  Created by tr on 6/02/19.
//

import Foundation
import CoreLocation
import UIKit
import then
import NavRushFramework

protocol NavRushTrackerDelegate {
    /**
     Delegate Method called to obtain list of beacon UUIDs for position
     
     - Parameter tracker: This NavRushTracker instance
     - Parameter position: Current Position
     
     */
    func trackerBeaconsForPosition(tracker:NavRushTracker, position:NavRushLocationData)->Promise<[String]>
    /**
     Delegate Method called when device ranged beacons in region
     
     - Parameter tracker: This NavRushTracker instance
     - Parameter beacons: List of *NavRushBeacon* data containing RSSI values
     
     - Returns: Promise<[String]>: List of UUIDs
     */
    func trackerBeaconsRanged(tracker:NavRushTracker, beacons:[NavRushBeacon])
    /**
     Delegate Method called when device motion state changed
     
     - Parameter tracker: This NavRushTracker instance
     - Parameter isMoving: Device moving state
     
     */
    func trackerMotionChanged(tracker:NavRushTracker, isMoving:Bool)
    /**
     Delegate Method called when device GPS position changed
     
     - Parameter tracker: This NavRushTracker instance
     - Parameter position: List of GPS positions
     
     */
    func trackerGPSPositionChanged(tracker:NavRushTracker, position:[NavRushLocationData])
}

class NavRushTracker:NSObject
{
    internal let _locationManager = CLLocationManager()
    
    //List of trackers
    internal var gpsTracker:NavRushGPSTracker?
    internal var beaconsTracker:NavRushBeaconsTracker?
    internal var motionsTracker:NavRushMotionsTracker?
    
    var lastLocation:CLLocation?
    
    /// When `true`, location will reduce power usage from adjusted accuracy when backgrounded.
    var adjustLocationUseWhenBackgrounded: Bool = false
    
    /// When `true`, location will reduce power usage from adjusted accuracy based on the current battery level.
    var adjustLocationUseFromBatteryLevel: Bool = false {
        didSet {
            UIDevice.current.isBatteryMonitoringEnabled = self.adjustLocationUseFromBatteryLevel
        }
    }
    
    var isTracking = false
    internal var isMoving = false
    var delegate:NavRushTrackerDelegate?
    
    
    override init() {
        super.init()
        self.addBatteryObservers()
        self.addAppObservers()
        
        self._locationManager.delegate = self
        self._locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self._locationManager.pausesLocationUpdatesAutomatically = false //Background thread
        
        beaconsTracker = NavRushBeaconsTracker(tracker: self, delegate: self)
        gpsTracker = NavRushGPSTracker(tracker: self, delegate: self)
        motionsTracker = NavRushMotionsTracker(tracker: self, delegate: self)
    }
    
    deinit {
        self.removeAppObservers()
        self.removeBatteryObservers()
    }
    
    func startTracking()
    {
        if !isTracking
        {
            if self.locationServicesStatus == .allowedWhenInUse ||
                self.locationServicesStatus == .allowedAlways {
                //Start tracking low energy tracking to obtain initial location
                gpsTracker?.startLowPowerUpdating()
                isTracking = true
            } else {
                // request permissions based on the type of location support required.
                self.requestAlwaysLocationAuthorization()
            }
        }
    }
    
    func stopTracking()
    {
        if isTracking
        {
            gpsTracker?.stopUpdating()
            gpsTracker?.stopLowPowerUpdating()
            beaconsTracker?.stopBeaconsMonitoring()
            motionsTracker?.stopDeviceMotion()
        }
    }
}

// MARK: - NSNotifications

extension NavRushTracker {
    
    // application
    
    internal func addAppObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationDidBecomeActive(_:)), name: NSNotification.Name.UIApplicationDidBecomeActive, object: UIApplication.shared)
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationWillResignActive(_:)), name: NSNotification.Name.UIApplicationWillResignActive, object: UIApplication.shared)
    }
    
    internal func removeAppObservers() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: UIApplication.shared)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationWillResignActive, object: UIApplication.shared)
    }
    
    internal func addBatteryObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleBatteryLevelChanged(_:)), name: NSNotification.Name.UIDeviceBatteryLevelDidChange, object: UIApplication.shared)
        NotificationCenter.default.addObserver(self, selector: #selector(handleBatteryStateChanged(_:)), name: NSNotification.Name.UIDeviceBatteryStateDidChange, object: UIApplication.shared)
    }
    
    internal func removeBatteryObservers() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIDeviceBatteryLevelDidChange, object: UIApplication.shared)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIDeviceBatteryStateDidChange, object: UIApplication.shared)
    }
    
    func checkAuthorizationStatusForServices()
    {
        if self.locationServicesStatus == .denied {
            
        }
    }
    
    @objc func handleApplicationDidBecomeActive(_ notification: Notification) {
        self.checkAuthorizationStatusForServices()
        
        // if position is not updating, don't modify state
        if self.gpsTracker?.isTracking == false {
            return
        }
        
        // internally, locationManager will adjust desiredaccuracy to trackingDesiredAccuracyBackground
        if self.adjustLocationUseWhenBackgrounded == true {
            self.gpsTracker?.stopLowPowerUpdating()
        }
    }
    
    @objc func handleApplicationWillResignActive(_ notification: Notification) {
        if self.gpsTracker?.isTracking == true {
            return
        }
        
        if self.adjustLocationUseWhenBackgrounded == true {
            self.gpsTracker?.startLowPowerUpdating()
        }
        
        self.gpsTracker?.updateLocationAccuracyIfNecessary()
    }
    
    @objc func handleBatteryLevelChanged(_ notification: Notification) {
        let batteryLevel = UIDevice.current.batteryLevel
        if batteryLevel < 0 {
            return
        }
        self.gpsTracker?.updateLocationAccuracyIfNecessary()
    }
    
    @objc func handleBatteryStateChanged(_ notification: Notification) {
        self.gpsTracker?.updateLocationAccuracyIfNecessary()
    }
    
}


// MARK: - NavRushGPSTrackerDelegate

extension NavRushTracker:NavRushGPSTrackerDelegate
{
    func gpsTracker(_ gpsTracker: NavRushGPSTracker, didUpdateTrackingLocations locations: [NavRushLocationData]) {
        if let first = locations.first
        {
            
            self.delegate?.trackerBeaconsForPosition(tracker: self, position: first).then { beaconUUIDs in
                self.beaconsTracker?.startBeaconsMonitoring(uuids: beaconUUIDs)
                }.onError{err in
                    print(err)
            }
            
            if self.motionsTracker?.isTracking == false
            {
                self.motionsTracker?.startDeviceMotion()
            }
            self.delegate?.trackerGPSPositionChanged(tracker: self, position: locations)
        }
    }
    
    func gpsTracker(_ gpsTracker: NavRushGPSTracker, didFailWithError error: Error?) {
        print(error)
    }
    
    func gpsTracker(_ gpsTracker: NavRushGPSTracker, didChangeLocationAuthorizationStatus status: NavRushFramework.LocationAuthorizationStatus) {
        if status == .allowedAlways || status == .allowedWhenInUse
        {
            //Restart tracking
            self.stopTracking()
            self.startTracking()
        }
        else
        {
            //Stop tracking ?
        }
    }
}
// MARK: - NavRushBeaconsTrackerDelegate

extension NavRushTracker:NavRushBeaconsTrackerDelegate
{
    func beaconsTrackerRanged(tracker:NavRushBeaconsTracker, beacons: [NavRushBeacon]) {
        var isAnyClose = beacons.filter({ (el) -> Bool in
            return el.proximity != -1 //Limit all beacons which are close enough
        }).count >= 3 //If we have at least 3
        
        //However if any beacon is is immediate location, update server
        for beacon in beacons
        {
            if  beacon.proximity == 0
            {
                isAnyClose = true
            }
        }
        
        if isAnyClose
        {
            //Stop precise GPS tracking if any and restart Low energy
            if self.gpsTracker?.isTracking == true
            {
                self.gpsTracker?.stopUpdating()
            }
            if self.gpsTracker?.isTrackingLowPower == false
            {
                self.gpsTracker?.startLowPowerUpdating()
            }
            
            //Send information back to NavRushServer
            self.delegate?.trackerBeaconsRanged(tracker: self, beacons: beacons)
        }
        else
        {
            //Start precise GPS tracking and stop low energy
            
            if self.gpsTracker?.isTrackingLowPower == true
            {
                self.gpsTracker?.stopLowPowerUpdating()
            }
            if self.gpsTracker?.isTracking == false
            {
                self.gpsTracker?.startUpdating()
            }
            
            //Do we have beacons to track ?
            if tracker.monitoredRegions.count > 0
            {
                //Keep ranging those beacons and make decision once any of them is close enough
            }
            else
            {
                tracker.stopBeaconsMonitoring()
            }
        }
    }
}

// MARK: - NavRushMotionsTrackerDelegate

extension NavRushTracker:NavRushMotionsTrackerDelegate
{
    func motionTrackerChangedState(tracker:NavRushMotionsTracker, isMoving: Bool) {
        //Process beacons data, if device movement changes
        self.isMoving = isMoving
        self.beaconsTracker?.processCapturedBeacons()
        //Inform delegate about change
        self.delegate?.trackerMotionChanged(tracker: self, isMoving: isMoving)
    }
}

// MARK: - CLLocationManagerDelegate

extension NavRushTracker: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        if let tracker:NavRushBeaconsTracker = self.beaconsTracker
        {
            if beacons.count > 0 {
                for beacon in beacons
                {
                    let navRushBeacon = NavRushBeacon(beacon: beacon, in: region)
                    if tracker.capturedBeaconsData[navRushBeacon.getVirtualId()] == nil
                    {
                        tracker.capturedBeaconsData[navRushBeacon.getVirtualId()] = []
                    }
                    tracker.capturedBeaconsData[navRushBeacon.getVirtualId()]!.append(navRushBeacon)
                    if tracker.lastBeaconChange == nil
                    {
                        //Start capturing beacons
                        tracker.lastBeaconChange = Date()
                    }
                    else
                    {
                        //Check device status
                        if self.isMoving
                        {
                            if Date().timeIntervalSince(tracker.lastBeaconChange!) > NavRushFramework.MOVING_BEACON_BUFFER
                            {
                                tracker.processCapturedBeacons()
                            }
                        }
                        else
                        {
                            if Date().timeIntervalSince(tracker.lastBeaconChange!) > NavRushFramework.STANDING_BEACON_BUFFER
                            {
                                tracker.processCapturedBeacons()
                            }
                        }
                    }
                }
            }
        }
        
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.gpsTracker?.executeClosureAsyncOnRequestQueueIfNecessary {
            // update last location
            self.gpsTracker?.locations = locations
            // update one-shot requests
            self.gpsTracker?.processLocationRequests()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.gpsTracker?.executeClosureAsyncOnRequestQueueIfNecessary {
            DispatchQueue.main.async {
                if let tracker:NavRushGPSTracker = self.gpsTracker
                {
                    tracker.delegate?.gpsTracker(tracker, didFailWithError: error)
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.gpsTracker?.executeClosureAsyncOnRequestQueueIfNecessary {
            DispatchQueue.main.async {
                if let tracker:NavRushGPSTracker = self.gpsTracker
                {
                    tracker.delegate?.gpsTracker(tracker, didChangeLocationAuthorizationStatus: self.locationServicesStatus)
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        if let tracker:NavRushGPSTracker = self.gpsTracker
        {
            tracker.delegate?.gpsTracker(tracker, didFailWithError: error)
        }
    }
    
}

// MARK: - permissions and access

extension NavRushTracker {
    
    /// Request location authorization for in use always.
    func requestAlwaysLocationAuthorization() {
        self._locationManager.requestAlwaysAuthorization()
    }
    
    /// Request location authorization for in app use only.
    func requestWhenInUseLocationAuthorization() {
        self._locationManager.requestWhenInUseAuthorization()
    }
    
    var locationServicesStatus: NavRushFramework.LocationAuthorizationStatus {
        get {
            guard CLLocationManager.locationServicesEnabled() == true else {
                return .notAvailable
            }
            
            var status: NavRushFramework.LocationAuthorizationStatus = .notDetermined
            switch CLLocationManager.authorizationStatus() {
            case .authorizedAlways:
                status = .allowedAlways
                break
            case .authorizedWhenInUse:
                status = .allowedWhenInUse
                break
            case .denied, .restricted:
                status = .denied
                break
            case .notDetermined:
                status = .notDetermined
                break
            }
            return status
        }
    }
}
