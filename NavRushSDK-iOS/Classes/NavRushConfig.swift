//
//  NavRushConfig.swift
//  NavRushSDK
//
//  Created by tr on 24/01/19.
//

import Foundation
import ObjectMapper

/// Configuration for current NavRush SDK instance
public class NavRushConfig:Mappable {
    
    /// Determine wether NavRush SDK is running in local mode or connected to NavRush Server instance
    public var isLocal:Bool = true
    
    public init (isLocal:Bool)
    {
        self.isLocal = isLocal
    }
    
    public required init?(map: Map) {
    }
    
    /**
     Required function for ObjectMapper to parse JSON
     
     - Parameter map: Map/Dictionary to parse
     */
    public func mapping(map: Map) {
    }
    
}
