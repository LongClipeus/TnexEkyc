package com.tnex.ekyc.tnexekyc

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.otaliastudios.transcoder.Transcoder
import com.otaliastudios.transcoder.TranscoderListener
import com.otaliastudios.transcoder.common.TrackType
import com.otaliastudios.transcoder.source.UriDataSource
import com.otaliastudios.transcoder.strategy.DefaultVideoStrategy
import com.otaliastudios.transcoder.strategy.TrackStrategy
import java.io.*


interface CompressVideoListener {
    fun onCompleted(imagePath: String)
    fun onFailed()
}

class CompressVideo
{
    fun compressVideo(path: String, quality: Int,   activity: Activity, listener: CompressVideoListener) {
        val permissions = arrayOf(
            Manifest.permission.READ_EXTERNAL_STORAGE,
            Manifest.permission.WRITE_EXTERNAL_STORAGE
        )

        if (!hasPermissions(activity, permissions)) {
            ActivityCompat.requestPermissions(
                activity,
                permissions,
                1
            )
            compress(path, quality, activity, listener, 0)
        } else {
            compress(path, quality, activity, listener, 0)
        }

    }

    private fun checkFile(destPath:String){
        try {
            val file = File(destPath)
            if(file.exists()){
                file.delete()
            }
        } catch (e: Exception) {

        }
    }


    private fun compress(path: String, quality: Int, context: Context, listener: CompressVideoListener, retry:Int){
        val sdCardRoot = context.filesDir.absolutePath
        val destPath: String = sdCardRoot + File.separator + System.currentTimeMillis() + path.hashCode() + ".mp4"

//        val destPath: String = sdCardRoot + File.separator + "tnex_video_ekyc_compress.mp4"
//        checkFile(destPath)
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
                    .frameRate(30) // will be capped to the input frameRate
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

        val dataSource = UriDataSource(context, Uri.parse(path))
        Log.i("updateProgress", "addKYCDocument dataSource = $dataSource")
        Transcoder.into(destPath)
            .addDataSource(TrackType.VIDEO, dataSource)
            //.setAudioTrackStrategy(audioTrackStrategy)
            .setVideoTrackStrategy(videoTrackStrategy)
            .setListener(object : TranscoderListener {
                override fun onTranscodeProgress(progress: Double) {
                    Log.i("updateProgress", "addKYCDocument updateProgress = " + progress * 100.00)
                }
                override fun onTranscodeCompleted(successCode: Int) {
                    Log.i("updateProgress", "addKYCDocument destPath = $destPath")
                    if(successCode == Transcoder.SUCCESS_NOT_NEEDED){
                        Log.i("updateProgress", "addKYCDocument SUCCESS_NOT_NEEDED retry = $retry")
                        if(retry >= 3){
                            Log.i("updateProgress", "addKYCDocument SUCCESS_NOT_NEEDED listener.onFailed")
                            listener.onFailed()
                        }else{
                            compress(path, quality, context, listener, retry + 1)
                        }
                    }else{
                        listener.onCompleted(destPath)
                    }
                }

                override fun onTranscodeCanceled() {
                    Log.i("updateProgress", "addKYCDocument onTranscodeCanceled")
                    listener.onFailed()
                }

                override fun onTranscodeFailed(exception: Throwable) {
                    Log.i("updateProgress", "addKYCDocument onTranscodeFailed")
                    listener.onFailed()
                }
            }).transcode()
    }

    private fun hasPermissions(
        context: Context?,
        permissions: Array<String>
    ): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && context != null) {
            for (permission in permissions) {
                if (ContextCompat.checkSelfPermission(
                        context,
                        permission
                    ) != PackageManager.PERMISSION_GRANTED
                ) {
                    return false
                }
            }
        }
        return true
    }
}