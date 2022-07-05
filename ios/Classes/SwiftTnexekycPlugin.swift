import Flutter
import UIKit
import AVFoundation

public class SwiftTnexekycPlugin: NSObject, FlutterPlugin {
    private static var factoryEkyc: EkycViewFactory?
    private static var factoryCamera: CameraViewFactory?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "tnexekyc", binaryMessenger: registrar.messenger())
        let instance = SwiftTnexekycPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        factoryEkyc = EkycViewFactory(messenger: registrar.messenger())
        registrar.register(factoryEkyc!, withId: "plugins.tnex.ekyc/camera")

        factoryCamera = CameraViewFactory(messenger: registrar.messenger())
        registrar.register(factoryCamera!, withId: "plugins.tnex.capture/camera")
    }
    
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result("iOS " + UIDevice.current.systemVersion)
        switch call.method {
        case "onStartEkyc":
            guard let factoryView = SwiftTnexekycPlugin.factoryEkyc else {
                return
            }
            factoryView.startDetection()
            break
        case "onStopEkyc":
            guard let factoryView = SwiftTnexekycPlugin.factoryEkyc else {
                return
            }
            factoryView.stopDetection()
            break
        case "onCapture":
            guard let factoryCamera = SwiftTnexekycPlugin.factoryCamera else {
                return
            }
            factoryCamera.captureImage()
            break
        case "onStartCamera":
            guard let factoryCamera = SwiftTnexekycPlugin.factoryCamera else {
                return
            }
            factoryCamera.startCamera()
            break
        case "onStopCamera":
            guard let factoryCamera = SwiftTnexekycPlugin.factoryCamera else {
                return
            }
            factoryCamera.stopCamera()
            break
        case "compressVideo":
            if let args = call.arguments as? Dictionary<String, Any>,
                        let path = args["path"] as? String, let quality = args["quality"] as? NSNumber {
                compressVideo(path, quality, result)
            }else{
                result(nil)
            }
        default:
            break
        }
    }
    
    private func getExportPreset(_ quality: NSNumber)->String {
           switch(quality) {
           case 1:
               return AVAssetExportPresetLowQuality
           case 2:
               return AVAssetExportPresetMediumQuality
           case 3:
               return AVAssetExportPresetHighestQuality
           case 4:
               return AVAssetExportPreset640x480
           case 5:
               return AVAssetExportPreset960x540
           case 6:
               return AVAssetExportPreset1280x720
           case 7:
               return AVAssetExportPreset1920x1080
           default:
               return AVAssetExportPresetMediumQuality
           }
       }
    
    private func getComposition(_ isIncludeAudio: Bool,_ timeRange: CMTimeRange, _ sourceVideoTrack: AVAssetTrack)->AVAsset {
            let composition = AVMutableComposition()
            if !isIncludeAudio {
                let compressionVideoTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
                compressionVideoTrack!.preferredTransform = sourceVideoTrack.preferredTransform
                try? compressionVideoTrack!.insertTimeRange(timeRange, of: sourceVideoTrack, at: CMTime.zero)
            } else {
                return sourceVideoTrack.asset!
            }
            
            return composition
        }
    
    private func compressVideo(_ path: String,_ quality: NSNumber,
                                  _ result: @escaping FlutterResult) {
       let avController = AvController()
       let sourceVideoUrl = UIConstants.getPathUrl(path)
       let sourceVideoType = "mp4"
       
       let sourceVideoAsset = avController.getVideoAsset(sourceVideoUrl)
       let sourceVideoTrack = avController.getTrack(sourceVideoAsset)

       let uuid = NSUUID()
       let compressionUrl = UIConstants.getPathUrl("\(UIConstants.basePath())/\(UIConstants.getFileName(path))\(uuid.uuidString).\(sourceVideoType)")

       let timescale = sourceVideoAsset.duration.timescale
       let minStartTime = Double(0)
       
       let videoDuration = sourceVideoAsset.duration.seconds
       let minDuration = Double(videoDuration)
       let maxDurationTime = minStartTime + minDuration < videoDuration ? minDuration : videoDuration
       
       let cmStartTime = CMTimeMakeWithSeconds(minStartTime, preferredTimescale: timescale)
       let cmDurationTime = CMTimeMakeWithSeconds(maxDurationTime, preferredTimescale: timescale)
       let timeRange: CMTimeRange = CMTimeRangeMake(start: cmStartTime, duration: cmDurationTime)
       
       
       let session = getComposition(false, timeRange, sourceVideoTrack!)
       
       let exporter = AVAssetExportSession(asset: session, presetName: getExportPreset(quality))!
       
       exporter.outputURL = compressionUrl
       exporter.outputFileType = AVFileType.mp4
       exporter.shouldOptimizeForNetworkUse = true
           
        let videoComposition = AVMutableVideoComposition(propertiesOf: sourceVideoAsset)
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: Int32(30))
        exporter.videoComposition = videoComposition
        exporter.timeRange = timeRange
           
        UIConstants.deleteFile(compressionUrl.absoluteString)
        exporter.exportAsynchronously(completionHandler: {
               result(compressionUrl.path)
           })
       }
}
