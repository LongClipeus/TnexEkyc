/*
 * Copyright 2020 Google LLC. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.tnex.ekyc.tnexekyc

import android.content.Context
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.gms.tasks.Task
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.*
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.OutputStream
import java.util.*
import kotlin.collections.ArrayList
import kotlin.collections.HashMap
import kotlin.math.abs


enum class DetectionEvent(val eventName: String) {
  FAILED("FAILED"),
  NO_FACE("NO_FACE"),
  LOST_FACE("LOST_FACE"),
  DETECTION_EMPTY("DETECTION_EMPTY"),
  MULTIPLE_FACE("MULTIPLE_FACE"),
  SUCCESS("SUCCESS"),
  FAKE_FACE("FAKE_FACE"),
}

enum class DetectionType(val type: String) {
  SMILE("smile"),
  BLINK_EYE("blink_eye"),
  TURN_LEFT("turn_left"),
  TURN_RIGHT("turn_right"),
}


enum class DataType(val type: String) {
  SMILE("smile"),
  EYE_LEFT("eye_left"),
  EYE_RIGHT("eye_right"),
  TURN_LEFT("turn_left"),
  TURN_RIGHT("turn_right"),
  MOUTH_X("MOUTH_X"),
  MOUTH_Y("MOUTH_Y"),
  LANDMARK_FACE_Y("LANDMARK_FACE_Y"),
  LANDMARK_EYEBROW_LEFT_Y("LANDMARK_EYEBROW_LEFT_Y"),
  LANDMARK_EYEBROW_RIGHT_Y("LANDMARK_EYEBROW_RIGHT_Y")
}

interface DetectionListener {
  val listener: EkycListener

  fun onResults(event: DetectionEvent, imagesPath: HashMap<String, String>?)
  fun onStartDetectionType(type: String)
  fun onStartRecording()
}


/** Face Detector Demo.  */
class FaceDetectorProcessor(context: Context, detectorOptions: FaceDetectorOptions?, override val listDetectionType: ArrayList<DetectionType>,
                            override val listener: DetectionListener, viewHeight: Int, viewWidth: Int
) :
  VisionProcessorBase<List<Face>>(context) {

  private var mContext: Context = context
  private var currIndexDetectionType: Int = 0
  private var currViewHeight: Int = 0
  private var currViewWidth: Int = 0
  private var currDetectionType: DetectionType = DetectionType.SMILE
  private val detector: FaceDetector
  private val timeoutDetectionTime: Long = 30000
  private var isStart: Boolean = false
  private var isPauseDetect: Boolean = true
  private var listSmiling = arrayListOf<Float>()
  private val mHandler: Handler = Handler(Looper.getMainLooper())
  private var imageData = hashMapOf<String, String>()

  private var listDataDetect =  hashMapOf<String, ArrayList<Float>>()

  private var runnableTimeout: Runnable = Runnable {
    Log.i(TAG, "ekycEvent runnableTimeout")
    if(isStart){
      listener.onResults(DetectionEvent.LOST_FACE, null)
    }else{
      listener.onResults(DetectionEvent.NO_FACE, null)
    }

    clearDetectData()
  }

  init {
    currViewWidth = viewWidth
    currViewHeight = viewHeight
    isStart = false
    imageData.clear()
    val options = detectorOptions
      ?: FaceDetectorOptions.Builder()
        .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL)
        .enableTracking()
        .build()

    detector = FaceDetection.getClient(options)
    if(listDetectionType.isNullOrEmpty()){
      listener.onResults(DetectionEvent.DETECTION_EMPTY, null)
    }else{
      isPauseDetect = true
      currIndexDetectionType = 0
      listDataDetect.clear()
      currDetectionType = listDetectionType[currIndexDetectionType]
      listener.onStartDetectionType(currDetectionType.type)
      mHandler.postDelayed(runnableTimeout, timeoutDetectionTime)
      delayDetect()
    }

    Log.v(MANUAL_TESTING_LOG, "Face detector options: $options")
  }

  override fun stop() {
    super.stop()
    detector.close()
    mHandler.removeCallbacks(runnableTimeout)
  }

  override fun detectInImage(image: InputImage): Task<List<Face>> {
    return detector.process(image)
  }

  override fun onSuccess(results: List<Face>, graphicOverlay: GraphicOverlay, originalCameraImage: Bitmap?) {
    Log.i(TAG, "onSuccess")
    if(isPauseDetect){
      return
    }

    Log.i(TAG, "onSuccess $isPauseDetect")

    val faceDetect = arrayListOf<Face>()
    for (face in results) {
      if(face.trackingId != null){
        val x = translateX(face.boundingBox.centerX().toFloat(), graphicOverlay)
        val y = translateY(face.boundingBox.centerY().toFloat(), graphicOverlay)

        // Calculate positions.
        val left = x - scale(face.boundingBox.width() / 2.0f, graphicOverlay)
        val top = y - scale(face.boundingBox.height() / 2.0f, graphicOverlay)
        val right = x + scale(face.boundingBox.width() / 2.0f, graphicOverlay)
        val bottom = y + scale(face.boundingBox.height() / 2.0f, graphicOverlay)

        if(left >= 0 && top >= 0 && right <= currViewWidth && bottom <= currViewHeight){
          faceDetect.add(face)
        }
      }
    }

    Log.i(TAG, "onSuccess ${faceDetect.size}")
    if(faceDetect.isNullOrEmpty()){
      Log.i(TAG, "ekyc Event no face")
    }else{
      if(!isStart){
        listener.onStartRecording()
        isStart = true
      }

      if (faceDetect.size > 1){
        onMultipleFace(faceDetect, graphicOverlay)
      }else{
        val face = faceDetect[0]
        onFace(face, graphicOverlay, originalCameraImage)
      }
    }
  }

  private fun clearDetectData(){
    mHandler.removeCallbacks(runnableTimeout)
    isPauseDetect = true
    imageData.clear()
    isStart = false
    listDataDetect.clear()
  }

  private fun onFace(face:Face, graphicOverlay: GraphicOverlay, originalCameraImage: Bitmap?){
    val headEulerAngleY  = face.headEulerAngleY
    if(headEulerAngleY < 16 && headEulerAngleY > -16){
      face.smilingProbability?.let { listSmiling.add(it) }
    }

    graphicOverlay.add(FaceGraphic(graphicOverlay, face))

    listDataDetect = addDataDetectionType(face, listDataDetect, currDetectionType)

    Log.i(TAG, "onSuccess listDataDetect = $listDataDetect")
    val isDetectionType = validateDetectionType()
    Log.i(TAG, "onSuccess isDetectionType = $isDetectionType")
    if(isDetectionType){
      val saveImagePath = bitmapToFile(originalCameraImage, context = mContext, fileName =  currDetectionType.type+"_"+System.currentTimeMillis().toString()+".jpg")
      if(saveImagePath != null){
        val key = currDetectionType.type
        imageData[key] = saveImagePath
      }

      if(currIndexDetectionType < listDetectionType.size - 1){
        isPauseDetect = true
        listDataDetect.clear()
        currIndexDetectionType += 1
        currDetectionType=listDetectionType[currIndexDetectionType]
        listener.onStartDetectionType(currDetectionType.type)
        mHandler.removeCallbacks(runnableTimeout)
        mHandler.postDelayed(runnableTimeout, timeoutDetectionTime)
        delayDetect()
      }else{
        listDataDetect.clear()
        mHandler.removeCallbacks(runnableTimeout)
        isPauseDetect = true

        val smiling = getAmplitude(listSmiling)
        Log.i("SUCCESS", "CHECK_FACE check listSmiling = $listSmiling")
        if(smiling <= 0.2f){
          listener.onResults(DetectionEvent.LOST_FACE, null)
        }else{
          listener.onResults(DetectionEvent.SUCCESS, imageData)
        }
        clearDetectData()
      }
    }
  }

  private fun onMultipleFace(faces: List<Face>, graphicOverlay: GraphicOverlay){
    listener.onResults(DetectionEvent.MULTIPLE_FACE, null)
    clearDetectData()
    Log.i(TAG, "ekycEvent multiple face")
    for (face in faces) {
      Log.i("ekycEventMultipleFace", "trackingId = " + face.trackingId)
      if(face.trackingId != null){
        graphicOverlay.add(FaceGraphic(graphicOverlay, face))
      }
    }
  }

  private fun validateDetectionType(): Boolean{
    return when (currDetectionType) {
      DetectionType.BLINK_EYE -> validateBlinkingEyesDetection()
      DetectionType.SMILE -> validateSmileDetection()
      else -> checkDetectionType(listDataDetect, currDetectionType)
    }
  }

  private fun validateSmileDetection(): Boolean{
    val isDetectionType = checkDetectionType(listDataDetect, currDetectionType)
    if(isDetectionType){
      val isChangeMount = validateChangeMouth(listDataDetect[DataType.MOUTH_X.type], listDataDetect[DataType.MOUTH_Y.type])
      if(isChangeMount){
        return true
      }else{
        listDataDetect.clear()
      }
    }

    return false
  }

  private fun validateBlinkingEyesDetection(): Boolean{
    val isDetectionType = checkDetectionType(listDataDetect, currDetectionType)
    Log.i(TAG, "onSuccess validateBlinkingEyesDetection isDetectionType = $isDetectionType")
    if(isDetectionType){
      val isChangeEye = validateEyes(listDataDetect[DataType.LANDMARK_FACE_Y.type], listDataDetect[DataType.LANDMARK_EYEBROW_LEFT_Y.type], listDataDetect[DataType.LANDMARK_EYEBROW_RIGHT_Y.type])
      Log.i(TAG, "onSuccess validateBlinkingEyesDetection isChangeEye = $isChangeEye")
      if(isChangeEye){
        return true
      }else{
        listDataDetect.clear()
      }
    }

    return false
  }

  private fun delayDetect(){
    Timer().schedule(object : TimerTask() {
      override fun run() {
        isPauseDetect = false
      }
    }, 100)
  }

  override fun onFailure(e: Exception) {
    listener.onResults(DetectionEvent.FAILED, null)
    clearDetectData()
    Log.i(TAG, "Face detection failed $e")
  }

  companion object {
    private const val TAG = "FaceDetectorProcessor"

    private fun scale(imagePixel: Float, overlay: GraphicOverlay): Float {
      return imagePixel * overlay.scaleFactor
    }

    private fun translateY(y: Float, overlay: GraphicOverlay): Float {
      return scale(y, overlay) - overlay.postScaleHeightOffset
    }

    private fun translateX(x: Float, overlay: GraphicOverlay): Float {
      return if (overlay.isImageFlipped) {
        overlay.getWidth() - (scale(x, overlay) - overlay.postScaleWidthOffset)
      } else {
        scale(x, overlay) - overlay.postScaleWidthOffset
      }
    }

    private fun checkDetectionType(currData: HashMap<String, ArrayList<Float>>, detectionType: DetectionType): Boolean{
      return when (detectionType) {
        DetectionType.BLINK_EYE -> checkBlinkingEyes(currData[DataType.EYE_LEFT.type], currData[DataType.EYE_RIGHT.type])
        DetectionType.SMILE -> checkSmiling(currData[DataType.SMILE.type])
        DetectionType.TURN_RIGHT -> checkFaceTurnLeft(currData[DataType.TURN_LEFT.type])
        DetectionType.TURN_LEFT -> checkFaceTurnRight(currData[DataType.TURN_RIGHT.type])
      }
    }

    private fun addDataDetectionType(face: Face, currData: HashMap<String, ArrayList<Float>>, detectionType: DetectionType):HashMap<String, ArrayList<Float>>{
      return when (detectionType) {
          DetectionType.BLINK_EYE -> addBlinkingEyes(face, currData[DataType.EYE_LEFT.type], currData[DataType.EYE_RIGHT.type], currData[DataType.LANDMARK_FACE_Y.type], currData[DataType.LANDMARK_EYEBROW_LEFT_Y.type], currData[DataType.LANDMARK_EYEBROW_RIGHT_Y.type])
          DetectionType.SMILE -> addDataSmiling(face, currData[DataType.SMILE.type], currData[DataType.MOUTH_X.type], currData[DataType.MOUTH_Y.type])
          DetectionType.TURN_RIGHT -> addFaceTurnLeft(face, currData[DataType.TURN_LEFT.type])
          DetectionType.TURN_LEFT -> addFaceTurnRight(face, currData[DataType.TURN_RIGHT.type])
      }
    }

    private fun addBlinkingEyes(face: Face, listDataLeft: ArrayList<Float>?, listDataRight: ArrayList<Float>?, landmarkFaceY: ArrayList<Float>?, landmarkEyeLeftY: ArrayList<Float>?, landmarkEyeRightY: ArrayList<Float>?): HashMap<String, ArrayList<Float>>{
      val left = face.leftEyeOpenProbability
      val right = face.rightEyeOpenProbability
      //val isFaceStraight = checkFaceStraight(face)
      val newListDataLeft = arrayListOf<Float>()
      if(!listDataLeft.isNullOrEmpty()){
        newListDataLeft.addAll(listDataLeft)
      }

      val newListDataRight = arrayListOf<Float>()
      if(!listDataRight.isNullOrEmpty()){
        newListDataRight.addAll(listDataRight)
      }

      val newListLandmarkFaceY = arrayListOf<Float>()
      if(!landmarkFaceY.isNullOrEmpty()){
        newListLandmarkFaceY.addAll(landmarkFaceY)
      }

      val newListLandmarkLeftY = arrayListOf<Float>()
      if(!landmarkEyeLeftY.isNullOrEmpty()){
        newListLandmarkLeftY.addAll(landmarkEyeLeftY)
      }

      val newListLandmarkRightY = arrayListOf<Float>()
      if(!landmarkEyeRightY.isNullOrEmpty()){
        newListLandmarkRightY.addAll(landmarkEyeRightY)
      }

      Log.i(TAG, "onSuccess addBlinkingEyes newListDataLeft = $newListDataLeft")
      Log.i(TAG, "onSuccess addBlinkingEyes newListDataRight = $newListDataRight")


//      val decLeft = decCheck(newListDataLeft)
//      val decRight = decCheck(newListDataRight)
//
//      Log.i(TAG, "onSuccess addBlinkingEyes decLeft = $decLeft decRight = $decRight isFaceStraight = $isFaceStraight")
//
//      if(!decLeft || !decRight){
//        newListDataLeft.clear()
//        newListLandmarkLeftY.clear()
//        newListLandmarkFaceY.clear()
//        newListDataRight.clear()
//        newListLandmarkRightY.clear()
//      }


//      if(isFaceStraight){
        if(left != null && right != null){
//          if((newListDataLeft.size > 0 && left > newListDataLeft[newListDataLeft.size -1]) || (newListDataRight.size > 0 && right > newListDataRight[newListDataRight.size -1]) ){
//            newListDataLeft.clear()
//            newListLandmarkLeftY.clear()
//            newListLandmarkFaceY.clear()
//            newListDataRight.clear()
//            newListLandmarkRightY.clear()
//          }

          val faceLeft = face.getContour(FaceContour.LEFT_EYEBROW_TOP)
          val minYEyeLeft = getMinPointF(faceLeft)
          val faceRight = face.getContour(FaceContour.RIGHT_EYEBROW_TOP)
          val minYEyeRight = getMinPointF(faceRight)

          val faceTop = face.getContour(FaceContour.FACE)
          val minYFace = getMinPointF(faceTop)

          val faceNose = face.getLandmark(FaceLandmark.NOSE_BASE)

          newListDataLeft.add(left)

          if(faceNose != null && minYEyeLeft != null){
            val lY = abs(minYEyeLeft - faceNose.position.y)

            newListLandmarkLeftY.add(lY)
          }

          newListDataRight.add(right)

          if(faceNose != null && minYEyeRight != null){
            val lY = abs(minYEyeRight - faceNose.position.y)

            newListLandmarkRightY.add(lY)
          }

          if(faceNose != null && minYFace != null){
            val lY = abs(minYFace - faceNose.position.y)

            newListLandmarkFaceY.add(lY)
          }
        }

//      }

      val newData =  hashMapOf<String, ArrayList<Float>>()
      newData[DataType.EYE_LEFT.type] = newListDataLeft
      newData[DataType.EYE_RIGHT.type] = newListDataRight
      newData[DataType.LANDMARK_EYEBROW_LEFT_Y.type] = newListLandmarkLeftY
      newData[DataType.LANDMARK_EYEBROW_RIGHT_Y.type] = newListLandmarkRightY
      newData[DataType.LANDMARK_FACE_Y.type] = newListLandmarkFaceY
      Log.i(TAG, "onSuccess addBlinkingEyes newData = $newData")

      return newData
    }

    private fun validateEyes(landmarkFaceY: ArrayList<Float>?, landmarkEyeLeftY: ArrayList<Float>?, landmarkEyeRightY: ArrayList<Float>?): Boolean{
      return true

//      if(landmarkFaceY.isNullOrEmpty() || landmarkEyeLeftY.isNullOrEmpty() || landmarkEyeRightY.isNullOrEmpty()){
//        return false
//      }
//
//      val fy = getAmplitude(landmarkFaceY)
//      val ly = getAmplitude(landmarkEyeLeftY)
//      val ry = getAmplitude(landmarkEyeRightY)
//
//
//      Log.i(TAG, "onSuccess FaceGraphicDrawFacecheckSmiling fy = $fy")
//      Log.i(TAG, "onSuccess FaceGraphicDrawFacecheckSmiling ly = $ly")
//      Log.i(TAG, "onSuccess FaceGraphicDrawFacecheckSmiling ry = $ry")
//
//      if(fy < 8 && ly < 6  && ry < 6){
//        Log.i(TAG, "onSuccess FaceGraphicDrawFacecheckSmiling")
//        return true
//      }
//
//      return false
    }

    private fun checkBlinkingEyes(listDataLeft: ArrayList<Float>?, listDataRight: ArrayList<Float>?): Boolean{
      Log.i(TAG, "onSuccess checkBlinkingEyes listDataLeft = $listDataLeft listDataRight = $listDataRight ")


      if(listDataLeft.isNullOrEmpty() || listDataLeft.size < 4 || listDataRight.isNullOrEmpty() || listDataRight.size < 4){
        return false
      }

//      val decLeft = decCheck(listDataLeft)
//      val decRight = decCheck(listDataRight)

//      if(decLeft && decRight){
        val newLeft = sortDEC(listDataLeft)
        val newRight = sortDEC(listDataRight)
        Log.i(TAG, "onSuccess FaceGraphicDrawFacecheckSmiling newRight = $newRight")
        Log.i(TAG, "onSuccess FaceGraphicDrawFacecheckSmiling newLeft = $newLeft")

        if(newLeft[0] > 0.6f && newLeft[newLeft.size - 1 ] < 0.2f && newRight[0] > 0.6f && newRight[newRight.size - 1] < 0.2f){
          return true
        }
//      }


      return false
    }

    private fun addDataSmiling(face: Face, listData: ArrayList<Float>?, listMouthBottomLeftX: ArrayList<Float>?, listMouthBottomLeftY: ArrayList<Float>?): HashMap<String, ArrayList<Float>>{
      val newListData = arrayListOf<Float>()
      if(!listData.isNullOrEmpty()){
        newListData.addAll(listData)
      }

      val newMouthBottomLeftX = arrayListOf<Float>()
      if(!listMouthBottomLeftX.isNullOrEmpty()){
        newMouthBottomLeftX.addAll(listMouthBottomLeftX)
      }

      val newMouthBottomLeftY = arrayListOf<Float>()
      if(!listMouthBottomLeftY.isNullOrEmpty()){
        newMouthBottomLeftY.addAll(listMouthBottomLeftY)
      }

      Log.i(TAG, "onSuccess addDataSmiling newMouthBottomLeftX = $newMouthBottomLeftX")
      Log.i(TAG, "onSuccess addDataSmiling listMouthBottomLeftY = $listMouthBottomLeftY")
      Log.i(TAG, "onSuccess addDataSmiling newListData = $newListData")

      val smilingProbability = face.smilingProbability
//      val isFaceStraight = checkFaceStraight(face)
//      val isASC = ascCheck(newListData)
//
//      Log.i(TAG, "onSuccess addDataSmiling smilingProbability = $smilingProbability isFaceStraight = $isFaceStraight isASC = $isASC")
//
//      if(!isASC){
//        newListData.clear()
//        newMouthBottomLeftX.clear()
//        newMouthBottomLeftY.clear()
//      }
//
//      if(isFaceStraight){
        if(smilingProbability != null){
//          if(newListData.size > 0 && smilingProbability < newListData[newListData.size - 1]){
//            newListData.clear()
//            newMouthBottomLeftX.clear()
//            newMouthBottomLeftY.clear()
//          }

          newListData.add(smilingProbability)
          val faceLandmark = face.getLandmark(FaceLandmark.MOUTH_BOTTOM)
          val faceLeft = face.getLandmark(FaceLandmark.MOUTH_LEFT)
          val faceRight = face.getLandmark(FaceLandmark.MOUTH_RIGHT)

          if(faceLandmark != null && faceLeft != null && faceRight != null){
            val lX = abs(faceLeft.position.x - faceLandmark.position.x)
            val lY = abs(faceLeft.position.y - faceLandmark.position.y)
            val rX = abs(faceRight.position.x - faceLandmark.position.x)
            val rY = abs(faceRight.position.y - faceLandmark.position.y)

            val x = abs(lX - rX)
            val y = abs(lY - rY)
            newMouthBottomLeftX.add(x)
            newMouthBottomLeftY.add(y)
          }
        }
//      }

      val newData =  hashMapOf<String, ArrayList<Float>>()
      newData[DataType.SMILE.type] = newListData
      newData[DataType.MOUTH_X.type] = newMouthBottomLeftX
      newData[DataType.MOUTH_Y.type] = newMouthBottomLeftY

      Log.i(TAG, "onSuccess newData = $newData")

      return newData
    }

    private fun validateChangeMouth(listMouthBottomLeftX: ArrayList<Float>?, listMouthBottomLeftY: ArrayList<Float>?): Boolean{
      return true
    //      if(listMouthBottomLeftX.isNullOrEmpty() || listMouthBottomLeftY.isNullOrEmpty()){
//        return false
//      }
//
//      val lx = getAmplitude(listMouthBottomLeftX)
//      val ly = getAmplitude(listMouthBottomLeftY)
//      if(lx < 5 && ly < 5 && ly > 1.5){
//        return true
//      }
//
//      return false
    }

    private fun checkSmiling(listData: ArrayList<Float>?): Boolean{
      if(listData.isNullOrEmpty() || listData.size < 4){
        return false
      }

//      val isASC = ascCheck(listData)
//      if(isASC){
        val newList = sortASC(listData)
        if(newList[0] <= 0.4f && newList[newList.size - 1] >= 0.8f){
          return true
        }
//      }

      return false
    }

    private fun addFaceTurnRight(face: Face, listData: ArrayList<Float>?): HashMap<String, ArrayList<Float>>{
      val y = face.headEulerAngleY
      val newListData = arrayListOf<Float>()
      if(!listData.isNullOrEmpty()){
        newListData.addAll(listData)
      }

//      val isASC = ascCheck(newListData)
//      if(!isASC){
//        newListData.clear()
//      }else if(newListData.size > 0 && y < newListData[newListData.size -1]){
//        newListData.clear()
//      }

      newListData.add(y)

      val newData =  hashMapOf<String, ArrayList<Float>>()
      newData[DataType.TURN_RIGHT.type] = newListData

      return newData
    }

    private fun checkFaceTurnRight(listData: ArrayList<Float>?): Boolean{
      if(listData.isNullOrEmpty() || listData.size < 4){
        return false
      }

//      val isASC = ascCheck(listData)
//      if(isASC){
        val newData = sortASC(listData)
        if(newData[0] <= 10 &&  newData[newData.size - 1] > 40){
          return true
        }
//      }
      return false
    }

    private fun addFaceTurnLeft(face: Face, listData: ArrayList<Float>?): HashMap<String, ArrayList<Float>>{
      val y = face.headEulerAngleY
      val newListData = arrayListOf<Float>()
      if(!listData.isNullOrEmpty()){
        newListData.addAll(listData)
      }

//      val isDEC = decCheck(newListData)
//      if(!isDEC){
//        newListData.clear()
//      }else if(newListData.size > 0 && y > newListData[newListData.size -1]){
//        newListData.clear()
//      }

      newListData.add(y)

      val newData =  hashMapOf<String, ArrayList<Float>>()
      newData[DataType.TURN_LEFT.type] = newListData

      return newData
    }

    private fun checkFaceTurnLeft(listData: ArrayList<Float>?): Boolean{
      if(listData.isNullOrEmpty() || listData.size < 4){
        return false
      }
//      val isDEC = decCheck(listData)
//      if(isDEC){
        val newData = sortDEC(listData)
        if(newData[0] >= -10  && newData[newData.size - 1] < -40){
          return true
        }
//      }

      return false
    }

    private fun checkFaceStraight(face: Face): Boolean {
      var isFaceStraight = false
      val y = face.headEulerAngleY
      if (y <= 15 && y >= -15) {
        isFaceStraight = true
      }
      return isFaceStraight
    }

    private fun sortASC(listData: ArrayList<Float>): ArrayList<Float>{
      var tg: Float
      for (i in 0 until listData.size - 1) {
        for (j in i + 1 until listData.size) {
          if(listData[i] > listData[j]){
            tg = listData[i]
            listData[i] = listData[j]
            listData[j] = tg
          }
        }
      }

      return listData
    }

    private fun sortDEC(listData: ArrayList<Float>): ArrayList<Float>{
      var tg: Float
      for (i in 0 until listData.size - 1) {
        for (j in i + 1 until listData.size) {
          if(listData[i] < listData[j]){
            tg = listData[i]
            listData[i] = listData[j]
            listData[j] = tg
          }
        }
      }

      return listData
    }

    private fun ascCheck(listData: ArrayList<Float>): Boolean{
      for (i in 0 until listData.size - 1) {
        if (listData[i] > listData[i+1]) {
          return false
        }
      }
      return true
    }

    private fun decCheck(listData: ArrayList<Float>): Boolean{
      for (i in 0 until listData.size - 1) {
        if (listData[i] < listData[i+1]) {
          return false
        }
      }
      return true
    }


    private fun createImageFile(context: Context, fileName: String): File? {
      var file: File? = null
      try {
        val sdcardroot = context.filesDir.absolutePath
        file = File(sdcardroot, fileName)
      } catch (e: Exception) {

      }
      return file
    }

    private fun bitmapToFile(bitmap:Bitmap?, context: Context, fileName: String): String? {
      val file = createImageFile(context, fileName) ?: return null
      val currBitmap = bitmap ?: return null

      try{
        val stream: OutputStream = FileOutputStream(file)
        currBitmap.compress(Bitmap.CompressFormat.JPEG,100,stream)
        stream.flush()
        stream.close()
      }catch (e: IOException){
        e.printStackTrace()
      }

      return file.absolutePath
    }

    private fun getMinPointF(contour: FaceContour?): Float?{
      var min : Float? = null ;


      if(contour == null){
        return min
      }
      for (point in contour.points) {
        if(min == null || point.y < min){
          min = point.y
        }
      }

      return min
    }

    private fun getAmplitude(listCheck: ArrayList<Float>):Float{
      var min : Float? = null
      var max : Float? = null
      for (i in 0 until listCheck.size) {
        val d = listCheck[i]
        if(min == null || d < min){
          min = d
        }

        if(max == null || d > max){
          max = d
        }
      }

      Log.i(TAG, "FaceGraphicDrawFacecheckSmiling max = $max min = $min")

      return if (max != null && min != null) {
        max - min
      }else{
        0f
      }
    }
  }
}
