//
//  UIConstants.swift
//  tnexekyc
//
//  Created by Tnex on 05/05/2022.
//

import AVFoundation
import CoreVideo
import CoreML
import UIKit
import MLKitVision

/// Defines UI-related utilitiy methods for vision detection.
public class UIConstants {
    
    // MARK: - Public
    
    public static func addCircle(
        atPoint point: CGPoint,
        to view: UIView,
        color: UIColor,
        radius: CGFloat
    ) {
        let divisor: CGFloat = 2.0
        let xCoord = point.x - radius / divisor
        let yCoord = point.y - radius / divisor
        let circleRect = CGRect(x: xCoord, y: yCoord, width: radius, height: radius)
        guard circleRect.isValid() else { return }
        let circleView = UIView(frame: circleRect)
        circleView.layer.cornerRadius = radius / divisor
        circleView.alpha = Constants.circleViewAlpha
        circleView.backgroundColor = color
        view.addSubview(circleView)
    }
    
    public static func addRectangle(_ rectangle: CGRect, to view: UIView, color: UIColor) {
        guard rectangle.isValid() else { return }
        let rectangleView = UIView(frame: rectangle)
        rectangleView.layer.cornerRadius = Constants.rectangleViewCornerRadius
        rectangleView.alpha = Constants.rectangleViewAlpha
        rectangleView.backgroundColor = UIColor.clear
        rectangleView.layer.borderWidth = 3
        rectangleView.layer.borderColor = color.cgColor
        view.addSubview(rectangleView)
    }
    
