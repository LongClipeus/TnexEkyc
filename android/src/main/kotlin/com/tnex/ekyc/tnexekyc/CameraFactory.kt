package com.tnex.ekyc.tnexekyc

import android.app.Activity
import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory


class CameraFactory constructor(
    private val activity: Activity,
    private val listener: EkycListener
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    private lateinit var cameraView: FlutterCameraView

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as Map<*, *>?
        cameraView =  FlutterCameraView(activity, context, viewId, creationParams, listener)
        return cameraView
    }

    fun onStartEkyc() {
        cameraView.onStartEkyc()
    }

    fun onStopEkyc() {
        cameraView.onStopEkyc()
    }
}