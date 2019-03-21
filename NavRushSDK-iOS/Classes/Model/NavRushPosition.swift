//
//  NavRushPosition.swift
//  NavRushSDK
//
//  Created by tr on 25/01/19.
//


import Foundation
import CoreLocation
import ObjectMapper

/// NavRush GeoJSON Position Object
public class NavRushPosition:Mappable {
    var _id:String?
    
    /// GeoJson specification
    var type:String?
    
    /// Coordinates Data
    public var coordinates:[Double] = []
    
    public required init?(map: Map) {
    }
    
    /**
     Returns CoreLocation Coordinate
     
     - Returns: CLLocationCoordinate2D?
     */
    public func getCoordinate2D() -> CLLocationCoordinate2D? {
        if coordinates.count == 2
        {
            return CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
        }
        return nil
    }
    
    /**
     Required function for ObjectMapper to parse JSON
     
     - Parameter map: Map/Dictionary to parse
     */
    public func mapping(map: Map) {
        _id                 <- map["_id"]
        type                <- map["type"]
        coordinates         <- map["coordinates"]
    }
    
}
