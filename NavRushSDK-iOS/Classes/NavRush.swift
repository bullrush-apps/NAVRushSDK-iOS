import then
import Alamofire
import Starscream
import CoreLocation
import AlamofireObjectMapper
import Disk
import SwifterSwift
import NavRushFramework

public protocol NavRushDelegate
{
    /**
     Delegate method which is triggered when movement state of device changes
     
     - Parameter isMoving: standing still or moving
     */
    func NavRushDeviceStateChanged(isMoving:Bool)
    
    /**
     Delegate method which returns RAW data from ranged beacons
     - Note: You can get your apiKey and apiSecret using WebPortal or via API
     
     - Parameter beacons: List of NavRushBeacons - UUID, Major, Minor, RSSI
     */
    
    func NavRushBeaconsRanged(beacons: [NavRushBeacon])
    
    /**
     Delegate method which is called on every location change
     - Note: Contains position either coming from NavRush server or locally from GPS sensor in local mode
     
     - Parameter position: NavRushLocationData - coordinates, accuracy, heading etc.
     */
    func NavRushCurrentPositionChanged(position:NavRushLocationData)
    
    /**
     Delegate method which is called when new set of beacons are received from NavRush Server based on provided location
     - Note: This method is only called when SDK is connected to NavRush Server
     
     - Parameter position: NavRushLocationData position for set of beacons
     - Parameter beacons: List of NavRushBeacons in provided location - UUID, Major, Minor, RSSI
     
     */
    func NavRushBeaconsInLocation(position:NavRushLocationData, beacons:[NavRushBeacon])
    /**
     Delegate methods which allows you to provide custom list of Beacon UUIDs for ranging
     - Note: This method can only be used if Local Mode
     
     - Parameter position: NavRushLocationData location for you need to provide list of UUIDs
     
     
     - Returns: [String]: List of Beacon UUIDs
     */
    func NavRushBeaconsForLocation(position:NavRushLocationData)->[String]
}


/// Possible NavRush Error types
public enum NavRushError: Error, CustomStringConvertible {
    case auth(message:String)
    case unknown(stack:String)
    case track(message:String)
    case gps(type:GPSTrackerErrorType)
    
    public var description: String {
        get {
            switch self {
            case .gps(type: _):
                return "GPS Tracker Error"
            case .track(message: _):
                return "Tracking Error"
            case .auth:
                return "Authorization Error"
            case .unknown(stack: _):
                return "Uknown Error"
            }
        }
    }
}

/// 📌 Singleton Class to access tracking framework NavRush
public class NavRush {
    
    //MARK: public
    
    /// **Singleton** instance
    public static let sharedInstance = NavRush()
    
    /// change anytime and change userId identification of your requests
    public var currentUserId:String = ""
    
    /// **Read only**, call *config* to change this variable
    private(set) public var currentServer:String = ""
    
    /// **Read only**, call *config* to change this variable
    private(set) public var currentApiKey:String = ""
    
    /// **Read only**, call *config* to change this variable
    private(set) public var navrushConfig:NavRushConfig?
    
    /// Public delegate for NavRush SDK
    public var delegate:NavRushDelegate?
    
    /// common tracker instance for all available trackers - GPS, BLE, Motion, etc...
    internal var trackerInstance:NavRushTracker?
    
    
    /**
     Configures NavRush SDK
     - Note: You can get your apiKey and apiSecret using WebPortal or via API
     
     - Parameter server: NavRush Server, fallbacks to default
     - Parameter apiKey: NavRush Application ID
     - Parameter apiSecret: NavRush Application Secret
     - Parameter userId: User identifier, user can have multiple devices
     
     - Returns: Promise<NavRushConfig>
     */
    public func config(server: String?, apiKey:String?, apiSecret:String?, userId:String) -> Promise<NavRushConfig>
    {
        var url:String? = server
        //Url fallback to default NavRush Server
        if url == nil
        {
            url = NavRushFramework.DEFAULT_NAVRUSH_SERVER
        }
        self.currentServer = url!
        self.currentUserId = userId
        
        return Promise { resolve, reject in
            if let key:String = apiKey, let secret:String = apiSecret
            {
                self.currentApiKey = key
                self.currentAPISecret = secret
                self.NavRushRequest(route: "/app/config", method: .get, params: nil)
                    .responseJSON { response in
                        
                        if let json = response.result.value {
                            print("JSON: \(json)") // serialized json response
                        }
                        
                        
                        self.connectToWS()
                        
                        //Create new NavRushTracker instance and listen for events
                        self.trackerInstance = NavRushTracker.init()
                        self.trackerInstance?.delegate = self
                        
                        //TODO: replace with parsed NavRush config object
                        self.navrushConfig = NavRushConfig(isLocal: false)
                        resolve(self.navrushConfig!)
                }
            }
            else
            {
                //Mode without server, basic functions only
                //Create new NavRushTracker instance and listen for events
                self.trackerInstance = NavRushTracker.init()
                self.trackerInstance?.delegate = self
                
                self.navrushConfig = NavRushConfig(isLocal: true)
                resolve(self.navrushConfig!)
            }
        }
    }
    