    public static func addShape(withPoints points: [NSValue]?, to view: UIView, color: UIColor) {
        guard let points = points else { return }
        let path = UIBezierPath()
        for (index, value) in points.enumerated() {
            let point = value.cgPointValue
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
            if index == points.count - 1 {
                path.close()
            }
        }
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = color.cgColor
        let rect = CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height)
        let shapeView = UIView(frame: rect)
        shapeView.alpha = Constants.shapeViewAlpha
        shapeView.layer.addSublayer(shapeLayer)
        view.addSubview(shapeView)
    }
    
    public static func imageOrientation(
        fromDevicePosition devicePosition: AVCaptureDevice.Position = .back
    ) -> UIImage.Orientation {
        var deviceOrientation = UIDevice.current.orientation
        if deviceOrientation == .faceDown || deviceOrientation == .faceUp
            || deviceOrientation
            == .unknown
        {
            deviceOrientation = currentUIOrientation()
        }
        switch deviceOrientation {
        case .portrait:
            return devicePosition == .front ? .leftMirrored : .right
        case .landscapeLeft:
            return devicePosition == .front ? .downMirrored : .up
        case .portraitUpsideDown:
            return devicePosition == .front ? .rightMirrored : .left
        case .landscapeRight:
            return devicePosition == .front ? .upMirrored : .down
        case .faceDown, .faceUp, .unknown:
            return .up
        @unknown default:
            fatalError()
        }
    }
    
    
    /// Converts an image buffer to a `UIImage`.
    ///
    /// @param imageBuffer The image buffer which should be converted.
    /// @param orientation The orientation already applied to the image.
    /// @return A new `UIImage` instance.
    public static func createUIImage(
        from imageBuffer: CVImageBuffer,
        orientation: UIImage.Orientation,
        width: CGFloat,
        height: CGFloat
    ) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext(options: nil)
        
        let w = ciImage.extent.width
        let h = ciImage.extent.height
        
        let epsilon = (w - width)/2

        
        guard let image = context.createCGImage(ciImage, from: CGRect(x: -CGFloat(epsilon), y: 0, width: w, height: h)) else { return nil }
        
        return UIImage(cgImage: image, scale: Constants.originalScale, orientation: orientation)
    }
    
    public static func createUIImage(
        from uiImage: UIImage,
        width: CGFloat,
        height: CGFloat
    ) -> UIImage? {
        //let context = CIContext(options: nil)
        //guard let ciImage = CIImage(data: imageData) else { return nil }
        
        let w = uiImage.size.width
        let h = uiImage.size.height
        
        var newW = w
        var newH = (height/width)*w
        var x = 0.0
        var y = 0.0
        
        if(newH > h){
            newH = h
            newW = (width/height)*h + 20
            x = CGFloat((newW - width) / 2) + newH - newW
        }else{
            newH += 20
            y = CGFloat((newH - height) / 2) + newW - newH
        }
        
        print("BienNTCamera height = \(height) width = \(width)")
        print("BienNTCamera x = \(x) y = \(y)")
        print("BienNTCamera newW = \(newW) newH = \(newH)")
        print("BienNTCamera w = \(w) h = \(h)")
        
        let cropRect = CGRect(
            x: y,
            y: x,
            width: newH,
            height: newW
        ).integral

        guard let sourceCGImage = uiImage.cgImage else { return nil }
        
        guard let croppedCGImage = sourceCGImage.cropping(
            to: cropRect
        ) else { return nil }
        
        print("BienNTCamera image.width = \(croppedCGImage.width) image.height = \(croppedCGImage.height)")
        
        let croppedImage = UIImage(
            cgImage: croppedCGImage,
            scale: uiImage.imageRendererFormat.scale,
            orientation: uiImage.imageOrientation
        )
        
        print("BienNTCamera scale = \(uiImage.imageRendererFormat.scale) orientation = \(uiImage.imageOrientation.rawValue)")
        
        print("BienNTCamera image.width = \(croppedImage.size.width) image.height = \(croppedImage.size.height)")
        
        return croppedImage
    }
    
    public static func createUIImage(
        from imageBuffer: CVImageBuffer,
        orientation: UIImage.Orientation
    ) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext(options: nil)
        
        guard let image = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        return UIImage(cgImage: image, scale: Constants.originalScale, orientation: orientation)
    }
    
    /// Converts a `UIImage` to an image buffer.
    ///
    /// @param image The `UIImage` which should be converted.
    /// @return The image buffer. Callers own the returned buffer and are responsible for releasing it
    ///     when it is no longer needed. Additionally, the image orientation will not be accounted for
    ///     in the returned buffer, so callers must keep track of the orientation separately.
    public static func createImageBuffer(from image: UIImage) -> CVImageBuffer? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        
        var buffer: CVPixelBuffer? = nil
        CVPixelBufferCreate(
            kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil,
            &buffer)
        guard let imageBuffer = buffer else { return nil }
        
        let flags = CVPixelBufferLockFlags(rawValue: 0)
        CVPixelBufferLockBaseAddress(imageBuffer, flags)
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let context = CGContext(
            data: baseAddress, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: bytesPerRow, space: colorSpace,
            bitmapInfo: (CGImageAlphaInfo.premultipliedFirst.rawValue
                         | CGBitmapInfo.byteOrder32Little.rawValue))
        
        if let context = context {
            let rect = CGRect.init(x: 0, y: 0, width: width, height: height)
            context.draw(cgImage, in: rect)
            CVPixelBufferUnlockBaseAddress(imageBuffer, flags)
            return imageBuffer
        } else {
            CVPixelBufferUnlockBaseAddress(imageBuffer, flags)
            return nil
        }
    }
    
    
    /// Returns a color interpolated between to other colors.
    ///
    /// - Parameters:
    ///   - fromColor: The start color of the interpolation.
    ///   - toColor: The end color of the interpolation.
    ///   - ratio: The ratio in range [0, 1] by which the colors should be interpolated. Passing 0
    ///         results in `fromColor` and passing 1 results in `toColor`, whereas passing 0.5 results
    ///         in a color that is half-way between `fromColor` and `startColor`. Values are clamped
    ///         between 0 and 1.
    /// - Returns: The interpolated color.
    private static func interpolatedColor(
        fromColor: UIColor, toColor: UIColor, ratio: CGFloat
    ) -> UIColor {
        var fromR: CGFloat = 0
        var fromG: CGFloat = 0
        var fromB: CGFloat = 0
        var fromA: CGFloat = 0
        fromColor.getRed(&fromR, green: &fromG, blue: &fromB, alpha: &fromA)
        
        var toR: CGFloat = 0
        var toG: CGFloat = 0
        var toB: CGFloat = 0
        var toA: CGFloat = 0
        toColor.getRed(&toR, green: &toG, blue: &toB, alpha: &toA)
        
        let clampedRatio = max(0.0, min(ratio, 1.0))
        
        let interpolatedR = fromR + (toR - fromR) * clampedRatio
        let interpolatedG = fromG + (toG - fromG) * clampedRatio
        let interpolatedB = fromB + (toB - fromB) * clampedRatio
        let interpolatedA = fromA + (toA - fromA) * clampedRatio
        
        return UIColor(
            red: interpolatedR, green: interpolatedG, blue: interpolatedB, alpha: interpolatedA)
    }
    
    /// Returns the distance between two 3D points.
    ///
    /// - Parameters:
    ///   - fromPoint: The starting point.
    ///   - endPoint: The end point.
    /// - Returns: The distance.
    private static func distance(fromPoint: Vision3DPoint, toPoint: Vision3DPoint) -> CGFloat {
        let xDiff = fromPoint.x - toPoint.x
        let yDiff = fromPoint.y - toPoint.y
        let zDiff = fromPoint.z - toPoint.z
        return CGFloat(sqrt(xDiff * xDiff + yDiff * yDiff + zDiff * zDiff))
    }
    
    
    private static func currentUIOrientation() -> UIDeviceOrientation {
        let deviceOrientation = { () -> UIDeviceOrientation in
            switch UIApplication.shared.statusBarOrientation {
            case .landscapeLeft:
                return .landscapeRight
            case .landscapeRight:
                return .landscapeLeft
            case .portraitUpsideDown:
                return .portraitUpsideDown
            case .portrait, .unknown:
                return .portrait
            @unknown default:
                fatalError()
            }
        }
        guard Thread.isMainThread else {
            var currentOrientation: UIDeviceOrientation = .portrait
            DispatchQueue.main.sync {
                currentOrientation = deviceOrientation()
            }
            return currentOrientation
        }
        return deviceOrientation()
    }
}

