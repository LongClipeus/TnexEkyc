package com.tnex.ekyc.tnexekyc

import android.app.Activity
import android.content.Context
import android.util.Log
import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** TnexekycPlugin */
class TnexekycPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, EkycListener, CaptureListener {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var context: Context
  private lateinit var activity: Activity
  private lateinit var eventEkycChannel: EventChannel
  private lateinit var eventCaptureChannel: EventChannel
  private lateinit var flutterPluginBinding : FlutterPlugin.FlutterPluginBinding
  private var cameraFactory : CameraFactory? = null
  private var eventEkycSink: EventSink? = null
  private var eventCaptureSink: EventSink? = null

  private var captureFactory : CaptureFactory? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    this.flutterPluginBinding = flutterPluginBinding

    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "tnexekyc")
    channel.setMethodCallHandler(this)
    eventEkycChannel = EventChannel(flutterPluginBinding.binaryMessenger, "tnex_ekyc_listener")
    eventEkycChannel.setStreamHandler( object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
          eventEkycSink = events
      }

      override fun onCancel(arguments: Any?) {
        eventEkycSink = null
      }
    })

    eventCaptureChannel = EventChannel(flutterPluginBinding.binaryMessenger, "tnex_capture_listener")
    eventCaptureChannel.setStreamHandler( object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventCaptureSink = events
      }

      override fun onCancel(arguments: Any?) {
        eventCaptureSink = null
      }
    })
    context = flutterPluginBinding.applicationContext
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if (call.method == "onStartEkyc") {
      cameraFactory?.onStartEkyc()
    } else if (call.method == "onStopEkyc") {
      cameraFactory?.onStopEkyc()
    } else if (call.method == "onCapture") {
      captureFactory?.onCaptureImage()
    } else if (call.method == "onStartCamera") {
      captureFactory?.onStartCamera()
    } else if (call.method == "onStopCamera") {
      captureFactory?.onStopCamera()
    } else if (call.method == "compressVideo") {
      val path = call.argument<String>("path")
      var quality = call.argument<Int>("quality")
      if(path.isNullOrEmpty()){
        result.success(null)
      }else{
        if(quality == null){
          quality = 3
        }
        CompressVideo().compressVideo(path, quality, activity, object  : CompressVideoListener {
          override fun onCompleted(imagePath: String) {
            result.success(imagePath)
          }

          override fun onFailed() {
            Log.i("updateProgress", "addKYCDocument SUCCESS_NOT_NEEDED result.success null")
            result.success(null)
          }

        })
      }
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    if(cameraFactory == null ){
      cameraFactory = CameraFactory(binding.activity, this@TnexekycPlugin)
      flutterPluginBinding
        .platformViewRegistry
        .registerViewFactory("plugins.tnex.ekyc/camera", cameraFactory)
    }

    if(captureFactory == null) {
      captureFactory = CaptureFactory(binding.activity, this@TnexekycPlugin)
      flutterPluginBinding.platformViewRegistry.registerViewFactory("plugins.tnex.capture/camera", captureFactory)
    }

//    cameraFactory?.onStartEkyc() ?: run {
//      cameraFactory = CameraFactory(binding.activity, this@TnexekycPlugin)
//      flutterPluginBinding
//        .platformViewRegistry
//        .registerViewFactory("plugins.tnex.ekyc/camera", cameraFactory)
//    }
//
//    captureFactory?.onStartCamera() ?: run {
//      captureFactory = CaptureFactory(binding.activity, this@TnexekycPlugin)
//      flutterPluginBinding.platformViewRegistry.registerViewFactory("plugins.tnex.capture/camera", captureFactory)
//    }
  }

  override fun onDetachedFromActivityForConfigChanges() {
//    cameraFactory?.onStopEkyc()
//    captureFactory?.onStopCamera()
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
//    cameraFactory?.onStartEkyc()
//    captureFactory?.onStartCamera()
  }

  override fun onDetachedFromActivity() {
//    cameraFactory?.onStopEkyc()
//    captureFactory?.onStopCamera()
  }

//  override fun onListen(arguments: Any?, events: EventSink?) {
//    Log.i("TAG", "ekycEvent EventSink = $events")
//    eventSink=events
//  }
//
//  override fun onCancel(arguments: Any?) {
//    eventSink = null
//  }

  override fun onResults(
    event: DetectionEvent,
    imagesPath: HashMap<String, String>?,
    videoPath: String?
  ) {
    Log.i("TAG", "ekycEvent TnexekycPlugin onResults  = " + event.eventName)

    if (eventEkycSink == null) {
      Log.i("TAG", "ekycEvent TnexekycPlugin eventSink  = null")
      return
    }

    Log.i("TAG", "ekycEvent TnexekycPlugin eventSink  != null")
    val events: MutableMap<String, String> = HashMap()
    events["eventType"] = event.eventName
    if(!videoPath.isNullOrEmpty()){
      events["videoPath"] = videoPath
    }

    if(!imagesPath.isNullOrEmpty()){
      for(key in imagesPath.keys){
        val imagePath = imagesPath[key]
        if(!imagePath.isNullOrEmpty()){
          events[key] = imagePath
        }
      }
    }

    Log.i("TAG", "ekycEventBIENNT TnexekycPlugin events $events")
    eventEkycSink!!.success(events)
  }

  override fun onStartDetectionType(type: String) {
    if (eventEkycSink == null) {
      Log.i("TAG", "ekycEvent TnexekycPlugin eventSink  = null")
      return
    }

    val events: MutableMap<String, String> = HashMap()
    events["eventType"] = "START_DETECTION"
    events["detectionType"] = type

    Log.i("TAG", "ekycEvent TnexekycPlugin events $events")
    eventEkycSink!!.success(events)
  }

  override fun onResults(imagePath: String) {
    if (eventCaptureSink == null) {
      return
    }

    val events: MutableMap<String, String> = HashMap()
    events["imagePath"] = imagePath
    events["eventType"] = "SUCCESS"
    eventCaptureSink!!.success(events)
  }

  override fun onError(type: String) {
    if (eventCaptureSink == null) {
      return
    }

    val events: MutableMap<String, String> = HashMap()
    events["errorType"] = type
    events["eventType"] = "ERROR"
    eventCaptureSink!!.success(events)
  }
}
