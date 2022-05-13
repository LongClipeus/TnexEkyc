import Flutter
import UIKit

public class SwiftTnexekycPlugin: NSObject, FlutterPlugin {
    private static var factory: FLNativeViewFactory?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "tnexekyc", binaryMessenger: registrar.messenger())
        let instance = SwiftTnexekycPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        factory = FLNativeViewFactory(messenger: registrar.messenger())
        registrar.register(factory!, withId: "plugins.tnex.ekyc/camera")
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result("iOS " + UIDevice.current.systemVersion)
        guard let factoryView = SwiftTnexekycPlugin.factory else {
            return
        }
        
        switch call.method {
        case "onStartEkyc":
            factoryView.startDetection()
            break
        case "onStopEkyc":
            factoryView.stopDetection()
            break
        default:
            break
        }
    }
}
