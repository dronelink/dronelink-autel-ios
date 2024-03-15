//
//  AutelAdapters.swift
//  DronelinkAutel
//
//  Created by Jim McAndrew on 1/20/22.
//  Copyright © 2022 Dronelink. All rights reserved.
//
import DronelinkCore
import AUTELSDK

public class AutelDroneAdapter: DroneAdapter {
    public let drone: AUTELDrone
    public weak var session: AutelDroneSession?
    
    public init(drone: AUTELDrone) {
        self.drone = drone
    }
    
    public var remoteControllers: [RemoteControllerAdapter]? { nil }
    
    public var cameras: [CameraAdapter]? {
        if let camera = camera(channel: 0) {
            return [camera]
        }
        return nil
    }
    
    public var gimbals: [GimbalAdapter]? {
        if let gimbal = gimbal(channel: 0) {
            return [gimbal]
        }
        return nil
    }
    
    public func remoteController(channel: UInt) -> RemoteControllerAdapter? { channel == 0 ? AutelRemoteControllerAdapter(remoteController: drone.remoteController) : nil }
    
    public func cameraChannel(videoFeedChannel: UInt?) -> UInt? { nil }
    
    public func camera(channel: UInt) -> CameraAdapter? { channel == 0 ? AutelCameraAdapter(camera: drone.camera) : nil }
    
    public func gimbal(channel: UInt) -> GimbalAdapter? { channel == 0 ? AutelGimbalAdapter(gimbal: drone.gimbal) : nil }
    
    public let batteries: [DronelinkCore.BatteryAdapter]? = nil
    
    public func battery(channel: UInt) -> DronelinkCore.BatteryAdapter? { nil }
    
    public var rtk: DronelinkCore.RTKAdapter? { nil }
    
    public var liveStreaming: DronelinkCore.LiveStreamingAdapter? { nil }
    
    public func send(velocityCommand: Kernel.VelocityDroneCommand?) {
        guard let velocityCommand = velocityCommand else {
            sendResetVelocityCommand()
            return
        }
        
        guard
            let session = session,
            let airLink = drone.airLink,
            airLink.isConnected,
            airLink.isLinkGen2Supported,
            let linkGen2 = airLink.linkGen2
        else {
            return
        }
        let orientation = session.orientation
        
        let model = AUTELRCVirtualJoystickControlModel()
        //positive = clockwise
        if let heading = velocityCommand.heading {
            model.leftHorizonPole = max(-100, min(100, Int32(((heading.angleDifferenceSigned(angle: orientation.yaw).convertRadiansToDegrees / 180.0) * 75.0))))
        }
        else {
            model.leftHorizonPole = max(-100, min(100, Int32((velocityCommand.velocity.rotational.convertRadiansToDegrees / AUTELDrone.maxRotationalVelocity * 100))))
        }
        //positive = up
        model.leftVerticalPole = max(-100, min(100, Int32((velocityCommand.velocity.vertical / (velocityCommand.velocity.vertical > 0 ? session.maxAscentVelocity : session.maxDescentVelocity)) * 100)))
        
        let horizontalVelocity = velocityCommand.velocity.horizontal
        var horizontalVelocityNormalized = Kernel.Vector2(direction: horizontalVelocity.direction.angleDifferenceSigned(angle: orientation.yaw), magnitude: min(horizontalVelocity.magnitude, session.maxHorizontalVelocity) / session.maxHorizontalVelocity)
        
        let maxMagnitude = abs(sin(horizontalVelocityNormalized.direction)) + abs(cos(horizontalVelocityNormalized.direction))
        horizontalVelocityNormalized = Kernel.Vector2(direction: horizontalVelocityNormalized.direction, magnitude: horizontalVelocityNormalized.magnitude * maxMagnitude)
        
        //positive = left
        model.rightHorizonPole = max(-100, min(100, Int32(-horizontalVelocityNormalized.y * 100)))
        //positive = backwards
        model.rightVerticalPole = max(-100, min(100, Int32(-horizontalVelocityNormalized.x * 100)))
        linkGen2.sendVirtualJoystickControlCommand(model, withCompletion: nil)
    }
    
