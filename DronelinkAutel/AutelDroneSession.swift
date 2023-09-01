//
//  AutelDroneSession.swift
//  DronelinkAutel
//
//  Created by Jim McAndrew on 1/20/22.
//  Copyright © 2022 Dronelink. All rights reserved.
//
import os
import DronelinkCore
import AUTELSDK

private enum AutelDroneSessionMainControllerInitAction: Error {
    case setPitchStickSensitivity
    case setRollStickSensitivity
    case setYawStickSensitivity
    case setThrustStickSensitivity
    case setAttitudeStickSensitivity
    case setBrakeStickSensitivity
    case setYawSchStickSensitivity
    case getGoHomeDefaultAltitude
    case getLowBatteryWarning
    case setBeginnerMode
    case setMaxFlightHorizontalSpeed
    case getMaxFlightHeight
}

public class AutelDroneSession: NSObject {
    internal static let log = OSLog(subsystem: "DronelinkAutel", category: "AutelDroneSession")
    
    public let manager: DroneSessionManager
    public let adapter: AutelDroneAdapter
    
    private let _opened = Date()
    private var _closed = false
    private var _id = UUID().uuidString
    private var _serialNumber: String?
    private var _firmwarePackageVersion: String?
    private var _initialized = false
    private var _located = false
    private var _lastKnownGroundLocation: CLLocation?
    
    private let delegates = MulticastDelegate<DroneSessionDelegate>()
    private let droneCommands = CommandQueue()
    private let remoteControllerCommands = MultiChannelCommandQueue()
    private let cameraCommands = MultiChannelCommandQueue()
    private let gimbalCommands = MultiChannelCommandQueue()
    
    private let mainControllerSerialQueue = DispatchQueue(label: "AutelDroneSession+mainControllerState")
    private var _mainControllerState: DatedValue<AUTELMCSystemState>?
    public var _mainControllerGoHomeDefaultAltitude: Float?
    public var _mainControllerLowBatteryThreshold: Double?
    public var _flightLimitationMaxFlightHeight: Float?
    
    private let batterySerialQueue = DispatchQueue(label: "AutelDroneSession+batteryState")
    private var _batteryState: DatedValue<AUTELBatteryState>?
    
    private let remoteControllerSerialQueue = DispatchQueue(label: "AutelDroneSession+remoteControllerState")
    private var _remotecontrollerRCState: DatedValue<AUTELRCState>?
    private var _remoteControllerStateAdapter: DatedValue<RemoteControllerStateAdapter>?
    
    private let cameraSerialQueue = DispatchQueue(label: "DJIDroneSession+cameraStates")
    private var _cameraStates: [UInt: DatedValue<AUTELCameraSystemBaseState>] = [:]
    private var _cameraStorageStates: [UInt: DatedValue<AUTELCameraSDCardState>] = [:]
    internal var _cameraExposureMode: DatedValue<AUTELCameraExposureMode>?
    private var _cameraExposureParameters: [String: DatedValue<AUTELCameraExposureParameters>] = [:]
    private var _cameraHistograms: [String: DatedValue<[UInt]?>] = [:]
    internal var _cameraFocusMode: DatedValue<AUTELCameraLensFocusMode>?
    
    private let gimbalSerialQueue = DispatchQueue(label: "AutelDroneSession+gimbalStates")
    private var _gimbalStates: [UInt: DatedValue<GimbalStateAdapter>] = [:]
    
    private var _mostRecentCameraFile: DatedValue<CameraFile>?
    public var mostRecentCameraFile: DatedValue<CameraFile>? { get { _mostRecentCameraFile } }
    
    private var _maxHorizontalVelocity = 15.0
    public var maxHorizontalVelocity: Double { get { _maxHorizontalVelocity } }
    private var _maxAscentVelocity = 5.0
    public var maxAscentVelocity: Double { get { _maxAscentVelocity } }
    private var _maxDescentVelocity = 5.0
    public var maxDescentVelocity: Double { get { _maxDescentVelocity } }
    
    public init(manager: DroneSessionManager, drone: AUTELDrone) {
        self.manager = manager
        adapter = AutelDroneAdapter(drone: drone)
        super.init()
        adapter.session = self
        initDrone()
        Thread.detachNewThread(self.execute)
    }
    
    private func initDrone() {
        os_log(.info, log: AutelDroneSession.log, "Drone session opened")
        adapter.drone.delegate = self
        
        initMainController()
        initDroneDetails()
        
        adapter.drone.battery?.delegate = self
        adapter.drone.remoteController?.delegate = self
        adapter.drone.gimbal?.delegate = self
        adapter.drone.gimbal.setGimbalPitchAngleRange(.type2)
        adapter.drone.camera?.delegate = self
    }
    
