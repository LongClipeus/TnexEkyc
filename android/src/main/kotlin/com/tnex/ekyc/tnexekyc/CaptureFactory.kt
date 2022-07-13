package com.tnex.ekyc.tnexekyc

import android.app.Activity
import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory


class CaptureFactory constructor(
    private val activity: Activity,
    private val listener: CaptureListener
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    private lateinit var captureView: FlutterCaptureView
    private var isInit = false

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as Map<*, *>?
        captureView = FlutterCaptureView(activity, context, viewId, creationParams, listener)
        isInit = true
        return captureView
    }

    fun onStopCamera() {
        if(isInit){
            captureView.onStopCamera()
        }
    }

    fun onStartCamera() {
        if(isInit){
            captureView.onStartCamera()
        }
    }

    fun onCaptureImage() {
        if(isInit){
            captureView.onCaptureImage()
        }
    }

}