    public func sendResetVelocityCommand(withCompletion: AUTELCompletionBlock? = nil) {
        guard
            let airLink = drone.airLink,
            airLink.isConnected,
            airLink.isLinkGen2Supported,
            let linkGen2 = airLink.linkGen2
        else {
            return
        }
        
        let model = AUTELRCVirtualJoystickControlModel()
        model.rightHorizonPole = 0
        model.rightVerticalPole = 0
        model.leftHorizonPole = 0
        model.leftVerticalPole = 0
        linkGen2.sendVirtualJoystickControlCommand(model, withCompletion: withCompletion)
    }
    
    public func send(remoteControllerSticksCommand: Kernel.RemoteControllerSticksDroneCommand?) {
        guard
            let orientation = session?.orientation,
            let remoteControllerSticksCommand = remoteControllerSticksCommand,
            let airLink = drone.airLink,
            airLink.isConnected,
            airLink.isLinkGen2Supported,
            let linkGen2 = airLink.linkGen2
        else {
            return
        }
        
        let model = AUTELRCVirtualJoystickControlModel()
        if let heading = remoteControllerSticksCommand.heading {
            model.leftHorizonPole = max(-100, min(100, Int32((heading.angleDifferenceSigned(angle: orientation.yaw).convertRadiansToDegrees / AUTELDrone.maxRotationalVelocity * 100))))
        }
        else {
            model.leftHorizonPole = Int32(remoteControllerSticksCommand.leftStick.x * 100)
        }
        model.leftVerticalPole = Int32(remoteControllerSticksCommand.leftStick.y * 100)
        
        model.rightHorizonPole = Int32(-remoteControllerSticksCommand.rightStick.x * 100)
        model.rightVerticalPole = Int32(-remoteControllerSticksCommand.rightStick.y * 100)
        linkGen2.sendVirtualJoystickControlCommand(model, withCompletion: nil)
    }
    
    public func startTakeoff(finished: CommandFinished?) {
        drone.mainController.startTakeoff(completion: finished)
    }
    
    public func startReturnHome(finished: CommandFinished?) {
        drone.mainController.startGoHome(completion: finished)
    }
    
    public func stopReturnHome(finished: CommandFinished?) {
        drone.mainController.cancelGoHome(completion: finished)
    }
    
    public func startLand(finished: CommandFinished?) {
        drone.mainController.startLanding(completion: finished)
    }
    
    public func stopLand(finished: CommandFinished?) {
        drone.mainController.cancelLanding(comletion: finished)
    }
    
    public func startCompassCalibration(finished: CommandFinished?) {
        drone.mainController.compass?.startCalibration(completion: finished)
    }
    
    public func stopCompassCalibration(finished: CommandFinished?) {
        finished?("AutelDroneAdapter.stopCompassCalibration.unavailable".localized)
    }
    
    public func enumElements(parameter: String) -> [EnumElement]? {
        return nil
    }
}

public class AutelRemoteControllerAdapter: RemoteControllerAdapter {
    public let remoteController: AUTELRemoteController
    
    public init(remoteController: AUTELRemoteController) {
        self.remoteController = remoteController
    }
    
    public func startDeviceCharging(finished: CommandFinished?) {
        finished?("AutelRemoteControllerAdapter.deviceCharging.unavailable".localized)
    }
    
    public func stopDeviceCharging(finished: CommandFinished?) {
        finished?("AutelRemoteControllerAdapter.deviceCharging.unavailable".localized)
    }

    public var index: UInt { 0 }
}

public class AutelCameraAdapter: CameraAdapter {
    public let camera: AUTELBaseCamera
    
    public init(camera: AUTELBaseCamera) {
        self.camera = camera
    }
    
    public var model: String? {
        switch camera.cameraType {
        case .unknown: return "unknown"
        case .xteadyR12: return "xteadyR12"
        case .xteadyR20: return "xteadyR20"
        case .xteadyH2: return "xteadyH2"
        case .XT701: return "XT701"
        case .XT705: return "XT705"
        case .XT706: return "XT706"
        case .XT706_R: return "XT706_R"
        case .XT709: return "XT709"
        case .XT712: return "XT712"
        case .XL719: return "XL719"
        case .XL720: return "XL720"
        case .flirDuo: return "flirDuo"
        case .flirDuo_R: return "flirDuo_R"
        @unknown default: return "unknown"
        }
    }
    
