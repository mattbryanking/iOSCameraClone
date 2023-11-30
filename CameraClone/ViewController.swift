import AVFoundation
import Photos
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
    var videoTimer: Timer?
    var videoTimerSeconds = 0
    let focusIndicator = UIImageView()
    
    @IBOutlet weak var aspectRatioPickerView: UIPickerView!
    @IBOutlet weak var qualityPickerView: UIPickerView!
    @IBOutlet weak var flashPickerView: UIPickerView!
    @IBOutlet weak var videoTimerLabel: UILabel!
    @IBOutlet weak var CameraModeScroller: UIScrollView!
    @IBOutlet weak var cameraModeStackView: UIStackView!
    @IBOutlet weak var rotateCameraButton: UIButton!
    @IBOutlet weak var photosButton: UIButton!
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
        setupVideoTimerLabel()
        setupCameraModeScroller()
        setupShutterButton()
        setupRotateCameraButton()
        setupPhotosButton()
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
        aspectRatioPickerView.subviews.last?.isHidden = true
        flashPickerView.subviews.last?.isHidden = true
        qualityPickerView.subviews.last?.isHidden = true
    }
    
    func setupVideoTimerLabel() {
        videoTimerLabel.alpha = 0
        videoTimerLabel.layer.cornerRadius = 5
        videoTimerLabel.clipsToBounds = true
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
            button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
            
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
    
    func setupPhotosButton() {
        self.photosButton.imageView?.contentMode = .scaleAspectFill
        self.photosButton.imageView?.clipsToBounds = true
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        
        // if last camera roll file is video, grab thumbnail
        if let asset = fetchResult.firstObject {
            if asset.mediaType == .video {
                PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
                    guard let avAsset = avAsset else { return }
                    
                    avAsset.loadTracks(withMediaType: AVMediaType.video) { tracks, _ in
                        DispatchQueue.main.async {
                            if let _ = tracks?.first {
                                let imageGenerator = AVAssetImageGenerator(asset: avAsset)
                                imageGenerator.appliesPreferredTrackTransform = true
                                let time = CMTime(seconds: 0.0, preferredTimescale: 600)
                                do {
                                    let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                                    let image = UIImage(cgImage: cgImage)
                                    self.photosButton.setImage(image, for: .normal)
                                } catch {
                                }
                            }
                        }
                    }
                }
            } else if asset.mediaType == .image {
                PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 55, height: 55), contentMode: .aspectFit, options: nil) { image, _ in
                    DispatchQueue.main.async {
                        self.photosButton.setImage(image, for: .normal)
                    }
                }
            }
        }
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
            UIView.animate(withDuration: 0.2) {
                self.shutterButton.backgroundColor = UIColor.white
            }
        }
        else {
            UIView.animate(withDuration: 0.3) {
                self.shutterButton.backgroundColor = UIColor(red: 0.99, green: 0.27, blue: 0.27, alpha: 1.00)
            }
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
            print("session not initialized")
            return
        }
        
        session.stopRunning()
        session.beginConfiguration()
        
        if cameraConfig.cameraMode == .slomo {
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraConfig.cameraPosition) else {
                print("camera not available")
                return
            }
            configureForSlomo(device: camera)
        } else {
            session.sessionPreset = cameraConfig.quality.preset
        }
        
        session.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    func configureForSlomo(device: AVCaptureDevice) {
        
        var bestFormat: AVCaptureDevice.Format?
        var bestFrameRateRange: AVFrameRateRange?
        
        for format in device.formats {
            for range in format.videoSupportedFrameRateRanges {
                if range.maxFrameRate > bestFrameRateRange?.maxFrameRate ?? 0 {
                    bestFormat = format
                    bestFrameRateRange = range
                }
            }
        }
        
        if let bestFormat = bestFormat,
           let bestFrameRateRange = bestFrameRateRange {
            do {
                try device.lockForConfiguration()
                
                device.activeFormat = bestFormat
                
                let duration = bestFrameRateRange.minFrameDuration
                device.activeVideoMinFrameDuration = duration
                device.activeVideoMaxFrameDuration = duration
                
                device.unlockForConfiguration()
            } catch {
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
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraConfig.cameraPosition) else {
            return
        }
        
        let photoSettings = AVCapturePhotoSettings()
        
        let supportedFlashModes = output.supportedFlashModes

         switch cameraConfig.flash {
         case .auto:
             if supportedFlashModes.contains(.auto) {
                 photoSettings.flashMode = .auto
             }
         case .on:
             if supportedFlashModes.contains(.on) {
                 photoSettings.flashMode = .on
             }
         case .off:
             if supportedFlashModes.contains(.off) {
                 photoSettings.flashMode = .off
             }
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
    
    func takeVideo() {
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
                if camera.isTorchAvailable && camera.isTorchModeSupported(.on) {
                    camera.torchMode = .on
                }
            case .off:
                if camera.isTorchModeSupported(.off) {
                    camera.torchMode = .off
                }
            case .auto:
                if camera.isTorchModeSupported(.off) {
                    camera.torchMode = .off
                }
            }
            
            camera.unlockForConfiguration()
        } catch {
        }
        videoOutput.startRecording(to: outputFileURL, recordingDelegate: self)
    }
    
    // since this was created programatically, we can't use an IBAction
    @objc func cameraModeButtonUp(_ sender: UIButton) {
        guard let title = sender.title(for: .normal),
              let mode = CameraConfig.CameraMode.allCases.first(where: { $0.description == title }) else {
            return
        }
        
        cameraConfig.cameraMode = mode
        
        updateQuality()
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
                
                videoTimer?.invalidate()
                videoTimer = nil
                UIView.animate(withDuration: 0.5) {
                    self.videoTimerLabel.alpha = 0
                }
            } else {
                takeVideo()
                
                videoTimerLabel.alpha = 0
                UIView.animate(withDuration: 0.5) {
                    self.videoTimerLabel.alpha = 1.0
                }
                videoTimerSeconds = 0
                videoTimerLabel.text = "00:00"
                videoTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    self?.videoTimerSeconds += 1
                    let minutes = self!.videoTimerSeconds / 60
                    let remainingSeconds = self!.videoTimerSeconds % 60
                    self!.videoTimerLabel.text = String(format: "%02d:%02d", minutes, remainingSeconds)
                }
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
    
    @IBAction func photosButtonUp(_ sender: UIButton) {
        UIApplication.shared.open(URL(string:"photos-redirect://")!)
    }
    
    @IBAction func zoomPinchRecognizer(_ sender: UIPinchGestureRecognizer) {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraConfig.cameraPosition) else {
            print("could not access camera")
            return
        }
        
        if sender.state == .changed {
            do {
                try camera.lockForConfiguration()
                defer { camera.unlockForConfiguration() }
                
                let scaleFactor = sender.scale
                let newScaleFactor = camera.videoZoomFactor * scaleFactor
                
                camera.videoZoomFactor = max(min(newScaleFactor, camera.maxAvailableVideoZoomFactor), camera.minAvailableVideoZoomFactor)
                cameraConfig.zoom = camera.videoZoomFactor
                
                sender.scale = 1.0
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
            print("locked!")
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
            if cameraConfig.cameraMode == .slomo {
                Task {
                    await exportSloMo(originalVideoURL: outputFileURL)
                }
            }
            else if cameraConfig.cameraMode == .timelapse {
                Task {
                    await exportTimelapse(originalVideoURL: outputFileURL)
                }
            }
            else {
                UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, self, #selector(video(_:didFinishSavingWithError:contextInfo:)), nil)
            }
        }
    }
    
    func exportSloMo(originalVideoURL: URL) async {
        
        let asset = AVURLAsset(url: originalVideoURL)
        let sloMoComposition = AVMutableComposition()
        
        do {
            guard let srcVideoTrack = try await asset.loadTracks(withMediaType: .video).first else { return }
            let sloMoVideoTrack = sloMoComposition.addMutableTrack(withMediaType: .video,
                                                                   preferredTrackID: kCMPersistentTrackID_Invalid)
            do {
                let preferredTransform = try await srcVideoTrack.load(.preferredTransform)
                sloMoVideoTrack?.preferredTransform = preferredTransform
                try await sloMoVideoTrack?.insertTimeRange(CMTimeRangeMake(start: .zero, duration: asset.load(.duration)),
                                                           of: srcVideoTrack,
                                                           at: .zero)
            } catch {
                print("error inserting time range")
                return
            }
            
            let newDuration = try await CMTimeMultiplyByFloat64( asset.load(.duration), multiplier: 2)
            try await sloMoVideoTrack?.scaleTimeRange(CMTimeRangeMake(start: .zero, duration: asset.load(.duration)), toDuration: newDuration)
            
            guard let exportSession = AVAssetExportSession(asset: sloMoComposition, presetName: AVAssetExportPresetPassthrough) else {
                print("could not create export session.")
                return
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMddHHmmss"
            let dateString = dateFormatter.string(from: Date())
            let outputPath = NSTemporaryDirectory() + dateString + "slowmo.mov"
            let outputFileURL = URL(fileURLWithPath: outputPath)
            exportSession.outputURL = outputFileURL
            exportSession.outputFileType = .mov
            
            exportSession.exportAsynchronously {
                DispatchQueue.main.async {
                    switch exportSession.status {
                    case .completed:
                        UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, nil, nil, nil)
                        print("slomo recording finished, saved at: \(outputFileURL.path)")
                    case .failed:
                        print("export failed")
                    default:
                        break
                    }
                }
            }
        } catch {
            print("an error occurred")
        }
    }
    
    
    func exportTimelapse(originalVideoURL: URL) async {
        
        let asset = AVURLAsset(url: originalVideoURL)
        let timelapseComposition = AVMutableComposition()
        
        do {
            guard let srcVideoTrack = try await asset.loadTracks(withMediaType: .video).first else { return }
            let timelapseVideoTrack = timelapseComposition.addMutableTrack(withMediaType: .video,
                                                                           preferredTrackID: kCMPersistentTrackID_Invalid)
            do {
                let preferredTransform = try await srcVideoTrack.load(.preferredTransform)
                timelapseVideoTrack?.preferredTransform = preferredTransform
                try await timelapseVideoTrack?.insertTimeRange(CMTimeRangeMake(start: .zero, duration: asset.load(.duration)),
                                                               of: srcVideoTrack,
                                                               at: .zero)
            } catch {
                print("error inserting time range")
                return
            }
            
            let newDuration = try await CMTimeMultiplyByFloat64(asset.load(.duration), multiplier: 1 / 20)
            try await timelapseVideoTrack?.scaleTimeRange(CMTimeRangeMake(start: .zero, duration: asset.load(.duration)), toDuration: newDuration)
            
            guard let exportSession = AVAssetExportSession(asset: timelapseComposition, presetName: AVAssetExportPresetPassthrough) else {
                print("could not create export session.")
                return
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMddHHmmss"
            let dateString = dateFormatter.string(from: Date())
            let outputPath = NSTemporaryDirectory() + dateString + "timelapse.mov"
            let outputFileURL = URL(fileURLWithPath: outputPath)
            exportSession.outputURL = outputFileURL
            exportSession.outputFileType = .mov
            
            exportSession.exportAsynchronously {
                DispatchQueue.main.async {
                    switch exportSession.status {
                    case .completed:
                        UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, nil, nil, nil)
                        print("timelapse recording finished, saved at: \(outputFileURL.path)")
                    case .failed:
                        print("export failed")
                    default:
                        break
                    }
                }
            }
        } catch {
            print("an error occurred")
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
