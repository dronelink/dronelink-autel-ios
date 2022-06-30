//
//  AutelDroneSession+GimbalCommand.swift
//  DronelinkAutel
//
//  Created by Jim McAndrew on 1/22/22.
//  Copyright © 2022 Dronelink. All rights reserved.
//
import os
import DronelinkCore
import AUTELSDK

extension AutelDroneSession {
    func execute(gimbalCommand: KernelGimbalCommand, finished: @escaping CommandFinished) -> Error? {
        guard
            let gimbal = adapter.drone.gimbal(channel: gimbalCommand.channel),
            let state = gimbalState(channel: gimbalCommand.channel)?.value
        else {
            return "MissionDisengageReason.drone.gimbal.unavailable.title".localized
        }
        
        if let command = gimbalCommand as? Kernel.ModeGimbalCommand {
            Command.conditionallyExecute(command.mode != state.mode, finished: finished) {
                gimbal.setGimbalWorkMode(command.mode.autelValue, withCompletion: finished)
            }
            return nil
        }
        
        if let command = gimbalCommand as? Kernel.OrientationGimbalCommand {
            if (command.orientation.pitch == nil && command.orientation.roll == nil && command.orientation.yaw == nil) {
                finished(nil)
                return nil
            }
            
            var pitch = command.orientation.pitch?.convertRadiansToDegrees
            if let pitchValid = pitch, abs(pitchValid + 90) < 0.1 {
                pitch = -89.9
            }
            
            let roll = command.orientation.roll?.convertRadiansToDegrees
            let yaw = command.orientation.yaw?.convertRadiansToDegrees
            
            if pitch == nil && roll == nil && (state.mode != .free || yaw == nil) {
                finished(nil)
                return nil
            }
            
            if let rotation = AUTELGimbalRotation(
                pitchValue: pitch as NSNumber?,
                rollValue: state.mode == .free ? roll as NSNumber? : nil,
                yawValue: state.mode == .free ? yaw as NSNumber? : nil,
                mode: .absoluteAngle) {
                gimbal.rotate(with: rotation, withCompletion: finished)
            }
            else {
                return "FIXME"
            }
            return nil
        }
        
        if let _ = gimbalCommand as? Kernel.YawSimultaneousFollowGimbalCommand {
            return "FIXME"
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
}