    public var index: UInt { 0 }
    
    public func lensIndex(videoStreamSource: Kernel.CameraVideoStreamSource) -> UInt { 0 }
    
    public func format(storageLocation: Kernel.CameraStorageLocation, finished: CommandFinished?) {
        camera.formatSDCard(completion: finished)
    }
    
    public func histogram(enabled: Bool, finished: DronelinkCore.CommandFinished?) {
        camera.setHistogramEnabled(enabled, withCompletion: finished)
    }
    
    public func enumElements(parameter: String) -> [EnumElement]? {
        switch parameter {
        case "CameraPhotoInterval":
            return (2...10).map {
                EnumElement(display: "\($0) s", value: $0)
            }
        default:
            break
        }
        
        guard let enumDefinition = Dronelink.shared.enumDefinition(name: parameter) else {
            return nil
        }
        
        var range: [String?]?
        
        switch parameter {
        case "CameraAperture":
            range = camera.parameters?.supportedCameraApertureRange().map { AUTELCameraAperture(rawValue: $0.uint8Value)?.kernelValue.rawValue }
            break
        case "CameraExposureCompensation":
            range = camera.parameters?.supportedCameraExposureCompensationRange().map { AUTELCameraExposureCompensation(rawValue: $0.uint8Value)?.kernelValue.rawValue }
            break
        case "CameraExposureMode":
            range = camera.parameters?.supportedCameraExposureModeRange().map { AUTELCameraExposureMode(rawValue: $0.uint8Value)?.kernelValue.rawValue }
            break
        case "CameraISO":
            range = camera.parameters?.supportedCameraISORange().map { AUTELCameraISO(rawValue: $0.uint8Value)?.kernelValue.rawValue }
            break
        case "CameraMode":
            range = camera.parameters?.supportedCameraModeRange().map { AUTELCameraWorkMode(rawValue: $0.uint8Value)?.kernelValue.rawValue }
            break
        case "CameraPhotoFileFormat":
            range = camera.parameters.supportedCameraPhotoFileFormatRange().map { AUTELCameraPhotoFileFormat(rawValue: $0.uint8Value)?.kernelValue.rawValue }
            break
        case "CameraPhotoMode":
            range = [
                Kernel.CameraPhotoMode.single.rawValue,
                Kernel.CameraPhotoMode.interval.rawValue,
                Kernel.CameraPhotoMode.aeb.rawValue,
                Kernel.CameraPhotoMode.burst.rawValue
            ]
            break
        case "CameraShutterSpeed":
            range = camera.parameters?.supportedCameraShutterSpeedRange().map { AUTELCameraShutterSpeed(rawValue: $0.uint8Value)?.kernelValue.rawValue }
            break
        case "CameraStorageLocation":
            range = [Kernel.CameraStorageLocation.sdCard.rawValue]
            break
        case "CameraVideoFileFormat":
            range = camera.parameters.supportedCameraVideoFileFormatRange().map  { AUTELCameraVideoFileFormat(rawValue: $0.uint8Value)?.kernelValue.rawValue }
            break
        case "CameraWhiteBalancePreset":
            range = camera.parameters.supportedCameraWhiteBalanceRange().map  { AUTELCameraWhiteBalance(rawValue: $0.uint8Value)?.kernelValue.rawValue }
            break
        default:
            return nil
        }
        
        var enumElements: [EnumElement] = []
        range?.forEach { value in
            if let value = value, value != "unknown", let display = enumDefinition[value] {
                enumElements.append(EnumElement(display: display, value: value))
            }
        }
        
        return enumElements.isEmpty ? nil : enumElements
    }
    
