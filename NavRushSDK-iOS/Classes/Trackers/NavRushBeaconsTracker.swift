//
//  NavRushTracker.swift
//  NavRushSDK
//  Internal Class to manage tracking across iOS
//  Created by tr on 24/01/19.
//

import Foundation
import CoreLocation
import NavRushFramework

protocol NavRushBeaconsTrackerDelegate {
    /**
     Delegate Method called when device ranged beacons in region
     
     - Parameter tracker: This NavRushBeaconsTracker instance
     - Parameter beacons: List of *NavRushBeacon* data containing RSSI values
     
     */
    func beaconsTrackerRanged(tracker:NavRushBeaconsTracker, beacons:[NavRushBeacon])
}

class NavRushBeaconsTracker:NSObject {
    unowned let navRushTracker : NavRushTracker
    var delegate:NavRushBeaconsTrackerDelegate?
    var isTracking = false
    var monitoredRegions:[CLRegion] = []
    var capturedBeaconsData:[String:[NavRushBeacon]] = [:]
    internal var lastBeaconChange:Date?
    
    /**
     NavRushBeaconsTracker Constructor
     
     - Parameter tracker: Common NavRush Tracker
     - Parameter delegate: Listens to beacon ranged events
     
     - Returns: NavRushBeaconsTracker
     */
    init(tracker:NavRushTracker, delegate:NavRushBeaconsTrackerDelegate) {
        self.navRushTracker = tracker
        super.init()
        self.delegate = delegate
    }
    
    /**
     Starts beacons ranging for selected UUIDs
     
     - Parameter uuids: List of beacon UUIDs
     
     */
    func startBeaconsMonitoring(uuids:[String])
    {
        //Restart tracking
        if isTracking
        {
            self.stopBeaconsMonitoring()
        }
        
        if CLLocationManager.authorizationStatus() != .authorizedAlways {
            self.navRushTracker._locationManager.requestAlwaysAuthorization()
        }
        
        //Remove duplicates
        let uniqueBeaconUUIDs = Array(Set(uuids))
        if uniqueBeaconUUIDs.count < 1
        {
            //Nothing to track
            isTracking = false
            return
        }
        
        if CLLocationManager.isMonitoringAvailable(for:
            CLBeaconRegion.self) {
            for beaconUUID in uniqueBeaconUUIDs
            {
                // Match all beacons with the specified UUID
                let proximityUUID = UUID(uuidString:beaconUUID)
                //Local UUID
                let beaconID = UUID.init().uuidString
                
                // Create the region and begin monitoring it.
                let beaconRegion = CLBeaconRegion(proximityUUID: proximityUUID!,
                                                  identifier: beaconID)
                
                self.navRushTracker._locationManager.startRangingBeacons(in: beaconRegion)
                self.monitoredRegions.append(beaconRegion)
            }
            self.isTracking = true
            print("NavRushBeaconsTracker started tracking")
        }
    }
    
    /**
     Stops beacons ranging, remove references
     
     
     */
    func stopBeaconsMonitoring()
    {
        if !isTracking
        {
            return
        }
        for region in self.monitoredRegions
        {
            self.navRushTracker._locationManager.stopMonitoring(for: region)
        }
        self.monitoredRegions = []
        self.isTracking = false
        print("NavRushBeaconsTracker stopped tracking")
    }
    
    /**
     Smoooth RSSI values, to remove noise and fluctuations
     
     - Parameter beacons: List of beacons for calculation
     
     - Returns: NavRushBeacon?: Beacon with smoothed RSSI value
     */
    func calculateMeanBeaconValues(beacons:[NavRushBeacon])->NavRushBeacon?
    {
        if beacons.count == 0
        {
            return nil
        }
        
        //Update first one with smoothed RSSI and return it
        let calculatedBeacon = beacons[0]
        calculatedBeacon.rssi = NavRushFramework.smoothRSSI(input: beacons.map({ (el) -> Double in
            return el.rssi
        }))
        
        calculatedBeacon.timestamp = Date()
        return calculatedBeacon
    }
    
    /**
     Process all captured beacons - smooth rssi and group them for delegate
     
     */
    func processCapturedBeacons()
    {
        var processedBeacons:[NavRushBeacon] = []
        //Process each beacon group
        for beaconGroup in self.capturedBeaconsData.keys
        {
            if let beacons = self.capturedBeaconsData[beaconGroup]
            {
                //Remove all beacons with rssi >= 0, invalid data
                if let calcResult = self.calculateMeanBeaconValues(beacons: beacons.filter({ (el) -> Bool in
                    return el.rssi < 0
                }))
                {
                        processedBeacons.append(calcResult)
                }
            }
        }
        //Inform SDK about ranged beacons
        self.delegate?.beaconsTrackerRanged(tracker: self, beacons: processedBeacons)
        //Reset beacons capture
        self.capturedBeaconsData = [:]
        self.lastBeaconChange = nil
    }
}
