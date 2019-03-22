//
//  ViewController.swift
//  NavRushSDK
//
//  Created by Tomas Radvansky on 01/23/2019.
//  Copyright (c) 2019 Tomas Radvansky. All rights reserved.
//

import UIKit
import NavRushSDK_iOS
import GoogleMaps
import CoreLocation

class ViewController: UIViewController {
    @IBOutlet weak var mainTableView: UITableView!
    
    @IBOutlet weak var mapView: GMSMapView!
    
    var beaconData:[NavRushBeacon] = []
    var beacons:[NavRushBeacon] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //apiKey: "5c58bb2b83f9fe0694afcf96", apiSecret: "7806d9e8-649e-4b5a-bb61-fd8a0db607e1",
        
        NavRush.sharedInstance.config(server: nil, apiKey: nil, apiSecret: nil, userId: "1234").then { result in
            print(result)
            do
            {
                try NavRush.sharedInstance.startTracking()
            }
            catch
            {
                print(error)
            }
            
            }.onError{err in
                print(err)
        }
        NavRush.sharedInstance.delegate = self
        // Do any additional setup after loading the view, typically from a nib.
        //map
        let camera = GMSCameraPosition.camera(withLatitude: 51.50, longitude: -0.076, zoom: 10.0)
        mapView.mapType = .hybrid
        mapView.camera = camera
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

extension ViewController:UITableViewDelegate,UITableViewDataSource
{
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.beacons.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let beaconCell:BeaconCell = tableView.dequeueReusableCell(withIdentifier: "BeaconCell", for: indexPath) as! BeaconCell
        let beacon = self.beacons[indexPath.row]
        beaconCell.uuidLabel.text = beacon.uuid
        beaconCell.majorLabel.text = beacon.major.unwrapped(or: 0).string
        beaconCell.minorLabel.text = beacon.minor.unwrapped(or: 0).string
        beaconCell.rssiLabel.text = beacon.rssi.string
        return beaconCell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60.0
    }
}


extension ViewController:NavRushDelegate
{
    func NavRushBeaconsRanged(beacons: [NavRushBeacon]) {
           self.beacons = beacons
         self.mainTableView.reloadData()
    }
    
    func NavRushBeaconsInLocation(position: NavRushLocationData, beacons: [NavRushBeacon]) {
        self.beaconData = beacons
    }
    
    func NavRushBeaconsForLocation(position: NavRushLocationData) -> [String] {
        return ["e2c56db5-dffb-48d2-b060-d0f5a71096e0"]
    }
    
    
    func NavRushCurrentPositionChanged(position: NavRushLocationData) {
        print("lat:\(position.lat) lng:\(position.lng) radius:\(position.horizontalAccuracy)")
        
        mapView.clear()
        if position.horizontalAccuracy == 2 && position.horizontalAccuracy == 2
        {
            let circleCenter = CLLocationCoordinate2D(latitude: position.lat, longitude: position.lng)
            let circ = GMSCircle(position: circleCenter, radius: 2)
            circ.strokeColor = UIColor.red
            circ.map = mapView
        }
        else
        {
            let circleCenter = CLLocationCoordinate2D(latitude: position.lat, longitude: position.lng)
            let circ = GMSCircle(position: circleCenter, radius: position.horizontalAccuracy)
            circ.strokeColor = UIColor.green
            circ.map = mapView
        }
        
        for beacon in self.beacons
        {
            let positionData:NavRushBeacon? = self.beaconData.filter { (element) -> Bool in
                return element.uuid! == beacon.uuid && element.major! == beacon.major && element.minor! == beacon.minor
                }.first
            if let tmp:CLLocationCoordinate2D = positionData?.position?.getCoordinate2D()
            {
                let circ = GMSCircle(position: tmp, radius: 1)
                circ.strokeColor = UIColor.purple
                circ.map = mapView
            }
            
        }
        
        if let boundary = self.beaconData.first?.room?.boundary
        {
            let coordinates = boundary.getCoordinate2D()
            let path = GMSMutablePath()
            for point in coordinates
            {
                path.add(point)
            }
            let rectangle = GMSPolyline(path: path)
            rectangle.map = mapView
        }
        //Reset table
        self.beacons = []
        self.mainTableView.reloadData()
    }
    
    func NavRushDeviceStateChanged(isMoving: Bool) {
        print("NavRushDeviceStateChanged \(isMoving)")
    }
}