    public func tupleEnumElements(parameter: String) -> [EnumElementTuple]? {
        //TODO add Autel/Kernel Video Resolution and FrameRate Enums and test
//        var tuples: [EnumElementTuple] = []
//        switch parameter {
//        case "CameraVideoResolutionFrameRate":
//            if let videoResolutionAndFrameRates = camera.parameters.supportedCameraVideoResolutionAndFrameRateRange() {
//                videoResolutionAndFrameRates.forEach { resolutionFrameRate in
//                    if let resolutionRaw = AUTELCameraVideoResolution(rawValue: resolutionFrameRate[0].uint8Value)?.kernelValue.rawValue
//                       let frameRateRaw = AUTELCameraVideoResolution(rawValue: resolutionFrameRate[1].uint8Value)?.kernelValue.rawValue {
//                        tuples.append(
//                            EnumElementTuple(
//                            element1: EnumElement(display: Dronelink.shared.formatEnum(name: "CameraVideoResolution", value: resolutionRaw), value: resolutionRaw),
//                           element2: EnumElement(display: Dronelink.shared.formatEnum(name: "CameraVideoFrameRate", value: frameRateRaw), value: frameRateRaw)))
//                    }
//                }
//            }
//        default:
//            return nil
//        }
//        
//        return tuples.isEmpty ? nil : tuples
        return nil
    }
}

public struct AutelCameraFile : CameraFile {
    public let channel: UInt
    public var name: String { mediaFile.fileName }
    public var size: Int64 { mediaFile.fileSizeInBytes }
    public var metadata: String? { nil }
    public let created = Date()
    public let coordinate: CLLocationCoordinate2D?
    public let altitude: Double?
    public let orientation: Kernel.Orientation3?
    public let mediaFile: AUTELMedia
    
    init(channel: UInt, mediaFile: AUTELMedia, coordinate: CLLocationCoordinate2D?, altitude: Double?, orientation: Kernel.Orientation3?) {
        self.channel = channel
        self.mediaFile = mediaFile
        self.coordinate = coordinate
        self.altitude = altitude
        self.orientation = orientation
    }
}

public class AutelCameraStateAdapter: CameraStateAdapter {
    public let systemState: AUTELCameraSystemBaseState
    public let storageState: AUTELCameraSDCardState?
    private let _exposureMode: AUTELCameraExposureMode?
    public let exposureParameters: AUTELCameraExposureParameters?
    private let _focusMode: AUTELCameraLensFocusMode?
    public let histogram: [UInt]?
    
    public init(systemState: AUTELCameraSystemBaseState, storageState: AUTELCameraSDCardState?, exposureMode: AUTELCameraExposureMode?, exposureParameters: AUTELCameraExposureParameters?, focusMode: AUTELCameraLensFocusMode?, histogram: [UInt]?) {
        self.systemState = systemState
        self.storageState = storageState
        self._exposureMode = exposureMode
        self.exposureParameters = exposureParameters
        self._focusMode = focusMode
        self.histogram = histogram
    }
    
