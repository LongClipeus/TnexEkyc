import Flutter
import UIKit

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
        default:
            break
        }
    }
}