// MARK: - Constants

private enum Constants {
    static let circleViewAlpha: CGFloat = 0.7
    static let rectangleViewAlpha: CGFloat = 1.0
    static let shapeViewAlpha: CGFloat = 0.3
    static let rectangleViewCornerRadius: CGFloat = 0.0
    static let maxColorComponentValue: CGFloat = 255.0
    static let originalScale: CGFloat = 1.0
    static let bgraBytesPerPixel = 4
}

// MARK: - Extension

extension CGRect {
    /// Returns a `Bool` indicating whether the rectangle's values are valid`.
    func isValid() -> Bool {
        return
        !(origin.x.isNaN || origin.y.isNaN || width.isNaN || height.isNaN || width < 0 || height < 0)
    }
}


enum DetectionEvent: String {
    case FAILED = "FAILED"
    case NO_FACE = "NO_FACE"
    case LOST_FACE = "LOST_FACE"
    case DETECTION_EMPTY = "DETECTION_EMPTY"
    case MULTIPLE_FACE = "MULTIPLE_FACE"
    case SUCCESS = "SUCCESS"
    case FAKE_FACE = "FAKE_FACE"
}

enum DetectionType : String {
    case SMILE = "smile"
    case BLINK_EYE = "blink_eye"
    case TURN_LEFT = "turn_left"
    case TURN_RIGHT = "turn_right"
    
    func getMediaType() -> MediaType {
        switch self {
        case .SMILE:
            return MediaType.photoSmile
        case .BLINK_EYE:
            return MediaType.photoBlinkEye
        case .TURN_LEFT:
            return MediaType.photoTurnLeft
        case .TURN_RIGHT:
            return MediaType.photoTurnRight
        }
    }
}


enum DataType : String {
    case SMILE = "smile"
    case EYE_LEFT = "eye_left"
    case EYE_RIGHT = "eye_right"
    case TURN_LEFT = "turn_left"
    case TURN_RIGHT = "turn_right"
    case MOUTH_X = "MOUTH_X"
    case MOUTH_Y = "MOUTH_Y"
    case LANDMARK_FACE_Y = "LANDMARK_FACE_Y"
    case LANDMARK_EYEBROW_LEFT_Y = "LANDMARK_EYEBROW_LEFT_Y"
    case LANDMARK_EYEBROW_RIGHT_Y = "LANDMARK_EYEBROW_RIGHT_Y"
}