    init() {
        //After construction, watch for device status changes
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationDidBecomeActive(_:)), name: NSNotification.Name.UIApplicationDidBecomeActive, object: UIApplication.shared)
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationWillResignActive(_:)), name: NSNotification.Name.UIApplicationWillResignActive, object: UIApplication.shared)
    }
    
    deinit {
        //Remove listeners
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: UIApplication.shared)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationWillResignActive, object: UIApplication.shared)
    }
    
    func connectToWS()
    {
        //Setup real-time connection
        var wsRequest = URLRequest(url: URL(string: self.currentServer.replacingOccurrences(of: "https", with: "ws").replacingOccurrences(of: "http", with: "ws"))!)
        wsRequest.timeoutInterval = 5
        //Basic HTTP base64 auth using API key & secret
        let loginString = String(format: "%@:%@", self.currentApiKey, self.currentAPISecret)
        let loginData = loginString.data(using: String.Encoding.utf8)!
        let base64LoginString = loginData.base64EncodedString()
        wsRequest.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        
        //Add identification to WS -> deviceId & userId
        wsRequest.setValue(NavRushFramework.getDeviceId() , forHTTPHeaderField: "DeviceId")
        
        wsRequest.setValue(self.currentUserId, forHTTPHeaderField: "UserId")
        
        //Connect to WebSockets and listen for events
        self.socket = WebSocket.init(request: wsRequest)
        self.socket?.delegate = self
        self.socket?.connect()
    }
    
    /**
     Creates authenticated REST API request using stored API key & secret
     - Note: You can get your apiKey and apiSecret using WebPortal or via API
     
     - Parameter route: REST API route
     - Parameter method: GET, POST, PUT, DELETE, etc...
     - Parameter params: Alamofire parameters (dictionary)
     
     - Returns: DataRequest
     */
    func NavRushRequest(route:String, method:HTTPMethod, params:Parameters?)->DataRequest
    {
        let url = "\(self.currentServer)\(route)"
        
        return Alamofire.request(url, method: method, parameters: params, encoding: JSONEncoding.default, headers: nil).authenticate(user: currentApiKey, password: currentAPISecret)
    }
    
    @objc func handleApplicationDidBecomeActive(_ notification: Notification) {
        do
        {
            try self.processCache()
            //Check if WS connection is not active
            if self.socket?.isConnected == true
            {
                print("WS is still connected")
            }
            else
            {
                if self.navrushConfig?.isLocal != true
                {
                    self.connectToWS()
                }
            }
        }
        catch
        {
            print(error)
        }
    }
    
    @objc func handleApplicationWillResignActive(_ notification: Notification) {
        do
        {
            try self.processCache()
        }
        catch
        {
            print(error)
        }
    }
    
    /**
     Starts NavRush tracking for current userId
     - Note: NavRushSDK will use all available sources to track user's position
     */
    public func startTracking() throws
    {
        if let tracker = self.trackerInstance
        {
            tracker.startTracking()
        }
        else
        {
            throw NavRushError.track(message: "Tracker Instance is not available!")
        }
    }
    
    /**
     Stops NavRush tracking for current userId
     */
    public func stopTracking() throws
    {
        if let tracker = self.trackerInstance
        {
            tracker.stopTracking()
        }
        else
        {
            throw NavRushError.track(message: "Tracker Instance is not available!")
        }
    }
    
    //MARK: private
    /// Last determined location
    internal var socket:WebSocket?
    internal var currentAPISecret:String = "" //TODO: keychain?
    internal var lastGPSSent:Date?
    internal var lastBeaconSent:Date?
    
    
    func postBeaconsData(beacons:[NavRushBeacon])->Promise<Bool>
    {
        return Promise { resolve, reject in
            if self.navrushConfig?.isLocal == true
            {
                //No server attached
                return resolve(true)
            }
            
            var request:NavRushBeaconsRequest = NavRushBeaconsRequest()
            request.userId = self.currentUserId
            request.beacons = beacons
            if beacons.count == 0
            {
                //Nothing to post
                return resolve(true)
            }
            print("Should post \(beacons)")
            do
            {
                let encodedData = try JSONEncoder().encode(request)
                let params = try JSONSerialization.jsonObject(with: encodedData, options: .allowFragments) as? [String: Any]
                
                self.NavRushRequest(route: "/app/beacon", method: .post, params: params)
                    .responseJSON { response in
                        
                        if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                            print("Data: \(utf8Text)") // original server data as UTF8 string
                        }
                        
                        resolve(true)
                }
            }
            catch
            {
                return reject(error)
            }
            
        }
    }
    
    func postLocationsData(locations:[NavRushLocationData])->Promise<Bool>
    {
        return Promise { resolve, reject in
            if self.navrushConfig?.isLocal == true
            {
                //No server attached
                return resolve(true)
            }
            
            if locations.count == 0
            {
                //Nothing to send
                return resolve(true)
            }
            var request:NavRushLocationsRequest = NavRushLocationsRequest()
            request.userId = self.currentUserId
            request.locations = locations
            print("Should post \(locations)")
            do
            {
                let encodedData = try JSONEncoder().encode(request)
                let params = try JSONSerialization.jsonObject(with: encodedData, options: .allowFragments) as? [String: Any]
                self.NavRushRequest(route: "/app/gps", method: .post, params: params)
                    .responseJSON { response in
                        
                        if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                            print("Data: \(utf8Text)") // original server data as UTF8 string
                        }
                        
                        resolve(true)
                }
            }
            catch
            {
                return reject(error)
            }
        }
    }
}

