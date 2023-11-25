import AVFoundation
import UIKit

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
    
    enum Flash: CaseIterable, CustomStringConvertible {
        case auto, on, off
        
        var description: String {
            switch self {
            case .auto:
                return "AUTO"
            case .on:
                return "ON"
            case .off:
                return "OFF"
            }
        }
    }
    
    enum Quality: CaseIterable, CustomStringConvertible {
        case max, med, low
        
        var preset: AVCaptureSession.Preset {
            switch self {
            case .max:
                return .hd4K3840x2160
            case .med:
                return .hd1920x1080
            case .low:
                return .vga640x480
            }
        }
        
        var description: String {
            switch self {
            case .max:
                return "MAX"
            case .med:
                return "MED"
            case .low:
                return "LOW"
            }
        }
    }
    
    enum AspectRatio: CaseIterable, CustomStringConvertible{
        case full, ratio4_3, ratio16_9, ratio1_1
        
        var size: CGSize {
            switch self {
            case .full:
                return CGSize()
            case .ratio4_3:
                return CGSize(width: 4, height: 3)
            case .ratio16_9:
                return CGSize(width: 16, height: 9)
            case .ratio1_1:
                return CGSize(width: 1, height: 1)
            }
        }
        
        var description: String {
            switch self {
            case .full:
                return "FULL"
            case .ratio4_3:
                return "4:3"
            case .ratio16_9:
                return "16:9"
            case .ratio1_1:
                return "1:1"
            }
        }
    }
    
    var cameraMode: CameraMode = .photo
    var cameraPosition: AVCaptureDevice.Position = .back
    var flash: Flash = .auto
    var quality: Quality = .max
    var aspectRatio: AspectRatio = .full
    var zoom: CGFloat = 1.0
}

