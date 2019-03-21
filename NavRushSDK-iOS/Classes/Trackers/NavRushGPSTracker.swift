import UIKit
import Foundation
import CoreLocation
import NavRushFramework

private let RequestQueueIdentifier = "RequestQueueIdentifier"
private let RequestQueueSpecificKey = DispatchSpecificKey<()>()

/// GPS Specific Error Types
public enum GPSTrackerErrorType: CustomStringConvertible {
    case timedOut
    case restricted
    case cancelled
    
    public var description: String {
        get {
            switch self {
            case .timedOut:
                return "Timed out"
            case .restricted:
                return "Restricted"
            case .cancelled:
                return "Cancelled"
            }
        }
    }
}

/// Position location updates protocol.
protocol NavRushGPSTrackerDelegate: AnyObject {
    /**
     Delegate Method called when CoreLocation have new location
     
     - Parameter tracker: This NavRushGPSTracker instance
     - Parameter locations: List of *NavRushLocationData* data containing GPS data
     
     */
    func gpsTracker(_ tracker: NavRushGPSTracker, didUpdateTrackingLocations locations: [NavRushLocationData])
    
    /**
     Delegate Method called when CoreLocation tracker produce error
     
     - Parameter tracker: This NavRushGPSTracker instance
     - Parameter error: Error object
     
     */
    func gpsTracker(_ tracker: NavRushGPSTracker, didFailWithError error: Error?)
    
    /**
     Delegate Method called when User change CoreLocation permissions
     
     - Parameter tracker: This NavRushGPSTracker instance
     - Parameter status: New LocationAuthorizationStatus
     
     */
    func gpsTracker(_ tracker: NavRushGPSTracker, didChangeLocationAuthorizationStatus status: NavRushFramework.LocationAuthorizationStatus)
}

class NavRushGPSTracker:NSObject {
    //MARK: Variables
    unowned let navRushTracker : NavRushTracker
    
    internal var distanceFilter: Double = 0.0 {
        didSet {
            self.updateLocationAccuracyIfNecessary()
        }
    }
    
    internal var timeFilter: TimeInterval = 0.0
    
    internal var trackingDesiredAccuracyActive: Double = kCLLocationAccuracyHundredMeters {
        didSet {
            self.updateLocationAccuracyIfNecessary()
        }
    }
    
    internal var trackingDesiredAccuracyBackground: Double = kCLLocationAccuracyKilometer {
        didSet {
            self.updateLocationAccuracyIfNecessary()
        }
    }
    
    internal var locations: [CLLocation]?
    internal var _requestQueue: DispatchQueue!
    
    private(set) var isTracking: Bool = false
    private(set) var isTrackingLowPower: Bool = false
    
    var delegate:NavRushGPSTrackerDelegate?
    
    
    /// Last determined location
    public var location: CLLocation? {
        get {
            return self.locations?.first
        }
    }
    
    //MARK: Methods
    
    /**
     NavRushBeaconsTracker Constructor
     
     - Parameter tracker: Common NavRush Tracker
     - Parameter delegate: Listens to gps events
     
     - Returns: NavRushGPSTracker
     */
    init(tracker:NavRushTracker, delegate:NavRushGPSTrackerDelegate) {
        self.navRushTracker = tracker
        super.init()
        self.delegate = delegate
        self._requestQueue = DispatchQueue(label: RequestQueueIdentifier, autoreleaseFrequency: .workItem, target: DispatchQueue.global())
        self._requestQueue.setSpecific(key: RequestQueueSpecificKey, value: ())
    }
    
    /**
     Updates Accuracy and Distance filter, based on current device state and battery level
     
     */
    internal func updateLocationAccuracyIfNecessary() {
        //Update levels based on current Battery Level
        if self.navRushTracker.adjustLocationUseFromBatteryLevel == true {
            switch UIDevice.current.batteryState {
            case .full,
                 .charging:
                self.trackingDesiredAccuracyActive = NavRushFramework.POWER_ACCURACY_ACTIVE
                self.trackingDesiredAccuracyBackground = NavRushFramework.POWER_ACCURACY_BCG
                break
            case .unplugged,
                 .unknown:
                let batteryLevel: Float = UIDevice.current.batteryLevel
                if batteryLevel < NavRushFramework.BATTERY_THRESHOLD {
                    self.trackingDesiredAccuracyActive = NavRushFramework.FLAT_ACCURACY_ACTIVE
                    self.trackingDesiredAccuracyBackground = NavRushFramework.FLAT_ACCURACY_BCG
                } else {
                    self.trackingDesiredAccuracyActive = NavRushFramework.BATT_ACCURACY_ACTIVE
                    self.trackingDesiredAccuracyBackground = NavRushFramework.BATT_ACCURACY_BCG
                }
                break
            }
        }
        
        //Apply new setting
        if self.isTracking == true {
            self.navRushTracker._locationManager.desiredAccuracy = self.trackingDesiredAccuracyActive
        } else if self.isTrackingLowPower == true {
            self.navRushTracker._locationManager.desiredAccuracy = self.trackingDesiredAccuracyBackground
        }
        
        //Update distance filter
        self.navRushTracker._locationManager.distanceFilter = self.distanceFilter
    }
}