    private func initMainController(action: AutelDroneSessionMainControllerInitAction = .setPitchStickSensitivity) {
        guard let mainController = adapter.drone.mainController else {
            os_log(.error, log: AutelDroneSession.log, "Main controller unavailable")
            return
        }
        
        if mainController.mcDelegate == nil {
            mainController.mcDelegate = self
        }
        
        switch action {
        case .setPitchStickSensitivity:
            mainController.getPitchStickSensitivity { [weak self] (value, error) in
                if let error = error {
                    os_log(.error, log: AutelDroneSession.log, "Main controller getPitchStickSensitivity failed: %{public}s", error.localizedDescription)
                }
                
                if error != nil || abs(value - 0.5) > 0.01 {
                    mainController.setPitchStickSensitivity(0.5) {error in
                        if let error = error {
                            os_log(.error, log: AutelDroneSession.log, "Main controller setPitchStickSensitivity failed: %{public}s", error.localizedDescription)
                        }
                        else {
                            os_log(.info, log: AutelDroneSession.log, "Main controller setPitchStickSensitivity reset to 0.5 (%{public}f)", value)
                        }
                        self?.initMainController(action: .setRollStickSensitivity)
                    }
                    return
                }
                
                os_log(.info, log: AutelDroneSession.log, "Main controller getPitchStickSensitivity already set to 0.5")
                self?.initMainController(action: .setRollStickSensitivity)
            }
            break
            
        case .setRollStickSensitivity:
            mainController.getRollStickSensitivity { [weak self] (value, error) in
                if let error = error {
                    os_log(.error, log: AutelDroneSession.log, "Main controller getRollStickSensitivity failed: %{public}s", error.localizedDescription)
                }
                
                if error != nil || abs(value - 0.5) > 0.01 {
                    mainController.setRollStickSensitivity(0.5) {error in
                        if let error = error {
                            os_log(.error, log: AutelDroneSession.log, "Main controller setRollStickSensitivity failed: %{public}s", error.localizedDescription)
                        }
                        else {
                            os_log(.info, log: AutelDroneSession.log, "Main controller setRollStickSensitivity reset to 0.5 (%{public}f)", value)
                        }
                        self?.initMainController(action: .setYawStickSensitivity)
                    }
                    return
                }
                
                os_log(.info, log: AutelDroneSession.log, "Main controller getRollStickSensitivity already set to 0.5")
                self?.initMainController(action: .setYawStickSensitivity)
            }
            break
            
        case .setYawStickSensitivity:
            mainController.getYawStickSensitivity { [weak self] (value, error) in
                if let error = error {
                    os_log(.error, log: AutelDroneSession.log, "Main controller getYawStickSensitivity failed: %{public}s", error.localizedDescription)
                }
                
                if error != nil || abs(value - 0.5) > 0.01 {
                    mainController.setYawStickSensitivity(0.5) {error in
                        if let error = error {
                            os_log(.error, log: AutelDroneSession.log, "Main controller setYawStickSensitivity failed: %{public}s", error.localizedDescription)
                        }
                        else {
                            os_log(.info, log: AutelDroneSession.log, "Main controller setYawStickSensitivity reset to 0.5 (%{public}f)", value)
                        }
                        self?.initMainController(action: .setThrustStickSensitivity)
                    }
                    return
                }
                
                os_log(.info, log: AutelDroneSession.log, "Main controller getYawStickSensitivity already set to 0.5")
                self?.initMainController(action: .setThrustStickSensitivity)
            }
            break
            
        case .setThrustStickSensitivity:
            mainController.getThrustStickSensitivity { [weak self] (value, error) in
                if let error = error {
                    os_log(.error, log: AutelDroneSession.log, "Main controller getThrustStickSensitivity failed: %{public}s", error.localizedDescription)
                }
                
                if error != nil || abs(value - 0.5) > 0.01 {
                    mainController.setThrustStickSensitivity(0.5) {error in
                        if let error = error {
                            os_log(.error, log: AutelDroneSession.log, "Main controller setYawStickSensitivity failed: %{public}s", error.localizedDescription)
                        }
                        else {
                            os_log(.info, log: AutelDroneSession.log, "Main controller setYawStickSensitivity reset to 0.5 (%{public}f)", value)
                        }
                        self?.initMainController(action: .setAttitudeStickSensitivity)
                    }
                    return
                }
                
                os_log(.info, log: AutelDroneSession.log, "Main controller getThrustStickSensitivity already set to 0.5")
                self?.initMainController(action: .setAttitudeStickSensitivity)
            }
            break
            
        case .setAttitudeStickSensitivity:
            mainController.getAttitudeStickSensitivity { [weak self] (value, error) in
                if let error = error {
                    os_log(.error, log: AutelDroneSession.log, "Main controller getAttitudeStickSensitivity failed: %{public}s", error.localizedDescription)
                }
                
                if error != nil || abs(value - 1.0) > 0.01 {
                    mainController.setAttitudeStickSensitivity(1.0) {error in
                        if let error = error {
                            os_log(.error, log: AutelDroneSession.log, "Main controller setAttitudeStickSensitivity failed: %{public}s", error.localizedDescription)
                        }
                        else {
                            os_log(.info, log: AutelDroneSession.log, "Main controller setAttitudeStickSensitivity reset to 1.0 (%{public}f)", value)
                        }
                        self?.initMainController(action: .setBrakeStickSensitivity)
                    }
                    return
                }
                
                os_log(.info, log: AutelDroneSession.log, "Main controller getAttitudeStickSensitivity already set to 1.0")
                self?.initMainController(action: .setBrakeStickSensitivity)
            }
            break
            
        case .setBrakeStickSensitivity:
            mainController.getBrakeStickSensitivity { [weak self] (value, error) in
                if let error = error {
                    os_log(.error, log: AutelDroneSession.log, "Main controller getBrakeStickSensitivity failed: %{public}s", error.localizedDescription)
                }
                
                if error != nil || abs(value - 1.0) > 0.01 {
                    mainController.setBrakeStickSensitivity(1.0) {error in
                        if let error = error {
                            os_log(.error, log: AutelDroneSession.log, "Main controller setBrakeStickSensitivity failed: %{public}s", error.localizedDescription)
                        }
                        else {
                            os_log(.info, log: AutelDroneSession.log, "Main controller setBrakeStickSensitivity reset to 1.0 (%{public}f)", value)
                        }
                        self?.initMainController(action: .setYawSchStickSensitivity)
                    }
                    return
                }
                
                os_log(.info, log: AutelDroneSession.log, "Main controller getBrakeStickSensitivity already set to 1.0")
                self?.initMainController(action: .setYawSchStickSensitivity)
            }
            break
            
        case .setYawSchStickSensitivity:
            mainController.getYawSchStickSensitivity { [weak self] (value, error) in
                if let error = error {
                    os_log(.error, log: AutelDroneSession.log, "Main controller getYawSchStickSensitivity failed: %{public}s", error.localizedDescription)
                }
                
                if error != nil || abs(value - 0.75) > 0.01 {
                    mainController.setYawSchStickSensitivity(0.75) {error in
                        if let error = error {
                            os_log(.error, log: AutelDroneSession.log, "Main controller setBrakeStickSensitivity failed: %{public}s", error.localizedDescription)
                        }
                        else {
                            os_log(.info, log: AutelDroneSession.log, "Main controller setBrakeStickSensitivity reset to 0.75 (%{public}f)", value)
                        }
                        self?.initMainController(action: .getGoHomeDefaultAltitude)
                    }
                    return
                }
                
                os_log(.info, log: AutelDroneSession.log, "Main controller getYawSchStickSensitivity already set to 0.75")
                self?.initMainController(action: .getGoHomeDefaultAltitude)
            }
            break
            
        case .getGoHomeDefaultAltitude:
            mainController.getGoHomeDefaultAltitude { [weak self] (value, error) in
                if let error = error {
                    os_log(.error, log: AutelDroneSession.log, "Main controller getGoHomeDefaultAltitude failed: %{public}s", error.localizedDescription)
                }
                else {
                    self?._mainControllerGoHomeDefaultAltitude = value
                }
                self?.initMainController(action: .getLowBatteryWarning)
            }
            break
            
        case .getLowBatteryWarning:
            mainController.getLowBatteryWarning { [weak self] (value, error) in
                if let error = error {
                    os_log(.error, log: AutelDroneSession.log, "Main controller getLowBatteryWarning failed: %{public}s", error.localizedDescription)
                }
                else {
                    self?._mainControllerLowBatteryThreshold = Double(value) / 100
                }
                self?.initMainController(action: .setBeginnerMode)
            }
            break
            
        case .setBeginnerMode:
            if let flightLimitation = mainController.flightLimitation {
                flightLimitation.getBeginnerModeEnable { [weak self] enabled, error in
                    if let error = error {
                        os_log(.error, log: AutelDroneSession.log, "Main controller getBeginnerModeEnable failed: %{public}s", error.localizedDescription)
                    }
                    
                    if error != nil || enabled {
                        flightLimitation.setBeginnerMode(false) { error in
                            if let error = error {
                                os_log(.error, log: AutelDroneSession.log, "Main controller setBeginnerMode failed: %{public}s", error.localizedDescription)
                            }
                            else {
                                os_log(.info, log: AutelDroneSession.log, "Main controller setBeginnerMode to false")
                            }
                            self?.initMainController(action: .setMaxFlightHorizontalSpeed)
                        }
                        return
                    }
                    
                    os_log(.info, log: AutelDroneSession.log, "Main controller getBeginnerModeEnable already set to false")
                    self?.initMainController(action: .setMaxFlightHorizontalSpeed)
                }
            }
            else {
                os_log(.error, log: AutelDroneSession.log, "Main controller flightLimitation unavailable to getBeginnerModeEnable")
                initMainController(action: .setMaxFlightHorizontalSpeed)
            }
            break
            
        case .setMaxFlightHorizontalSpeed:
            if let flightLimitation = mainController.flightLimitation {
                flightLimitation.getMaxFlightHorizontalSpeed { [weak self] value, error in
                    if let error = error {
                        os_log(.error, log: AutelDroneSession.log, "Main controller getMaxFlightHorizontalSpeed failed: %{public}s", error.localizedDescription)
                    }
                    
                    if error != nil || abs(value - 15.0) > 0.01 {
                        flightLimitation.setMaxFlightHorizontalSpeed(15) { error in
                            if let error = error {
                                os_log(.error, log: AutelDroneSession.log, "Main controller setMaxFlightHorizontalSpeed failed: %{public}s", error.localizedDescription)
                            }
                            else {
                                os_log(.info, log: AutelDroneSession.log, "Main controller setMaxFlightHorizontalSpeed to 15 m/s")
                            }
                            self?.initMainController(action: .getMaxFlightHeight)
                        }
                        return
                    }
                    
                    os_log(.info, log: AutelDroneSession.log, "Main controller setMaxFlightHorizontalSpeed already set to 15 m/s")
                    self?.initMainController(action: .getMaxFlightHeight)
                }
            }
            else {
                os_log(.error, log: AutelDroneSession.log, "Main controller flightLimitation unavailable to getMaxFlightHorizontalSpeed")
                initMainController(action: .getMaxFlightHeight)
            }
            break
            
        case .getMaxFlightHeight:
            if let flightLimitation = mainController.flightLimitation {
                flightLimitation.getMaxFlightHeight { [weak self] value, error in
                    if let error = error {
                        os_log(.error, log: AutelDroneSession.log, "Main controller getMaxFlightHeight failed: %{public}s", error.localizedDescription)
                    }
                    else {
                        self?._flightLimitationMaxFlightHeight = value
                        os_log(.info, log: AutelDroneSession.log, "Main controller getMaxFlightHeight %{public}f", value)
                    }
                }
            }
            else {
                os_log(.error, log: AutelDroneSession.log, "Main controller flightLimitation unavailable to getMaxFlightHeight")
            }
            break
        }
        
        
// Autel claims this is legacy code
//            flightLimitation.setMaxDescentSpeed(-5) { [weak self] error in
//                flightLimitation.getMaxDescentSpeed { (value, error) in
//                    if let error = error {
//                        os_log(.debug, log: AutelDroneSession.log, "Main controller max descent velocity unknown")
//                    }
//                    else {
//                        os_log(.debug, log: AutelDroneSession.log, "Main controller max descent velocity: %{public}f", value)
//                        self?._maxDescentVelocity = Double(value)
//                    }
//                }
//            }
        
// Autel claims this is legacy code
//            flightLimitation.setMaxAscentSpeed(5) { [weak self] error in
//                flightLimitation.getMaxAscentSpeed { (value, error) in
//                    if let error = error {
//                        os_log(.debug, log: AutelDroneSession.log, "Main controller max ascent velocity unknown")
//                    }
//                    else {
//                        os_log(.debug, log: AutelDroneSession.log, "Main controller max ascent velocity: %{public}f", value)
//                        self?._maxAscentVelocity = Double(value)
//                    }
//                }
//            }
    }
    
