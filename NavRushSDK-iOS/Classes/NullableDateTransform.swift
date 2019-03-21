//
//  NullableDateTransform.swift
//  NavRushSDK
//
//  Created by tr on 25/01/19.
//

import Foundation
import ObjectMapper

/// Helper class for ObjectMapper, which allows optional Date? class to be parsed as Unix timestamp
open class NullableDateTransfrom: TransformType {
    public typealias Object = Date
    public typealias JSON = Double
    
    public init() {}
    
    open func transformFromJSON(_ value: Any?) -> Date? {
        if let timeInt = value as? Double {
            if timeInt < 0
            {
                return nil
            }
            return Date(timeIntervalSince1970: TimeInterval(timeInt))
        }
        
        if let timeStr = value as? String {
            if timeStr == "-1"
            {
                return nil
            }
            return Date(timeIntervalSince1970: TimeInterval(atof(timeStr)))
        }
        
        if  let timeDate = value as? Date
        {
            return timeDate
        }
        return nil
    }
    
    open func transformToJSON(_ value: Date?) -> Double? {
        if let date = value {
            return Double(date.timeIntervalSince1970)
        }
        return -1
    }
}
