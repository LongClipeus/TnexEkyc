//
//  EkycView.swift
//  tnexekyc
//
//  Created by Tnex on 05/05/2022.
//

import AVFoundation
import CoreVideo
import MLImage
import MLKitVision
import MLKitFaceDetection
import AVKit

//let epsilon = 80

class EkycView: UIView {
    private var currIndexDetectionType : Int = 0
    private var currDetectionType : DetectionType = DetectionType.SMILE
    private var timeoutDetectionTime: Int = 30
    private var isStart: Bool = false
    private var isPauseDetect: Bool = true
    private var listSmiling : [Float] = []
    private var imageData : [String: String] = [:]
    private var listDataDetect :  [String: [Float]] = [:]
    private var listDetectType : [DetectionType] = []
    private var timerTimeout = Timer()
    private var completion:((DetectionEvent, [String:String]?, String?)->())? = nil
    private var changeDetectType:((String) -> ())? = nil
    private var isStopDetection: Bool = true
    
    
    private var isUsingFrontCamera = true
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private lazy var captureSession = AVCaptureSession()
    private lazy var sessionQueue = DispatchQueue(label: Constant.sessionQueueLabel)
    private var lastFrame: CMSampleBuffer?

    fileprivate var videoDataOutput: AVCaptureVideoDataOutput?
    fileprivate(set) lazy var isRecording = false
    fileprivate var videoWriter: AVAssetWriter?
    fileprivate var videoWriterInput: AVAssetWriterInput?
    fileprivate var sessionAtSourceTime: CMTime?
    
    private lazy var previewOverlayView: UIImageView = {
        precondition(true)
        let previewOverlayView = UIImageView(frame: .zero)
        previewOverlayView.contentMode = UIView.ContentMode.scaleAspectFill
        previewOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return previewOverlayView
    }()
    
    private lazy var annotationOverlayView: UIView = {
        precondition(true)
        let annotationOverlayView = UIView(frame: .zero)
        annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return annotationOverlayView
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        print("BienNT awakeFromNib")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        print("BienNT didMoveToSuperview")
        startDetection()
    }
    
    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        self.backgroundColor = .black
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer.frame = bounds
        previewLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        previewLayer.connection?.videoOrientation = .portrait
        