    private func initDroneDetails(attempt: Int = 0) {
        guard attempt < 3 else {
            return
        }
        
        AUTELAppManager.getFirmwareVersion { [weak self] (details, error) in
            guard let details = details, error == nil else {
                DispatchQueue.global().asyncAfter(deadline: .now() + Double(attempt)) {
                    self?.initDroneDetails(attempt: attempt + 1)
                }
                return
            }
            
            for detail in details {
                if let componentName = detail["ComponetName"] as? String,
                   let serialNumber = detail["SerialNumber"] as? String,
                    let software = detail["Software"] as? String {
                    if componentName == "DEV_UAV" {
                        self?._serialNumber = serialNumber
                        os_log(.info, log: AutelDroneSession.log, "Serial number: %{public}s", serialNumber)
                        self?._firmwarePackageVersion = software
                        os_log(.info, log: AutelDroneSession.log, "Firmware package version: %{public}s", software)
                    }
                }
            }
        }
    }
    
    public var mainControllerState: DatedValue<AUTELMCSystemState>? {
        mainControllerSerialQueue.sync { [weak self] in
            return self?._mainControllerState
        }
    }
    
    public var batteryState: DatedValue<AUTELBatteryState>? {
        batterySerialQueue.sync { [weak self] in
            return self?._batteryState
        }
    }
    
