package com.tnex.ekyc.tnexekyc

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.util.AttributeSet
import android.util.Log
import android.util.Rational
import androidx.constraintlayout.widget.ConstraintLayout
import android.util.TypedValue
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.*
import androidx.lifecycle.Observer
import java.io.File

interface CaptureListener {
    fun onResults(imagePath: String)
    fun onError(type: String)
}

@SuppressLint("ViewConstructor")
class CameraCaptureLayout(context: Context,
                          private val listener: CaptureListener,
                          attrs: AttributeSet? = null,
                          defStyleAttr: Int = 0
) :
    ConstraintLayout(context, attrs, defStyleAttr) {

    private var previewView: PreviewView
    private var constraintLayout: ConstraintLayout
    private lateinit var activity: Activity
    private val mainThreadExecutor by lazy { ContextCompat.getMainExecutor(context) }
    private var cameraProvider: ProcessCameraProvider? = null
    private var imageCapture: ImageCapture? = null
    private var lifecycleOwner: LifecycleOwner? = null


    init {
        inflate(context, R.layout.camerax_capture, this)
        constraintLayout = findViewById(R.id.constraintLayout)
        previewView = findViewById(R.id.previewView)
    }


    fun initCameraView(activity:Activity, height: Int, width: Int){
        this.activity = activity
        val layoutParams = constraintLayout.layoutParams
        if (layoutParams != null) {
            val widthPixel =
                TypedValue.applyDimension(
                    TypedValue.COMPLEX_UNIT_DIP,
                    width.toFloat(),
                    resources.displayMetrics
                )
                    .toInt()
            val heightPixel = TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP,
                height.toFloat(),
                resources.displayMetrics
            )
                .toInt()

            layoutParams.height = heightPixel
            layoutParams.width = widthPixel
            constraintLayout.layoutParams = layoutParams
        }

        invalidate()
        initCamera()
    }

    private fun sendError(errorType: String){
        listener.onError(errorType)
    }

    private fun sendResults(imagePath: String){
        listener.onResults(imagePath)
    }

    private fun Activity.getLifecycleOwner(): LifecycleOwner {
        return try {
            this as LifecycleOwner
        } catch (exception: ClassCastException) {
            (this as ContextWrapper).baseContext as LifecycleOwner
        }
    }

    private fun initCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(activity)
        cameraProviderFuture.addListener(Runnable{
            cameraProvider = cameraProviderFuture.get()
            bindAllCameraUseCases()
        }, mainThreadExecutor)
    }

    private fun bindAllCameraUseCases() {
        if (cameraProvider == null) {
            sendError("FAILED")
            return
        }

        cameraProvider!!.unbindAll()
        lifecycleOwner = activity.getLifecycleOwner()
        if(lifecycleOwner == null){
            sendError("FAILED")
            return
        }

        val preview = Preview.Builder()
            .build()
            .also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }

        imageCapture = ImageCapture.Builder()
            .build()
        imageCapture!!.setCropAspectRatio(Rational(width, height))
        val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

        try {
            cameraProvider?.unbindAll()
            cameraProvider?.bindToLifecycle(
                lifecycleOwner!!, cameraSelector, preview, imageCapture)

        } catch (exc: Exception) {
            sendError("FAILED")
        }
    }


    private fun createFile(): File? {
        var file: File? = null
        try {
            val sdCardRoot = activity.filesDir.absolutePath
            val mFileName = System.currentTimeMillis().toString() + ".jpg"
            file = File(sdCardRoot, mFileName)
        } catch (e: Exception) {

        }
        return file
    }

    fun startCamera(){
        bindAllCameraUseCases()
    }

    fun stopCamera(){
        if (cameraProvider != null) {
            cameraProvider!!.unbindAll()
        }
    }

    fun captureImage(){
        val capture = imageCapture
        if(capture == null){
            sendError("IMAGE_FAILED")
            return
        }

        val file = createFile()
        if(file == null){
            sendError("IMAGE_FAILED")
            return
        }

        try {
            val fileOutput = ImageCapture.OutputFileOptions.Builder(file)
                .build()

            capture.takePicture(fileOutput, mainThreadExecutor,
                object : ImageCapture.OnImageSavedCallback {
                    override fun onError(error: ImageCaptureException)
                    {
                        sendError("IMAGE_FAILED")
                    }
                    override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {

                        val uri = outputFileResults.savedUri
                        if(uri == null){
                            sendError("IMAGE_FAILED")
                            return
                        }

                        val path = uri.path
                        if(path.isNullOrEmpty()){
                            sendError("IMAGE_FAILED")
                            return
                        }

                        sendResults(path)
                    }
                })
        } catch (e: Exception) {
            sendError("IMAGE_FAILED")
        }
    }

}