        setUpPreviewOverlayView()
        setUpAnnotationOverlayView()
        setUpCaptureSessionOutput()
        setUpCaptureSessionInput()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        //previewLayer.bounds = bounds
    }
    
    private func detectFacesOnDevice(in image: VisionImage, width: CGFloat, height: CGFloat, photoData: PhotoData) {
        // When performing latency tests to determine ideal detection settings, run the app in 'release'
        // mode to get accurate performance metrics.
        let options = FaceDetectorOptions()
        options.landmarkMode = .all
        options.contourMode = .all
        options.classificationMode = .all
        options.performanceMode = .fast
        options.isTrackingEnabled = true
        let faceDetector = FaceDetector.faceDetector(options: options)
        var faces: [Face]
        do {
            faces = try faceDetector.results(in: image)
        } catch let error {
            print("Failed to detect faces with error: \(error.localizedDescription).")
            self.updatePreviewOverlayViewWithLastFrame()
            self.sendCallback(detectionEvent: DetectionEvent.FAILED, imagePath: nil, videoPath: nil)
            self.clearDetectData()
            return
        }
    
        self.updatePreviewOverlayViewWithLastFrame()
        weak var weakSelf = self
        DispatchQueue.main.sync {
            guard let strongSelf = weakSelf else {
                self.sendCallback(detectionEvent: DetectionEvent.FAILED, imagePath: nil, videoPath: nil)
                self.clearDetectData()
                return
            }
//            let epsilon = (width - strongSelf.frame.width)/2
            let epsilon = 0
            var facesDetect : [Face] = []
            for face in faces {
                if(face.hasTrackingID){
                    let normalizedRect = CGRect(
                        x: (face.frame.origin.x + CGFloat(epsilon)) / width,
                        y: face.frame.origin.y / height,
                        width: face.frame.size.width / width,
                        height: face.frame.size.height / height
                    )
                    let standardizedRect = strongSelf.previewLayer.layerRectConverted(
                        fromMetadataOutputRect: normalizedRect
                    ).standardized
                    
                    print("BienNT standardizedRect \(standardizedRect.origin.x) \(standardizedRect.origin.y)")
                    let h = standardizedRect.origin.y + standardizedRect.size.height
                    let w = standardizedRect.origin.x + standardizedRect.size.width

                    if(standardizedRect.origin.y >= 0 && standardizedRect.origin.x >= 0 && h < frame.height && w < frame.width){
                        facesDetect.append(face)
                        UIConstants.addRectangle(
                            standardizedRect,
                            to: strongSelf.annotationOverlayView,
                            color: UIColor.white
                        )
                    }
                }
            }
            strongSelf.detect(faces: facesDetect, photoData: photoData)
        }
    }
    
    
    // MARK: - Private
    
    private func setUpCaptureSessionOutput() {
        weak var weakSelf = self
        sessionQueue.async {
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            strongSelf.captureSession.beginConfiguration()
            let currentOutputs = strongSelf.captureSession.outputs
            for output in currentOutputs {
                strongSelf.captureSession.removeOutput(output)
            }
            
            // When performing latency tests to determine ideal capture settings,
            // run the app in 'release' mode to get accurate performance metrics
            strongSelf.captureSession.sessionPreset = AVCaptureSession.Preset.medium
            strongSelf.videoDataOutput = AVCaptureVideoDataOutput()
            guard let videoDataOutput = strongSelf.videoDataOutput else { return }
            videoDataOutput.videoSettings = [
                (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA
            ]
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            // We want the buffers to be in portrait orientation otherwise they are
            // rotated by 90 degrees. Need to set this _after_ addOutput()!
            videoDataOutput.connection(with: AVMediaType.video)?.videoOrientation = .portrait
            let outputQueue = DispatchQueue(label: Constant.videoDataOutputQueueLabel)
            videoDataOutput.setSampleBufferDelegate(strongSelf, queue: outputQueue)
            guard strongSelf.captureSession.canAddOutput(videoDataOutput) else {
                print("Failed to add capture session output.")
                return
            }
            strongSelf.captureSession.addOutput(videoDataOutput)
            strongSelf.captureSession.commitConfiguration()
        }
    }
    
    private func setUpCaptureSessionInput() {
        weak var weakSelf = self
        sessionQueue.async {
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            let cameraPosition: AVCaptureDevice.Position = strongSelf.isUsingFrontCamera ? .front : .back
            guard let device = strongSelf.captureDevice(forPosition: cameraPosition) else {
                print("Failed to get capture device for camera position: \(cameraPosition)")
                return
            }
            do {
                strongSelf.captureSession.beginConfiguration()
                let currentInputs = strongSelf.captureSession.inputs
                for input in currentInputs {
                    strongSelf.captureSession.removeInput(input)
                }
                
                let input = try AVCaptureDeviceInput(device: device)
                guard strongSelf.captureSession.canAddInput(input) else {
                    print("Failed to add capture session input.")
                    return
                }
                strongSelf.captureSession.addInput(input)
                strongSelf.captureSession.commitConfiguration()
            } catch {
                print("Failed to create capture device input: \(error.localizedDescription)")
            }
        }
    }
    
    private func startSession() {
        weak var weakSelf = self
        sessionQueue.async {
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            if !strongSelf.captureSession.isRunning {
                strongSelf.captureSession.startRunning()
            }
        }
    }
    
    private func stopSession() {
        print("BienNT EkycView stopDetection stopSession");

        weak var weakSelf = self
        sessionQueue.async {
            guard let strongSelf = weakSelf else {
                print("BienNT EkycView stopDetection stopSession Self nil");
                return
            }
            if strongSelf.captureSession.isRunning {
                print("BienNT EkycView stopDetection stopSession captureSession isRunning true");

                strongSelf.captureSession.stopRunning()
            }else{
                print("BienNT EkycView stopDetection stopSession captureSession isRunning false");
            }
        }
    }
    
    private func setUpPreviewOverlayView() {
        addSubview(previewOverlayView)
        NSLayoutConstraint.activate([
            previewOverlayView.centerXAnchor.constraint(equalTo: centerXAnchor),
            previewOverlayView.centerYAnchor.constraint(equalTo: centerYAnchor),
            previewOverlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            previewOverlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
        ])
    }
    
    private func setUpAnnotationOverlayView() {
        addSubview(annotationOverlayView)
        NSLayoutConstraint.activate([
            annotationOverlayView.topAnchor.constraint(equalTo: topAnchor),
            annotationOverlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            annotationOverlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            annotationOverlayView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    
    private func captureDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if #available(iOS 10.0, *) {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .unspecified
            )
            return discoverySession.devices.first { $0.position == position }
        }
        return nil
    }
    
    private func removeDetectionAnnotations() {
        for annotationView in annotationOverlayView.subviews {
            annotationView.removeFromSuperview()
        }
    }
    
    private func updatePreviewOverlayViewWithLastFrame() {
        weak var weakSelf = self
        DispatchQueue.main.sync {
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            
            guard let lastFrame = lastFrame,
                  let imageBuffer = CMSampleBufferGetImageBuffer(lastFrame)
            else {
                return
            }
            strongSelf.updatePreviewOverlayViewWithImageBuffer(imageBuffer)
            strongSelf.removeDetectionAnnotations()
        }
    }
    
    private func updatePreviewOverlayViewWithImageBuffer(_ imageBuffer: CVImageBuffer?) {
        guard let imageBuffer = imageBuffer else {
            return
        }
        let orientation: UIImage.Orientation = isUsingFrontCamera ? .leftMirrored : .right
        let image = UIConstants.createNewUIImage(from: imageBuffer, orientation: orientation, width: frame.width, height: frame.height)
        
        previewOverlayView.image = image
    }
    
    private func normalizedPoint(
        fromVisionPoint point: VisionPoint,
        width: CGFloat,
        height: CGFloat
    ) -> CGPoint {
        let epsilon = (width - self.frame.width)/2
        let cgPoint = CGPoint(x: point.x + CGFloat(epsilon), y: point.y)
        var normalizedPoint = CGPoint(x: cgPoint.x / width, y: cgPoint.y / height)
        normalizedPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
        
        return normalizedPoint
    }
    
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate

extension EkycView: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get image buffer from sample buffer.")
            return
        }
        
        lastFrame = sampleBuffer
        let visionImage = VisionImage(buffer: sampleBuffer)
        let orientation = UIConstants.imageOrientation(
            fromDevicePosition: isUsingFrontCamera ? .front : .back
        )
        visionImage.orientation = orientation
        
        guard let inputImage = MLImage(sampleBuffer: sampleBuffer) else {
            print("Failed to create MLImage from sample buffer.")
            return
        }
        inputImage.orientation = orientation
        
        print("BienNT captureOutput orientation = \(orientation)")
        let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))
        print("BienNT captureOutput imageWidth = \(imageWidth) imageHeight = \(imageHeight)")
        let photoData = PhotoData()
        // photo
        photoData.updateData(data: imageBuffer, orientation: orientation, width: imageWidth, height: imageHeight)
        
        detectFacesOnDevice(in: visionImage, width: imageWidth, height: imageHeight, photoData: photoData)
        // video
        captureVideo(output, didOutput: sampleBuffer, from: connection)
    }
}