    public var remotecontrollerRCState: DatedValue<AUTELRCState>? {
        remoteControllerSerialQueue.sync { [weak self] in
            return self?._remotecontrollerRCState
        }
    }
    
    private func execute() {
        while !_closed {
            if !_initialized,
                _serialNumber != nil,
                _firmwarePackageVersion != nil
            {
                _initialized = true
                DispatchQueue.global().async { [weak self] in
                    guard let session = self else {
                        return
                    }
                    session.delegates.invoke { $0.onInitialized(session: session) }
                }
            }
            
            if let location = location {
                if (!_located) {
                    _located = true
                    DispatchQueue.global().async { [weak self] in
                        guard let session = self else {
                            return
                        }
                        session.delegates.invoke { $0.onLocated(session: session) }
                    }
                }
                
                if !isFlying {
                    _lastKnownGroundLocation = location
                }
            }
            
            if -(_cameraExposureMode?.date.timeIntervalSinceNow ?? -5.0) >= 5.0 {
                //update the date so we don't run twice
                _cameraExposureMode = DatedValue(value: _cameraExposureMode?.value ?? .unknown)
                adapter.drone.camera.getExposureMode { [weak self] (value, error) in
                    self?.cameraSerialQueue.async {
                        self?._cameraExposureMode = DatedValue(value: value)
                    }
                }
            }
            
            if -(_cameraFocusMode?.date.timeIntervalSinceNow ?? -5.0) >= 5.0 {
                //update the date so we don't run twice
                _cameraFocusMode = DatedValue(value: _cameraFocusMode?.value ?? .unknown)
                adapter.drone.camera.getLensFocusMode { [weak self] (value, error) in
                    self?.cameraSerialQueue.async {
                        self?._cameraFocusMode = DatedValue(value: value)
                    }
                }
            }
            
            self.droneCommands.process()
            self.remoteControllerCommands.process()
            self.cameraCommands.process()
            self.gimbalCommands.process()
            
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        os_log(.info, log: AutelDroneSession.log, "Drone session closed")
    }
    
    internal func sendResetVelocityCommand(withCompletion: AUTELCompletionBlock? = nil) {
        adapter.sendResetVelocityCommand(withCompletion: withCompletion)
    }
    
    internal func sendResetGimbalCommands() {
        if let rotation = AUTELGimbalRotation(pitchValue: -12, rollValue: 0, yawValue: nil, mode: .absoluteAngle) {
            adapter.drone.gimbal.rotate(with: rotation, withCompletion: nil)
        }
    }
    
    internal func sendResetCameraCommands() {
        if let cameraState = cameraState(channel: 0)?.value {
            if (cameraState.isCapturingVideo) {
                adapter.drone.camera.stopRecordVideo(completion: nil)
            }
            else if (cameraState.isCapturing) {
                adapter.drone.camera.stopShootPhoto(completion: nil)
            }
        }
    }
}

extension AutelDroneSession: AUTELDeviceDelegate {
    public func device(_ device: AUTELDevice!, didConnectionStatusChanged status: AUTELDeviceConnectionStatus) {
        switch status {
        case .ConnectionBroken:
            manager.closeSession()
            break
            
        case .ConnectionSucceeded:
            break
            
        @unknown default:
            break
        }
    }
}

extension AutelDroneSession: AUTELDroneMainControllerDelegate {
    public func mainController(_ mc: AUTELDroneMainController, didUpdateSystemState state: AUTELMCSystemState) {
        mainControllerSerialQueue.sync { [weak self] in
            self?._mainControllerState = DatedValue(value: state)
        }
    }
    
