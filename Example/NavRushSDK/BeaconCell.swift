//
//  BeaconCell.swift
//  NavRushSDK_Example
//
//  Created by tr on 26/02/19.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Foundation
import UIKit

class BeaconCell:UITableViewCell
{
    @IBOutlet weak var uuidLabel: UILabel!
    @IBOutlet weak var majorLabel: UILabel!
    @IBOutlet weak var rssiLabel: UILabel!
    @IBOutlet weak var minorLabel: UILabel!
}