private enum Constant {
    static let videoDataOutputQueueLabel = "com.google.mlkit.visiondetector.VideoDataOutputQueue"
    static let sessionQueueLabel = "com.google.mlkit.visiondetector.SessionQueue"
    static let noResultsMessage = "No Results"
    static let localModelFile = (name: "bird", type: "tflite")
    static let labelConfidenceThreshold = 0.75
    static let smallDotRadius: CGFloat = 4.0
    static let lineWidth: CGFloat = 3.0
    static let originalScale: CGFloat = 1.0
    static let padding: CGFloat = 10.0
    static let resultsLabelHeight: CGFloat = 200.0
    static let resultsLabelLines = 5
    static let imageLabelResultFrameX = 0.4
    static let imageLabelResultFrameY = 0.1
    static let imageLabelResultFrameWidth = 0.5
    static let imageLabelResultFrameHeight = 0.8
    static let segmentationMaskAlpha: CGFloat = 0.5
}

extension  UIView {
    func setSize( width : CGFloat ,  height : CGFloat)  {
        
        translatesAutoresizingMaskIntoConstraints = false
        
        if  width != 0 {
            widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        
        if  height != 0 {
            heightAnchor.constraint(equalToConstant: height).isActive = true
            
        }
    }
}

extension EkycView {
    func listenerDetection(listener: @escaping (String) -> (), completion: @escaping (DetectionEvent, [String:String]?, String?)->()){
        self.changeDetectType = listener
        self.completion = completion
    }
    
    private func sendCallback(detectionEvent: DetectionEvent, imagePath: [String:String]?, videoPath: String?){
        if let mCallback = self.completion {
            stopDetection()
            mCallback(detectionEvent, imagePath, videoPath)
        }
    }
    
    private func sendChangeDetectType(detectType: String){
        if let mCallback = self.changeDetectType {
            mCallback(detectType)
        }
    }
    
    func startDetection(){
        if(listDetectType.isEmpty){
            self.sendCallback(detectionEvent: DetectionEvent.DETECTION_EMPTY, imagePath: nil, videoPath: nil)
        }else{
            isStopDetection = false
            currIndexDetectionType = 0
            currDetectionType = listDetectType[0]
            sendChangeDetectType(detectType: currDetectionType.rawValue)
            isStart = false
            isPauseDetect = true
            listSmiling.removeAll()
            imageData.removeAll()
            listDataDetect.removeAll()
            startSession()
            delayDetect()
            startDetectTimeout()
            //startRecordVideo()
        }
    }
    
    private func getDetectTypeFromName(typeName: String) -> DetectionType {
        switch typeName {
        case "smile":
            return DetectionType.SMILE
        case "blink_eye":
            return DetectionType.BLINK_EYE
        case "turn_left":
            return DetectionType.TURN_LEFT
        case "turn_right":
            return DetectionType.TURN_RIGHT
        default:
            return DetectionType.SMILE
        }
    }
    
    func setListDetectType(list : [String]){
        listDetectType.removeAll()
        for item in list {
            let typeName = getDetectTypeFromName(typeName: item)
            listDetectType.append(typeName)
        }
    }
    
    func stopDetection(){
        print("BienNT EkycView stopDetection");

        isStopDetection = true
        self.timerTimeout.invalidate()
        stopRecordVideo()
        stopSession()
    }
    
    private func delayDetect(){
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
            self.isPauseDetect = false
        }
    }
    
    private func startDetectTimeout(){
        self.timerTimeout.invalidate()
        self.timerTimeout = Timer.scheduledTimer(withTimeInterval: TimeInterval(timeoutDetectionTime), repeats: true) { (_) in
            //sendEvent
            if(self.isStart){
                self.sendCallback(detectionEvent: DetectionEvent.LOST_FACE, imagePath: nil, videoPath: nil)
            }else{
                self.sendCallback(detectionEvent: DetectionEvent.NO_FACE, imagePath: nil, videoPath: nil)
            }
            
            self.clearDetectData()
        }
    }
    
    private func clearDetectData(){
        isStart = false
        timerTimeout.invalidate()
        isPauseDetect = true
        listDataDetect.removeAll()
        imageData.removeAll()
      }
    