    public var lensIndex: UInt { 0 }
    public var isBusy: Bool { systemState.isBusy || (storageState?.formattingState ?? .none) == .formatting || storageState?.isInitializing ?? false }
    public var isCapturing: Bool { systemState.isCapturing }
    public var isCapturingPhotoInterval: Bool { systemState.isCapturingPhotoInterval }
    public var isCapturingVideo: Bool { systemState.isCapturingVideo }
    public var isCapturingContinuous: Bool { systemState.isCapturingContinuous }
    public var isSDCardInserted: Bool { storageState?.isInserted ?? false }
    public var videoStreamSource: Kernel.CameraVideoStreamSource { .unknown }
    public var storageLocation: Kernel.CameraStorageLocation { .sdCard }
    public var storageRemainingSpace: Int? {
        if let remainingSpaceInMegaBytes = storageState?.remainingSpaceInMegaBytes {
            return remainingSpaceInMegaBytes * 1048576
        }
        return nil
    }
    public var storageRemainingPhotos: Int? { storageState?.availableCaptureCount }
    public var mode: Kernel.CameraMode { systemState.mode.kernelValue }
    public var photoMode: Kernel.CameraPhotoMode? { systemState.mode.kernelValuePhotoMode }
    public var photoInterval: Int? { nil } //TODO
    public var photoFileFormat: Kernel.CameraPhotoFileFormat { .unknown } //TODO
    public var burstCount: Kernel.CameraBurstCount? { nil } //TODO
    public var aebCount: Kernel.CameraAEBCount? { nil } //TODO
    public var videoFileFormat: Kernel.CameraVideoFileFormat { .unknown } //TODO
    //TODO N remove when spec is added
    public var videoFrameRateTest: Kernel.CameraVideoFrameRate { .unknown } //TODO
    public var videoResolutionTest: Kernel.CameraVideoResolution { .unknown } //TODO
    public var videoResolutionFrameRateSpecification: Kernel.CameraVideoResolutionFrameFrameRateSpecification? { nil } //TODO
    public var currentVideoTime: Double? { systemState.currentVideoTime }
    public var exposureMode: Kernel.CameraExposureMode { _exposureMode?.kernelValue ?? .unknown }
    public var exposureCompensation: Kernel.CameraExposureCompensation { exposureParameters?.exposureCompensation.kernelValue ?? .unknown }
    public var iso: Kernel.CameraISO { exposureParameters?.iso.kernelValue ?? .unknown }
    public var isoActual: Int? { nil } //TODO
    public var shutterSpeed: Kernel.CameraShutterSpeed { exposureParameters?.shutterSpeed.kernelValue ?? .unknown }
    public var shutterSpeedActual: Kernel.CameraShutterSpeed? { shutterSpeed }
    public var aperture: Kernel.CameraAperture { exposureParameters?.aperture.kernelValue ?? .unknown }
    public var apertureActual: DronelinkCore.Kernel.CameraAperture { aperture }
    public var whiteBalancePreset: Kernel.CameraWhiteBalancePreset { .unknown } //TODO
    public var whiteBalanceColorTemperature: Int? { nil } //TODO
    public var lensDetails: String? { nil }
    public var focusMode: DronelinkCore.Kernel.CameraFocusMode { _focusMode?.kernelValue ?? .unknown }
    public var focusRingValue: Double? { nil }
    public var focusRingMax: Double? { nil }
    public var meteringMode: DronelinkCore.Kernel.CameraMeteringMode { .unknown }
    public var isAutoExposureLockEnabled: Bool { false }
    public var aspectRatio: Kernel.CameraPhotoAspectRatio { mode == .photo ? ._3x2 : ._16x9 }
    public var isPercentZoomSupported: Bool {false }
    public var isRatioZoomSupported: Bool { false }
    public var defaultZoomSpecification: DronelinkCore.Kernel.PercentZoomSpecification? { nil }
}

public class AutelGimbalAdapter: GimbalAdapter {
    public let gimbal: AUTELDroneGimbal
    
    public init(gimbal: AUTELDroneGimbal) {
        self.gimbal = gimbal
    }
    
    public var index: UInt { 0 }

    public func send(velocityCommand: Kernel.VelocityGimbalCommand, mode: Kernel.GimbalMode) {
        if let rotation = AUTELGimbalRotation(
            pitchValue: max(-90, min(90, velocityCommand.velocity.pitch.convertRadiansToDegrees)) as NSNumber,
            rollValue: mode == .free ? max(-90, min(90, velocityCommand.velocity.roll.convertRadiansToDegrees)) as NSNumber : nil,
            yawValue: mode == .free ? velocityCommand.velocity.yaw.convertRadiansToDegrees as NSNumber : nil,
            mode: .speed) {
            gimbal.rotate(with: rotation, withCompletion: nil)
        }
    }
    
    public func reset() {
        //TODO absoluteAngle seems to have no affect
        if let rotation = AUTELGimbalRotation(pitchValue: 0, rollValue: 0, yawValue: nil, mode: .absoluteAngle) {
            gimbal.setGimbalWorkMode(.GimbalYawFollowMode) { [weak self] error in
                self?.gimbal.rotate(with: rotation)
            }
        }
    }
    
    public func fineTune(roll: Double) {
        gimbal.fineTuneGimbalRoll(inDegree: Float(roll.convertRadiansToDegrees), gimbalAttitude: .roll, withCompletion: nil)
    }
    
