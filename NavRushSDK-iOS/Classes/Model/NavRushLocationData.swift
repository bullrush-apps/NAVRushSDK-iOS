//
//  NavRushLocationsData.swift
//  NavRushSDK
//
//  Created by tr on 10/02/19.
//

import Foundation
import CoreLocation
import SwifterSwift

/// NavRush Location Object extended with CoreLocation data
public class NavRushLocationData:Codable {
    public var lat:Double
    public var lng:Double
    public var horizontalAccuracy:Double
    public var verticalAccuracy:Double
    public var altitude:Double
    public var heading:Double
    public var timestamp:Date
    
    /**
     Location contstructor from CoreLocation Object
     
     - Parameter location: CoreLocation
     */
    init(location:CLLocation)
    {
        self.lat = location.coordinate.latitude
        self.lng = location.coordinate.longitude
        self.altitude = location.altitude
        self.timestamp = location.timestamp
        self.horizontalAccuracy = location.horizontalAccuracy
        self.verticalAccuracy = location.verticalAccuracy
        self.heading = location.course
    }
    
    /**
     Location contstructor from WS (WebSocket) Message
     
     - Parameter ws: Map/Dictionary to parse
     */
    init?(ws:[String:Any])
    {
        if let position = ws["position"] as? [String:Any], let coords = position["coordinates"] as? [Double]
        {
            self.lat = coords[1]
            self.lng = coords[0]
        }
        else
        {
            return nil
        }
        
        self.altitude = ws["altitude"] as! Double
        self.timestamp = Date(timeIntervalSince1970: TimeInterval(ws["timestamp"] as? Double ?? 0))
        self.horizontalAccuracy = ws["horizontalAccuracy"] as? Double ?? 0
        self.verticalAccuracy = ws["verticalAccuracy"] as? Double ?? 0
        self.heading = ws["heading"] as? Double ?? 0
        
    }
    
}

