//
//  NavRushBoundary.swift
//  NavRushSDK
//
//  Created by tr on 25/01/19.
//

import Foundation
import CoreLocation
import ObjectMapper

/// NavRush GeoJSON Polygon Object
public class NavRushBoundary:Mappable {
    var _id:String?
    
    /// GeoJson specification
    var type:String?
    
    /// Coordinates Data
    public var coordinates:[[[Double]]] = []
    
    public required init?(map: Map) {
    }
    
    /**
     Returns List CoreLocation Coordinates, representing polygon, boundary
     
     - Returns: [CLLocationCoordinate2D]
     */
    public func getCoordinate2D() -> [CLLocationCoordinate2D] {
        var results:[CLLocationCoordinate2D] = []
        for dataset in coordinates
        {
            for point in dataset
            {
                results.append(CLLocationCoordinate2D(latitude: point[1], longitude: point[0]))
            }
        }
        return results
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