    private func detect(faces: [Face], photoData: PhotoData){
        print("BienNT Log Detect")
        if(isPauseDetect || isStopDetection){
            return
        }
        
        if(faces.isEmpty){
            
        }else if(faces.count > 1){
            self.sendCallback(detectionEvent: DetectionEvent.MULTIPLE_FACE, imagePath: nil, videoPath: nil)
            self.clearDetectData()
        }else{
            if(!isStart){
                isStart = true
                startRecordVideo()
            }
            
            let face = faces[0]
            print("BienNT Log Detect face \(face)")
            let headEulerAngleY  = face.headEulerAngleY
            if(headEulerAngleY < 16 && headEulerAngleY > -16){
                listSmiling.append(Float(face.smilingProbability))
            }
            
            listDataDetect = addDataDetectionType(face: face, currData: listDataDetect, detectionType: currDetectionType)
            print("BienNT Log Detect face \(listDataDetect)")
            let isDetectionType = validateDetectionType()
            print("BienNT Log Detect face \(isDetectionType)")
            if(isDetectionType){
                if(currIndexDetectionType < listDetectType.count - 1){
                    takePhoto(mediaType: currDetectionType.getMediaType(), photoData: photoData)
                    isPauseDetect = true
                    listDataDetect.removeAll()
                    currIndexDetectionType += 1
                    currDetectionType=listDetectType[currIndexDetectionType]
                    sendChangeDetectType(detectType: currDetectionType.rawValue)
                    startDetectTimeout()
                    delayDetect()
                }else{
                    takePhoto(mediaType: currDetectionType.getMediaType(), photoData: photoData)
                    
//                    let smiling = getAmplitude(listCheck: listSmiling)
//                    if(smiling <= 0.2){
//                        self.sendCallback(detectionEvent: DetectionEvent.LOST_FACE, imagePath: nil, videoPath: nil)
//                    }else{
                        let videoPath = getVideoPath()
                        let imagePath = getListImagePath()
                        self.sendCallback(detectionEvent: DetectionEvent.SUCCESS, imagePath: imagePath, videoPath: videoPath)
//                    }
                    
                    self.clearDetectData()
                }
            }
        }
    }
    
    
    private func validateDetectionType()-> Bool{
        switch currDetectionType {
        case DetectionType.BLINK_EYE:
            return validateBlinkingEyesDetection()
        case DetectionType.SMILE:
            return validateSmileDetection()
        default:
            return checkDetectionType(currData: listDataDetect, detectionType: currDetectionType)
        }
    }
    
    private func validateSmileDetection()-> Bool{
        let isDetectionType = checkDetectionType(currData: listDataDetect, detectionType: currDetectionType)
        if(isDetectionType){
            let isChangeMount = validateChangeMouth(listMouthBottomLeftX: listDataDetect[DataType.MOUTH_X.rawValue], listMouthBottomLeftY: listDataDetect[DataType.MOUTH_Y.rawValue])
            if(isChangeMount){
                return true
            }else{
                listDataDetect.removeAll()
            }
        }
        
        return false
    }
    
    private func validateBlinkingEyesDetection()-> Bool{
        let isDetectionType = checkDetectionType(currData: listDataDetect, detectionType: currDetectionType)
        if(isDetectionType){
            let isChangeEye = validateEyes(landmarkFaceY: listDataDetect[DataType.LANDMARK_FACE_Y.rawValue], landmarkEyeLeftY: listDataDetect[DataType.LANDMARK_EYEBROW_LEFT_Y.rawValue], landmarkEyeRightY: listDataDetect[DataType.LANDMARK_EYEBROW_RIGHT_Y.rawValue])
            if(isChangeEye){
                return true
            }else{
                listDataDetect.removeAll()
            }
        }
        
        return false
    }
    
    
    private func checkDetectionType(currData: [String: [Float]], detectionType: DetectionType)-> Bool{
        switch detectionType {
        case .SMILE:
            return checkSmiling(listData: currData[DataType.SMILE.rawValue])
        case .BLINK_EYE:
            return checkBlinkingEyes(listDataLeft: currData[DataType.EYE_LEFT.rawValue], listDataRight: currData[DataType.EYE_RIGHT.rawValue])
        case .TURN_LEFT:
            return checkFaceTurnLeft(listData: currData[DataType.TURN_LEFT.rawValue])
        case .TURN_RIGHT:
            return checkFaceTurnRight(listData: currData[DataType.TURN_RIGHT.rawValue])
        }
    }
    
