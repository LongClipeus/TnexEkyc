package com.tnex.ekyc.tnexekyc

import android.app.Activity
import android.content.Context
import android.util.Log
import android.view.View
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.platform.PlatformView


internal class FlutterCameraView(activity:Activity, context: Context, id: Int, creationParams: Map<*, *>?, listener: EkycListener) :
    PlatformView {
    private val cameraView: CameraConstraintLayout = CameraConstraintLayout(context, listener)
    override fun getView(): View {
        return cameraView
    }

    override fun dispose() {
        cameraView.onStopEkyc()
    }

    init {
        val height = creationParams?.get("height") as Int
        val width = creationParams["width"] as Int
        val listDetectType = creationParams["detectType"] as ArrayList<String>
        Log.i("TAG", "ekycEvent FlutterCameraView listDetectType $listDetectType")
        cameraView.initCameraView(activity, height, width, listDetectType = listDetectType)
    }


    fun onStartEkyc() {
        cameraView.onStartEkyc()
    }

    fun onStopEkyc() {
        cameraView.onStopEkyc()
    }
}