    public func mainController(_ mc: AUTELDroneMainController, didUpdateRTKState state: AUTELRTKStatusInfoModel) {}
    
    public func mainController(_ mc: AUTELDroneMainController, didUpdateRTKDiffData data: Data) {}
}

extension AutelDroneSession: AUTELBatteryDelegate {
    public func battery(_ battery: AUTELBattery!, didUpdataState state: AUTELBatteryState!) {
        batterySerialQueue.async { [weak self] in
            self?._batteryState = DatedValue<AUTELBatteryState>(value: state)
        }
    }
}

extension AutelDroneSession: AUTELRemoteControllerDelegate {
    public func remoteController(_ rc: AUTELRemoteController!, didUpdateRCState rcState: AUTELRCState) {
        remoteControllerSerialQueue.async { [weak self] in
            self?._remotecontrollerRCState = DatedValue<AUTELRCState>(value: rcState)
        }
    }
    
    public func remoteController(_ rc: AUTELRemoteController!, didUpdateHardwareState hardwareState: AUTELRCHardwareState) {
        remoteControllerSerialQueue.async { [weak self] in
            self?._remoteControllerStateAdapter = DatedValue<RemoteControllerStateAdapter>(value: AutelRemoteControllerStateAdapter(rcHardwareState: hardwareState))
        }
    }
}

extension AutelDroneSession: AUTELBaseCameraDelegate {
    public func camera(_ camera: AUTELBaseCamera!, didUpdateSystemState systemState: AUTELCameraSystemBaseState!) {
        cameraSerialQueue.async { [weak self] in
            self?._cameraStates[0] = DatedValue<AUTELCameraSystemBaseState>(value: systemState)
        }
    }