    private func addDataDetectionType(face: Face, currData: [String: [Float]], detectionType: DetectionType) -> [String: [Float]] {
        switch detectionType {
        case .SMILE:
            return addDataSmiling(face: face, listData: currData[DataType.SMILE.rawValue], listMouthBottomLeftX: currData[DataType.MOUTH_X.rawValue], listMouthBottomLeftY: currData[DataType.MOUTH_Y.rawValue])
        case .BLINK_EYE:
            return addBlinkingEyes(face: face, listDataLeft: currData[DataType.EYE_LEFT.rawValue], listDataRight: currData[DataType.EYE_RIGHT.rawValue], landmarkFaceY: currData[DataType.LANDMARK_FACE_Y.rawValue], landmarkEyeLeftY: currData[DataType.LANDMARK_EYEBROW_LEFT_Y.rawValue], landmarkEyeRightY: currData[DataType.LANDMARK_EYEBROW_RIGHT_Y.rawValue])
        case .TURN_LEFT:
            return addFaceTurnLeft(face: face, listData: currData[DataType.TURN_LEFT.rawValue])
        case .TURN_RIGHT:
            return addFaceTurnRight(face: face, listData: currData[DataType.TURN_RIGHT.rawValue])
        }
    }
    
    
    private func addBlinkingEyes(face: Face, listDataLeft: [Float]?, listDataRight: [Float]?, landmarkFaceY: [Float]?, landmarkEyeLeftY: [Float]?, landmarkEyeRightY: [Float]?) -> [String: [Float]] {
        let left = Float(face.leftEyeOpenProbability)
        let right = Float(face.rightEyeOpenProbability)
        let isFaceStraight = checkFaceStraight(face: face)
        var newListDataLeft: [Float] = []
        if let dataLeft = listDataLeft, !dataLeft.isEmpty {
            newListDataLeft = dataLeft
        }
        
        var newListDataRight: [Float] = []
        if let dataRight = listDataRight, !dataRight.isEmpty {
            newListDataRight = dataRight
        }
        
        var newListLandmarkFaceY : [Float] = []
        if let faceY = landmarkFaceY, !faceY.isEmpty {
            newListLandmarkFaceY = faceY
        }
        
        var newListLandmarkLeftY : [Float] = []
        if let eyeLeftY = landmarkEyeLeftY, !eyeLeftY.isEmpty {
            newListLandmarkLeftY = eyeLeftY
        }
        
        var newListLandmarkRightY : [Float] = []
        if let eyeRightY = landmarkEyeRightY, !eyeRightY.isEmpty{
            newListLandmarkRightY = eyeRightY
        }
        
//        print("BienNT Log Detect newListDataLeft =  \(newListDataLeft)")
//        print("BienNT Log Detect newListDataRight =  \(newListDataRight)")
//        let decLeft = decCheck(listData: newListDataLeft)
//        let decRight = decCheck(listData: newListDataRight)
//
//        print("BienNT Log Detect decLeft =  \(decLeft) decRight = \(decRight) isFaceStraight = \(isFaceStraight)")
//        if(!decLeft || !decRight){
//            newListDataLeft.removeAll()
//            newListLandmarkLeftY.removeAll()
//            newListLandmarkFaceY.removeAll()
//            newListDataRight.removeAll()
//            newListLandmarkRightY.removeAll()
//        }
        
        
//        if(isFaceStraight){
//            if((newListDataLeft.count > 0 && left > newListDataLeft[newListDataLeft.count - 1]) || (newListDataRight.count > 0 && right > newListDataRight[newListDataRight.count - 1]) ){
//                newListDataLeft.removeAll()
//                newListLandmarkLeftY.removeAll()
//                newListLandmarkFaceY.removeAll()
//                newListDataRight.removeAll()
//                newListLandmarkRightY.removeAll()
//            }
            
            let faceLeft = face.contour(ofType: .leftEyebrowTop)
            let minYEyeLeft = getMinPointF(contour: faceLeft)
            let faceRight = face.contour(ofType: .rightEyebrowTop)
            let minYEyeRight = getMinPointF(contour: faceRight)
            
            let faceTop = face.contour(ofType: .face)
            let minYFace = getMinPointF(contour: faceTop)
            
            let faceNose = face.landmark(ofType: .noseBase)
            
            if let minLY = minYEyeLeft, let mNose = faceNose {
                let lY = abs(minLY - Float(mNose.position.y))
                newListLandmarkLeftY.append(lY)
            }
            
            
            newListDataRight.append(right)
            newListDataLeft.append(left)
            if let minrY = minYEyeRight , let mNose = faceNose{
                let rY = abs(minrY - Float(mNose.position.y))
                newListLandmarkRightY.append(rY)
            }
            
            if let minfY = minYFace , let mNose = faceNose{
                let fY = abs(minfY - Float(mNose.position.y))
                newListLandmarkFaceY.append(fY)
            }
            
            print("BienNT Log Detect newListDataRight =  \(newListDataRight) newListDataLeft = \(newListDataLeft) isFaceStraight = \(isFaceStraight)")
//
//        }
        
        var newData: [String: [Float]] = [:]
        newData[DataType.EYE_LEFT.rawValue] = newListDataLeft
        newData[DataType.EYE_RIGHT.rawValue] = newListDataRight
        newData[DataType.LANDMARK_EYEBROW_LEFT_Y.rawValue] = newListLandmarkLeftY
        newData[DataType.LANDMARK_EYEBROW_RIGHT_Y.rawValue] = newListLandmarkRightY
        newData[DataType.LANDMARK_FACE_Y.rawValue] = newListLandmarkFaceY
        
        return newData
    }
    
    private func validateEyes(landmarkFaceY: [Float]?, landmarkEyeLeftY: [Float]?, landmarkEyeRightY: [Float]?) -> Bool {
        return true
//        if let fY = landmarkFaceY, !fY.isEmpty, let lY = landmarkEyeLeftY, !lY.isEmpty, let rY = landmarkEyeRightY, !rY.isEmpty{
//            let fy = getAmplitude(listCheck: fY)
//            let ly = getAmplitude(listCheck: lY)
//            let ry = getAmplitude(listCheck: rY)
//            if(fy < 8 && ly < 6  && ry < 6){
//                return true
//            }
//
//            return false
//        }
//
//        return false
        
    }
    
    private func checkBlinkingEyes(listDataLeft: [Float]?, listDataRight: [Float]?) -> Bool{
        if let l = listDataLeft, !l.isEmpty, l.count >= 3, let r = listDataRight, !r.isEmpty, r.count >= 3{
//            let decLeft = decCheck(listData: l)
//            let decRight = decCheck(listData: r)
//
//            if(decLeft && decRight){
                let newLeft = sortDEC(listData: l)
                let newRight = sortDEC(listData: r)
                
                if(newLeft[0] > 0.6 && newLeft[newLeft.count - 1 ] < 0.2 && newRight[0] > 0.6 && newRight[newRight.count - 1] < 0.2){
                    return true
                }
//            }
            
            
            return false
        }
        
        return false
    }
    
