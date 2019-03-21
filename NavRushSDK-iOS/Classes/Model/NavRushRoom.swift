//
//  NavRushRoom.swift
//  NavRushSDK
//
//  Created by tr on 25/01/19.
//

import Foundation
import ObjectMapper

/// NavRush Room Object, which is on Floor inside Building
public class NavRushRoom:Mappable {
    public var applicationId:String?
    public var _id:String?
    public var width:Double?
    public var height:Double?
    public var name:String?
    public var desc:String?
    
    /// Floor Reference
    public var floorId:String?
    
    /// Building Reference
    public var buildingId:String?
    
    /// Boundary of room is defined by GeoJson polygon, consisting of 4 GeoPoints
    public var boundary:NavRushBoundary?
    
    public required init?(map: Map) {
    }
    
    /**
     Required function for ObjectMapper to parse JSON
     
     - Parameter map: Map/Dictionary to parse
     */
    public  func mapping(map: Map) {
        applicationId           <- map["applicationId"]
        _id                     <- map["_id"]
        width                   <- map["width"]
        height                  <- map["height"]
        floorId                 <- map["floorId"]
        buildingId              <- map["buildingId"]
        name                    <- map["name"]
        desc                    <- map["desc"]
        boundary                <- map["boundary"]
    }
    
}