var cameraConfig = CameraConfig()

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
    
    var session: AVCaptureSession?
    let output = AVCapturePhotoOutput()
    var videoOutput = AVCaptureMovieFileOutput()
    var previewLayer = AVCaptureVideoPreviewLayer()
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    var burstModeTimer: Timer?
    let focusIndicator = UIImageView()
    
    @IBOutlet weak var aspectRatioPickerView: UIPickerView!
    @IBOutlet weak var qualityPickerView: UIPickerView!
    @IBOutlet weak var flashPickerView: UIPickerView!
    @IBOutlet weak var CameraModeScroller: UIScrollView!
    @IBOutlet weak var cameraModeStackView: UIStackView!
    @IBOutlet weak var rotateCameraButton: UIButton!
    @IBOutlet weak var shutterButton: UIButton!
    @IBOutlet weak var shutterRing: UIButton!
    @IBOutlet weak var cameraView: UIView!
    
    let aspectRatioDataSourceDelegate = AspectRatioPickerDataSourceDelegate()
    
    let qualityDataSourceDelegate = QualityPickerDataSourceDelegate()
    
    let flashDataSourceDelegate = FlashPickerDataSourceDelegate()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        session = AVCaptureSession()
        
        setupCamera()
        setupCameraModeScroller()
        setupShutterButton()
        setupRotateCameraButton()
        setupFocusIndicator()
        setupAspectRatioPickerView()
        setupQualityPickerView()
        setupFlashPickerView()
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
        shutterButton.layer.cornerRadius = shutterButton.frame.width / 2
        shutterButton.layer.masksToBounds = true
        
        shutterRing.layer.cornerRadius = shutterRing.frame.width / 2
        shutterRing.layer.borderColor = UIColor.white.cgColor
        shutterRing.layer.borderWidth = 4
        shutterRing.layer.masksToBounds = true
    }
    
    func setupRotateCameraButton() {
        rotateCameraButton.layer.cornerRadius = rotateCameraButton.frame.width / 2
        rotateCameraButton.layer.masksToBounds = true
    }
    
    func setupFocusIndicator() {
        focusIndicator.image = UIImage(named: "FocusIcon")
        focusIndicator.contentMode = .scaleAspectFit
        focusIndicator.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        focusIndicator.alpha = 0
        focusIndicator.layer.zPosition = 100
        cameraView.addSubview(focusIndicator)
    }
    
    func setupAspectRatioPickerView() {
        aspectRatioPickerView.dataSource = aspectRatioDataSourceDelegate
        aspectRatioPickerView.delegate = aspectRatioDataSourceDelegate
    }
    
    func setupQualityPickerView() {
        qualityPickerView.dataSource = qualityDataSourceDelegate
        qualityPickerView.delegate = qualityDataSourceDelegate
        
        qualityDataSourceDelegate.onQualityChange = { [weak self] newQuality in
            self?.updateQuality()
        }
    }
    
    func setupFlashPickerView() {
        flashPickerView.dataSource =
        flashDataSourceDelegate
        flashPickerView.delegate =
        flashDataSourceDelegate
    }
    
    func setupCamera() {
        session = AVCaptureSession()
        guard let session = session else { return }
        
        session.sessionPreset = cameraConfig.quality.preset
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraConfig.cameraPosition) else {
            print("\(cameraConfig.cameraPosition) camera unavailable")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            session.addInput(input)
            session.addOutput(output)
            session.addOutput(videoOutput)
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
    
    func updateQuality() {
        guard let session = self.session else {
            print("Session not initialized")
            return
        }
        
        print(cameraConfig.quality.description)
        
        session.stopRunning()
        session.beginConfiguration()
        session.sessionPreset = cameraConfig.quality.preset
        session.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    func switchCamera() {
        guard let session = session else { return }
        
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else { return }
        
        cameraConfig.cameraPosition = (cameraConfig.cameraPosition == .front) ? .back : .front
        
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraConfig.cameraPosition) else {
            print("could not find the camera for position: \(cameraConfig.cameraPosition)")
            return
        }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            
            session.removeInput(currentInput)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
            } else {
                print("could not add new input")
                return
            }
        } catch {
            print("error switching cameras: \(error)")
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
        
        switch cameraConfig.flash {
        case .auto:
            photoSettings.flashMode = .auto
        case .on:
            photoSettings.flashMode = .on
        case .off:
            photoSettings.flashMode = .off
        }
        
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
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraConfig.cameraPosition) else {
            return
        }
        
        do {
            try camera.lockForConfiguration()
            
            switch cameraConfig.flash {
            case .on:
                if camera.isTorchAvailable {
                    camera.torchMode = .on
                }
            case .off:
                camera.torchMode = .off
            case .auto:
                camera.torchMode = .off
            }
            
            camera.unlockForConfiguration()
        } catch {
        }
        
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
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraConfig.cameraPosition) else {
            print("pinch recognizer could not access camera")
            return
        }
        
        if sender.state == .changed {
            let pinchVelocityDividerFactor: CGFloat = 1.0
            
            do {
                try camera.lockForConfiguration()
                defer { camera.unlockForConfiguration() }
                
                let newScaleFactor = camera.videoZoomFactor + atan2(sender.velocity, pinchVelocityDividerFactor)
                camera.videoZoomFactor = max(min(newScaleFactor, camera.maxAvailableVideoZoomFactor), camera.minAvailableVideoZoomFactor)
                cameraConfig.zoom = camera.videoZoomFactor
                
            } catch {
                print("could not lock camera for config")
            }
        }
    }
    
    @IBAction func tapFocusRecognizer(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: cameraView)
        let focusPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: location)
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraConfig.cameraPosition) else {
            print("tap recognizer could not access camera")
            return
        }
        
        focusIndicator.center = location
        focusIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        UIView.animateKeyframes(withDuration: 1, delay: 0, options: [], animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.05) {
                self.focusIndicator.alpha = 1
                self.focusIndicator.transform = CGAffineTransform.identity
            }
            
            for i in 0...2 {
                let startTime = Double(i) * 1.0 / 3.0
                
                UIView.addKeyframe(withRelativeStartTime: startTime, relativeDuration: 1.0 / 6.0) {
                    self.focusIndicator.alpha = 0.5
                }
                
                UIView.addKeyframe(withRelativeStartTime: startTime + 1.0 / 6.0, relativeDuration: 1.0 / 6.0) {
                    self.focusIndicator.alpha = 1
                }
            }
            
            UIView.addKeyframe(withRelativeStartTime: 5.0 / 6.0, relativeDuration: 1.0 / 6.0) {
                self.focusIndicator.alpha = 0
            }
        })
        
        do {
            try camera.lockForConfiguration()
            
            if camera.isFocusPointOfInterestSupported && camera.isFocusModeSupported(.autoFocus) {
                camera.focusPointOfInterest = focusPoint
                if camera.isFocusModeSupported(.continuousAutoFocus) {
                    camera.focusMode = .continuousAutoFocus
                }
                else {
                    camera.focusMode = .autoFocus
                }
            }
            
            if camera.isExposurePointOfInterestSupported && camera.isExposureModeSupported(.autoExpose) {
                camera.exposurePointOfInterest = focusPoint
                
                if camera.isExposureModeSupported(.continuousAutoExposure) {
                    camera.exposureMode = .continuousAutoExposure
                }
                else {
                    camera.exposureMode = .autoExpose
                }
            }
            
            camera.unlockForConfiguration()
        } catch {
            print("could not lock camera for config")
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
        if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraConfig.cameraPosition), camera.isTorchActive {
            do {
                try camera.lockForConfiguration()
                camera.torchMode = .off
                camera.unlockForConfiguration()
            } catch {
            }
        }
        
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
        if cameraConfig.aspectRatio == .full {
            return image
        }
        
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