    private func addDataSmiling(face: Face, listData: [Float]?, listMouthBottomLeftX: [Float]?, listMouthBottomLeftY: [Float]?) -> [String: [Float]]{
        var newListData:[Float] = []
        if let d = listData, !d.isEmpty {
            newListData = d
        }
        
        var newMouthBottomLeftX :[Float] = []
        if let blX = listMouthBottomLeftX, !blX.isEmpty {
            newMouthBottomLeftX = blX
        }
        
        
        var newMouthBottomLeftY :[Float] = []
        if let blY = listMouthBottomLeftY, !blY.isEmpty {
            newMouthBottomLeftY = blY
        }
        
        print("BienNT Log Detect addDataSmiling  newListData =  \(newListData)")
        
        let smilingProbability = face.smilingProbability
//        let isFaceStraight = checkFaceStraight(face: face)
//        let isASC = ascCheck(listData: newListData)
//
//
//        print("BienNT Log Detect addDataSmiling  smilingProbability =  \(smilingProbability) isFaceStraight = \(isFaceStraight) isASC = \(isASC)")
//
//        if(!isASC){
//            newListData.removeAll()
//            newMouthBottomLeftX.removeAll()
//            newMouthBottomLeftY.removeAll()
//        }
//
//        if(isFaceStraight){
//            if(newListData.count > 0 && Float(smilingProbability) < newListData[newListData.count - 1]){
//                newListData.removeAll()
//                newMouthBottomLeftX.removeAll()
//                newMouthBottomLeftY.removeAll()
//            }
//
            newListData.append(Float(smilingProbability))
            print("BienNT Log Detect addDataSmiling  newListData =  \(newListData)")
            
            let faceLandmark = face.landmark(ofType: .mouthBottom)
            let faceLeft = face.landmark(ofType: .mouthLeft)
            let faceRight = face.landmark(ofType: .mouthRight)
            
            if let f = faceLandmark, let l = faceLeft, let r = faceRight {
                let lX = abs(l.position.x - f.position.x)
                let lY = abs(l.position.y - f.position.y)
                let rX = abs(r.position.x - f.position.x)
                let rY = abs(r.position.y - f.position.y)
                
                let x = abs(lX - rX)
                let y = abs(lY - rY)
                newMouthBottomLeftX.append(Float(x))
                newMouthBottomLeftY.append(Float(y))
            }
//        }else{
//            newListData.removeAll()
//            newMouthBottomLeftX.removeAll()
//            newMouthBottomLeftY.removeAll()
//        }
//
        var newData : [String: [Float]] = [:]
        newData[DataType.SMILE.rawValue] = newListData
        newData[DataType.MOUTH_X.rawValue] = newMouthBottomLeftX
        newData[DataType.MOUTH_Y.rawValue] = newMouthBottomLeftY
        
        return newData
    }
    
    private func validateChangeMouth(listMouthBottomLeftX: [Float]?, listMouthBottomLeftY: [Float]?) -> Bool{
        return true
//        if let mX = listMouthBottomLeftX, !mX.isEmpty , let mY = listMouthBottomLeftY, !mY.isEmpty {
//            let lx = getAmplitude(listCheck: mX)
//            let ly = getAmplitude(listCheck: mY)
//            if(lx < 5 && ly < 5 && ly > 1.5){
//                return true
//            }
//
//            return false
//        }
//
//        return false
    }
    
    private func checkSmiling(listData: [Float]?) -> Bool {
        if let data = listData, !data.isEmpty, data.count >= 3 {
//            let isASC = ascCheck(listData: data)
//            if(isASC){
                let newList = sortASC(listData: data)
                if(newList[0] <= 0.4 && newList[newList.count - 1] >= 0.8){
                    return true
                }
//            }
            
            return false
        }
        
        return false
    }
    
    private func addFaceTurnRight(face: Face, listData: [Float]?) -> [String: [Float]]{
        let y = face.headEulerAngleY
        var newListData: [Float] = []
        
        if let data = listData, !data.isEmpty{
            newListData = data
        }
        
        print("BienNT Log Detect addFaceTurnRight  newListData =  \(newListData)")

//
//        let isASC = ascCheck(listData: newListData)
//        if(!isASC){
//            newListData.removeAll()
//        }else if(newListData.count > 0 && Float(y) < newListData[newListData.count - 1]){
//            newListData.removeAll()
//        }
        
        newListData.append(Float(y))
        print("BienNT Log Detect addFaceTurnRight  newListData =  \(newListData)")

        var newData :  [String: [Float]] = [:]
        newData[DataType.TURN_RIGHT.rawValue] = newListData
        
        return newData
    }
    
    private func checkFaceTurnRight(listData: [Float]?) -> Bool{
        if let data = listData, !data.isEmpty{
//            let isASC = ascCheck(listData: data)
//            if(isASC){
                let newData = sortASC(listData: data)
                print("BienNT Log Detect addFaceTurnRight  newData =  \(newData)")

                if(newData[0] <= 10 &&  newData[newData.count - 1] > 30){
                    return true
                }
//            }
            return false
        }
        
        return false
    }
    
