//
//  DronelinkAutel.swift
//  DronelinkAutel
//
//  Created by Jim McAndrew on 1/20/22.
//  Copyright © 2022 Dronelink. All rights reserved.
//
import DronelinkCore
import AUTELSDK

extension DronelinkAutel {
    internal static let bundle = Bundle(for: DronelinkAutel.self)
}

public class DronelinkAutel {}

extension AUTELDeviceType {
    var name: String { "AUTELDeviceType.value.\(rawValue)".localized }
}

extension AUTELDrone {
    public static var maxRotationalVelocity: Double { 90.0 }
        
    public func camera(channel: UInt) -> AUTELBaseCamera? { channel == 0 ? camera : nil }
    public func gimbal(channel: UInt) -> AUTELDroneGimbal? { channel == 0 ? gimbal : nil }
}

extension AUTELMCSystemState {
    public var location: CLLocation? { return isGPSWeakWarning ? nil : droneLocation.asLocation }
    public var horizontalSpeed: Double { Double(sqrt(pow(velocityX, 2) + pow(velocityY, 2))) }
    public var verticalSpeed: Double { velocityZ == 0 ? 0 : Double(velocityZ) }
    public var course: Double { Double(atan2(velocityY, velocityX)) }
    
    public var orientation: Kernel.Orientation3 {
        Kernel.Orientation3(
            x: Double(attitude.pitch),
            y: Double(attitude.roll),
            z: Double(attitude.yaw)
        )
    }
}

extension AUTELGpsSignalLevel {
    var doubleValue: Double? {
        switch self {
        case .GpsSignalLevel0: return 0
        case .GpsSignalLevel1: return 0.2
        case .GpsSignalLevel2: return 0.4
        case .GpsSignalLevel3: return 0.6
        case .GpsSignalLevel4: return 0.8
        case .GpsSignalLevel5: return 1
        case .GpsSignalLevelNone: return nil
        @unknown default: return nil
        }
    }
}

extension AUTELCameraSystemBaseState {
    public var isBusy: Bool { isStoringPhoto || isShootingSinglePhoto || isShootingSinglePhotoInRAWFormat || isShootingIntervalPhoto || isShootingBurstPhoto || isUpgrading }
    public var isCapturing: Bool { isRecording || isShootingSinglePhoto || isShootingSinglePhotoInRAWFormat || isShootingIntervalPhoto || isShootingBurstPhoto }
    public var isCapturingPhotoInterval: Bool { isShootingIntervalPhoto }
    public var isCapturingVideo: Bool { isRecording }
    public var isCapturingContinuous: Bool { isCapturingPhotoInterval || isCapturingVideo }
    public var currentVideoTime: Double? { isCapturingVideo ? Double(currentVideoRecordingTimeInSeconds) : nil }
}

