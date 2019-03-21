//
//  NavRushBeaconsRequest.swift
//  NavRushSDK
//
//  Created by tr on 25/01/19.
//  REST API Beacons Structure

import Foundation
import NavRushFramework

/// NavRushBeacon Request Codable Structure - REST API Request
struct NavRushBeaconsRequest:Codable {
    var userId:String?
    var deviceId:String = NavRushFramework.getDeviceId()
    var beacons:[NavRushBeacon] = []
}