    private func addFaceTurnLeft(face: Face, listData: [Float]?) -> [String: [Float]] {
        let y = face.headEulerAngleY
        var newListData: [Float] = []
        if let data = listData, !data.isEmpty{
            newListData = data
        }
        
        print("BienNT Log Detect addFaceTurnLeft  newListData =  \(newListData)")

//        let isDEC = decCheck(listData: newListData)
//        if(!isDEC){
//            newListData.removeAll()
//        }else if(newListData.count > 0 && Float(y) > newListData[newListData.count - 1]){
//            newListData.removeAll()
//          }
        
        newListData.append(Float(y))
        print("BienNT Log Detect addFaceTurnLeft  newListData =  \(newListData)")

        var newData : [String: [Float]] = [:]
        newData[DataType.TURN_LEFT.rawValue] = newListData
        
        return newData
    }
    
    
    private func checkFaceTurnLeft(listData: [Float]?) -> Bool{
        if let data = listData, !data.isEmpty{
//            let isDEC = decCheck(listData: data)
//            if(isDEC){
                let newData = sortDEC(listData: data)
                print("BienNT Log Detect addFaceTurnLeft  newData =  \(newData)")

                if(newData[0] >= -10  && newData[newData.count - 1] < -30){
                    return true
                }
//            }
            
            return false
        }
        
        return false
    }
    
    
    private func checkFaceStraight(face: Face) -> Bool {
        var isFaceStraight = false
        let y = face.headEulerAngleY
        if (y <= 15 && y >= -15) {
            isFaceStraight = true
        }
        return isFaceStraight
    }
    
    private func getMinPointF(contour: FaceContour?) -> Float?{
        var min : Float?
        if let mContour = contour {
            for point in mContour.points {
                let pointY = Float(point.y)
                if let mMin = min {
                    if(mMin > pointY){
                        min = pointY
                    }
                }else{
                    min = pointY
                }
            }
        }
        
        return min
    }
        
        private func getAmplitude(listCheck: [Float]) -> Float{
            var min : Float?
            var max : Float?
            for item in listCheck {
                if let mMin = min {
                    if item < mMin {
                        min = item
                    }
                }
                else{
                    min = item
                }
                
                if let mMax = max {
                    if item > mMax {
                        max = item
                    }
                }
                else{
                    max = item
                }
            }
            
            if let mMin = min, let mMax = max {
                return mMax - mMin
            }
            
            return 0
        }
        
        
        private func sortASC(listData: [Float]) -> [Float]{
            return listData.sorted(by: { $0 < $1 })
        }
        
        private func sortDEC(listData: [Float]) -> [Float]{
            return listData.sorted(by: {$0 > $1})
        }
        
        private func ascCheck(listData: [Float]) -> Bool{
            for (index, _) in listData.enumerated() {
                if (index < listData.count - 1 && listData[index] > listData[index+1]) {
                    return false
                }
            }
            
            return true
        }
        
        private func decCheck(listData: [Float]) -> Bool{
            for (index, _) in listData.enumerated() {
                if (index < listData.count - 1 && listData[index] < listData[index+1]) {
                    return false
                }
            }
            
            return true
        }
}

// MARK: - Record video and take photo
extension EkycView {
    private func playVideo() {
        guard let videoURL = getOutputUrlIfFileExists(mediaType: .video) else {return}
        let player = AVPlayer(url: videoURL)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        if let topController = UIApplication.topViewController() {
            topController.present(playerViewController, animated: true) {
                playerViewController.player?.play()
            }
        }
    }
    
    private func takePhoto(mediaType: MediaType, photoData: PhotoData) {
        removeFileIfNeeded(mediaType: mediaType)
        guard let data = photoData.getData(), let orientation = photoData.getOrientation()  else { return }
        if let imageData = UIConstants.createUIImage(from: data, orientation: orientation) {
            savePhotoToDocuments(imageData: imageData, mediaType: mediaType)
        }
        
    }
    
    private func setUpWriter() {
        do {
            removeFileIfNeeded(mediaType: .video)
            guard let outputFileLocation = getDirectoryPath(mediaType: .video) else {return}
            videoWriter = try AVAssetWriter(outputURL: outputFileLocation, fileType: AVFileType.mp4)
            guard let videoWriter = videoWriter else { return }
            
            // add video input
            if #available(iOS 11.0, *) {
                videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: [
                    AVVideoCodecKey : AVVideoCodecType.h264,
                    AVVideoWidthKey : 480,
                    AVVideoHeightKey : 360,
                    AVVideoCompressionPropertiesKey : [
                        AVVideoAverageBitRateKey : 2300000,
                    ],
                ])
            } else {
                // Fallback on earlier versions
            }
            guard let videoWriterInput = videoWriterInput else { return }
            videoWriterInput.mediaTimeScale = CMTimeScale(bitPattern: 600)
            videoWriterInput.expectsMediaDataInRealTime = true
            videoWriterInput.transform = CGAffineTransform(rotationAngle: .pi/2)
            
