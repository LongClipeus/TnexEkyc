package com.tnex.ekyc.tnexekyc

import android.app.Activity
import android.content.Context
import android.util.Log
import android.view.View
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.platform.PlatformView


internal class FlutterCaptureView(activity:Activity, context: Context, id: Int, creationParams: Map<*, *>?, listener: CaptureListener) :
    PlatformView {
    private val captureView: CameraCaptureLayout = CameraCaptureLayout(context, listener)
    override fun getView(): View {
        Log.i("ekycEventBIENNT", "ekycEventBIENNT FlutterCaptureView getView")
        return captureView
    }

    override fun dispose() {
        Log.i("ekycEventBIENNT", "ekycEventBIENNT FlutterCaptureView dispose")
        captureView.stopCamera()
    }

    init {
        val height = creationParams?.get("height") as Int
        val width = creationParams["width"] as Int
        captureView.initCameraView(activity, height, width)
    }


    fun onStopCamera() {
        captureView.stopCamera()
    }

    fun onStartCamera() {
        captureView.startCamera()
    }

    fun onCaptureImage() {
        captureView.captureImage()
    }
}