    public func camera(_ camera: AUTELBaseCamera!, didUpdateSDCardState sdCardState: AUTELCameraSDCardState!) {
        cameraSerialQueue.async { [weak self] in
            self?._cameraStorageStates[0] = DatedValue<AUTELCameraSDCardState>(value: sdCardState)
        }
    }
    
    public func camera(_ camera: AUTELBaseCamera!, didUpdateCurrentExposureValues exposureParameters: AUTELCameraExposureParameters!) {
        cameraSerialQueue.async { [weak self] in
            self?._cameraExposureParameters["0.0"] = DatedValue<AUTELCameraExposureParameters>(value: exposureParameters)
        }
    }
    
    public func camera(_ camera: AUTELBaseCamera!, didUpdateHistogramTotalPixels totalPixels: Int, andPixelsPerLevel pixelsArray: [Any]!) {
        cameraSerialQueue.async { [weak self] in
            self?._cameraHistograms["0.0"] = DatedValue<[UInt]?>(value: pixelsArray?.map({
                ($0 as? NSNumber)?.uintValue ?? 0
            }))
        }
    }

    public func camera(_ camera: AUTELBaseCamera!, didGenerateNewMediaFile newMedia: AUTELMedia!) {
        var orientation = self.orientation
        if let gimbalState = self.gimbalState(channel: 0)?.value {
            orientation.x = gimbalState.orientation.x
            orientation.y = gimbalState.orientation.y
            if gimbalState.mode == .free {
                orientation.z = gimbalState.orientation.z
            }
        }
        else {
            orientation.x = 0
            orientation.y = 0
        }

        let cameraFile = AutelCameraFile(channel: 0, mediaFile: newMedia, coordinate: self.location?.coordinate, altitude: self.altitude, orientation: orientation)
        _mostRecentCameraFile = DatedValue(value: cameraFile)
        self.delegates.invoke { $0.onCameraFileGenerated(session: self, file: cameraFile) }
    }
}

extension AutelDroneSession: AUTELDroneGimbalDelegate {
    public func gimbalController(_ controller: AUTELDroneGimbal, didUpdateGimbalState gimbalState: AUTELDroneGimbalState) {
        gimbalSerialQueue.async { [weak self] in
            self?._gimbalStates[0] = DatedValue<GimbalStateAdapter>(value: AutelGimbalStateAdapter(gimbalState: gimbalState))
        }
    }
}

extension AutelDroneSession: DroneSession {
    public var drone: DroneAdapter { adapter }
    public var state: DatedValue<DroneStateAdapter>? { DatedValue(value: self, date: mainControllerState?.date ?? Date()) }
    public var opened: Date { _opened }
    public var closed: Bool { _closed }
    public var id: String { _id }
    public var adapterName: String { "autel" }
    public var manufacturer: String { "Autel" }
    public var serialNumber: String? { _serialNumber }
    public var name: String? { nil }
    public var model: String? { adapter.drone.deviceType().name }
    public var firmwarePackageVersion: String? { _firmwarePackageVersion }
    public var initialized: Bool { _initialized }
    public var located: Bool { _located }
    public var telemetryDelayed: Bool { false }
    
    public var disengageReason: Kernel.Message? {
        if _closed {
            return Kernel.Message(title: "MissionDisengageReason.drone.disconnected.title".localized)
        }
        
        if adapter.drone.mainController == nil {
            return Kernel.Message(title: "MissionDisengageReason.drone.control.unavailable.title".localized)
        }
        
        if mainControllerState == nil {
            return Kernel.Message(title: "MissionDisengageReason.telemetry.unavailable.title".localized)
        }
        
        if telemetryDelayed {
            return Kernel.Message(title: "MissionDisengageReason.telemetry.delayed.title".localized, details: "MissionDisengageReason.telemetry.delayed.details".localized)
        }
        
        if let state = mainControllerState?.value {
            if state.isReachMaxHeight {
                return Kernel.Message(title: "MissionDisengageReason.drone.max.altitude.title".localized, details: "MissionDisengageReason.drone.max.altitude.details".localized)
            }
            
            if state.isReachMaxRange {
                return Kernel.Message(title: "MissionDisengageReason.drone.max.distance.title".localized, details: "MissionDisengageReason.drone.max.distance.details".localized)
            }
        }

        return nil
    }
    
    public func identify(id: String) { _id = id }
    
    public func add(delegate: DroneSessionDelegate) {
        delegates.add(delegate)
        
        if _initialized {
            delegate.onInitialized(session: self)
        }
        
        if _located {
            delegate.onLocated(session: self)
        }
    }
    
