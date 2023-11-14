//
//  ViewController.swift
//  CameraClone
//
//  Created by Matthew King on 11/11/23.
//

import AVFoundation
import UIKit

class ViewController: UIViewController {
    
    var session: AVCaptureSession?
    let output = AVCapturePhotoOutput()
    var previewLayer = AVCaptureVideoPreviewLayer()
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
  
    @IBOutlet weak var shutterButton: UIButton!
    @IBOutlet weak var cameraView: UIView!
    
    struct CameraConfig {
        enum CameraMode {
            case photo, video, portrait, nightMode, burst
        }

        var cameraMode: CameraMode
        var cameraPosition: AVCaptureDevice.Position
        var frameRate: Int
        var resolution: AVCaptureSession.Preset
        var isHDR: Bool
        var zoom: CGFloat = 1.0
    }
    
    var cameraConfig = CameraConfig(cameraMode: .photo, cameraPosition: .back, frameRate: 30, resolution: .high, isHDR: false)
    
    override func viewDidLoad() {
        super.viewDidLoad()
       
        session = AVCaptureSession()
        setupCamera()
        updateUI()
        
        // programatically round button and add border
        shutterButton.layer.cornerRadius = shutterButton.frame.width / 2
        shutterButton.layer.masksToBounds = true
        shutterButton.layer.zPosition = 1
        
        // add ring behind button
        let circleLayer = CAShapeLayer()
        let circleDiameter: CGFloat = shutterButton.frame.width * 1.125
        let circlePath = UIBezierPath(ovalIn: CGRect(x: shutterButton.center.x - circleDiameter / 2, y: shutterButton.center.y - circleDiameter / 2, width: circleDiameter, height: circleDiameter))

        circleLayer.path = circlePath.cgPath
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = UIColor.white.cgColor
        circleLayer.lineWidth = 4
        circleLayer.zPosition = 1

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
    
    func updateUI() {
        self.shutterButton.backgroundColor = self.cameraConfig.cameraMode == .video ? UIColor.red : UIColor.white

    }
    
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
        case .nightMode:
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
        takePhoto()
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

extension ViewController: AVCapturePhotoCaptureDelegate {
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
}

