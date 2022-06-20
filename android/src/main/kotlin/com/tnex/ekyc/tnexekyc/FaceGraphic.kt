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

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PointF
import android.util.Log
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceContour
import com.google.mlkit.vision.face.FaceLandmark.LandmarkType

/**
 * Graphic instance for rendering face position, contour, and landmarks within the associated
 * graphic overlay view.
 */
class FaceGraphic constructor(overlay: GraphicOverlay?, private val face: Face) : GraphicOverlay.Graphic(overlay) {
  private val facePositionPaint: Paint
  private val numColors = COLORS.size
  private val idPaints = Array(numColors) { Paint() }
  private val boxPaints = Array(numColors) { Paint() }
  private val labelPaints = Array(numColors) { Paint() }

  init {
    val selectedColor = Color.WHITE
    facePositionPaint = Paint()
    facePositionPaint.color = selectedColor
    for (i in 0 until numColors) {
      idPaints[i] = Paint()
      idPaints[i].color = COLORS[i][0]
      idPaints[i].textSize = ID_TEXT_SIZE
      boxPaints[i] = Paint()
      boxPaints[i].color = COLORS[i][1]
      boxPaints[i].style = Paint.Style.STROKE
      boxPaints[i].strokeWidth = BOX_STROKE_WIDTH
      labelPaints[i] = Paint()
      labelPaints[i].color = COLORS[i][1]
      labelPaints[i].style = Paint.Style.FILL
    }
  }

  /** Draws the face annotations for position on the supplied canvas. */
  override fun draw(canvas: Canvas) {
    // Draws a circle at the position of the detected face, with the face's track id below.

    // Draws a circle at the position of the detected face, with the face's track id below.
    val x = translateX(face.boundingBox.centerX().toFloat())
    val y = translateY(face.boundingBox.centerY().toFloat())

    // Calculate positions.
    val left = x - scale(face.boundingBox.width() / 2.0f)
    val top = y - scale(face.boundingBox.height() / 2.0f)
    val right = x + scale(face.boundingBox.width() / 2.0f)
    val bottom = y + scale(face.boundingBox.height() / 2.0f)

    canvas.drawRect(left, top, right, bottom, boxPaints[0])

//    val point1 = getMinPointF(face.getContour(FaceContour.FACE))
//    if(point1 != null){
//      canvas.drawCircle(
//        translateX(point1.x),
//        translateY(point1.y),
//        FACE_POSITION_RADIUS,
//        facePositionPaint
//      )
//    }
//
//    val point2 = getMinPointF(face.getContour(FaceContour.RIGHT_EYEBROW_TOP))
//    if(point2 != null){
//      canvas.drawCircle(
//        translateX(point2.x),
//        translateY(point2.y),
//        FACE_POSITION_RADIUS,
//        facePositionPaint
//      )
//    }
//
//    val point3 = getMinPointF(face.getContour(FaceContour.LEFT_EYEBROW_TOP))
//    if(point3 != null){
//      canvas.drawCircle(
//        translateX(point3.x),
//        translateY(point3.y),
//        FACE_POSITION_RADIUS,
//        facePositionPaint
//      )
//    }
//
//    // Draw facial landmarks
//    drawFaceLandmark(canvas, FaceLandmark.LEFT_EYE)
//    drawFaceLandmark(canvas, FaceLandmark.RIGHT_EYE)
//    drawFaceLandmark(canvas, FaceLandmark.MOUTH_BOTTOM)
//    drawFaceLandmark(canvas, FaceLandmark.MOUTH_RIGHT)
//    drawFaceLandmark(canvas, FaceLandmark.MOUTH_LEFT)
//    drawFaceLandmark(canvas, FaceLandmark.NOSE_BASE)
//    drawFaceLandmark(canvas, FaceLandmark.RIGHT_EAR)
//    drawFaceLandmark(canvas, FaceLandmark.LEFT_EAR)
//    drawFaceLandmark(canvas, FaceLandmark.LEFT_CHEEK)
//    drawFaceLandmark(canvas, FaceLandmark.RIGHT_CHEEK)
  }

  private fun getMinPointF(contour: FaceContour?): PointF?{
    var min : PointF? = null ;


    if(contour == null){
      return min
    }
    for (point in contour.points) {
      if(min == null || point.y < min.y){
        min = point
      }
    }

    return min
  }

  private fun drawFaceLandmark(canvas: Canvas, @LandmarkType landmarkType: Int) {
    val faceLandmark = face.getLandmark(landmarkType)
    Log.i("FaceGraphicDrawFace", "$landmarkType = $faceLandmark")
    Log.i("FaceGraphicDrawFace", "face.headEulerAngleY = ${face.headEulerAngleY}")

    if (faceLandmark != null) {
      canvas.drawCircle(
        translateX(faceLandmark.position.x),
        translateY(faceLandmark.position.y),
        FACE_POSITION_RADIUS,
        facePositionPaint
      )
    }
  }

  companion object {
    private const val FACE_POSITION_RADIUS = 8.0f
    private const val ID_TEXT_SIZE = 30.0f
    private const val ID_Y_OFFSET = 40.0f
    private const val BOX_STROKE_WIDTH = 5.0f
    private const val NUM_COLORS = 10
    private val COLORS =
      arrayOf(
        intArrayOf(Color.BLACK, Color.WHITE),
        intArrayOf(Color.WHITE, Color.MAGENTA),
        intArrayOf(Color.BLACK, Color.LTGRAY),
        intArrayOf(Color.WHITE, Color.RED),
        intArrayOf(Color.WHITE, Color.BLUE),
        intArrayOf(Color.WHITE, Color.DKGRAY),
        intArrayOf(Color.BLACK, Color.CYAN),
        intArrayOf(Color.BLACK, Color.YELLOW),
        intArrayOf(Color.WHITE, Color.BLACK),
        intArrayOf(Color.BLACK, Color.GREEN)
      )
  }
}
