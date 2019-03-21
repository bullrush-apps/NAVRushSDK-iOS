//
//  NavRushLocationsRequest.swift
//  NavRushSDK
//
//  Created by tr on 10/02/19.
//  REST API GPS Location Structure

import Foundation
import NavRushFramework

/// NavRushLocation Request Codable Structure - REST API Request
struct NavRushLocationsRequest:Codable {
    var userId:String?
    var deviceId:String = NavRushFramework.getDeviceId()
    var locations:[NavRushLocationData] = []
}
