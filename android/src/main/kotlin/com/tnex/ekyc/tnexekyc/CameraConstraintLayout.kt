package com.tnex.ekyc.tnexekyc

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.graphics.*
import android.util.AttributeSet
import android.util.Log
import androidx.constraintlayout.widget.ConstraintLayout
import android.util.TypedValue
import android.widget.Toast
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.*
import androidx.camera.video.VideoCapture
import androidx.core.content.ContextCompat
import androidx.core.util.Consumer
import androidx.lifecycle.*
import androidx.lifecycle.Observer
import com.google.mlkit.common.MlKitException
import java.io.File
import java.util.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.collections.ArrayList
import kotlin.collections.HashMap
import kotlin.concurrent.schedule

interface EkycListener {
    fun onResults(event: DetectionEvent, imagesPath:HashMap<String, String>?, videoPath: String?)
    fun onStartDetectionType(type: String)
}

@SuppressLint("ViewConstructor")
class CameraConstraintLayout(context: Context,
                             override val listener: EkycListener,
                             attrs: AttributeSet? = null,
                             defStyleAttr: Int = 0
) :
    ConstraintLayout(context, attrs, defStyleAttr), DetectionListener {


    private var constraintLayout: ConstraintLayout? = null
    private lateinit var activity: Activity

    private var listDetectType = arrayListOf<String>()
    private var videoCapture: VideoCapture<Recorder>? = null
    private var currentRecording: Recording? = null
    private var recordingState: VideoRecordEvent? = null
    private var videoPath: String? = null

    private var graphicOverlay: GraphicOverlay? = null
    private var graphicImage: GraphicOverlay? = null

    private var cameraProvider: ProcessCameraProvider? = null
    private var analysisUseCase: ImageAnalysis? = null
    private var imageProcessor: VisionImageProcessor? = null
    private var needUpdateGraphicOverlayImageSourceInfo = false
    private var lensFacing = CameraSelector.LENS_FACING_FRONT
    private var cameraSelector: CameraSelector? = null
    private var lifecycleOwner: LifecycleOwner? = null

    private var viewHeight: Int = 0
    private var viewWidth: Int = 0

    private var isWaitingSendEvent = false
    private var imagePathWaiting = hashMapOf<String, String>()

    init {
        inflate(context, R.layout.camerax_live_preview, this)
        constraintLayout = findViewById(R.id.constraintLayout)
        graphicOverlay = findViewById(R.id.graphic_overlay)
        graphicImage = findViewById(R.id.graphic_image)
    }


    fun initCameraView(activity:Activity, height: Int, width: Int, listDetectType: ArrayList<String>){
        this.activity = activity
        this.listDetectType.clear()
        this.listDetectType.addAll(listDetectType)
        val layoutParams = constraintLayout?.layoutParams
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

            Log.i("FaceDetectorProcessor","FaceDetectorProcessor layoutParams height = $heightPixel width = $widthPixel")
            layoutParams.height = heightPixel
            layoutParams.width = widthPixel
            viewHeight = heightPixel
            viewWidth = widthPixel
            constraintLayout?.layoutParams = layoutParams
        }

        invalidate()
        lifecycleOwner = activity.getLifecycleOwner()
        if(lifecycleOwner == null){
            sendEkycEvent(DetectionEvent.FAILED, null)
            return
        }
        cameraSelector = CameraSelector.Builder().requireLensFacing(lensFacing).build()
        ViewModelProvider.AndroidViewModelFactory.getInstance(activity.application).create(CameraXViewModel::class.java)
            .processCameraProvider
            .observe(
                lifecycleOwner!!,
                Observer { provider: ProcessCameraProvider? ->
                    cameraProvider = provider
                    bindAllCameraUseCases()

//                    Timer().schedule(500) {
//                        initCameraView()
//                    }
                }
            )
    }

    private fun initCameraView() {
        if(activity.isDestroyed || activity.isFinishing){
            return
        }

        activity.runOnUiThread {
            bindAllCameraUseCases()
        }
    }

    private fun Activity.getLifecycleOwner(): LifecycleOwner {
        return try {
            this as LifecycleOwner
        } catch (exception: ClassCastException) {
            (this as ContextWrapper).baseContext as LifecycleOwner
        }
    }

    private fun bindAllCameraUseCases() {
        isWaitingSendEvent = false
        imagePathWaiting.clear()

        if (cameraProvider != null) {
            cameraProvider!!.unbindAll()
            bindAnalysisUseCase()
        }else{
            sendEkycEvent(DetectionEvent.FAILED, null)
        }
    }

    private fun bindAnalysisUseCase() {
        if (cameraProvider == null) {
            sendEkycEvent(DetectionEvent.FAILED, null)
            return
        }
        if (analysisUseCase != null) {
            cameraProvider!!.unbind(analysisUseCase)
        }

        if (videoCapture != null) {
            cameraProvider!!.unbind(videoCapture)
        }

        if (imageProcessor != null) {
            imageProcessor!!.stop()
        }

        analysisUseCase?.clearAnalyzer()


        imageProcessor =
            try {
                val faceDetectorOptions = PreferenceUtils.getFaceDetectorOptions(context)
                val listDetectionType = getListDetectType()
                Log.i("FaceDetectorProcessor", "FaceDetectorProcessor layoutParams height = $viewHeight width = $viewWidth")
                context?.let { FaceDetectorProcessor(it, faceDetectorOptions, listDetectionType, this, viewHeight, viewWidth) }
            } catch (e: Exception) {
                Log.i("FaceDetectorProcessor", "Can not create image processor: " + e.localizedMessage)
                sendEkycEvent(DetectionEvent.FAILED, null)
                return
            }


        try {
            val quality = Quality.SD
            val qualitySelector = QualitySelector.from(quality)
            val builder = ImageAnalysis.Builder()
            val targetResolution = PreferenceUtils.getCameraXTargetResolution(context, lensFacing)

            // image
            if (targetResolution != null) {
                builder.setTargetResolution(targetResolution)
            }

            analysisUseCase = builder.build()

            needUpdateGraphicOverlayImageSourceInfo = true

            analysisUseCase?.setAnalyzer(
                // imageProcessor.processImageProxy will use another thread to run the detection underneath,
                // thus we can just runs the analyzer itself on main thread.
                ContextCompat.getMainExecutor(activity),
                ImageAnalysis.Analyzer { imageProxy: ImageProxy ->
                    Log.i("FaceDetectorProcessor", "ImageAnalysis $needUpdateGraphicOverlayImageSourceInfo")
                    if (needUpdateGraphicOverlayImageSourceInfo) {
                        val isImageFlipped = lensFacing == CameraSelector.LENS_FACING_FRONT
                        val rotationDegrees = imageProxy.imageInfo.rotationDegrees
                        if (rotationDegrees == 0 || rotationDegrees == 180) {
                            graphicOverlay!!.setImageSourceInfo(imageProxy.width, imageProxy.height, isImageFlipped)
                            graphicImage!!.setImageSourceInfo(imageProxy.width, imageProxy.height, isImageFlipped)
                        } else {
                            graphicOverlay!!.setImageSourceInfo(imageProxy.height, imageProxy.width, isImageFlipped)
                            graphicImage!!.setImageSourceInfo(imageProxy.height, imageProxy.width, isImageFlipped)
                        }
                        needUpdateGraphicOverlayImageSourceInfo = false
                    }

                    proxyImageProcess1(imageProxy)
                }
            )

            val recorder = Recorder.Builder()
                .setQualitySelector(qualitySelector)
                .build()
            videoCapture = VideoCapture.withOutput(recorder)

            cameraProvider!!.bindToLifecycle(/* lifecycleOwner= */lifecycleOwner!!, cameraSelector!!, videoCapture, analysisUseCase)
        } catch (e: Exception) {
            Log.i("FaceDetectorProcessor", "Failed to process image. Error: " + e.localizedMessage)
            sendEkycEvent(DetectionEvent.FAILED, null)
        }
    }

    @SuppressLint("UnsafeOptInUsageError")
    private fun proxyImageProcess1(imageProxy: ImageProxy){
        val frameMetadata = FrameMetadata.Builder()
            .setWidth(imageProxy.width)
            .setHeight(imageProxy.height)
            .setRotation(imageProxy.imageInfo.rotationDegrees)
            .build()

        val nv21Buffer = BitmapUtils.yuv420ThreePlanesToNV21(
            imageProxy.image?.planes,
            imageProxy.width,
            imageProxy.height
        )

        val bitmap: Bitmap? = BitmapUtils.getBitmap(nv21Buffer, frameMetadata)
        imageProxy.close()

        imageProcessor!!.drawImageBitmap(bitmap, graphicImage)

        try {
            imageProcessor!!.processByteBuffer(nv21Buffer, frameMetadata, graphicOverlay)
            Log.i("FaceDetectorProcessor", "imageProcessor")
        } catch (e: MlKitException) {
            Log.i("FaceDetectorProcessor", "Failed to process image. Error: " + e.localizedMessage)
            Toast.makeText(context, e.localizedMessage, Toast.LENGTH_SHORT).show()
            sendEkycEvent(DetectionEvent.FAILED, null)
        }
    }

    private fun getDetectTypeFromName(type: String): DetectionType{
        return when (type) {
            DetectionType.BLINK_EYE.type -> DetectionType.BLINK_EYE
            DetectionType.SMILE.type -> DetectionType.SMILE
            DetectionType.TURN_LEFT.type -> DetectionType.TURN_LEFT
            DetectionType.TURN_RIGHT.type -> DetectionType.TURN_RIGHT
            else -> DetectionType.TURN_RIGHT
        }
    }

    private fun getListDetectType(): ArrayList<DetectionType>{
        Log.i("TAG", "ekycEvent listDetectType $listDetectType")
        val list = arrayListOf<DetectionType>()
        for (type in listDetectType) {
            val typeName = getDetectTypeFromName(type = type)
            list.add(typeName)
        }

        Log.i("TAG", "ekycEvent getListDetectType $list")
        return list
    }

    private fun startRecoding(){
        val capture = videoCapture
        if(capture == null){
            sendEkycEvent(DetectionEvent.FAILED, null)
            return
        }

        val file = createFile()
        if(file == null){
            sendEkycEvent(DetectionEvent.FAILED, null)
            return
        }

        try {
            videoPath = file.absolutePath
            val fileOutput = FileOutputOptions.Builder(file)
                .build()

            Log.i("ekycEvent", "ekycEvent start recoder $videoPath")


            currentRecording = capture.output
                .prepareRecording(activity, fileOutput)
                .start(ContextCompat.getMainExecutor(activity), captureListener)
        } catch (e: Exception) {
            sendEkycEvent(DetectionEvent.FAILED, null)
        }
    }

    private fun stopRecoding() {
        if (currentRecording == null || recordingState is VideoRecordEvent.Finalize) {
            return
        }

        Log.i("Camerx","addKYCDocument call stop")
        currentRecording?.stop()
        currentRecording = null
    }

    private fun createFile(): File? {
        var file: File? = null
        try {
            //val sdcardroot: String = context.getExternalFilesDir("video_ekyc")!!.absolutePath
            //val mFileName = "tnex_video_ekyc.mp4"

            val sdcardroot = activity.filesDir.absolutePath
            val mFileName = System.currentTimeMillis().toString() + ".mp4"
            file = File(sdcardroot, mFileName)
        } catch (e: Exception) {

        }
        return file
    }

    /**
     * CaptureEvent listener.
     */
    private val captureListener = Consumer<VideoRecordEvent> { event ->
        recordingState = event
        if(event is VideoRecordEvent.Finalize){
            Log.i("ekycEvent", "addKYCDocument VideoRecordEvent.Finalize")
            if(isWaitingSendEvent){
                Log.i("ekycEvent", "addKYCDocument isWaitingSendEvent true")
                if (!event.hasError()) {
                    Log.i("ekycEvent", "addKYCDocument DetectionEvent.SUCCESS $imagePathWaiting")
                    Log.i("ekycEvent", "addKYCDocument DetectionEvent.SUCCESS  $videoPath")
                    listener.onResults(DetectionEvent.SUCCESS, imagePathWaiting, videoPath)
                } else {
                    listener.onResults(DetectionEvent.FAILED, null, null)
                    currentRecording?.close()
                    currentRecording = null
                    Log.e("BienNT", "addKYCDocument Video capture ends with error: " +
                            "${event.error}")
                }

                isWaitingSendEvent = false
                imagePathWaiting.clear()
            }
        }
    }

    override fun onResults(event: DetectionEvent, imagesPath: HashMap<String, String>?) {
        Log.i("TAG", "ekycEvent CameraConstraintLayout onResults event = " + event.eventName)
        sendEkycEvent(event, imagesPath)
    }

    override fun onStartDetectionType(type: String) {
        listener.onStartDetectionType(type)
    }

    override fun onStartRecording() {
        Log.i("FaceDetectorProcessor", "call startRecoding")
        startRecoding()
    }


    private fun sendEkycEvent(event: DetectionEvent, imagesPath: HashMap<String, String>?){
        if(event == DetectionEvent.SUCCESS){
            isWaitingSendEvent = true
            Log.i("ekycEvent", "addKYCDocument sendEkycEvent isWaitingSendEvent $imagesPath")
            if(imagesPath != null){
                imagePathWaiting.putAll(imagesPath)
            }
            Log.i("ekycEvent", "addKYCDocument sendEkycEvent isWaitingSendEvent1 $imagePathWaiting")

            onStopEkyc()
        }else{
            onStopEkyc()
            listener.onResults(event, imagesPath, videoPath)
        }
    }


    fun onStartEkyc() {
        bindAllCameraUseCases()
    }

    fun onStopEkyc() {
        stopRecoding()

        analysisUseCase?.clearAnalyzer()

        if(imageProcessor != null){
            imageProcessor?.run { this.stop() }
        }

        if (cameraProvider != null) {
            cameraProvider!!.unbindAll()
        }
    }
}