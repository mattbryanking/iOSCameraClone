import AVFoundation
import Photos
import UIKit

struct CameraConfig {
    
    // specifies which type of photo/video you're capturing
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
    
    // specifies state of camera flash
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
    
    // specifies resolution + framerate
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
    
    // specifies output cropping for photos
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
    
    // default app settings
    var cameraMode: CameraMode = .photo
    var cameraPosition: AVCaptureDevice.Position = .back
    var flash: Flash = .auto
    var quality: Quality = .max
    var aspectRatio: AspectRatio = .full
    var zoom: CGFloat = 1.0
}

// stores current user settings, referenced by various camera calls
var cameraConfig = CameraConfig()

// MARK: - CLASS - ViewController
// ----------------------------------
//
// Main class for camera app view
// controller
//
// ----------------------------------

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
    
    // media capture "controller", manages data flow from camera to output
    var session: AVCaptureSession?
    
    // used to capture images, processes and formats data to be saved
    let output = AVCapturePhotoOutput()
    
    // used to capture video, processes and formats data to be saved
    var videoOutput = AVCaptureMovieFileOutput()
    
    // subclass of CALayer, used to display camera feed
    var previewLayer = AVCaptureVideoPreviewLayer()
    
    // iOS haptic feedback generator
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    
    // used to control duration between captures in burst mode
    var burstModeTimer: Timer?
    
    // used to keep track of recording duration
    var videoTimer: Timer?
    
    // current video duration in seconds
    var videoTimerSeconds = 0
    
    // icon to indicate user focus - created programatically
    let focusIndicator = UIImageView()
    
    // allows user to select photo aspect ratio
    @IBOutlet weak var aspectRatioPickerView: UIPickerView!
    
    // allows user to select photo/video quality
    @IBOutlet weak var qualityPickerView: UIPickerView!
    
    // allows user to specify photo flash state
    @IBOutlet weak var flashPickerView: UIPickerView!
    
    // UI element to show current view duration
    @IBOutlet weak var videoTimerLabel: UILabel!
    
    // allows user to scroll through camera capture modes
    @IBOutlet weak var CameraModeScroller: UIScrollView!
    
    // alligns camera capture modes horizontally
    @IBOutlet weak var cameraModeStackView: UIStackView!
    
    // allows user to switch between front and back cameras
    @IBOutlet weak var rotateCameraButton: UIButton!
    
    // UI element to redirect user to photo album
    @IBOutlet weak var photosButton: UIButton!
    
    // UI element to captures photo or video
    @IBOutlet weak var shutterButton: UIButton!
    
    // outer ring for shutter button
    @IBOutlet weak var shutterRing: UIButton!
    
    // live camera feed
    @IBOutlet weak var cameraView: UIView!
    
    // black view to simulate camera shutter
    @IBOutlet weak var fadeView: UIView!
    
    // manages data and user interactions for the aspect ratio pickerview
    let aspectRatioDataSourceDelegate = AspectRatioPickerDataSourceDelegate()
    
    // manages data and user interactions for the camera quality pickerview
    let qualityDataSourceDelegate = QualityPickerDataSourceDelegate()
    
    // manages data and user interactions for the camera flash pickerview
    let flashDataSourceDelegate = FlashPickerDataSourceDelegate()
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        // instantiate and set up app components
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
    }
    
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // aligns preview layer with camera view UIView
        previewLayer.frame = cameraView.bounds
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // scrolls camera modes halfway, effectively centering them
        CameraModeScroller.setContentOffset(CGPoint(x: CameraModeScroller.contentSize.width / 2 - CameraModeScroller.bounds.size.width / 2, y: 0), animated: false)
        
        // UI cleanup - hides gray background
        aspectRatioPickerView.subviews.last?.isHidden = true
        flashPickerView.subviews.last?.isHidden = true
        qualityPickerView.subviews.last?.isHidden = true
    }
    
    // MARK: - Setup and Updates
    // ----------------------------------
    //
    // Contains functions to set up or
    // update camera and UI elements
    //
    // ----------------------------------
    
    func setupVideoTimerLabel() {
        
        // make video label start as invisible and round corners
        videoTimerLabel.alpha = 0
        videoTimerLabel.layer.cornerRadius = 5
        videoTimerLabel.clipsToBounds = true
    }
    
    func setupCameraModeScroller() {
        // programatically set up constraints
        let leadingConstraint = CameraModeScroller.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        let trailingConstraint = CameraModeScroller.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        let widthConstraint = CameraModeScroller.widthAnchor.constraint(equalTo: view.widthAnchor)
        
        NSLayoutConstraint.activate([leadingConstraint, trailingConstraint, widthConstraint])
        
        // hide scrollbars
        CameraModeScroller.showsVerticalScrollIndicator = false
        CameraModeScroller.showsHorizontalScrollIndicator = false
        
        // programatically add buttons for each camera mode
        for mode in CameraConfig.CameraMode.allCases {
            let button = UIButton()
            button.setTitle(mode.description, for: .normal)
            button.setTitleColor(.white, for: .normal)
            
            // set initially selected button as yellow
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
        // make shutter button circle
        shutterButton.layer.cornerRadius = shutterButton.frame.width / 2
        shutterButton.layer.masksToBounds = true
        
        // make shutter button ring circle
        shutterRing.layer.cornerRadius = shutterRing.frame.width / 2
        shutterRing.layer.borderColor = UIColor.white.cgColor
        shutterRing.layer.borderWidth = 4
        shutterRing.layer.masksToBounds = true
    }
    
    func setupRotateCameraButton() {
        // make rotate camera button circle
        rotateCameraButton.layer.cornerRadius = rotateCameraButton.frame.width / 2
        rotateCameraButton.layer.masksToBounds = true
    }
    
    func setupPhotosButton() {
        // make photo fill button
        
        // sort by creation date to pull most recent photo/video
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        
        if let asset = fetchResult.firstObject {
            // if last camera roll file is video, create thumbnail
            if asset.mediaType == .video {
                PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
                    guard let avAsset = avAsset else { return }
                    
                    avAsset.loadTracks(withMediaType: AVMediaType.video) { tracks, _ in
                        DispatchQueue.main.async {
                            if let _ = tracks?.first {
                                
                                // create image thumbnail for first frame of video
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
            }
            // if last camera roll file is image, grab image file
            else if asset.mediaType == .image {
                let buttonSize = self.photosButton.frame.size
                PHImageManager.default().requestImage(for: asset, targetSize: buttonSize, contentMode: .aspectFit, options: nil) { image, _ in
                    DispatchQueue.main.async {
                        self.photosButton.setImage(image, for: .normal)
                    }
                }
            }
        }
    }
    
    // create tap to focus indicator
    func setupFocusIndicator() {
        focusIndicator.image = UIImage(named: "FocusIcon")
        focusIndicator.contentMode = .scaleAspectFit
        focusIndicator.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        focusIndicator.alpha = 0
        focusIndicator.layer.zPosition = 100
        cameraView.addSubview(focusIndicator)
    }
    
    func setupAspectRatioPickerView() {
        // configures aspect ratio picker view with its dataSource and delegate.
        aspectRatioPickerView.dataSource = aspectRatioDataSourceDelegate
        aspectRatioPickerView.delegate = aspectRatioDataSourceDelegate
    }
    
    func setupQualityPickerView() {
        // configures camera quality picker view with its dataSource and delegate.
        qualityPickerView.dataSource = qualityDataSourceDelegate
        qualityPickerView.delegate = qualityDataSourceDelegate
        
        // calls updateQuality when a new quality is selected
        qualityDataSourceDelegate.onQualityChange = { [weak self] newQuality in
            self?.updateQuality()
        }
    }
    
    func setupFlashPickerView() {
        // configures camera flash picker view with its dataSource and delegate.
        flashPickerView.dataSource =
        flashDataSourceDelegate
        flashPickerView.delegate =
        flashDataSourceDelegate
    }
    
    func setupCamera() {
        session = AVCaptureSession()
        guard let session = session else {
            print("could not access session")
            return }
        
        // set session quality based on cameraConfig
        session.sessionPreset = cameraConfig.quality.preset
        
        // check if camera is available
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraConfig.cameraPosition) else {
            print("\(cameraConfig.cameraPosition) camera unavailable")
            return
        }
        
        // check if mic is available
        guard let microphone = AVCaptureDevice.default(for: .audio) else {
            print("audio device unavailable")
            return
        }
        
        do {
            // create and add photo/video input from camera to session
            let input = try AVCaptureDeviceInput(device: camera)
            let audioInput = try AVCaptureDeviceInput(device: microphone)
            
            // add image/video input
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            // add audio input
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }
            
            // add image output
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            // add video output
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }

        } catch {
            print("could not initialize camera for position: \(cameraConfig.cameraPosition)")
            return
        }
        
        // create preview layer (camera feed) from session data
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
        
        // change selected camera mode button to yellow
        if let stackView = CameraModeScroller.subviews.first as? UIStackView {
            for case let button as UIButton in stackView.arrangedSubviews {
                button.setTitleColor(button.title(for: .normal) == cameraConfig.cameraMode.description ? .systemYellow : .white, for: .normal)
            }
        }
    }
    
    func updateQuality() {
        guard let session = session else {
            print("could not access session")
            return
        }
        
        // pause session to allow for reconfig
        session.stopRunning()
        session.beginConfiguration()
        
        // push changes whenever function exits
        defer { session.commitConfiguration() }
        
        // if slomo is set, run specific config
        if cameraConfig.cameraMode == .slomo {
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraConfig.cameraPosition) else {
                print("could not access camera")
                return
            }
            configureForSlomo(device: camera)
        } else {
            session.sessionPreset = cameraConfig.quality.preset
        }
        
        
        // restart session in background to avoid hanging
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    func configureForSlomo(device: AVCaptureDevice) {
        var bestFormat: AVCaptureDevice.Format?
        var bestFrameRateRange: AVFrameRateRange?
        
        // loop through available formats to find best for slomo
        for format in device.formats {
            for range in format.videoSupportedFrameRateRanges {
                // find highest fps available
                if range.maxFrameRate > bestFrameRateRange?.maxFrameRate ?? 0 {
                    bestFormat = format
                    bestFrameRateRange = range
                }
            }
        }
        
        // if suitable format is found, apply
        if let bestFormat = bestFormat,
           let bestFrameRateRange = bestFrameRateRange {
            do {
                // pause updates to AVCaptureDevice config to allow for manual config
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                
                // apply new format
                device.activeFormat = bestFormat
                
                // set min and max frame duration to equal new fps
                let duration = bestFrameRateRange.minFrameDuration
                device.activeVideoMinFrameDuration = duration
                device.activeVideoMaxFrameDuration = duration
            } catch {
            }
        }
    }
    
    func switchCamera() {
        guard let session = session else {
            print("could not access session")
            return }
        
        // begin session reconfig - no need to pause
        session.beginConfiguration()
        
        // push changes whenever function exits
        defer { session.commitConfiguration() }
        
        // get current input
        guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else { return }
        
        // swap camera in cameraConfig
        cameraConfig.cameraPosition = (cameraConfig.cameraPosition == .front) ? .back : .front
        
        // find and set up new camera if available
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraConfig.cameraPosition) else {
            print("could not find the camera for position: \(cameraConfig.cameraPosition)")
            return
        }
        
        do {
            // create input for new camera
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            
            // remove old camera
            session.removeInput(currentInput)
            
            // add new camera
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
    
    // MARK: - Capture
    // ----------------------------------
    //
    // Contains takePhoto and takeVideo
    // functions
    //
    // ----------------------------------
    
    // master function for saving photo method/settings
    func takePhoto() {
        UIView.animate(withDuration: 0.1, animations: {
            self.fadeView.backgroundColor = UIColor.black
        }) { (finished) in
            UIView.animate(withDuration: 0.1, animations: {
                self.fadeView.backgroundColor = UIColor.clear
            })
        }
        
        // check if session is running and available to take photo
        guard let session = session, session.isRunning else {
            print("could not access session")
            return
        }
        
        // check if camera is available
        guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraConfig.cameraPosition) != nil else {
            print("could not access camera")
            return
        }
        
        // get current capture settings
        let photoSettings = AVCapturePhotoSettings()
        let supportedFlashModes = output.supportedFlashModes
        
        // enable flash if selected and available
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
            // run timer with specified interval to rapidly take photos
            burstModeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let timer = self else { return }
                self?.feedbackGenerator.impactOccurred()
                let photoSettings = AVCapturePhotoSettings()
                timer.output.capturePhoto(with: photoSettings, delegate: timer)
                
                UIView.animate(withDuration: 0.1, animations: {
                    self?.fadeView.backgroundColor = UIColor.black
                }) { (finished) in
                    UIView.animate(withDuration: 0.1, animations: {
                        self?.fadeView.backgroundColor = UIColor.clear
                    })
                }
            }
        default:
            break
        }
    }
    
    func takeVideo() {
        // check if session is running and available to take video
        guard let session = session, session.isRunning else {
            print("could not access session")
            return
        }
        
        // videos need to be saved to temp storage and cannot have same
        // file name - use date to generate unique name
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let dateString = dateFormatter.string(from: Date())
        let outputPath = NSTemporaryDirectory() + dateString + ".mov"
        let outputFileURL = URL(fileURLWithPath: outputPath)
        
        // check if camera is available
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraConfig.cameraPosition) else {
            print("could not access camera")
            return
        }
        
        do {
            try camera.lockForConfiguration()
            defer { camera.unlockForConfiguration() }
            // enable torch mode (video flash) if selected and available
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
        } catch {
        }
        videoOutput.startRecording(to: outputFileURL, recordingDelegate: self)
    }
    
    // MARK: - UI Actions
    // ----------------------------------
    //
    // Contains Objc functions, IBActions,
    // or other helper functions that
    // trigger on interactions with the UI
    //
    // ----------------------------------
    
    // since this was created programatically, we can't use an IBAction - use objc function instead
    @objc func cameraModeButtonUp(_ sender: UIButton) {
        // set cameraConfig as selected camera mode
        guard let title = sender.title(for: .normal),
              let mode = CameraConfig.CameraMode.allCases.first(where: { $0.description == title }) else {
            return
        }
        cameraConfig.cameraMode = mode
        
        // update quality and UI to reflect cameraConfig change
        updateQuality()
        updateUI()
    }
    
    @IBAction func shutterButtonDown(_ sender: UIButton) {
        // haptic feedback
        feedbackGenerator.impactOccurred()
        
        // animate button shrinking
        UIView.animate(withDuration: 0.3) {
            sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }
        
        // take photo if mode is applicable
        if cameraConfig.cameraMode == .photo || cameraConfig.cameraMode == .burst {
            takePhoto()
        } else {
            // start or stop video depending on recording status
            if videoOutput.isRecording {
                videoOutput.stopRecording()
                
                // reset and dismiss timer
                videoTimer?.invalidate()
                videoTimer = nil
                UIView.animate(withDuration: 0.5) {
                    self.videoTimerLabel.alpha = 0
                }
            } else {
                takeVideo()
                
                // configure and reveal timer
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
        // haptic feedback
        feedbackGenerator.impactOccurred()
        
        // animate button expanding
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform.identity
        }
        
        // stop burst if applicable
        if cameraConfig.cameraMode == .burst {
            burstModeTimer?.invalidate()
            burstModeTimer = nil
        }
    }
    
    @IBAction func rotateButtonUp(_ sender: UIButton) {
        // switch camera when rotate button is pressed
        switchCamera()
    }
    
    @IBAction func photosButtonUp(_ sender: UIButton) {
        // redirect user to pboto album app
        // THIS IS HACKY AND WILL LIKELY BREAK IN FUTURE
        UIApplication.shared.open(URL(string:"photos-redirect://")!)
    }
    
    @IBAction func zoomPinchRecognizer(_ sender: UIPinchGestureRecognizer) {
        // check if camera is available
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraConfig.cameraPosition) else {
            print("could not access camera")
            return
        }
        
        // respond to pinch gesture changes
        if sender.state == .changed {
            do {
                
                // lock auto-config to apply manual changes
                try camera.lockForConfiguration()
                defer { camera.unlockForConfiguration() }
                
                // calculate zoom scale
                let scaleFactor = sender.scale
                let newScaleFactor = camera.videoZoomFactor * scaleFactor
                
                // apply scale factor to calculate new zoom level
                camera.videoZoomFactor = max(min(newScaleFactor, camera.maxAvailableVideoZoomFactor), camera.minAvailableVideoZoomFactor)
                cameraConfig.zoom = camera.videoZoomFactor
                
                // reset scale
                sender.scale = 1.0
            } catch {
                print("could not lock camera for config")
            }
        }
        
    }
    
    @IBAction func tapFocusRecognizer(_ sender: UITapGestureRecognizer) {
        
        // get location of tap and translate to previewLayer location
        let location = sender.location(in: cameraView)
        let focusPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: location)
        
        // check if camera is available
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraConfig.cameraPosition) else {
            print("could not access camera")
            return
        }
        
        // display fancy focus indicator animation
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
            // lock auto-config to apply manual changes
            try camera.lockForConfiguration()
            defer { camera.unlockForConfiguration() }
            
            // if focus point is supported, set new focus point and reset to appropriate focus mode
            if camera.isFocusPointOfInterestSupported && camera.isFocusModeSupported(.autoFocus) {
                camera.focusPointOfInterest = focusPoint
                if camera.isFocusModeSupported(.continuousAutoFocus) {
                    camera.focusMode = .continuousAutoFocus
                }
                else {
                    camera.focusMode = .autoFocus
                }
            }
            
            // if exposure point is supported, set new exposure point and reset to appropriate exposure mode
            if camera.isExposurePointOfInterestSupported && camera.isExposureModeSupported(.autoExpose) {
                camera.exposurePointOfInterest = focusPoint
                
                if camera.isExposureModeSupported(.continuousAutoExposure) {
                    camera.exposureMode = .continuousAutoExposure
                }
                else {
                    camera.exposureMode = .autoExpose
                }
            }
            
        } catch {
            print("could not lock camera for config")
        }
    }
    
    // MARK: - Output
    // ----------------------------------
    //
    // Contains functions that export or
    // help format data for output
    //
    // ----------------------------------
    
    // triggered when photo is captured
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // convert photo to UIImage and check for errors
        guard let imageData = photo.fileDataRepresentation(),
              var image = UIImage(data: imageData) else {
            print("could not create image data")
            return
        }
        
        // apply crop to UIImage
        image = cropImage(image: image)
        
        // save to camera roll
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    // triggered when video recording starts
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("video recording started")
    }
    
    // triggered when video recording finishes
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        // turn off torch mode if active
        if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraConfig.cameraPosition), camera.isTorchActive {
            do {
                try camera.lockForConfiguration()
                defer { camera.unlockForConfiguration() }
                camera.torchMode = .off
            } catch {
            }
        }
        
        // catch recording errors
        if let error = error {
            print("video recording error: \(error.localizedDescription)")
        } else {
            if cameraConfig.cameraMode == .slomo {
                // asynchronously rebuild video for slomo
                Task {
                    await exportSloMo(originalVideoURL: outputFileURL)
                }
            }
            else if cameraConfig.cameraMode == .timelapse {
                // asynchronously rebuild video for timelapse
                Task {
                    await exportTimelapse(originalVideoURL: outputFileURL)
                }
            }
            //            else if cameraConfig.aspectRatio != .full {
            //                // asynchrnously crop video if needed
            //                Task {
            //                    await cropVideo(originalVideoURL: outputFileURL)
            //                }
            //            }
            else {
                // save video to camera roll as normal
                UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, nil, nil, nil)
            }
        }
    }
    
    // callback function when image is saved to camera roll
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        // catch errors during photo saving
        if let error = error {
            print("could not save photo: \(error.localizedDescription)")
        } else {
            print("photo saved successfully")
        }
    }
    
    // callback function when image is saved to camera roll
    @objc func video(_ videoPath: String, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        // catch errors during video saving
        if let error = error {
            print("error saving video: \(error.localizedDescription)")
        } else {
            print("video saved successfully")
        }
    }
    
    func exportSloMo(originalVideoURL: URL) async {
        // create asset from original video
        let asset = AVURLAsset(url: originalVideoURL)
        // create new mutable composition to store slow motion video
        let sloMoComposition = AVMutableComposition()
        
        do {
            // build video track from original video
            guard let srcVideoTrack = try await asset.loadTracks(withMediaType: .video).first else { return }
            
            // set up new video track for slow motion
            let sloMoVideoTrack = sloMoComposition.addMutableTrack(withMediaType: .video,
                                                                   preferredTrackID: kCMPersistentTrackID_Invalid)
            do {
                // rotate slow motion video track to match orientation of original
                let preferredTransform = try await srcVideoTrack.load(.preferredTransform)
                sloMoVideoTrack?.preferredTransform = preferredTransform
                // insert slow motion video track into composition
                try await sloMoVideoTrack?.insertTimeRange(CMTimeRangeMake(start: .zero, duration: asset.load(.duration)),
                                                           of: srcVideoTrack,
                                                           at: .zero)
            } catch {
                print("error inserting time range")
                return
            }
            
            // slow down video
            let newDuration = try await CMTimeMultiplyByFloat64(asset.load(.duration), multiplier: 2)
            try await sloMoVideoTrack?.scaleTimeRange(CMTimeRangeMake(start: .zero, duration: asset.load(.duration)), toDuration: newDuration)
            
            // set up export session
            guard let exportSession = AVAssetExportSession(asset: sloMoComposition, presetName: AVAssetExportPresetPassthrough) else {
                print("could not create export session.")
                return
            }
            
            // videos need to be saved to temp storage and cannot have same
            // file name - use date to generate unique name
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMddHHmmss"
            let dateString = dateFormatter.string(from: Date())
            let outputPath = NSTemporaryDirectory() + dateString + "slomo.mov"
            let outputFileURL = URL(fileURLWithPath: outputPath)
            exportSession.outputURL = outputFileURL
            exportSession.outputFileType = .mov
            
            // export slow motion video
            exportSession.exportAsynchronously {
                DispatchQueue.main.async {
                    switch exportSession.status {
                    case .completed:
                        // save exported video to camera roll
                        UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, nil, nil, nil)
                        print("slow motion recording finished, saved at: \(outputFileURL.path)")
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
        // create asset from original video
        let asset = AVURLAsset(url: originalVideoURL)
        // create new mutable composition to store timelapse video
        let timelapseComposition = AVMutableComposition()
        
        do {
            // build video track from original video
            guard let srcVideoTrack = try await asset.loadTracks(withMediaType: .video).first else { return }
            
            // set up new video track for timelapse
            let timelapseVideoTrack = timelapseComposition.addMutableTrack(withMediaType: .video,
                                                                           preferredTrackID: kCMPersistentTrackID_Invalid)
            do {
                // rotate timelapse video track to match orientation of original
                let preferredTransform = try await srcVideoTrack.load(.preferredTransform)
                timelapseVideoTrack?.preferredTransform = preferredTransform
                // insert timelapse video track into composition
                try await timelapseVideoTrack?.insertTimeRange(CMTimeRangeMake(start: .zero, duration: asset.load(.duration)),
                                                               of: srcVideoTrack,
                                                               at: .zero)
            } catch {
                print("error inserting time range")
                return
            }
            
            // speed up video
            let newDuration = try await CMTimeMultiplyByFloat64(asset.load(.duration), multiplier: 1 / 20)
            try await timelapseVideoTrack?.scaleTimeRange(CMTimeRangeMake(start: .zero, duration: asset.load(.duration)), toDuration: newDuration)
            
            // set up export session
            guard let exportSession = AVAssetExportSession(asset: timelapseComposition, presetName: AVAssetExportPresetPassthrough) else {
                print("could not create export session.")
                return
            }
            
            // videos need to be saved to temp storage and cannot have same
            // file name - use date to generate unique name
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMddHHmmss"
            let dateString = dateFormatter.string(from: Date())
            let outputPath = NSTemporaryDirectory() + dateString + "timelapse.mov"
            let outputFileURL = URL(fileURLWithPath: outputPath)
            exportSession.outputURL = outputFileURL
            exportSession.outputFileType = .mov
            
            // export slow motion video
            exportSession.exportAsynchronously {
                DispatchQueue.main.async {
                    switch exportSession.status {
                    case .completed:
                        // save exported video to camera roll
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
    
    func cropImage(image: UIImage) -> UIImage {
        // return original image if no crop is selected
        if cameraConfig.aspectRatio == .full {
            return image
        }
        
        // calculate new size
        let size = image.size
        let targetSize = cameraConfig.aspectRatio.size
        let newSize = CGSize(width: size.width, height: size.width * targetSize.height / targetSize.width)
        
        // create cropping rectangle
        let rect = CGRect(x: (size.width - newSize.width) / 2, y: (size.height - newSize.height) / 2, width: newSize.width, height: newSize.height)
        
        // create new cropped image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(x: -rect.origin.x, y: -rect.origin.y, width: size.width, height: size.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
    
    
}

// MARK: - CLASS - AspectRatioPickerDataSourceDelegate
// ----------------------------------
//
// Manages data and user interactions
// for the aspect ratio pickerview
//
// ----------------------------------

class AspectRatioPickerDataSourceDelegate: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
    // returns the number of components (columns)
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // returns the number of rows for the component
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return CameraConfig.AspectRatio.allCases.count
    }
    
    // provides the title for each row
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return CameraConfig.AspectRatio.allCases[row].description
    }
    
    // sets the appearance for each row
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        // populates options
        let title = self.pickerView(pickerView, titleForRow: row, forComponent: component) ?? ""
        let isSelected = row == pickerView.selectedRow(inComponent: component)
        let titleColor = isSelected ? UIColor.systemYellow : UIColor.white
        return NSAttributedString(string: title, attributes: [NSAttributedString.Key.foregroundColor: titleColor, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)])
    }
    
    // handles selection of a row
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // sets cameraConfig as selected option
        pickerView.reloadAllComponents()
        let selectedAspectRatio = CameraConfig.AspectRatio.allCases[row]
        cameraConfig.aspectRatio = selectedAspectRatio
    }
}

// MARK: - CLASS - QualityPickerDataSourceDelegate
// ----------------------------------
//
// Manages data and user interactions
// for the camera quality pickerview
//
// ----------------------------------

class QualityPickerDataSourceDelegate: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
    // closure called when quality is changed - needed since viewController needs to
    // see change as it happens to update quality immediatly
    var onQualityChange: ((CameraConfig.Quality) -> Void)?
    
    // returns the number of components (columns)
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // returns the number of rows for the component
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return CameraConfig.Quality.allCases.count
    }
    
    // provides the title for each row
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return CameraConfig.Quality.allCases[row].description
    }
    
    // sets the appearance for each row
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        // populates options
        let title = self.pickerView(pickerView, titleForRow: row, forComponent: component) ?? ""
        let isSelected = row == pickerView.selectedRow(inComponent: component)
        let titleColor = isSelected ? UIColor.systemYellow : UIColor.white
        return NSAttributedString(string: title, attributes: [NSAttributedString.Key.foregroundColor: titleColor, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)])
    }
    
    // handles selection of a row
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // sets cameraConfig as selected option
        pickerView.reloadAllComponents()
        let selectedQuality = CameraConfig.Quality.allCases[row]
        cameraConfig.quality = selectedQuality
        onQualityChange?(selectedQuality)
    }
}

// MARK: - CLASS - FlashPickerDataSourceDelegate
// ----------------------------------
//
// Manages data and user interactions
// for the camera flash pickerview
//
// ----------------------------------

class FlashPickerDataSourceDelegate: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
    // returns the number of components (columns)
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // returns the number of rows for the component
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return CameraConfig.Flash.allCases.count
    }
    
    // provides the title for each row
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return CameraConfig.Flash.allCases[row].description
    }
    
    // sets the appearance for each row
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        // populates options
        let title = self.pickerView(pickerView, titleForRow: row, forComponent: component) ?? ""
        let isSelected = row == pickerView.selectedRow(inComponent: component)
        let titleColor = isSelected ? UIColor.systemYellow : UIColor.white
        return NSAttributedString(string: title, attributes: [NSAttributedString.Key.foregroundColor: titleColor, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)])
    }
    
    // handles selection of a row
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // sets cameraConfig as selected option
        pickerView.reloadAllComponents()
        let selectedFlash = CameraConfig.Flash.allCases[row]
        cameraConfig.flash = selectedFlash
    }
}
