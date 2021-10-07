//
//  ViewController.swift
//  FaceRecognition
//
//  Created by Satrio Wicaksono on 14/09/21.
//

import UIKit
import AVFoundation
import Vision

class MainView: UIViewController {

    //MARK: Properties
    private let className = String(describing: MainView.self)
    private let bundle = Bundle(for: MainView.self)
    private var captureSession : AVCaptureSession!
    private var backCamera : AVCaptureDevice!
    private var frontCamera : AVCaptureDevice!
    private var backInput : AVCaptureInput!
    private var frontInput : AVCaptureInput!
    private var previewLayer : AVCaptureVideoPreviewLayer!
    private var videoOutput : AVCaptureVideoDataOutput!
    private var backCameraOn = true
    
    private var trackingRequests: [VNTrackObjectRequest]?
    private var detectionRequests: [VNDetectFaceRectanglesRequest]?
    private var faceRectangleView: UIView?
    private var sequenceRequestHandler = VNSequenceRequestHandler()
    
    lazy private var faceDetectionRequest: VNDetectFaceRectanglesRequest = {
        let faceDetectRectangleRequest = VNDetectFaceRectanglesRequest { request, error in
            guard let results = request.results as? [VNFaceObservation] else { fatalError("unexpected result type!") }
            self.handleFaceDetectionResults(results)
        }
        return faceDetectRectangleRequest
    }()
    
    //MARK: IBOutlets
    @IBOutlet weak var switchButton: UIButton!
    
    //MARK: Initialize
    init() {
        super.init(nibName: className, bundle: bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.isHidden = true
        setupAVSession()
        detectionRequests = [faceDetectionRequest]
    }
    
    // Ensure that the interface stays locked in Portrait.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    // Ensure that the interface stays locked in Portrait.
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }

    //MARK: Private Function
    private func setupAVSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession = AVCaptureSession()
            self.captureSession.beginConfiguration()
            self.setupDeviceInput()
            DispatchQueue.main.async {
                self.setupPreviewLayer()
            }
            self.setupDeviceOutput()
            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()
        }
    }
    
    private func setupPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.frame
        view.layer.insertSublayer(previewLayer, above: view.layer)
        view.layer.insertSublayer(switchButton.layer, above: previewLayer)
    }
    
    private func setupDeviceInput() {
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            self.backCamera = device
            guard let input = try? AVCaptureDeviceInput(device: self.backCamera) else { return }
            self.backInput = input
            if !captureSession.canAddInput(self.backInput) {
                fatalError("could not add back camera input to capture session")
            }
        } else {
            fatalError("no back camera")
        }
        
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            self.frontCamera = device
            guard let input = try? AVCaptureDeviceInput(device: self.frontCamera) else { return }
            self.frontInput = input
            if !captureSession.canAddInput(self.frontInput) {
                fatalError("could not add front camera input to capture session")
            }
        } else {
            fatalError("no front camera")
        }
        self.captureSession.addInput(self.backInput)
    }
    
    private func setupDeviceOutput() {
        videoOutput = AVCaptureVideoDataOutput()
        let videoQueue = DispatchQueue(label: "videoQueue", qos: .background)
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            fatalError("could not add video output")
        }
    }
    
    private func switchDeviceInput() {
        switchButton.isUserInteractionEnabled = false
        captureSession.beginConfiguration()
        resetDeviceInput()
        if backCameraOn {
            backCameraOn = false
            captureSession.addInput(frontInput)
        } else {
            backCameraOn = true
            captureSession.addInput(backInput)
        }
        captureSession.commitConfiguration()
        switchButton.isUserInteractionEnabled = true
    }
    
    private func resetDeviceInput() {
        captureSession.removeInput(frontInput)
        captureSession.removeInput(backInput)
    }
    
    private func handleFaceDetectionResults(_ results: [VNFaceObservation]) {
        DispatchQueue.main.async {
            var requests = [VNTrackObjectRequest]()
            for observation in results {
                let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                faceTrackingRequest.trackingLevel = .fast
                requests.append(faceTrackingRequest)
            }
            self.trackingRequests = requests
        }
    }
    
    private func drawFaceObservations(_ faceObservations: [VNFaceObservation]) {
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -self.previewLayer.bounds.height)
        let scale = CGAffineTransform.identity.scaledBy(x: self.previewLayer.bounds.width, y: self.previewLayer.bounds.height)
        guard let lastFaceObservation = faceObservations.last else { return }
        let bounds = lastFaceObservation.boundingBox.applying(scale).applying(transform)
        DispatchQueue.main.async {
            if self.faceRectangleView == nil {
                self.faceRectangleView = UIView(frame: bounds)
                self.faceRectangleView?.backgroundColor = .clear
                self.faceRectangleView?.layer.borderWidth = 3
                self.faceRectangleView?.layer.borderColor = UIColor.systemGreen.cgColor
                guard let boundingBoxView = self.faceRectangleView else { return }
                let labelName = UILabel(frame: CGRect(x: .zero, y: bounds.height + 4, width: bounds.width, height: 48))
                labelName.textAlignment = .center
                labelName.numberOfLines = 2
                labelName.text = "Tio Satrio Wicaksono"
                labelName.font = UIFont.boldSystemFont(ofSize: 18.0)
                labelName.textColor = .systemGreen
                labelName.backgroundColor = .black
                boundingBoxView.addSubview(labelName)
                self.view.addSubview(boundingBoxView)
            } else {
                UIView.animate(withDuration: 0.1, animations: {
                    self.faceRectangleView?.frame = bounds
                    guard let faceRectangleView = self.faceRectangleView else { return }
                    for label in faceRectangleView.subviews where label is UILabel {
                        label.frame = CGRect(x: .zero, y: bounds.height + 4, width: bounds.width, height: 48)
                    }
                })
            }
        }
    }
    
    //MARK: IBActions
    @IBAction func switchOnTapped() {
        switchDeviceInput()
    }
}