    public func remove(delegate: DroneSessionDelegate) {
        delegates.remove(delegate)
    }
    
    public func removeCommands() {
        droneCommands.removeAll()
        remoteControllerCommands.removeAll()
        cameraCommands.removeAll()
        gimbalCommands.removeAll()
    }
    
    public func add(command: KernelCommand) throws {
        let createCommand = { [weak self] (execute: @escaping (@escaping CommandFinished) -> Error?) -> Command in
            let c = Command(
                kernelCommand: command,
                execute: execute,
                finished: { [weak self] error in
                    self?.commandFinished(command: command, error: error)
                },
                config: command.config
            )
            
            if c.config.retriesEnabled == nil {
                //disable retries when the DJI SDK reports that the product does not support the feature
                c.config.retriesEnabled = { error in
                    if (error as NSError?)?.code == AUTELSDKError.productNotSupport.rawValue {
                        return false
                    }
                    return true
                }
            }
            
            if c.config.finishDelay == nil {
                //adding a 1.5 second delay after camera and gimbal mode commands
                if command is Kernel.ModeCameraCommand || command is Kernel.ModeGimbalCommand {
                    c.config.finishDelay = 1.5
                }
            }
            
            return c
        }
        
        if let command = command as? KernelDroneCommand {
            try droneCommands.add(command: createCommand({ [weak self] in
                self?.commandExecuted(command: command)
                return self?.execute(droneCommand: command, finished: $0)
            }))
            return
        }
        
        if let command = command as? KernelRemoteControllerCommand {
            try remoteControllerCommands.add(channel: command.channel, command: createCommand({ [weak self] in
                self?.commandExecuted(command: command)
                return self?.execute(remoteControllerCommand: command, finished: $0)
            }))
            return
        }
        
        if let command = command as? KernelCameraCommand {
            try cameraCommands.add(channel: command.channel, command: createCommand({ [weak self] in
                self?.commandExecuted(command: command)
                return self?.execute(cameraCommand: command, finished: $0)
            }))
            return
        }

        if let command = command as? KernelGimbalCommand {
            try gimbalCommands.add(channel: command.channel, command: createCommand({ [weak self] in
                self?.commandExecuted(command: command)
                return self?.execute(gimbalCommand: command, finished: $0)
            }))
            return
        }
        
        throw DroneSessionError.commandTypeUnhandled
    }
    
    private func commandExecuted(command: KernelCommand) {
        delegates.invoke { $0.onCommandExecuted(session: self, command: command) }
    }
    
    private func commandFinished(command: KernelCommand, error: Error?) {
        delegates.invoke { $0.onCommandFinished(session: self, command: command, error: error) }
    }
    
    public func createControlSession(executionEngine: Kernel.ExecutionEngine, executor: Executor?) throws -> DroneControlSession {
        switch executionEngine {
        case .dronelinkKernel:
            return AutelVirtualStickSession(droneSession: self)
            
        case .dji:
            break
        }
        
        throw String(format: "AutelDroneSession.createControlSession.execution.engine.unsupported".localized, Dronelink.shared.formatEnum(name: "ExecutionEngine", value: executionEngine.rawValue, defaultValue: ""))
    }
    
    public func remoteControllerState(channel: UInt) -> DatedValue<RemoteControllerStateAdapter>? {
        remoteControllerSerialQueue.sync { [weak self] in
            return self?._remoteControllerStateAdapter
        }
    }
    
    public func cameraState(channel: UInt) -> DatedValue<CameraStateAdapter>? {
        cameraState(channel: channel, lensIndex: nil)
    }
    
    public func cameraState(channel: UInt, lensIndex: UInt?) -> DatedValue<CameraStateAdapter>? {
        cameraSerialQueue.sync { [weak self] in
            guard let session = self, let camera = drone.camera(channel: channel) else {
                return nil
            }
            
            if let systemState = session._cameraStates[channel] {
                return DatedValue(
                    value: AutelCameraStateAdapter(
                        systemState: systemState.value,
                        storageState: _cameraStorageStates[0]?.value,
                        exposureMode: _cameraExposureMode?.value,
                        exposureParameters: _cameraExposureParameters["0.0"]?.value,
                        focusMode: _cameraFocusMode?.value,
                        histogram: _cameraHistograms["0.0"]?.value
                    ),
                    date: systemState.date)
            }
            return nil
        }
    }
    
    public func gimbalState(channel: UInt) -> DatedValue<GimbalStateAdapter>? {
        gimbalSerialQueue.sync { [weak self] in
            if let gimbalState = self?._gimbalStates[channel] {
                return DatedValue<GimbalStateAdapter>(value: gimbalState.value, date: gimbalState.date)
            }
            return nil
        }
    }
    
