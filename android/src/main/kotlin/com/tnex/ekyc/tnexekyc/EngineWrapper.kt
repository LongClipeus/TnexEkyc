package com.tnex.ekyc.tnexekyc

import android.content.res.AssetManager
import android.graphics.Bitmap
import android.util.Log
import com.mv.engine.FaceBox
import com.mv.engine.FaceDetector
import com.mv.engine.Live


class EngineWrapper(private var assetManager: AssetManager) {

    private var faceDetector: FaceDetector = FaceDetector()
    private var live: Live = Live()

    fun init(): Boolean {

        var ret = faceDetector.loadModel(assetManager)
        Log.i("engineWrapper", "BienNT liveness init faceDetector = $ret")

        if (ret == 0) {
            ret = live.loadModel(assetManager)
            Log.i("engineWrapper", "BienNT liveness init live = $ret")

            return ret == 0
        }

        return false
    }

    fun destroy() {
        faceDetector.destroy()
        live.destroy()
    }

    fun detect(yuv: ByteArray, width: Int, height: Int, orientation: Int): Float {
        val boxes = detectFace(yuv, width, height, orientation)
        Log.i("engineWrapper", "BienNT liveness boxes.size = " + boxes.size)
        if (boxes.isNotEmpty() && boxes.size == 1) {
            return detectLive(yuv, width, height, orientation, boxes[0])
        }

        return 0.0f
    }

    fun detect(bitmap: Bitmap): Float {
        val boxes = detectFace(bitmap)
        if (boxes != null && boxes.size == 1) {
            return detectLive(bitmap, boxes[0])
        }

        return 0.0f
    }

    private fun detectFace(
        yuv: ByteArray,
        width: Int,
        height: Int,
        orientation: Int
    ): List<FaceBox> = faceDetector.detect(yuv, width, height, orientation)

    private fun detectFace(
        bitmap: Bitmap
    ): List<FaceBox> = faceDetector.detect(bitmap)

    private fun detectLive(
        yuv: ByteArray,
        width: Int,
        height: Int,
        orientation: Int,
        faceBox: FaceBox
    ): Float = live.detect(yuv, width, height, orientation, faceBox)

    private fun detectLive(
        bitmap: Bitmap,
        faceBox: FaceBox
    ): Float = live.detectBitmap(bitmap, faceBox)

}