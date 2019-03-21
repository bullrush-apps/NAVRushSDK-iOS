//
//  NavRushMotionsTracker.swift
//  NavRushSDK
//
//  Created by tr on 6/02/19.
//  CoreMotion - Accelerometer tracker
//  Decisions whether device is standing/moving

import Foundation
import CoreMotion
import NavRushFramework

protocol NavRushMotionsTrackerDelegate {
    /**
     Delegate Method called when device motion state changes
     
     - Parameter tracker: This NavRushMotionsTracker instance
     - Parameter isMoving: Standing still or moving
     
     */
    func motionTrackerChangedState(tracker:NavRushMotionsTracker, isMoving:Bool)
}

class NavRushMotionsTracker:NSObject {
    unowned let navRushTracker : NavRushTracker
    var delegate:NavRushMotionsTrackerDelegate?
    let motionManager = CMMotionManager()
    var motionTimer:Timer?
    var lastChange:Date?
    var isTracking = false
    
    /**
     NavRushMotionsTracker Constructor
     
     - Parameter tracker: Common NavRush Tracker
     - Parameter delegate: Listens to motion events
     
     - Returns: NavRushMotionsTracker
     */
    init(tracker:NavRushTracker, delegate:NavRushMotionsTrackerDelegate) {
        self.navRushTracker = tracker
        super.init()
        self.delegate = delegate
    }
    
    /**
     If tracking, stops and remove references
     */
    func stopDeviceMotion()
    {
        if isTracking
        {
            motionTimer?.invalidate()
            motionTimer = nil
            motionManager.stopDeviceMotionUpdates()
            isTracking = false
            print("NavRushMotionsTracker stopped tracking")
        }
    }
    
    /**
     If not tracking, starts and updates delegate
     */
    func startDeviceMotion() {
        if isTracking
        {
            return
        }
        if self.motionManager.isDeviceMotionAvailable {
            self.motionManager.deviceMotionUpdateInterval = NavRushFramework.MOTIONS_INTERVAL
            self.motionManager.showsDeviceMovementDisplay = true
            self.motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
            self.isTracking = true
            print("NavRushMotionsTracker started tracking")
            // Configure a timer to fetch the motion data.
            self.motionTimer = Timer(fire: Date(), interval: (NavRushFramework.MOTIONS_INTERVAL), repeats: true, block: { (timer) in
                if let data = self.motionManager.deviceMotion {
                    // Get the attitude relative to the magnetic north reference frame.
                    let x =  fabs(data.userAcceleration.x)
                    let y = fabs(data.userAcceleration.y)
                    let z = fabs(data.userAcceleration.z)
                    
                    if (x > NavRushFramework.ACCELERATION_THRESHOLD || y > NavRushFramework.ACCELERATION_THRESHOLD || z > NavRushFramework.ACCELERATION_THRESHOLD)
                    {
                        if self.navRushTracker.isMoving
                        {
                            //Nothing, continue to move
                            self.lastChange = nil
                        }
                        else
                        {
                            //Was standing before, do we have lastChange?
                            if let tmpDate = self.lastChange
                            {
                                //Does it pass delay
                                if Date().timeIntervalSince(tmpDate) > NavRushFramework.MOVING_DELAY
                                {
                                    //Change state from standing -> moving
                                    self.delegate?.motionTrackerChangedState(tracker: self, isMoving: true)
                                    self.lastChange = nil
                                }
                            }
                            else
                            {
                                //Start counting delay towards Moving
                                self.lastChange = Date()
                            }
                        }
                    }
                    else
                    {
                        if self.navRushTracker.isMoving == false
                        {
                            //Nothing, continue to stand
                            self.lastChange = nil
                        }
                        else
                        {
                            //Was moving before, do we have lastChange?
                            if let tmpDate = self.lastChange
                            {
                                //Does it pass delay
                                if Date().timeIntervalSince(tmpDate) > NavRushFramework.STANDNING_DELAY
                                {
                                    //Change state from moving -> standing
                                    self.delegate?.motionTrackerChangedState(tracker: self, isMoving: false)
                                    self.lastChange = nil
                                }
                            }
                            else
                            {
                                //Start counting delay towards Moving
                                self.lastChange = Date()
                            }
                        }
                    }
                }
            })
            
            // Add the timer to the current run loop.
            RunLoop.current.add(self.motionTimer!, forMode: RunLoop.Mode.defaultRunLoopMode)
        }
    }
}