            if (videoWriter.canAdd(videoWriterInput)) {
                videoWriter.add(videoWriterInput)
                print("video input added")
            } else {
                print("no input added")
            }
            videoWriter.startWriting()
        } catch let error {
            debugPrint(error.localizedDescription)
        }
    }
    
    private func canWrite() -> Bool {
        return isRecording && videoWriter != nil && videoWriter?.status == .writing
    }
    
    //output url method
    private func getOutputUrlIfFileExists(mediaType: MediaType) -> URL? {
        if let videoOutputUrl = getDirectoryPath(mediaType: mediaType) {
            if FileManager.default.fileExists(atPath: videoOutputUrl.path) {
                return videoOutputUrl
            }
        }
        return nil
    }
    
    
    private func getVideoPath() -> String?{
        let video = getDirectoryPath(mediaType: .video)
        if let urlVideo = video {
            return urlVideo.path
        }
        
        return nil
    }
    
    private func getListImagePath() -> [String:String]{
        let smile = getDirectoryPath(mediaType: .photoSmile)
        let turnRight = getDirectoryPath(mediaType: .photoTurnRight)
        let turLeft = getDirectoryPath(mediaType: .photoTurnLeft)
        let blinkEye = getDirectoryPath(mediaType: .photoBlinkEye)
        
        var imagePath: [String:String] = [:]
        if let urlSmile = smile {
            imagePath["smile"] = urlSmile.path
        }
        
        if let urlTurnRight = turnRight {
            imagePath["turn_right"] = urlTurnRight.path
        }
        
        if let urlTurLeft = turLeft {
            imagePath["turn_left"] = urlTurLeft.path
        }
        
        if let urlBlinkEye = blinkEye {
            imagePath["blink_eye"] = urlBlinkEye.path
        }
        
        return imagePath
    }
    
    private func getDirectoryPath(mediaType: MediaType) -> URL? {
        if let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first as NSString? {
            return URL(fileURLWithPath: documentsPath.appendingPathComponent(mediaType.getName())).appendingPathExtension(mediaType.getExtension())
            
        }
        return nil
    }
    
    // remove file method
    private func removeFileIfNeeded(mediaType: MediaType) {
        if let videoOutputUrl = getDirectoryPath(mediaType: mediaType) {
            do {
                if FileManager.default.fileExists(atPath: videoOutputUrl.path) {
                    try FileManager.default.removeItem(at: videoOutputUrl)
                    print("file removed")
                }
            } catch {
                print(error)
            }
        }
    }
    
    private func savePhotoToDocuments(imageData: UIImage, mediaType: MediaType) {
        if let data = imageData.jpegData(compressionQuality: 1.0), let path = getDirectoryPath(mediaType: mediaType) {
            FileManager.default.createFile(atPath: path.path, contents: data)
        }
    }
    
    private func captureVideo(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let videoWriter = videoWriter, let videoWriterInput = videoWriterInput else { return }
        
        let writable = canWrite()
        if writable,
           sessionAtSourceTime == nil {
            // start writing
            sessionAtSourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            guard let sessionAtSourceTime = sessionAtSourceTime else { return }
            videoWriter.startSession(atSourceTime: sessionAtSourceTime)
            //print("Writing")
        }
        
        if writable,
           output == videoDataOutput,
           videoWriterInput.isReadyForMoreMediaData {
            // write video buffer
            videoWriterInput.append(sampleBuffer)
            //print("video buffering")
        }
    }
    
    // MARK: Start recording
    private func startRecordVideo() {
        guard !isRecording else { return }
        isRecording = true
        sessionAtSourceTime = nil
        setUpWriter()
        guard let videoWriter = videoWriter else { return }
        print(isRecording)
        print(videoWriter)
        if videoWriter.status == .writing {
            print("status writing")
        } else if videoWriter.status == .failed {
            print("status failed")
        } else if videoWriter.status == .cancelled {
            print("status cancelled")
        } else if videoWriter.status == .unknown {
            print("status unknown")
        } else {
            print("status completed")
        }
    }
    
    // MARK: Stop recording
    private func stopRecordVideo() {
        print("BienNT EkycView stopRecordVideo");

        guard isRecording else {
            print("BienNT EkycView stopRecordVideo isRecording false");
            return
        }
        print("BienNT EkycView stopRecordVideo isRecording true");
        isRecording = false
        guard let videoWriter = videoWriter, let videoWriterInput = videoWriterInput else {
            print("BienNT EkycView stopRecordVideo videoWriter null || videoWriterInput null");

            return
        }
        videoWriterInput.markAsFinished()
        print("BienNT EkycView stopRecordVideo  marked as finished")
        videoWriter.finishWriting { [weak self] in
            guard let weakSelf = self else {
                print("BienNT EkycView stopRecordVideo  self null")
                return
            }
            
            print("BienNT EkycView stopRecordVideo  sessionAtSourceTime null")
            weakSelf.sessionAtSourceTime = nil
        }
        //print("finished writing \(self.outputFileLocation)")
    }
}

extension UIApplication {
    class func topViewController(controller: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }
}

private class PhotoData {
    private var data: CVImageBuffer?
    private var orientation: UIImage.Orientation?
    private var width: CGFloat?
    private var height: CGFloat?
    
    func updateData(data: CVImageBuffer?, orientation: UIImage.Orientation?, width: CGFloat?, height: CGFloat?) {
        self.data = data
        self.orientation = orientation
        self.width = width
        self.height = height
    }
    
    func getData() -> CVImageBuffer? {
        return self.data
    }
    
    func getOrientation() -> UIImage.Orientation? {
        return self.orientation
    }
    func getWidth() -> CGFloat? {
        return self.width
    }
    func getHeight() -> CGFloat? {
        return self.height
    }
}

enum MediaType {
    case video
    case photoSmile
    case photoBlinkEye
    case photoTurnLeft
    case photoTurnRight
    
    
    func getName() -> String {
        switch self {
        case .video:
            return "ios_video"
        case .photoSmile:
            return "smile"
        case .photoBlinkEye:
            return "blink_eye"
        case .photoTurnLeft:
            return "turn_left"
        case .photoTurnRight:
            return "turn_right"
        }
    }
    
    func getExtension() -> String {
        switch self {
            case .video:
                return "mp4"
            case .photoSmile:
                return "jpg"
            case .photoBlinkEye:
                return "jpg"
            case .photoTurnLeft:
                return "jpg"
            case .photoTurnRight:
                return "jpg"
        }
    }
}
