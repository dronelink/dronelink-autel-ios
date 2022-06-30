//
//  AutelDroneSession+RemoteControllerCommand.swift
//  DronelinkAutel
//
//  Created by Jim McAndrew on 1/22/22.
//  Copyright © 2022 Dronelink. All rights reserved.
//
import DronelinkCore
import os

extension AutelDroneSession {
    func execute(remoteControllerCommand: KernelRemoteControllerCommand, finished: @escaping CommandFinished) -> Error? {
        //FIXME
//        guard
//            let remoteController = adapter.drone.remoteController(channel: remoteControllerCommand.channel)
//        else {
//            return "MissionDisengageReason.drone.remote.controller.unavailable.title".localized
//        }
//
//        if let command = remoteControllerCommand as? Kernel.TargetGimbalChannelRemoteControllerCommand {
//            remoteController.getControllingGimbalIndex { (current, error) in
//                Command.conditionallyExecute(current != command.targetGimbalChannel, error: error, finished: finished) {
//                    remoteController.setControllingGimbalIndex(command.targetGimbalChannel, withCompletion: finished)
//                }
//            }
//
//            return nil
//        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
}
