//
//  CameraViewFactory.swift
//  tnexekyc
//
//  Created by Tnex on 23/05/2022.
//
import Flutter
import UIKit

class CameraViewFactory: NSObject, FlutterPlatformViewFactory, FlutterStreamHandler {
    private var messenger: FlutterBinaryMessenger
    private var eventSink: FlutterEventSink?
    private var nativeView: CameraNativeView?

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
        
        let eventChannel = FlutterEventChannel(name: "tnex_capture_listener",
            binaryMessenger: messenger)
        eventChannel.setStreamHandler(self)
                                      
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
          return FlutterStandardMessageCodec.sharedInstance()
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    func startCamera(){
        guard let camera = nativeView else {
            return
        }
        
        camera.startCamera()
    }
    
    func captureImage(){
        guard let camera = nativeView else {
            return
        }
        
        camera.captureImage()
    }
    
    func stopCamera(){
        guard let camera = nativeView else {
            return
        }
        
        camera.stopCamera()
    }
    
    private func sendDartEvent(imagePath: String){
        guard let sink = self.eventSink else {
            print("listenerDetection eventSink nil")
            return
        }
        
        let eventJsonObject: NSMutableDictionary = NSMutableDictionary()
        eventJsonObject.setValue("SUCCESS", forKey: "eventType")
        eventJsonObject.setValue(imagePath, forKey: "imagePath")
        
        sink(eventJsonObject)
    }
    
    private func sendErrorEvent(errorType: String){
        guard let sink = self.eventSink else {
            print("listenerDetection eventSink nil")
            return
        }
        
        let eventJsonObject: NSMutableDictionary = NSMutableDictionary()
        eventJsonObject.setValue("ERROR", forKey: "eventType")
        eventJsonObject.setValue(errorType, forKey: "errorType")
        
        sink(eventJsonObject)
    }
    
    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        nativeView =  CameraNativeView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger,
            onResults: {imagePath in
                print("listenerDetection \(imagePath)")
                self.sendDartEvent(imagePath: imagePath)
            }, onError: { error in
                self.sendErrorEvent(errorType: error)
            })
        
        return nativeView!
    }
}

class CameraNativeView: NSObject, FlutterPlatformView {
    
    private var _view: UIView
    private var cameraView: CameraView?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger,
        onResults: @escaping (String) -> (),
        onError: @escaping (String)->()
    ) {
        _view = UIView()
        _view.backgroundColor = UIColor.red
        super.init()
        // iOS views can be created here
    
        createNativeView(view: _view, arguments: args, onResults: onResults, onError: onError)
    }

    func view() -> UIView {
        return _view
    }
    
    func startCamera(){
        guard let camera = cameraView else {
            return
        }
        
        camera.startCamera()
    }
    
    func stopCamera(){
        guard let camera = cameraView else {
            return
        }
        
        camera.stopCamera()
    }
    
    func captureImage(){
        guard let camera = cameraView else {
            return
        }
        
        camera.captureImage()
    }

    func createNativeView(view _view: UIView, arguments args: Any?, onResults: @escaping (String) -> (), onError: @escaping (String) -> ()){
        if let argsNotNull = args as? Dictionary<String, Any>,
            let height = argsNotNull["height"] as? Int,
            let width = argsNotNull["width"]  as? Int{
            _view.setSize(width: CGFloat(width), height: CGFloat(height))
            cameraView  = CameraView(frame: CGRect(x: 0, y: 0, width: width, height: height))
            guard let camera = cameraView else {
                return
            }
            
            camera.listenerCamera(onResults: onResults, onError: onError)
            _view.addSubview(camera)
          } else {
            
          }
    }
}
