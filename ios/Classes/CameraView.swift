//
//  CameraView.swift
//  tnexekyc
//
//  Created by Tnex on 23/05/2022.
//

import Foundation
import AVFoundation

class CameraView: UIView, AVCapturePhotoCaptureDelegate {
    private let photoOutput = AVCapturePhotoOutput()
    private let captureSession = AVCaptureSession()
    private var onError:((String) -> ())? = nil
    private var onResults:((String) -> ())? = nil
    
    override func awakeFromNib() {
        super.awakeFromNib()
        print("BienNT awakeFromNib")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        print("BienNT didMoveToSuperview")
        startCamera()
    }
    
    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        print("BienNT willMoveToSuperview")
        setupCaptureSession()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        print("BienNT layoutSubviews")
        print("layoutSubviews bounds = \(bounds)")
        print("layoutSubviews frame = \(frame)")
    }
    
    
    private func setupCaptureSession() {
           if let captureDevice = AVCaptureDevice.default(for: AVMediaType.video) {
               do {
                   let input = try AVCaptureDeviceInput(device: captureDevice)
                   if captureSession.canAddInput(input) {
                       captureSession.addInput(input)
                   }
               } catch let error {
                   print("Failed to set input device with error: \(error)")
                   sendError()
               }
               
               if captureSession.canAddOutput(photoOutput) {
                   captureSession.addOutput(photoOutput)
               }
               
               let cameraLayer = AVCaptureVideoPreviewLayer(session: captureSession)
               cameraLayer.frame = self.frame
               cameraLayer.videoGravity = .resizeAspectFill
               self.layer.addSublayer(cameraLayer)
               self.clipsToBounds = true
           }
    }
    
    private func savePhotoToDocuments(imageData: UIImage) -> String? {
        if let data = imageData.jpegData(compressionQuality: 1.0), let path = getDirectoryPath() {
            FileManager.default.createFile(atPath: path.path, contents: data)
            
            return path.path
        }
        
        return nil
    }
    
    private func getDirectoryPath() -> URL? {
        let timestamp = String(NSDate().timeIntervalSince1970)
        if let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first as NSString? {
            return URL(fileURLWithPath: documentsPath.appendingPathComponent(timestamp)).appendingPathExtension("jpg")
            
        }
        return nil
    }
    
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("BienNT photoOutput")
        guard let imageData = photo.fileDataRepresentation() else {
            sendError()
            return
        }
        
        guard let previewImage = UIImage(data: imageData) else {
            sendError()
            return
        }
                
        guard let saveImage = UIConstants.createUIImage(from: previewImage, width: self.frame.width, height: self.frame.height) else {
            sendError()
            return
        }
        
        let path = savePhotoToDocuments(imageData: saveImage)
        if let imagePath = path, !imagePath.isEmpty {
            sendResults(imagePath: imagePath)
        }else{
            sendError()
        }
    }
    
    private func sendError(){
        if let mCallback = self.onError {
            stopCamera()
            mCallback("FAILED")
        }
    }

    private func sendResults(imagePath: String){
        if let mCallback = self.onResults {
            stopCamera()
            mCallback(imagePath)
        }
    }
    
    
    func listenerCamera(onResults: @escaping (String) -> (), onError: @escaping (String) -> ()){
        self.onResults = onResults
        self.onError = onError
    }
    
    func startCamera(){
        captureSession.startRunning()
    }

    func stopCamera(){
        captureSession.stopRunning()
    }
    
    
    func captureImage() {
        let photoSettings = AVCapturePhotoSettings()
        if let photoPreviewType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoPreviewType]
            photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }else{
            sendError()
        }
    }
}