    public func enumElements(parameter: String) -> [EnumElement]? {
        guard let enumDefinition = Dronelink.shared.enumDefinition(name: parameter) else {
            return nil
        }
        
        var range: [String?]?
        
        switch parameter {
        case "GimbalMode":
            range = []
            range?.append(Kernel.GimbalMode.yawFollow.rawValue)
            range?.append(Kernel.GimbalMode.fpv.rawValue)
            break
        default:
            return nil
        }
        
        guard let rangeValid = range, !rangeValid.isEmpty else {
            return nil
        }
        
        var enumElements: [EnumElement] = []
        rangeValid.forEach { value in
            if let value = value, let display = enumDefinition[value] {
                enumElements.append(EnumElement(display: display, value: value))
            }
        }
        
        return enumElements.isEmpty ? nil : enumElements
    }
}

public class AutelGimbalStateAdapter: GimbalStateAdapter {
    public let gimbalState: AUTELDroneGimbalState
    
    public init(gimbalState: AUTELDroneGimbalState) {
        self.gimbalState = gimbalState
    }
    
    //TODO always seems to be unknown
    public var mode: Kernel.GimbalMode { gimbalState.workMode.kernelValue }
    
    public var orientation: Kernel.Orientation3 {
        Kernel.Orientation3(
            x: Double(gimbalState.attitude.pitch.convertDegreesToRadians),
            y: Double(gimbalState.attitude.roll.convertDegreesToRadians),
            z: Double(gimbalState.attitude.yaw.convertDegreesToRadians)
        )
    }
}

public class AutelRemoteControllerStateAdapter: RemoteControllerStateAdapter {
    public let rcHardwareState: AUTELRCHardwareState

    public init(rcHardwareState: AUTELRCHardwareState) {
        self.rcHardwareState = rcHardwareState
    }
    
    public var location: CLLocation? { nil }

    public var leftStick: Kernel.RemoteControllerStick {
        Kernel.RemoteControllerStick(
            x: rcHardwareState.mLeftHorizontal.percent,
            y: rcHardwareState.mLeftVertical.percent)
    }

    public var leftWheel: Kernel.RemoteControllerWheel {
        Kernel.RemoteControllerWheel(present: true, pressed: false, value: rcHardwareState.mLeftWheel.percent)
    }

    public var rightStick: Kernel.RemoteControllerStick {
        Kernel.RemoteControllerStick(
            x: -rcHardwareState.mRightHorizontal.percent,
            y: -rcHardwareState.mRightVertical.percent)
    }
    
    public var captureButton: DronelinkCore.Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(present: false, pressed: false)
    }
    
    public var videoButton: DronelinkCore.Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(
            present: true,
            pressed: rcHardwareState.mRecordButton.pressed)
    }
    
    public var photoButton: DronelinkCore.Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(
            present: true,
            pressed: rcHardwareState.mShutterButton.mButtonDown.boolValue)
    }
    
    public var functionButton: DronelinkCore.Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(present: false, pressed: false)
    }

    public var pauseButton: Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(
            present: true,
            pressed: rcHardwareState.mHoverButton.mButtonDown.boolValue)
    }
    
    public var returnHomeButton: Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(
            present: true,
            pressed: rcHardwareState.mGoHomeButton.mButtonDown.boolValue)
    }

    public var c1Button: Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(
            present: true,
            pressed: rcHardwareState.mCustomButton1.pressed)
    }

    public var c2Button: Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(
            present: true,
            pressed: rcHardwareState.mCustomButton2.pressed)
    }
    
    public var c3Button: DronelinkCore.Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(present: false, pressed: false)
    }
    
    public var upButton: DronelinkCore.Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(present: false, pressed: false)
    }
    
    public var downButton: DronelinkCore.Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(present: false, pressed: false)
    }
    
    public var leftButton: DronelinkCore.Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(present: false, pressed: false)
    }
    
    public var rightButton: DronelinkCore.Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(present: false, pressed: false)
    }
    
    public var l1Button: DronelinkCore.Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(present: false, pressed: false)
    }
    
    public var l2Button: DronelinkCore.Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(present: false, pressed: false)
    }
    
    public var l3Button: DronelinkCore.Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(present: false, pressed: false)
    }
    
    public var r1Button: DronelinkCore.Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(present: false, pressed: false)
    }
    
    public var r2Button: DronelinkCore.Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(present: false, pressed: false)
    }
    
    public var r3Button: DronelinkCore.Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(present: false, pressed: false)
    }
    
    public var isChargingDevice: Bool? { nil }

    public var batteryPercent: Double { 0.0 }
}
