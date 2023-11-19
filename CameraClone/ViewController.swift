import AVFoundation
import UIKit

class ViewController: UIViewController {
    
    var session: AVCaptureSession?
    let output = AVCapturePhotoOutput()
    var videoOutput = AVCaptureMovieFileOutput()
    var previewLayer = AVCaptureVideoPreviewLayer()
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    
    @IBOutlet weak var CameraModeScroller: UIScrollView!
    @IBOutlet weak var rotateCameraButton: UIButton!
    @IBOutlet weak var shutterButton: UIButton!
    @IBOutlet weak var cameraView: UIView!
    
    struct CameraConfig {
        enum CameraMode: CaseIterable, CustomStringConvertible {
            case timelapse, video, photo, burst, portrait
            
            var description: String {
                switch self {
                case .timelapse:
                    return "TIMELAPSE"
                case .video:
                    return "VIDEO"
                case .photo:
                    return "PHOTO"
                case .burst:
                    return "BURST"
                case .portrait:
                    return "PORTRAIT"
                }
            }
        }
        
        var cameraMode: CameraMode
        var cameraPosition: AVCaptureDevice.Position
        var frameRate: Int
        var resolution: AVCaptureSession.Preset
        var isHDR: Bool
        var isNightmode: Bool
        var zoom: CGFloat = 1.0
    }
    
    var cameraConfig = CameraConfig(cameraMode: .video, cameraPosition: .back, frameRate: 30, resolution: .high, isHDR: false, isNightmode: false)
    
    var pickerRotationAngle : CGFloat!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        session = AVCaptureSession()
        
        setupCamera()
        updateUI()
        
        let leadingConstraint = CameraModeScroller.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        let trailingConstraint = CameraModeScroller.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        let widthConstraint = CameraModeScroller.widthAnchor.constraint(equalTo: view.widthAnchor)
        