extension NavRushGPSTracker {
    
    /**
     Starts High energy GPS Tracker
     - Note: Permissions have to be granted
     
     */
    internal func startUpdating() {
        self.distanceFilter = NavRushFramework.HIGH_POWER_DIST
        self.timeFilter = NavRushFramework.HIGH_POWER_TIME
        switch self.navRushTracker.locationServicesStatus {
        case .allowedAlways,
             .allowedWhenInUse:
            self.navRushTracker._locationManager.startUpdatingLocation()
            self.isTracking = true
            self.updateLocationAccuracyIfNecessary()
            fallthrough
        default:
            break
        }
    }
    
    /**
     Stop High energy GPS Tracker
     - Note: Permissions have to be granted
     
     */
    internal func stopUpdating() {
        switch self.navRushTracker.locationServicesStatus {
        case .allowedAlways,
             .allowedWhenInUse:
            if self.isTracking == true {
                self.navRushTracker._locationManager.stopUpdatingLocation()
                self.isTracking = false
                self.updateLocationAccuracyIfNecessary()
            }
            fallthrough
        default:
            break
        }
    }
    
    /**
     Starts Low energy GPS Tracker
     - Note: Permissions have to be granted
     
     */
    internal func startLowPowerUpdating() {
        self.distanceFilter = NavRushFramework.LOW_POWER_DIST
        self.timeFilter = NavRushFramework.LOW_POWER_TIME
        let status: NavRushFramework.LocationAuthorizationStatus = self.navRushTracker.locationServicesStatus
        switch status {
        case .allowedAlways, .allowedWhenInUse:
            self.navRushTracker._locationManager.startMonitoringSignificantLocationChanges()
            self.isTrackingLowPower = true
            self.updateLocationAccuracyIfNecessary()
            fallthrough
        default:
            break
        }
    }
    
    /**
     Stop Low energy GPS Tracker
     - Note: Permissions have to be granted
     
     */
    internal func stopLowPowerUpdating() {
        let status: NavRushFramework.LocationAuthorizationStatus = self.navRushTracker.locationServicesStatus
        switch status {
        case .allowedAlways, .allowedWhenInUse:
            self.navRushTracker._locationManager.stopMonitoringSignificantLocationChanges()
            self.isTrackingLowPower = false
            self.updateLocationAccuracyIfNecessary()
            fallthrough
        default:
            break
        }
    }
    
}

// MARK: - Processing

extension NavRushGPSTracker {
    
    /**
     Main Processing Logic
     - Note: Selected Distance & Time Filter is applied
     
     */
    internal func processLocationRequests() {
        
        if let tmpLocations  = self.locations
        {
            //Map CLLocations -> NavRush structure NavRushLocationData
            let mappedLocations = tmpLocations.map({ (el) -> NavRushLocationData in
                return NavRushLocationData(location: el)
            })
            
            var shouldUpdate = false
            
            if let first = tmpLocations.first, let last = navRushTracker.lastLocation
            {
                if first.distance(from:last) > self.distanceFilter
                {
                    shouldUpdate = true
                }
                else
                {
                    if last.timestamp.timeIntervalSince(first.timestamp) > timeFilter
                    {
                        shouldUpdate = true
                    }
                }
            }
            else
            {
                shouldUpdate = true
            }
            
            if shouldUpdate
            {
                //Update last location
                navRushTracker.lastLocation = tmpLocations.first
                DispatchQueue.main.async {
                    self.delegate?.gpsTracker(self, didUpdateTrackingLocations: mappedLocations)
                }
            }
        }
    }
}

// MARK: - Queues

extension NavRushGPSTracker {
    internal func executeClosureAsyncOnRequestQueueIfNecessary(withClosure closure: @escaping () -> Void) {
        if DispatchQueue.getSpecific(key: RequestQueueSpecificKey) != nil {
            closure()
        } else {
            self._requestQueue.async(execute: closure)
        }
    }
}