extension NavRush
{
    func saveBeaconData(beacons: [NavRushBeacon]) throws
    {
        //Add data to cache
        if Disk.exists("beacons.json", in: .caches) == false
        {
            try Disk.save(beacons, to: .caches, as: "beacons.json")
        }
        else
        {
            for beacon in beacons
            {
                try Disk.append(beacon, to: "beacons.json", in: .caches)
            }
        }
        try processCache()
    }
    
    func saveGPSData(locations: [NavRushLocationData]) throws
    {
        //Add data to cache
        if Disk.exists("locations.json", in: .caches) == false
        {
            try Disk.save(locations, to: .caches, as: "locations.json")
        }
        else
        {
            for location in locations
            {
                try Disk.append(location, to: "locations.json", in: .caches)
            }
        }
        try processCache()
    }
    
    func processCache() throws
    {
        let state = UIApplication.shared.applicationState
        let retrievedBeacons = (try? Disk.retrieve("beacons.json", from: .caches, as: [NavRushBeacon].self)).unwrapped(or: [])
        let retrievedLocations = (try? Disk.retrieve("locations.json", from: .caches, as: [NavRushLocationData].self)).unwrapped(or: [])
        
        if state == .background  || state == .inactive{
            // background
            if lastBeaconSent == nil || lastGPSSent == nil
            {
                sendData(beacons: retrievedBeacons, locations: retrievedLocations)
                return
            }
            
            if Date().timeIntervalSince(lastGPSSent!) > NavRushFramework.GPS_DURATION_THRESHOLD_BCG || Date().timeIntervalSince(lastBeaconSent!) > NavRushFramework.BLE_DURATION_THRESHOLD_BCG
            {
                sendData(beacons: retrievedBeacons, locations: retrievedLocations)
            }
            else
            {
                
                if retrievedBeacons.count > NavRushFramework.BLE_ENTRIES_THRESHOLD_BCG || retrievedLocations.count > NavRushFramework.GPS_ENTRIES_THRESHOLD_BCG
                {
                    sendData(beacons: retrievedBeacons, locations: retrievedLocations)
                }
            }
        }else if state == .active {
            // foreground
            if lastBeaconSent == nil || lastGPSSent == nil
            {
                sendData(beacons: retrievedBeacons, locations: retrievedLocations)
                return
            }
            
            if Date().timeIntervalSince(lastGPSSent!) > NavRushFramework.GPS_DURATION_THRESHOLD || Date().timeIntervalSince(lastBeaconSent!) > NavRushFramework.BLE_DURATION_THRESHOLD
            {
                sendData(beacons: retrievedBeacons, locations: retrievedLocations)
            }
            else
            {
                
                if retrievedBeacons.count > NavRushFramework.BLE_ENTRIES_THRESHOLD || retrievedLocations.count > NavRushFramework.GPS_ENTRIES_THRESHOLD
                {
                    sendData(beacons: retrievedBeacons, locations: retrievedLocations)
                }
            }
        }
    }
    
