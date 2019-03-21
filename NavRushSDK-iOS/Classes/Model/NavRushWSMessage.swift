//
//  NavRushWSMessage.swift
//  NavRushSDK
//
//  Created by tr on 25/01/19.
//

import Foundation
import ObjectMapper

/// Generic NavRush WS (WebSocket) Message
class NavRushWSMessage:Mappable {
    var type:String? //Add Enums?
    var timestamp:Date?
    var applicationId:String?
    /// Any JSON payload, maybe in the future will create WS Message Types?!
    var data:[String: Any]?
    
    required init?(map: Map) {
    }
    
    /**
     Required function for ObjectMapper to parse JSON
     
     - Parameter map: Map/Dictionary to parse
     */
    func mapping(map: Map) {
        applicationId               <- map["applicationId"]
        type                        <- map["type"]
        data                        <- map["data"]
        timestamp                   <- (map["timestamp"], NullableDateTransfrom())
    }
}
