//
//  NavRushRelativePosition.swift
//  NavRushSDK
//
//  Created by tr on 25/01/19.
//

import Foundation
import CoreLocation
import SwifterSwift
import ObjectMapper

/// NavRush Relative position structure (X,Y Offset)
public class NavRushRelativePosition:Mappable {
    public var x:Double?
    public var y:Double?
    
    public required init?(map: Map) {
    }
    
    /**
     Required function for ObjectMapper to parse JSON
     
     - Parameter map: Map/Dictionary to parse
     */
    public func mapping(map: Map) {
        x           <- map["x"]
        y           <- map["y"]
    }
    
}