class AspectRatioPickerDataSourceDelegate: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return CameraConfig.AspectRatio.allCases.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return CameraConfig.AspectRatio.allCases[row].description
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let title = self.pickerView(pickerView, titleForRow: row, forComponent: component) ?? ""
        let isSelected = row == pickerView.selectedRow(inComponent: component)
        let titleColor = isSelected ? UIColor.systemYellow : UIColor.white
        return NSAttributedString(string: title, attributes: [NSAttributedString.Key.foregroundColor: titleColor, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)])
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        pickerView.reloadAllComponents()
        let selectedAspectRatio = CameraConfig.AspectRatio.allCases[row]
        cameraConfig.aspectRatio = selectedAspectRatio
    }
}

class QualityPickerDataSourceDelegate: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
    var onQualityChange: ((CameraConfig.Quality) -> Void)?
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return CameraConfig.Quality.allCases.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return CameraConfig.Quality.allCases[row].description
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let title = self.pickerView(pickerView, titleForRow: row, forComponent: component) ?? ""
        let isSelected = row == pickerView.selectedRow(inComponent: component)
        let titleColor = isSelected ? UIColor.systemYellow : UIColor.white
        return NSAttributedString(string: title, attributes: [NSAttributedString.Key.foregroundColor: titleColor, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)])
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        pickerView.reloadAllComponents()
        let selectedQuality = CameraConfig.Quality.allCases[row]
        cameraConfig.quality = selectedQuality
        print(cameraConfig.quality.description)
        onQualityChange?(selectedQuality)
    }
}

class FlashPickerDataSourceDelegate: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return CameraConfig.Flash.allCases.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return CameraConfig.Flash.allCases[row].description
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let title = self.pickerView(pickerView, titleForRow: row, forComponent: component) ?? ""
        let isSelected = row == pickerView.selectedRow(inComponent: component)
        let titleColor = isSelected ? UIColor.systemYellow : UIColor.white
        return NSAttributedString(string: title, attributes: [NSAttributedString.Key.foregroundColor: titleColor, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)])
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        pickerView.reloadAllComponents()
        let selectedFlash = CameraConfig.Flash.allCases[row]
        cameraConfig.flash = selectedFlash
    }
}
