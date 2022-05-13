package com.tnex.ekyc.tnexekyc

import android.text.TextUtils
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
class TnexekycPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, EkycListener, EventChannel.StreamHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var eventChannel: EventChannel
  private lateinit var flutterPluginBinding : FlutterPlugin.FlutterPluginBinding
  private var cameraFactory : CameraFactory? = null
  private var eventSink: EventSink? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    this.flutterPluginBinding = flutterPluginBinding

    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "tnexekyc")
    channel.setMethodCallHandler(this)
    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "tnex_ekyc_listener")
    eventChannel.setStreamHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if (call.method == "onStartEkyc") {
      cameraFactory?.onStartEkyc()
    } else if (call.method == "onStopEkyc") {
      cameraFactory?.onStopEkyc()
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    cameraFactory?.onStartEkyc() ?: run {
      cameraFactory = CameraFactory(binding.activity, this@TnexekycPlugin)
      flutterPluginBinding
        .platformViewRegistry
        .registerViewFactory("plugins.tnex.ekyc/camera", cameraFactory)
    }
  }

  override fun onDetachedFromActivityForConfigChanges() {
    cameraFactory?.onStopEkyc()
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    cameraFactory?.onStartEkyc()
  }

  override fun onDetachedFromActivity() {
    cameraFactory?.onStopEkyc()
  }

  override fun onListen(arguments: Any?, events: EventSink?) {
    Log.i("TAG", "ekycEvent EventSink = $events")
    eventSink=events
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }

  override fun onResults(
    event: DetectionEvent,
    imagesPath: HashMap<String, String>?,
    videoPath: String?
  ) {
    Log.i("TAG", "ekycEvent TnexekycPlugin onResults  = " + event.eventName)

    if (eventSink == null) {
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
    eventSink!!.success(events)
  }

  override fun onStartDetectionType(type: String) {
    if (eventSink == null) {
      Log.i("TAG", "ekycEvent TnexekycPlugin eventSink  = null")
      return
    }

    val events: MutableMap<String, String> = HashMap()
    events["eventType"] = "START_DETECTION"
    events["detectionType"] = type

    Log.i("TAG", "ekycEvent TnexekycPlugin events $events")
    eventSink!!.success(events)
  }
}