    public func batteryState(index: UInt) -> DronelinkCore.DatedValue<DronelinkCore.BatteryStateAdapter>? { nil }
    
    public var rtkState: DronelinkCore.DatedValue<DronelinkCore.RTKStateAdapter>? { nil }
    
    public var liveStreamingState: DronelinkCore.DatedValue<DronelinkCore.LiveStreamingStateAdapter>? { nil }
    
    public func resetPayloads() {
        resetPayloads(gimbal: true, camera: true)
    }
    
    public func resetPayloads(gimbal: Bool, camera: Bool) {
        if gimbal {
            sendResetGimbalCommands()
        }
        
        if camera {
            sendResetCameraCommands()
        }
    }
    
    public func close() {
        _closed = true
    }
}

extension AutelDroneSession: DroneStateAdapter {
    public var statusMessages: [Kernel.Message] {
        var messages: [Kernel.Message] = []
        
        if let state = mainControllerState?.value {
            messages.append(contentsOf: state.statusMessages)
        }
        else {
            messages.append(Kernel.Message(title: "AutelDroneSession.telemetry.unavailable".localized, level: .danger))
        }
        
        return messages
    }
    public var mode: String? { mainControllerState?.value.mainModeString }
    public var isFlying: Bool { mainControllerState?.value.isFlying ?? false }
    public var isReturningHome: Bool { mainControllerState?.value.isAutoFlyingToHomePoint ?? false }
    public var isLanding: Bool { mainControllerState?.value.flightMode == .AutelMCFlightModeLanding }
    public var isCompassCalibrating: Bool { adapter.drone.mainController.compass?.isCalibrating ?? false }
    public var compassCalibrationMessage: Kernel.Message? { adapter.drone.mainController.compass?.calibrationStatus.message }
    public var location: CLLocation? { mainControllerState?.value.location }
    public var homeLocation: CLLocation? { mainControllerState?.value.isHomeInvalid ?? true ? nil : mainControllerState?.value.homeLocation.asLocation }
    public var lastKnownGroundLocation: CLLocation? { _lastKnownGroundLocation }
    public var takeoffLocation: CLLocation? { isFlying ? (lastKnownGroundLocation ?? homeLocation) : location }
    public var takeoffAltitude: Double? { nil }
    public var course: Double { mainControllerState?.value.course ?? 0 }
    public var horizontalSpeed: Double { mainControllerState?.value.horizontalSpeed ?? 0 }
    public var verticalSpeed: Double { mainControllerState?.value.verticalSpeed ?? 0 }
    public var altitude: Double { Double(mainControllerState?.value.altitude ?? 0) }
    public var ultrasonicAltitude: Double? { mainControllerState?.value.isUltrasonicWorking ?? false ? Double(mainControllerState?.value.ultrasonicHeight ?? 0) : nil }
    public var returnHomeAltitude: Double? {
        if let returnHomeAltitude = _mainControllerGoHomeDefaultAltitude {
            return Double(returnHomeAltitude)
        }
        return nil
    }
    public var maxAltitude: Double? {
        if let maxAltitude = _flightLimitationMaxFlightHeight {
            return Double(maxAltitude)
        }
        return nil
    }
    public var batteryPercent: Double? {
        if let remainPowerPercent = batteryState?.value.remainPowerPercent {
            return Double(remainPowerPercent) / 100
        }
        return nil
    }
    
    public var lowBatteryThreshold: Double? { _mainControllerLowBatteryThreshold }
    
    public var flightTimeRemaining: Double? {
        if let remainingFlightTime = mainControllerState?.value.remainingFlightTime {
            return Double(remainingFlightTime)
        }
        return nil
    }
    
    public var obstacleDistance: Double? { nil } //TODO
    
    public var orientation: Kernel.Orientation3 { mainControllerState?.value.orientation ?? Kernel.Orientation3() }
    
    public var gpsSatellites: Int? {
        if let satelliteCount = mainControllerState?.value.satelliteCount {
            return Int(satelliteCount)
        }
        return nil
    }
    
    public var gpsSignalStrength: Double? { mainControllerState?.value.gpsSignalLevel.doubleValue }
    
    public var downlinkSignalStrength: Double? {
        if let quality = remotecontrollerRCState?.value.dspSignalQuality.mQuality {
            return Double(quality) / 100
        }
        return nil
    }
    
    public var uplinkSignalStrength: Double? {
        if let quality = remotecontrollerRCState?.value.rcSignalQuality.mQuality {
            return Double(quality) / 100
        }
        return nil
    }
    
    public var lightbridgeFrequencyBand: Kernel.DroneLightbridgeFrequencyBand? { nil }
    public var ocuSyncFrequencyBand: Kernel.DroneOcuSyncFrequencyBand? { nil }
    public var auxiliaryLightModeBottom: DronelinkCore.Kernel.DroneAuxiliaryLightMode? { nil }
}