extension AUTELCameraWorkMode {
    var kernelValue: Kernel.CameraMode {
        switch self {
        case .captureSingle: return .photo
        case .recordVideo: return .video
        case .captureBurst: return .photo
        case .captureInterval: return .photo
        case .captureAEB: return .photo
        case .capturePanorama: return .photo
        case .recordVideoSlowMotion: return .video
        case .recordVideoLooping: return .video
        case .captureMovingTimeLapse: return .photo
        case .captureHDR: return .photo
        case .captureMFNR: return .photo
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }
    
    var kernelValuePhotoMode: Kernel.CameraPhotoMode? {
        switch self {
        case .captureSingle: return .single
        case .recordVideo: return nil
        case .captureBurst: return .burst
        case .captureInterval: return .interval
        case .captureAEB: return .aeb
        case .capturePanorama: return .panorama
        case .recordVideoSlowMotion: return nil
        case .recordVideoLooping: return nil
        case .captureMovingTimeLapse: return .timeLapse
        case .captureHDR: return .hdr
        case .captureMFNR: return .unknown //FIXME
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

extension Kernel.CameraMode {
    var autelValue: AUTELCameraWorkMode {
        switch self {
        case .photo: return .captureSingle
        case .video: return .recordVideo
        case .playback: return .unknown
        case .download: return .unknown
        case .broadcast: return .unknown
        case .unknown: return .unknown
        }
    }
}

extension Kernel.CameraPhotoMode {
    var autelValue: AUTELCameraWorkMode {
        switch self {
        case .single: return .captureSingle
        case .hdr: return .captureHDR
        case .burst: return .captureBurst
        case .aeb: return .captureAEB
        case .interval: return .captureInterval
        case .timeLapse: return .captureMovingTimeLapse
        case .rawBurst: return .unknown
        case .shallowFocus: return .unknown
        case .panorama: return .capturePanorama
        case .ehdr: return .unknown
        case .hyperLight: return .unknown
        case .highResolution: return .unknown
        case .smart: return .unknown
        case .internalAISpotChecking: return .unknown
        case .unknown: return .unknown
        }
    }
}

extension Kernel.CameraPhotoFileFormat {
    var autelValue: AUTELCameraPhotoFileFormat {
        switch self {
        case .raw: return .DNG
        case .jpeg: return .JPG
        case .rawAndJpeg: return .jpgAndDNG
        case .tiff14bit: return .unknown
        case .radiometricJpeg: return .RJPEG
        case .tiff14bitLinearLowTempResolution: return .unknown
        case .tiff14bitLinearHighTempResolution: return .unknown
        case .unknown: return .unknown
        }
    }
}

extension AUTELCameraPhotoFileFormat {
    var kernelValue: Kernel.CameraPhotoFileFormat {
        switch self {
        case .DNG: return .raw
        case .JPG: return .jpeg
        case .jpgAndDNG: return .rawAndJpeg
        case .RJPEG: return .radiometricJpeg
        case .rjpegAndTIFF: return .unknown
        case .unknown: return .unknown
        }
    }
}

extension Kernel.PhotoIntervalCameraCommand {
    var photoIntervalAutelValue: AUTELCameraPhotoTimeLapseInterval {
        switch photoInterval {
            case 2: return .interval2
            case 3: return .interval3
            case 5: return .interval5
            case 7: return .interval7
            case 10: return .interval10
            case 20: return .interval20
            case 30: return .interval30
            case 60: return .interval60
            default: return .intervalUnknown
        }
    }
}

extension Kernel.AutoLockGimbalCameraCommand {
    var enabledAutelValue: AUTELCameraGimbalLockState { enabled ? .lock : .unLock }
}

extension AUTELCameraExposureCompensation {
    var kernelValue: Kernel.CameraExposureCompensation {
        switch self {
        case .N30: return .n30
        case .N27: return .n27
        case .N23: return .n23
        case .N20: return .n20
        case .N17: return .n17
        case .N13: return .n13
        case .N10: return .n10
        case .N07: return .n07
        case .N03: return .n03
        case .N00: return .n00
        case .P03: return .p03
        case .P07: return .p07
        case .P10: return .p10
        case .P13: return .p13
        case .P17: return .p17
        case .P20: return .p20
        case .P23: return .p23
        case .P27: return .p27
        case .P30: return .p30
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

extension Kernel.CameraExposureCompensation {
    var autelValue: AUTELCameraExposureCompensation {
        switch self {
        case .n50: return .unknown
        case .n47: return .unknown
        case .n43: return .unknown
        case .n40: return .unknown
        case .n37: return .unknown
        case .n33: return .unknown
        case .n30: return .N30
        case .n27: return .N27
        case .n23: return .N23
        case .n20: return .N20
        case .n17: return .N17
        case .n13: return .N13
        case .n10: return .N10
        case .n07: return .N07
        case .n03: return .N03
        case .n00: return .N00
        case .p03: return .P03
        case .p07: return .P07
        case .p10: return .P10
        case .p13: return .P13
        case .p17: return .P17
        case .p20: return .P20
        case .p23: return .P23
        case .p27: return .P27
        case .p30: return .P30
        case .p33: return .unknown
        case .p37: return .unknown
        case .p40: return .unknown
        case .p43: return .unknown
        case .p47: return .unknown
        case .p50: return .unknown
        case .fixed: return .unknown
        case .unknown: return .unknown
        }
    }
}

extension AUTELCameraExposureMode {
    var kernelValue: Kernel.CameraExposureMode {
        switch self {
        case .auto: return .program
        case .shutter: return .shutterPriority
        case .aperture: return .aperturePriority
        case .manual: return .manual
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

extension Kernel.CameraExposureMode {
    var autelValue: AUTELCameraExposureMode {
        switch self {
        case .program: return .auto
        case .shutterPriority: return .shutter
        case .aperturePriority: return .aperture
        case .manual: return .manual
        case .unknown: return .unknown
        }
    }
}

extension AUTELCameraLensFocusMode {
    var kernelValue: Kernel.CameraFocusMode {
        switch self {
        case .manual: return .manual
        case .auto: return .auto
        case .AFC: return .autoContinuous
        case .unknown: return .unknown
        }
    }
}

extension Kernel.CameraFocusMode {
    var autelValue: AUTELCameraLensFocusMode {
        switch self {
        case .manual: return .manual
        case .auto: return .AFC //FIXME .auto
        case .autoContinuous: return .AFC
        case .unknown: return .unknown
        }
    }
}

extension AUTELCameraISO {
    var kernelValue: Kernel.CameraISO {
        switch self {
        case .ISO100: return ._100
        case .ISO200: return ._200
        case .ISO400: return ._400
        case .ISO800: return ._800
        case .ISO1600: return ._1600
        case .ISO3200: return ._3200
        case .ISO6400: return ._6400
        case .ISO12800: return ._12800
        case .ISO25600: return ._25600
        case .isoUnknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

extension Kernel.CameraISO {
    var autelValue: AUTELCameraISO {
        switch self {
        case .auto: return .isoUnknown
        case ._100: return .ISO100
        case ._200: return .ISO200
        case ._400: return .ISO400
        case ._800: return .ISO800
        case ._1600: return .ISO1600
        case ._3200: return .ISO3200
        case ._6400: return .ISO6400
        case ._12800: return .ISO12800
        case ._25600: return .ISO25600
        case .unknown: return .isoUnknown
        }
    }
}

extension AUTELCameraShutterSpeed {
    var kernelValue: Kernel.CameraShutterSpeed {
        switch self {
        case .speed1_10000: return .unknown //FIXME
        case .speed1_8000: return ._1_8000
        case .speed1_6000: return ._1_6000
        case .speed1_5000: return ._1_5000
        case .speed1_4000: return ._1_4000
        case .speed1_3200: return ._1_3200
        case .speed1_2500: return ._1_2500
        case .speed1_2000: return ._1_2000
        case .speed1_1600: return ._1_1600
        case .speed1_1250: return ._1_1250
        case .speed1_1000: return ._1_1000
        case .speed1_800: return ._1_800
        case .speed1_640: return ._1_640
        case .speed1_500: return ._1_500
        case .speed1_400: return ._1_400
        case .speed1_320: return ._1_320
        case .speed1_240: return ._1_240
        case .speed1_200: return ._1_200
        case .speed1_160: return ._1_160
        case .speed1_120: return ._1_120
        case .speed1_100: return ._1_100
        case .speed1_80: return ._1_80
        case .speed1_60: return ._1_60
        case .speed1_50: return ._1_50
        case .speed1_40: return ._1_40
        case .speed1_30: return ._1_30
        case .speed1_25: return ._1_25
        case .speed1_20: return ._1_20
        case .speed1_15: return ._1_15
        case .speed1_12p5: return ._1_12dot5
        case .speed1_10: return ._1_10
        case .speed1_8: return ._1_8
        case .speed1_6p25: return ._1_6dot25
        case .speed1_5: return ._1_5
        case .speed1_4: return ._1_4
        case .speed1_3: return ._1_3
        case .speed1_2p5: return ._1_2dot5
        case .speed1_2: return ._1_2
        case .speed1_1p67: return ._1_1dot67
        case .speed1_1p25: return ._1_1dot25
        case .speed1p0: return ._1
        case .speed1p3: return ._1dot3
        case .speed1p6: return ._1dot6
        case .speed2p0: return ._2
        case .speed2p5: return ._2dot5
        case .speed3p0: return ._3
        case .speed3p2: return ._3dot2
        case .speed4p0: return ._4
        case .speed5p0: return ._5
        case .speed6p0: return ._6
        case .speed8p0: return ._8
        case .speed9p0: return ._9
        case .speed10p0: return ._10
        case .speed13p0: return ._13
        case .speed15p0: return ._15
        case .speed20p0: return ._20
        case .speed25p0: return ._25
        case .speed30p0: return ._30
        case .speedUnknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

extension Kernel.CameraShutterSpeed {
    var autelValue: AUTELCameraShutterSpeed {
        switch self {
        case .auto: return .speedUnknown
        case ._1_8000: return .speed1_8000
        case ._1_6400: return .speedUnknown
        case ._1_6000: return .speed1_6000
        case ._1_5000: return .speed1_5000
        case ._1_4000: return .speed1_4000
        case ._1_3200: return .speed1_3200
        case ._1_3000: return .speedUnknown
        case ._1_2500: return .speed1_2500
        case ._1_2000: return .speed1_2000
        case ._1_1600: return .speed1_1600
        case ._1_1500: return .speedUnknown
        case ._1_1250: return .speed1_1250
        case ._1_1000: return .speed1_1000
        case ._1_800: return .speed1_800
        case ._1_750: return .speedUnknown
        case ._1_725: return .speedUnknown
        case ._1_640: return .speed1_640
        case ._1_500: return .speed1_500
        case ._1_400: return .speed1_400
        case ._1_350: return .speedUnknown
        case ._1_320: return .speed1_320
        case ._1_250: return .speedUnknown
        case ._1_240: return .speed1_240
        case ._1_200: return .speed1_200
        case ._1_180: return .speedUnknown
        case ._1_160: return .speed1_160
        case ._1_125: return .speedUnknown
        case ._1_120: return .speed1_120
        case ._1_100: return .speed1_100
        case ._1_90: return .speedUnknown
        case ._1_80: return .speed1_80
        case ._1_60: return .speed1_60
        case ._1_50: return .speed1_50
        case ._1_45: return .speedUnknown
        case ._1_40: return .speed1_40
        case ._1_30: return .speed1_30
        case ._1_25: return .speed1_25
        case ._1_20: return .speed1_20
        case ._1_15: return .speed1_15
        case ._1_12dot5: return .speed1_12p5
        case ._1_10: return .speed1_10
        case ._1_8: return .speed1_8
        case ._1_6dot25: return .speed1_6p25
        case ._1_6: return .speedUnknown
        case ._1_5: return .speed1_5
        case ._1_4: return .speed1_4
        case ._1_3: return .speed1_3
        case ._1_2dot5: return .speed1_2p5
        case ._0dot3: return .speedUnknown
        case ._1_2: return .speed1_2
        case ._1_1dot67: return .speed1_1p67
        case ._1_1dot25: return .speed1_1p25
        case ._0dot7: return .speedUnknown
        case ._1: return .speed1p0
        case ._1dot3: return .speed1_3
        case ._1dot4: return .speed1_4
        case ._1dot6: return .speedUnknown
        case ._2: return .speed2p0
        case ._2dot5: return .speed2p5
        case ._3: return .speed3p0
        case ._3dot2: return .speed3p2
        case ._4: return .speed4p0
        case ._5: return .speed5p0
        case ._6: return .speed6p0
        case ._7: return .speedUnknown
        case ._8: return .speed8p0
        case ._9: return .speed9p0
        case ._10: return .speed10p0
        case ._11: return .speedUnknown
        case ._13: return .speed13p0
        case ._15: return .speed15p0
        case ._16: return .speedUnknown
        case ._20: return .speed20p0
        case ._23: return .speedUnknown
        case ._25: return .speed25p0
        case ._30: return .speed30p0
        case .unknown: return .speedUnknown
        }
    }
}

extension AUTELCameraAperture {
    var kernelValue: Kernel.CameraAperture {
        switch self {
        case .f1p8: return .f1dot8
        case .f2p0: return .f2
        case .f2p2: return .f2dot2
        case .f2p5: return .f2dot5
        case .f2p8: return .f2dot8
        case .f3p2: return .f3dot2
        case .f3p5: return .f3dot5
        case .f4p0: return .f4
        case .f4p5: return .f4dot5
        case .f5p0: return .f5
        case .f5p6: return .f5dot6
        case .f6p3: return .f6dot3
        case .f7p1: return .f7dot1
        case .f8p0: return .f8
        case .f9p0: return .f9
        case .F10: return .f10
        case .F11: return .f11
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

extension Kernel.CameraAperture {
    var autelValue: AUTELCameraAperture {
        switch self {
        case .f1dot6: return .unknown
        case .f1dot7: return .unknown
        case .f1dot8: return .f1p8
        case .f2: return .f2p0
        case .f2dot2: return .f2p2
        case .f2dot4: return .unknown
        case .f2dot5: return .f2p5
        case .f2dot6: return .unknown
        case .f2dot8: return .f2p8
        case .f3dot2: return .f3p2
        case .f3dot4: return .unknown
        case .f3dot5: return .unknown
        case .f4: return .f4p0
        case .f4dot5: return .f4p5
        case .f4dot8: return .unknown
        case .f5: return .f5p0
        case .f5dot6: return .f5p6
        case .f6dot3: return .f6p3
        case .f6dot8: return .unknown
        case .f7dot1: return .f7p1
        case .f8: return .f8p0
        case .f9: return .f9p0
        case .f9dot5: return .unknown
        case .f9dot6: return .unknown
        case .f10: return .F10
        case .f11: return .F11
        case .f13: return .unknown
        case .f14: return .unknown
        case .f16: return .unknown
        case .f18: return .unknown
        case .f19: return .unknown
        case .f20: return .unknown
        case .f22: return .unknown
        case .unknown: return .unknown
        }
    }
}

extension Kernel.CameraVideoFileFormat {
    var autelValue: AUTELCameraVideoFileFormat {
        switch self {
        case .mov: return .MOV
        case .mp4: return .MP4
        case .tiffSequence: return .TIFF
        case .seq: return .unknown
        case .unknown: return .unknown
        }
    }
}

extension AUTELCameraVideoFileFormat {
    var kernelValue: Kernel.CameraVideoFileFormat {
        switch self {
        case .MOV: return .mov
        case .MP4: return .mp4
        case .TIFF: return .tiffSequence
        case .unknown: return .unknown
        }
    }
}

extension AUTELCameraWhiteBalance {
    var kernelValue: Kernel.CameraWhiteBalancePreset {
        switch self {
        case .auto: return .auto
        case .sunny: return .sunny
        case .cloudy: return .cloudy
        case .incandescent: return .indoorIncandescent
        case .fluorescent: return .indoorFluorescent
        case .custom: return .custom
        case .unknown: return .unknown
        }
    }
}

extension AUTELDroneGimbalWorkMode {
    var kernelValue: Kernel.GimbalMode {
        switch self {
        case .GimbalAttitudMode: return .free
        case .GimbalFpvMode: return .fpv
        case .GimbalYawFollowMode: return .yawFollow
        case .GimbalPanoramaMode: return .unknown //FIXME
        case .GimbalWorkModeUnknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

extension Kernel.GimbalMode {
    var autelValue: AUTELDroneGimbalWorkMode {
        switch self {
        case .yawFollow: return .GimbalYawFollowMode
        case .free: return .GimbalAttitudMode
        case .fpv: return .GimbalFpvMode
        case .unknown: return .GimbalWorkModeUnknown
        }
    }
}

extension AUTELRCHardwareJoystick {
    var percent: Double { max(-1, min(1, (Double(mValue) - 1024) / 665)) }
}

extension AUTELRCHardwareLeftWheel {
    var percent: Double { max(-1, min(1, (Double(mValue) - 1024) / 665)) }
}

extension AUTELRCMultiPurposeButtonState {
    //FIXME not working?
    var pressed: Bool {
        switch self {
        case .RCMultiPurposeButtonUp: return false
        case .RCMultiPurposeButtonShortDown: return true
        case .RCMultiPurposeButtonLongDown: return true
        @unknown default: return false
        }
    }
}


extension AUTELMCSystemState {
    var statusMessages: [Kernel.Message] {
        var messages: [Kernel.Message] = []
        
        //AUTELControlMotorError?
        if let message = powerWarning.message {
            messages.append(message)
        }
        
        if let message = noFlyStatus.message {
            messages.append(message)
        }
        
        if isCompassError {
            messages.append(Kernel.Message(title: "DronelinkAutel:AUTELMCSystemState.statusMessages.isCompassError.title".localized, level: .warning))
        }
        
        if isIMUPreheating {
            messages.append(Kernel.Message(title: "DronelinkAutel:AUTELMCSystemState.statusMessages.isIMUPreheating.title".localized, level: .warning))
        }
        
        if isIMUOverheated {
            messages.append(Kernel.Message(title: "DronelinkAutel:AUTELMCSystemState.statusMessages.isIMUOverheated.title".localized, level: .warning))
        }
        
        if isUnknowBattery {
            messages.append(Kernel.Message(title: "DronelinkAutel:AUTELMCSystemState.statusMessages.isUnknowBattery.title".localized, level: .warning))
        }
        
        if isBatteryOverheated {
            messages.append(Kernel.Message(title: "DronelinkAutel:AUTELMCSystemState.statusMessages.isBatteryOverheated.title".localized, level: .warning))
        }
        
        if isBatteryVoltageDiff {
            messages.append(Kernel.Message(title: "DronelinkAutel:AUTELMCSystemState.statusMessages.isBatteryVoltageDiff.title".localized, level: .warning))
        }
        
        if isBatteryLowTemperature {
            messages.append(Kernel.Message(title: "DronelinkAutel:AUTELMCSystemState.statusMessages.isBatteryLowTemperature.title".localized, level: .warning))
        }
        
        if isReachMaxRange {
            messages.append(Kernel.Message(title: "DronelinkAutel:AUTELMCSystemState.statusMessages.isReachMaxRange.title".localized, level: .warning))
        }
        
        if isReachMaxHeight {
            messages.append(Kernel.Message(title: "DronelinkAutel:AUTELMCSystemState.statusMessages.isReachMaxHeight.title".localized, level: .warning))
        }
        
        if let message = flightMode.message {
            messages.append(message)
        }
        
        if location == nil {
            messages.append(Kernel.Message(title: "DronelinkAutel:AUTELMCSystemState.statusMessages.locationUnavailable.title".localized, details: "DronelinkAutel:AUTELMCSystemState.statusMessages.locationUnavailable.details".localized, level: .danger))
        }
        
        if isHomeInvalid {
            messages.append(Kernel.Message(title: "DronelinkAutel:AUTELMCSystemState.statusMessages.homeLocationNotSet.title".localized, level: .danger))
        }
        
        return messages
    }
}

extension AUTELMainControllerFlightMode {
    var message: Kernel.Message? {
        switch self {
        case .AutelMCFlightModeLanding,
            .AutelMCFlightModeTakeoff,
            .AutelMCFlightModeManualGoHome,
            .AutelMCFlightModeLowBattreyGoHome,
            .AutelMCFlightModeSmartLowBatteryGoHome,
            .AutelMCFlightModeFailSaveGoHome,
            .AutelMCFlightModeFailSaveHover:
            return Kernel.Message(title: "AUTELMainControllerFlightMode.value.\(rawValue)".localized, level: .warning)
            
        case .AutelMCFlightModeDisarm,
            .AutelMCFlightModeLanded,
            .AutelMCFlightModeAttitude,
            .AutelMCFlightModeGPS,
            .AutelMCFlightModeIOC:
            return nil

        case .AutelMCFlightModeWaypoint,
            .AutelMCFlightModeWaypointPause,
            .AutelMCFlightModeWaypointGoHome:
            return nil
            
        case .AutelMCFlightModeFollowMe,
            .AutelMCFlightModeHotpoint,
            .AutelMCFlightModeFollowMePause,
            .AutelMCFlightModeHotpointPause,
            .AutelMCFlightMode360Shoot,
            .AutelMCFlightModeEpic,
            .AutelMCFlightModeRise,
            .AutelMCFlightModeFadeAway,
            .AutelMCFlightModeIntosky,
            .AutelMCFlightModeBoomerang,
            .AutelMCFlightModeScrew,
            .AutelMCFlightModeParabola,
            .AutelMCFlightModeAsteroid,
            .AutelMCFlightModeCircleRound,
            .AutelMCFlightModeDollyZoom,
            .AutelMCFlightModeTripod,
            .AutelMCFlightModePhotographer,
            .AutelMCFlightModeRectangle,
            .AutelMCFlightModeRectanglePause,
            .AutelMCFlightModePolygon,
            .AutelMCFlightModePolygonPause,
            .AutelMCFlightModeDelayShot,
            .AutelMCFlightModeDelayShotPause,
            .AutelMCFlightModeObliquePhoto,
            .AutelMCFlightModeObliquePhotoPause,
            .AutelMCFlightModePanoramicPhoto,
            .AutelMCFlightModePanoramicPhotoPause,
            .AutelMCFlightModeTrackCommonMode,
            .AutelMCFlightModeTrackParallelMode,
            .AutelMCFlightModeTrackLockedMode,
            .AutelMCFlightModePointFlyInside,
            .AutelMCFlightModePointFlyOutside,
            .AutelMCFlightModeUnknow:
            return nil
            
        @unknown default:
            return nil
        }
    }
}

extension AUTELDroneLowPowerWarning {
    var message: Kernel.Message? {
        var level: Kernel.MessageLevel?
        
        switch self {
        case .DroneHeightPower, .DroneLowPowerUnknow:
            return nil
            
        case .DroneLowPower:
            level = .warning
            break
            
        case .DroneVeryLowPower:
            level = .danger
            break
            
        @unknown default:
            return nil
        }
        
        return Kernel.Message(title: "AUTELDroneLowPowerWarning.value.\(rawValue)".localized, level: level)
    }
}

extension AUTELMainControllerNoFlyStatus {
    var message: Kernel.Message? {
        var level: Kernel.MessageLevel?
        
        switch self {
        case .DroneNormalFlying, .UnknownStatus:
            return nil
            
        case .DroneApproachingNoFlyZone,
            .DroneUnderLimitFlyZone,
            .DroneReachMaxFlyingHeightInLimitFlyZone,
            .DroneInNoFlyZone,
            .DroneInENNoFlyZone:
            level = .warning
            break
            
            break
            
        @unknown default:
            return nil
        }
        
        return Kernel.Message(title: "AUTELMainControllerNoFlyStatus.title".localized, details: "AUTELMainControllerNoFlyStatus.value.\(rawValue)".localized, level: level)
    }
}

extension AUTELCompassCalibrationStatus {
    var message: Kernel.Message? {
        var level: Kernel.MessageLevel?
        
        switch self {
        case .none:
            return nil
            
        case .step1, .step2, .step3:
            level = .warning
            break
            
        case .calculating, .timeout:
            level = .warning
            break
            
        case .succeeded:
            level = .info
            break
            
        case .failed, .failedNoGPS:
            level = .error
            break
            
        case .unknown:
            return nil
            
        @unknown default:
            return nil
        }
        
        return Kernel.Message(title: "AUTELCompassCalibrationStatus.title".localized, details: "AUTELCompassCalibrationStatus.value.\(rawValue)".localized, level: level)
    }
}