extension MainView: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let exifOrientation: CGImagePropertyOrientation
        if backCameraOn {
            exifOrientation = .right
        } else {
            exifOrientation = .leftMirrored
        }
        guard let requests = self.trackingRequests, !requests.isEmpty else {
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation)
            do {
                guard let detectRequests = self.detectionRequests else { return }
                try imageRequestHandler.perform(detectRequests)
                
                // Remove any face rectangle
                DispatchQueue.main.async {
                    self.faceRectangleView?.removeFromSuperview()
                    self.faceRectangleView = nil
                }
            } catch let error as NSError {
                NSLog("Failed to perform FaceRectangleRequest: %@", error)
            }
            return
        }
        
        do {
            try self.sequenceRequestHandler.perform(requests, on: pixelBuffer, orientation: exifOrientation)
        } catch let error as NSError {
            NSLog("Failed to perform SequenceRequest: %@", error)
        }
        
        var newTrackingRequests = [VNTrackObjectRequest]()
        for trackingRequest in requests {
            guard let results = trackingRequest.results else { return }
            guard let observation = results.first as? VNDetectedObjectObservation else { return }

            if !trackingRequest.isLastFrame {
                if observation.confidence > 0.3 {
                    trackingRequest.inputObservation = observation
                } else {
                    trackingRequest.isLastFrame = true
                }
                newTrackingRequests.append(trackingRequest)
            }
        }
        self.trackingRequests = newTrackingRequests

        if newTrackingRequests.isEmpty {
            print("#nothing to track, so abort")
            return
        }
        
        let faceRectangleRequest = VNDetectFaceRectanglesRequest { request, error in
            if (error != nil) {
                print("Face detect rectangle error")
            }

            guard let rectangleRequest = request as? VNDetectFaceRectanglesRequest, let results = rectangleRequest.results else { return }

            DispatchQueue.main.async {
                self.drawFaceObservations(results)
            }
        }

        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation)

        do {
            try imageRequestHandler.perform([faceRectangleRequest])
        } catch let error as NSError {
            NSLog("Failed to perform FaceLandmarkRequest: %@", error)
        }
    }
}
