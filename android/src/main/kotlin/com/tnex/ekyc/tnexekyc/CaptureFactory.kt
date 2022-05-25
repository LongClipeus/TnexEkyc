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

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as Map<*, *>?
        captureView = FlutterCaptureView(activity, context, viewId, creationParams, listener)
        return captureView
    }

    fun onStopCamera() {
        captureView.onStopCamera()
    }

    fun onStartCamera() {
        captureView.onStartCamera()
    }

    fun onCaptureImage() {
        captureView.onCaptureImage()
    }

}