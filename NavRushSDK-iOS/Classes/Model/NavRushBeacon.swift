//
//  NavRushBeacon.swift
//  NavRushSDK
//
//  Created by tr on 25/01/19.
//

import Foundation
import CoreLocation
import SwifterSwift
import ObjectMapper

/// NavRush Beacon Object extended with ranging data
public class NavRushBeacon:Mappable, Codable {
    public var _id:String?
    public var applicationId:String?
    public var minor:Int?
    public var major:Int?
    public var power:Int?
    public var uuid:String?
    public var room:NavRushRoom?
    public var name:String?
    public var desc:String?
    
    /// Absolute position of NavRush Beacon, Lat & Lng coordinates used
    public var position:NavRushPosition?
    
    /// Relative position of beacon inside NavRush Room, X & Y coordinates used
    public var relativePosition:NavRushRelativePosition?
   
    /// RSSI value in dB, *-1* means unknown RSSI value
    
    public var rssi:Double = -1
    /*:
     Encoded Proximity value into Int
     
     - 0 immediate
     - 1 close
     - 2 far
     - -1 unknown
     */
    public var proximity:Int = -1
    public var timestamp:Date?
    
    /// Codable fields
    enum CodingKeys: String, CodingKey {
        case minor, major,uuid,rssi,timestamp
    }
    
    public required init?(map: Map) {
    }
    
    /**
     Helper methods which creates internal unique identifier for NavRush Beacon
     - Note: main identifier is **_id** linked to remote NavRush Server DB
     
     - Returns: String: VirtualId - UUID + Major + Minor values
     */
    public func getVirtualId()->String
    {
        return "\(self.uuid.unwrapped(or: "").lowercased())_\(self.major.unwrapped(or:0))_\(self.minor.unwrapped(or:0)))"
    }
    
    /**
     Custom constructor from CLBeacon and CLRegion
     - Note: Internal use, no _id etc..
     
     - Returns: NavRushBeacon
     */
    init(beacon:CLBeacon, in region:CLRegion)
    {
        self.uuid = beacon.proximityUUID.uuidString.lowercased()
        self.major = beacon.major.intValue
        self.minor = beacon.minor.intValue
        self.rssi = beacon.rssi.double
        switch beacon.proximity {
        case .far:
            self.proximity = 2
        case .immediate:
            self.proximity = 0
        case .near:
            self.proximity = 1
        default:
            self.proximity = -1
        }
        self.timestamp = Date()
    }
    
    /**
     Required function for ObjectMapper to parse JSON
     
     - Parameter map: Map/Dictionary to parse
     */
   public  func mapping(map: Map) {
        minor                   <- map["minor"]
        major                   <- map["major"]
        power                   <- map["power"]
        uuid                    <- map["uuid"]
        applicationId           <- map["applicationId"]
        room                    <- map["room"]
        _id                     <- map["_id"]
        name                    <- map["name"]
        desc                    <- map["desc"]
        position                <- map["position"]
        relativePosition        <- map["relativePosition"]
    }
    
}
