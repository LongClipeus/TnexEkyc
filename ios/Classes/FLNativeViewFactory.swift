//
//  FLNativeViewFactory.swift
//  tnexekyc
//
//  Created by Tnex on 05/05/2022.
//

import Flutter
import UIKit

class FLNativeViewFactory: NSObject, FlutterPlatformViewFactory, FlutterStreamHandler {
    private var messenger: FlutterBinaryMessenger
    private var eventSink: FlutterEventSink?
    private var nativeView: FLNativeView?

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
        
        let eventChannel = FlutterEventChannel(name: "tnex_ekyc_listener",
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
    
    func startDetection(){
        guard let camera = nativeView else {
            return
        }
        
        camera.startDetection()
    }
    
    func stopDetection(){
        guard let camera = nativeView else {
            return
        }
        
        camera.stopDetection()
    }
    
    private func sendDartEvent(eventType: String, imagePath: [String:String]?, videoPath: String?, detectType: String?){
        guard let sink = self.eventSink else {
            print("listenerDetection eventSink nil")
            return
        }
        
        let eventJsonObject: NSMutableDictionary = NSMutableDictionary()
        eventJsonObject.setValue(eventType, forKey: "eventType")
        if let image = imagePath, !image.isEmpty {
            for (key, value) in image {
                eventJsonObject.setValue(value, forKey: key)
            }
        }
        
        if let video = videoPath, !video.isEmpty {
            eventJsonObject.setValue(video, forKey: "videoPath")
        }
        
        if let detect = detectType, !detect.isEmpty {
            eventJsonObject.setValue(detect, forKey: "detectionType")
        }
        
        print("listenerDetection eventJsonObject \(eventJsonObject)")
        
        sink(eventJsonObject)
    }
    
    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        nativeView =  FLNativeView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger,
            listener: {result in
                print("listenerDetection \(result)")
                self.sendDartEvent(eventType: "START_DETECTION", imagePath: nil, videoPath: nil, detectType: result)
            }, completion: { detectType, imagePath, videoPath in
                print("listenerDetection detectType \(detectType.rawValue) imagePath \(String(describing: imagePath))  videoPath \(String(describing: videoPath))")
                self.sendDartEvent(eventType: detectType.rawValue, imagePath: nil, videoPath: nil, detectType: nil)
            })
        
        return nativeView!
    }
}

class FLNativeView: NSObject, FlutterPlatformView {
    
    private var _view: UIView
    private var cameraView: EkycView?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger,
        listener: @escaping (String) -> (),
        completion: @escaping (DetectionEvent, [String:String]?, String?)->()
    ) {
        _view = UIView()
        _view.backgroundColor = UIColor.red
        super.init()
        // iOS views can be created here
    
        createNativeView(view: _view, arguments: args, listener: listener, completion: completion)
    }

    func view() -> UIView {
        return _view
    }
    
    func startDetection(){
        guard let camera = cameraView else {
            return
        }
        
        camera.startDetection()
    }
    
    func stopDetection(){
        guard let camera = cameraView else {
            return
        }
        
        camera.stopDetection()
    }

    func createNativeView(view _view: UIView, arguments args: Any?, listener: @escaping (String) -> (), completion: @escaping (DetectionEvent, [String:String]?, String?)->()){
        if let argsNotNull = args as? Dictionary<String, Any>,
            let height = argsNotNull["height"] as? Int,
            let width = argsNotNull["width"]  as? Int,
            let listDetectType = argsNotNull["detectType"]  as? [String]{
            _view.setSize(width: CGFloat(width), height: CGFloat(height))
            cameraView  = EkycView(frame: CGRect(x: 0, y: 0, width: width, height: height))
            guard let camera = cameraView else {
                return
            }
            
            camera.setListDetectType(list: listDetectType)
            camera.listenerDetection(listener: listener, completion: completion)
            _view.addSubview(camera)
          } else {
            
          }
    }
}
