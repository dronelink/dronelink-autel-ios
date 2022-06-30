//
//  AutelVirtualStickSession.swift
//  DronelinkAutel
//
//  Created by Jim McAndrew on 1/20/22.
//  Copyright © 2022 Dronelink. All rights reserved.
//
import os
import DronelinkCore

public class AutelVirtualStickSession: DroneControlSession {
    private static let log = OSLog(subsystem: "DronelinkAutel", category: "AutelVirtualStickSession")
    
    private enum State {
        case MotorArmStart
        case MotorArmAttempting
        case MotorArmComplete
        case TakeoffStart
        case TakeoffAttempting
        case TakeoffComplete
        case Deactivated
    }
    
    public let executionEngine = Kernel.ExecutionEngine.dronelinkKernel
    public var reengaging: Bool = false
    private let droneSession: AutelDroneSession
    
    private var state = State.MotorArmStart
    private var _disengageReason: Kernel.Message?
    
    public init(droneSession: AutelDroneSession) {
        self.droneSession = droneSession
    }
    
    
    public var disengageReason: Kernel.Message? {
        if let attemptDisengageReason = _disengageReason {
            return attemptDisengageReason
        }
        
        //would like to disengage if they press the sticks (because it fights the v stick input)
        //the issue is v stick inputs show up here too (same as physical input)!
//        if let remoteControllerState = droneSession.remoteControllerState(channel: 0)?.value {
//            if remoteControllerState.leftStick.pressed || remoteControllerState.rightStick.pressed {
//                return Kernel.Message(title: "MissionDisengageReason.drone.control.override.title".localized, details: "MissionDisengageReason.drone.control.override.details".localized)
//            }
//        }
        
        return nil
    }
    
    public func activate() -> Bool? {
        guard
            let mainController = droneSession.adapter.drone.mainController,
            let mainControllerState = droneSession.mainControllerState
        else {
            deactivate()
            return false
        }
        
        switch state {
        case .MotorArmStart:
            if mainControllerState.value.isMotorWorking {
                state = .MotorArmComplete
                return activate()
            }
            
            state = .MotorArmAttempting
            os_log(.info, log: AutelVirtualStickSession.log, "Attempting to arm motors")
            mainController.turnOnMotor { [weak self] error in
                if let error = error {
                    os_log(.error, log: AutelVirtualStickSession.log, "Arming motors failed: %{public}s", error.localizedDescription)
                   self?._disengageReason = Kernel.Message(title: "MissionDisengageReason.arm.motors.failed.title".localized)
                   self?.deactivate()
                   return
                }

                os_log(.info, log: AutelVirtualStickSession.log, "Motors armed")
            }
            return nil
            
        case .MotorArmAttempting:
            if mainControllerState.value.isMotorWorking {
                state = .MotorArmComplete
                return activate()
            }
            return nil
            
        case .MotorArmComplete:
            state = .TakeoffStart
            return activate()
            
        case .TakeoffStart:
            if mainControllerState.value.isFlying {
                state = .TakeoffComplete
                return activate()
            }

            state = .TakeoffAttempting
            os_log(.info, log: AutelVirtualStickSession.log, "Attempting takeoff")
            mainController.startTakeoff { [weak self] error in
                if let error = error {
                    os_log(.error, log: AutelVirtualStickSession.log, "Takeoff failed: %{public}s", error.localizedDescription)
                   self?._disengageReason = Kernel.Message(title: "MissionDisengageReason.take.off.failed.title".localized)
                   self?.deactivate()
                   return
                }

                os_log(.info, log: AutelVirtualStickSession.log, "Takeoff succeeded")
            }
            return nil
            
        case .TakeoffAttempting:
            if mainControllerState.value.isFlying && mainControllerState.value.flightMode != .AutelMCFlightModeTakeoff {
                state = .TakeoffComplete
                return activate()
            }
            return nil
            
        case .TakeoffComplete:
            return true
            
        case .Deactivated:
            return false
        }
    }
    
    public func deactivate() {
        droneSession.sendResetVelocityCommand()
        droneSession.sendResetGimbalCommands()
        state = .Deactivated
    }
}
