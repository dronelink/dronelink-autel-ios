//
//  AutelDroneSessionManager.swift
//  DronelinkAutel
//
//  Created by Jim McAndrew on 1/20/22.
//  Copyright © 2022 Dronelink. All rights reserved.
//
import os
import DronelinkCore
import AUTELSDK

public class AutelDroneSessionManager: NSObject {
    private static let log = OSLog(subsystem: "DronelinkAutel", category: "AutelDroneSessionManager")
    
    private let delegates = MulticastDelegate<DroneSessionManagerDelegate>()
    private var _session: AutelDroneSession?
    
    public init(appKey: String) {
        super.init()
        AUTELAppManager.registerApp(appKey, with: self)
    }
}

extension AutelDroneSessionManager: DroneSessionManager {
    public func add(delegate: DroneSessionManagerDelegate) {
        delegates.add(delegate)
        if let session = _session {
            delegate.onOpened(session: session)
        }
    }
    
    public func remove(delegate: DroneSessionManagerDelegate) {
        delegates.remove(delegate)
    }
    
    public func closeSession() {
        if let session = _session {
            session.close()
            _session = nil
            delegates.invoke { $0.onClosed(session: session) }
        }
    }
    
    public func startRemoteControllerLinking(finished: CommandFinished?) {
        if let remoteController = (AUTELAppManager.connectedDevice() as? AUTELDrone)?.remoteController {
            remoteController.enterRCPairingMode { (state: AUTELRCParingResultState, error: Error?) in
                finished?(error)
            }
            return
        }
        finished?("AutelDroneSessionManager.remoteControllerLinking.unavailable".localized)
    }
    
    public func stopRemoteControllerLinking(finished: CommandFinished?) {
        if let remoteController = (AUTELAppManager.connectedDevice() as? AUTELDrone)?.remoteController {
            remoteController.exitRCCalibration(completion: finished)
            return
        }
        finished?("AutelDroneSessionManager.remoteControllerLinking.unavailable".localized)
    }
    
    public var session: DroneSession? { _session }
    
    public var statusMessages: [Kernel.Message] { [] }
}

extension AutelDroneSessionManager: AUTELAppManagerDelegate {
    public func appManagerDidRegisterWithError(_ error: Error?) {
        if let error = error {
            os_log(.error, log: AutelDroneSessionManager.log, "Autel SDK Registered with error: %{public}s", error.localizedDescription)
        }
        else {
            os_log(.info, log: AutelDroneSessionManager.log, "Autel SDK Registered successfully")
        }
    }
    
    public func appManagerDidConnectedDeviceChanged(_ newDevice: AUTELDevice) {
        if let drone = newDevice as? AUTELDrone {
            if let session = _session {
                if (session.adapter.drone === drone) {
                    return
                }
                closeSession()
            }
            
            _session = AutelDroneSession(manager: self, drone: drone)
            delegates.invoke { $0.onOpened(session: self._session!) }
        }
    }
}