        NSLayoutConstraint.activate([leadingConstraint, trailingConstraint, widthConstraint])
        
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 40
        stackView.distribution = .equalSpacing
        CameraModeScroller.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: CameraModeScroller.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: CameraModeScroller.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: CameraModeScroller.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: CameraModeScroller.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: CameraModeScroller.heightAnchor)
        ])
        
        CameraModeScroller.showsVerticalScrollIndicator = false
        CameraModeScroller.showsHorizontalScrollIndicator = false
        
        for mode in CameraConfig.CameraMode.allCases {
            let button = UIButton()
            button.setTitle(mode.description, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.contentHorizontalAlignment = .center
            stackView.addArrangedSubview(button)
        }
        
        // programatically round button and add border
        shutterButton.layer.cornerRadius = shutterButton.frame.width / 2
        shutterButton.layer.masksToBounds = true
        shutterButton.layer.zPosition = 100
        
        rotateCameraButton.layer.cornerRadius = rotateCameraButton.frame.width / 2
        rotateCameraButton.layer.masksToBounds = true
        
        // add ring behind button
        let circleLayer = CAShapeLayer()
        let circleDiameter: CGFloat = shutterButton.frame.width * 1.125
        let buttonCenterInCameraView = cameraView.convert(shutterButton.center, from: shutterButton.superview)
        let circlePath = UIBezierPath(ovalIn: CGRect(x: buttonCenterInCameraView.x - circleDiameter / 2, y: buttonCenterInCameraView.y - circleDiameter / 2, width: circleDiameter, height: circleDiameter))
        
        circleLayer.path = circlePath.cgPath
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = UIColor.white.cgColor
        circleLayer.lineWidth = 4
        circleLayer.zPosition = 100
        
        if let shutterButtonIndex = cameraView.layer.sublayers?.firstIndex(of: shutterButton.layer) {
            cameraView.layer.insertSublayer(circleLayer, at: UInt32(shutterButtonIndex))
        } else {
            cameraView.layer.addSublayer(circleLayer)
        }
        
        print("loaded!")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = cameraView.bounds
        
        CameraModeScroller.setContentOffset(CGPoint(x: CameraModeScroller.contentSize.width / 2 - CameraModeScroller.bounds.size.width / 2, y: 0), animated: false)
        
    }
    
    func setupCamera() {
        session = AVCaptureSession()
        guard let session = session else { return }
        
        session.sessionPreset = cameraConfig.resolution
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraConfig.cameraPosition) else {
            print("\(cameraConfig.cameraPosition) camera unavailable")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                print("could not add input to camera session")
                return
            }
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            } else {
                print("could not add output to camera session")
                return
            }
            
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            } else {
                print("could not add video output to camera session")
                return
            }
        } catch {
            print("could not initialize camera for position: \(cameraConfig.cameraPosition)")
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = cameraView.bounds
        
        DispatchQueue.main.async {
            self.cameraView.layer.addSublayer(self.previewLayer)
        }
        
        // start camera in background thread to avoid slowness
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    // change shutter button to red for video
    func updateUI() {
        self.shutterButton.backgroundColor = self.cameraConfig.cameraMode == .video ? UIColor.red : UIColor.white
    }
    
    func switchCamera() {
        guard let session = session else { return }
        
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else { return }
        
        cameraConfig.cameraPosition = (cameraConfig.cameraPosition == .front) ? .back : .front
        
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraConfig.cameraPosition) else {
            print("Could not find the camera for position: \(cameraConfig.cameraPosition)")
            return
        }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            
            session.removeInput(currentInput)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
            } else {
                print("Could not add new input")
                return
            }
        } catch {
            print("Error switching cameras: \(error)")
            return
        }
    }
    
    
    // master function for saving photo input
    func takePhoto() {
        guard let session = session, session.isRunning else {
            print("could not access session")
            return
        }
        
        let photoSettings = AVCapturePhotoSettings()
        
        // handle hdr
        
        // handle various camera modes
        switch cameraConfig.cameraMode {
        case .photo:
            break
        case .portrait:
            break
        case .burst:
            break
        default:
            break
        }
        
        // apply zoom
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraConfig.cameraPosition) {
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = max(min(cameraConfig.zoom, device.maxAvailableVideoZoomFactor), device.minAvailableVideoZoomFactor)
                device.unlockForConfiguration()
            } catch {
                print("error setting zoom: \(error)")
            }
        }
        
        output.capturePhoto(with: photoSettings, delegate: self)
    }
    
    @IBAction func shutterButtonDown(_ sender: UIButton) {
        feedbackGenerator.impactOccurred()
        UIView.animate(withDuration: 0.3) {
            sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }
    }
    
    @IBAction func shutterButtonUp(_ sender: UIButton) {
        feedbackGenerator.impactOccurred()
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform.identity
        }
        
        if cameraConfig.cameraMode == .video {
            if videoOutput.isRecording {
                videoOutput.stopRecording()
            } else {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMddHHmmss"
                let dateString = dateFormatter.string(from: Date())
                let outputPath = NSTemporaryDirectory() + "output_" + dateString + ".mov"
                let outputFileURL = URL(fileURLWithPath: outputPath)
                videoOutput.startRecording(to: outputFileURL, recordingDelegate: self)
            }
        } else {
            takePhoto()
        }
    }
    
    @IBAction func rotateButtonUp(_ sender: UIButton) {
        switchCamera()
    }
    
    @IBAction func zoomPinchRecognizer(_ sender: UIPinchGestureRecognizer) {
        
        print("zooming!!")
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraConfig.cameraPosition) else {
            print("pinch recognizer could not access camera")
            return
        }
        
        if sender.state == .changed {
            let pinchVelocityDividerFactor: CGFloat = 1.0
            
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                
                let newScaleFactor = device.videoZoomFactor + atan2(sender.velocity, pinchVelocityDividerFactor)
                device.videoZoomFactor = max(min(newScaleFactor, device.maxAvailableVideoZoomFactor), device.minAvailableVideoZoomFactor)
                cameraConfig.zoom = device.videoZoomFactor
                
            } catch {
                print("could not lock device for config")
            }
        }
    }
}

extension ViewController: AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("could not create image data")
            return
        }
        
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print("could not save photo: \(error.localizedDescription)")
        } else {
            print("photo saved successfully")
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("Video recording started")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Video recording error: \(error.localizedDescription)")
        } else {
            print("Video recording finished, saved at: \(outputFileURL.path)")
            UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, self, #selector(video(_:didFinishSavingWithError:contextInfo:)), nil)
        }
    }
    
    @objc func video(_ videoPath: String, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print("Error saving video: \(error.localizedDescription)")
        } else {
            print("Video saved successfully")
        }
    }
}


