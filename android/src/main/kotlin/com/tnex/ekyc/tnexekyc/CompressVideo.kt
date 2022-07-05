package com.tnex.ekyc.tnexekyc

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.util.Log
import androidx.camera.core.ImageProxy
import com.otaliastudios.transcoder.Transcoder
import com.otaliastudios.transcoder.TranscoderListener
import com.otaliastudios.transcoder.source.UriDataSource
import com.otaliastudios.transcoder.strategy.DefaultAudioStrategy
import com.otaliastudios.transcoder.strategy.DefaultVideoStrategy
import com.otaliastudios.transcoder.strategy.RemoveTrackStrategy
import com.otaliastudios.transcoder.strategy.TrackStrategy
import java.io.File
import java.util.*

interface CompressVideoListener {
    fun onCompleted(imagePath: String)
    fun onFailed()
}

class CompressVideo
{
    fun getBitmap(path: String, quality: Int, context: Context, listener: CompressVideoListener) {
        val frameRate = 30
        val tempDir: String = context.getExternalFilesDir("video_compress")!!.absolutePath
        val destPath: String = tempDir + File.separator + "VID_" + System.currentTimeMillis() + path.hashCode() + ".mp4"
        var videoTrackStrategy: TrackStrategy = DefaultVideoStrategy.atMost(340).build();
        when (quality) {
            0 -> {
                videoTrackStrategy = DefaultVideoStrategy.atMost(720).build()
            }
            1 -> {
                videoTrackStrategy = DefaultVideoStrategy.atMost(360).build()
            }
            2 -> {
                videoTrackStrategy = DefaultVideoStrategy.atMost(640).build()
            }
            3 -> {
                videoTrackStrategy = DefaultVideoStrategy.Builder()
                    .keyFrameInterval(3f)
                    .bitRate(1280 * 720 * 4.toLong())
                    .frameRate(frameRate) // will be capped to the input frameRate
                    .build()
            }
            4 -> {
                videoTrackStrategy = DefaultVideoStrategy.atMost(480, 640).build()
            }
            5 -> {
                videoTrackStrategy = DefaultVideoStrategy.atMost(540, 960).build()
            }
            6 -> {
                videoTrackStrategy = DefaultVideoStrategy.atMost(720, 1280).build()
            }
            7 -> {
                videoTrackStrategy = DefaultVideoStrategy.atMost(1080, 1920).build()
            }
        }

        val audioTrackStrategy = RemoveTrackStrategy()

        val dataSource = UriDataSource(context, Uri.parse(path))
        Transcoder.into(destPath)
            .addDataSource(dataSource)
            .setAudioTrackStrategy(audioTrackStrategy)
            .setVideoTrackStrategy(videoTrackStrategy)
            .setListener(object : TranscoderListener {
                override fun onTranscodeProgress(progress: Double) {
                    Log.i("updateProgress", "updateProgress = " + progress * 100.00)
                }
                override fun onTranscodeCompleted(successCode: Int) {
                    Log.i("updateProgress", "destPath = " + destPath)
                    listener.onCompleted(destPath)
                }

                override fun onTranscodeCanceled() {
                    Log.i("updateProgress", "onTranscodeCanceled")
                    listener.onFailed()
                }

                override fun onTranscodeFailed(exception: Throwable) {
                    Log.i("updateProgress", "onTranscodeFailed")

                    listener.onFailed()
                }
            }).transcode()

    }
}