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
    
    private var faceRectangleView: UIView?
    private var sequenceRequestHandler = VNSequenceRequestHandler()
    
    private lazy var faceRecognitionRequest: VNCoreMLRequest = {
        do {
            if #available(iOS 12.0, *) {
                let configModel = MLModelConfiguration()
                let faceRecognitionModel = try FaceRecognitionDetection(configuration: configModel).model
                let model = try VNCoreMLModel(for: faceRecognitionModel)
                let faceRecognitionRequest = VNCoreMLRequest(model: model) { [weak self] request, error in
                    guard let faceObservations = request.results as? [VNRecognizedObjectObservation] else { return }
                    self?.drawFaceObservations(faceObservations)
                }
                faceRecognitionRequest.imageCropAndScaleOption = .centerCrop
                return faceRecognitionRequest
            } else {
                fatalError("Failed to open model due to the OS version")
            }
        } catch {
            fatalError("Failed to open model")
        }
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
    
    private func resetBoundingBox() {
        DispatchQueue.main.async {
            self.view.subviews.forEach { boundingBox in
                if !(boundingBox is UIButton) {
                    boundingBox.removeFromSuperview()
                }
            }
        }
    }
    
    @available(iOS 12.0, *)
    private func drawFaceObservations(_ faceObservations: [VNRecognizedObjectObservation]) {
        resetBoundingBox()
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -self.previewLayer.bounds.height)
        let scale = CGAffineTransform.identity.scaledBy(x: self.previewLayer.bounds.width, y: self.previewLayer.bounds.height)
        for faceObservation in faceObservations {
            let bounds = faceObservation.boundingBox.applying(scale).applying(transform)
            DispatchQueue.main.async {
                self.faceRectangleView = UIView(frame: bounds)
                self.faceRectangleView?.backgroundColor = .clear
                self.faceRectangleView?.layer.borderWidth = 3
                self.faceRectangleView?.layer.borderColor = UIColor.systemGreen.cgColor
                guard let boundingBoxView = self.faceRectangleView else { return }
                let labelFrame = CGRect(x: .zero, y: -48, width: bounds.width, height: 48)
                let labelName = UILabel(frame: labelFrame)
                let confidence = Int((faceObservation.labels[0].confidence / 1.0) * 100)
                labelName.textAlignment = .left
                labelName.numberOfLines = 2
                labelName.text = faceObservation.labels[0].identifier + " (\(confidence)%)"
                labelName.font = UIFont.boldSystemFont(ofSize: 22.0)
                labelName.textColor = .systemGreen
                labelName.backgroundColor = .clear
                boundingBoxView.addSubview(labelName)
                self.view.addSubview(boundingBoxView)
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
        let imageHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation)
        do {
            try imageHandler.perform([faceRecognitionRequest])
        } catch {
            resetBoundingBox()
        }
    }
}