    func sendData(beacons: [NavRushBeacon], locations: [NavRushLocationData])
    {
        if self.navrushConfig?.isLocal != true
        {
            let mapped = beacons.map { (el) -> [String:Any] in
                return ["beacon":el.minor.unwrapped(or: 0).string, "rssi":el.rssi]
            }
            if let theJSONData = try? JSONSerialization.data(
                withJSONObject: mapped,
                options: []) {
                let theJSONText = String(data: theJSONData,
                                         encoding: .ascii)
                print("JSON string = \(theJSONText!)")
            }
            self.postBeaconsData(beacons: beacons).then{ beaconsDone in
                self.lastBeaconSent = Date()
                try? Disk.remove("beacons.json", from: .caches)
                }.onError{err in
                    print(err)
                }.chain { _ in
                    self.postLocationsData(locations: locations).then { gpsDone in
                        self.lastGPSSent = Date()
                        try? Disk.remove("locations.json", from: .caches)
                        }.onError{err in
                            print(err)
                    }
            }
        }
    }
}

extension NavRush:NavRushTrackerDelegate
{
    func trackerBeaconsRanged(tracker: NavRushTracker, beacons: [NavRushBeacon]) {
        do{
            //Expose raw smoothed data to public NavRush Delegate
            self.delegate?.NavRushBeaconsRanged(beacons: beacons)
            //Save data in cache for futher processing
            try self.saveBeaconData(beacons: beacons)
        }
        catch
        {
            print(error)
        }
    }
    
    func trackerMotionChanged(tracker: NavRushTracker, isMoving: Bool) {
        do
        {
            //In case of movement change, process cache
            try self.processCache()
            //Inform delegate about motion change
            self.delegate?.NavRushDeviceStateChanged(isMoving: isMoving)
        }
        catch
        {
            print(error)
        }
    }
    
    func trackerGPSPositionChanged(tracker: NavRushTracker, position: [NavRushLocationData]) {
        do
        {
            try self.saveGPSData(locations: position)
            //If this is only local configuration, return native GPS position
            if self.navrushConfig?.isLocal == true, let firstPosition = position.first
            {
                self.delegate?.NavRushCurrentPositionChanged(position: firstPosition)
            }
        }
        catch
        {
            print(error)
        }
    }
    
    func trackerBeaconsForPosition(tracker: NavRushTracker, position: NavRushLocationData) -> Promise<[String]> {
        return Promise { resolve, reject in
            if self.navrushConfig?.isLocal == true
            {
                if let uuids = self.delegate?.NavRushBeaconsForLocation(position: position)
                {
                    return resolve(uuids)
                }
                else
                {
                    return reject(NavRushError.unknown(stack: "Please provide list of UUIDs for location"))
                }
            }
            else
            {
                let path = "/app/beacon?lat=\(position.lat)&lng=\(position.lng)&radius=\(NavRushFramework.BEACONS_SEARCH_RADIUS)"
                self.NavRushRequest(route: path, method: .get, params: nil)
                    .responseArray(completionHandler: { ( response: DataResponse<[NavRushBeacon]>) in
                        if let beaconResponse = response.result.value
                        {
                            self.delegate?.NavRushBeaconsInLocation(position: position, beacons: beaconResponse)
                            return resolve(beaconResponse.filter({ (el) -> Bool in
                                return el.uuid != nil
                            }).map({ (el) -> String in
                                return el.uuid!
                            }))
                        }
                        else
                        {
                            if let err = response.error
                            {
                                return reject(err)
                            }
                            else
                            {
                                return reject(NavRushError.unknown(stack: "Get beacons for location failed."))
                            }
                        }
                    })
            }
        }
    }
}

// MARK: WebSocketDelegate
/// Handles connection to NavRush WS server
extension NavRush:WebSocketDelegate
{
    public func websocketDidConnect(socket: WebSocketClient) {
        print("NavRush WS Connected")
    }
    
    public func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        print("NavRush WS Disconnected: \(error?.localizedDescription)")
    }
    
    public func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        print(text)
        if let parsedMessage = NavRushWSMessage(JSONString: text)
        {
            
            if let postitionData:[String:Any] = parsedMessage.data, parsedMessage.type == NavRushFramework.WSMessageType.lastMessage.description
            {
                if let position = NavRushLocationData(ws: postitionData)
                {
                    self.delegate?.NavRushCurrentPositionChanged(position: position)
                }
            }
        }
    }
    
    public func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print(data)
    }
}
