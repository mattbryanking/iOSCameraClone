import AVFoundation
import UIKit

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
    
    var session: AVCaptureSession?
    let output = AVCapturePhotoOutput()
    var videoOutput = AVCaptureMovieFileOutput()
    var previewLayer = AVCaptureVideoPreviewLayer()
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    
    var burstModeTimer: Timer?
    
    @IBOutlet weak var CameraModeScroller: UIScrollView!
    @IBOutlet weak var cameraModeStackView: UIStackView!
    @IBOutlet weak var rotateCameraButton: UIButton!
    @IBOutlet weak var shutterButton: UIButton!
    @IBOutlet weak var cameraView: UIView!
    
    struct CameraConfig {
        enum CameraMode: CaseIterable, CustomStringConvertible {
            case timelapse, video, photo, burst, slomo
            
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
                case .slomo:
                    return "SLO-MO"
                }
            }
        }
        
        enum AspectRatio {
            case ratio4_3
            case ratio16_9
            case ratio1_1
            
            var size: CGSize {
                switch self {
                case .ratio4_3:
                    return CGSize(width: 4, height: 3)
                case .ratio16_9:
                    return CGSize(width: 16, height: 9)
                case .ratio1_1:
                    return CGSize(width: 1, height: 1)
                }
            }
        }
        
        var cameraMode: CameraMode
        var cameraPosition: AVCaptureDevice.Position
        var frameRate: Int
        var resolution: AVCaptureSession.Preset
        var aspectRatio: AspectRatio = .ratio1_1
        var zoom: CGFloat = 1.0
    }
    
    var cameraConfig = CameraConfig(cameraMode: .photo, cameraPosition: .back, frameRate: 30, resolution: .high)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        session = AVCaptureSession()
        
        setupCamera()
        setupCameraModeScroller()
        setupShutterButton()
        setupRotateCameraButton()
        updateUI()
        
        print("loaded!")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = cameraView.bounds
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CameraModeScroller.setContentOffset(CGPoint(x: CameraModeScroller.contentSize.width / 2 - CameraModeScroller.bounds.size.width / 2, y: 0), animated: false)
    }
    
    func setupCameraModeScroller() {
        let leadingConstraint = CameraModeScroller.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        let trailingConstraint = CameraModeScroller.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        let widthConstraint = CameraModeScroller.widthAnchor.constraint(equalTo: view.widthAnchor)
        
        NSLayoutConstraint.activate([leadingConstraint, trailingConstraint, widthConstraint])
        
        CameraModeScroller.showsVerticalScrollIndicator = false
        CameraModeScroller.showsHorizontalScrollIndicator = false
        
        for mode in CameraConfig.CameraMode.allCases {
            let button = UIButton()
            button.setTitle(mode.description, for: .normal)
            button.setTitleColor(.white, for: .normal)
            if button.title(for: .normal) == cameraConfig.cameraMode.description {
                button.setTitleColor(.systemYellow, for: .normal)
            }
            button.contentHorizontalAlignment = .center
            button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
            // add button tap action
            button.addTarget(self, action: #selector(cameraModeButtonUp(_:)), for: .touchUpInside)
            cameraModeStackView.addArrangedSubview(button)
        }
    }
    
    func setupShutterButton() {
        // programatically round button and add border
        shutterButton.layer.cornerRadius = shutterButton.frame.width / 2
        shutterButton.layer.masksToBounds = true
        shutterButton.layer.zPosition = 100
        
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
    }
    
    func setupRotateCameraButton() {
        rotateCameraButton.layer.cornerRadius = rotateCameraButton.frame.width / 2
        rotateCameraButton.layer.masksToBounds = true
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
        
        // asynchronously start camera preview feed to avoid freezing
        DispatchQueue.main.async {
            self.cameraView.layer.addSublayer(self.previewLayer)
        }
        
        // start camera in background thread to avoid slowness
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    func updateUI() {
        // change shutter button to red for video or white for camera
        if cameraConfig.cameraMode == .photo || cameraConfig.cameraMode == .burst {
            shutterButton.backgroundColor = UIColor.white
        }
        else {
            shutterButton.backgroundColor = UIColor.red
        }
        
        // change camera mode buttons to reflect selected
        if let stackView = CameraModeScroller.subviews.first as? UIStackView {
            for case let button as UIButton in stackView.arrangedSubviews {
                button.setTitleColor(button.title(for: .normal) == cameraConfig.cameraMode.description ? .systemYellow : .white, for: .normal)
            }
        }
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
    
    
    // master function for saving photo method/settings
    func takePhoto() {
        guard let session = session, session.isRunning else {
            print("could not access session")
            return
        }
        
        let photoSettings = AVCapturePhotoSettings()
        
        switch cameraConfig.cameraMode {
        case .photo:
            output.capturePhoto(with: photoSettings, delegate: self)
        case .burst:
            burstModeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let timer = self else { return }
                self?.feedbackGenerator.impactOccurred()
                let photoSettings = AVCapturePhotoSettings()
                timer.output.capturePhoto(with: photoSettings, delegate: timer)
            }
        default:
            break
        }
    }
    
    // master function to dertermine video method/settings
    func takeVideo() {
        
        // since videos are larger, their files need to be managed directly here.
        // we store them in temp memory, and specify an output path. photos
        // don't need this step as they're automatically handled in memory
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let dateString = dateFormatter.string(from: Date())
        let outputPath = NSTemporaryDirectory() + dateString + ".mov"
        let outputFileURL = URL(fileURLWithPath: outputPath)
        
        switch cameraConfig.cameraMode {
        case .video:
            videoOutput.startRecording(to: outputFileURL, recordingDelegate: self)
        case .slomo:
            break
        case .timelapse:
            break
        default:
            break
        }
    }
    
    
    @objc func cameraModeButtonUp(_ sender: UIButton) {
        guard let title = sender.title(for: .normal),
              let mode = CameraConfig.CameraMode.allCases.first(where: { $0.description == title }) else {
            return
        }
        
        cameraConfig.cameraMode = mode
        updateUI()
    }
    
    
    @IBAction func shutterButtonDown(_ sender: UIButton) {
        feedbackGenerator.impactOccurred()
        UIView.animate(withDuration: 0.3) {
            sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }
        
        if cameraConfig.cameraMode == .photo || cameraConfig.cameraMode == .burst {
            takePhoto()
        } else {
            if videoOutput.isRecording {
                videoOutput.stopRecording()
            } else {
                takeVideo()
            }
        }
    }
    
    @IBAction func shutterButtonUp(_ sender: UIButton) {
        feedbackGenerator.impactOccurred()
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform.identity
        }
        
        if cameraConfig.cameraMode == .burst {
            burstModeTimer?.invalidate()
            burstModeTimer = nil
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
    
    
    
    
    
    
    
    
    
    
    
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              var image = UIImage(data: imageData) else {
            print("could not create image data")
            return
        }
        
        image = cropImage(image: image)
        
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
        print("video recording started")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("video recording error: \(error.localizedDescription)")
        } else {
            print("video recording finished, saved at: \(outputFileURL.path)")
            UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, self, #selector(video(_:didFinishSavingWithError:contextInfo:)), nil)
        }
    }
    
    @objc func video(_ videoPath: String, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print("error saving video: \(error.localizedDescription)")
        } else {
            print("video saved successfully")
        }
    }
    
    
    func cropImage(image: UIImage) -> UIImage {
        let size = image.size
        let targetSize = cameraConfig.aspectRatio.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let newSize: CGSize
        
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width, height: size.width * targetSize.height / targetSize.width)
        } else {
            newSize = CGSize(width: size.height * targetSize.width / targetSize.height, height: size.height)
        }
        
        let rect = CGRect(x: (size.width - newSize.width) / 2, y: (size.height - newSize.height) / 2, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(x: -rect.origin.x, y: -rect.origin.y, width: size.width, height: size.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
    
}


