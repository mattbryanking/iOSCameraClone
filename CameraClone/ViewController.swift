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
        var zoom: CGFloat = 1.0    }
    
    var cameraConfig = CameraConfig(cameraMode: .photo, cameraPosition: .back, frameRate: 30, resolution: .high, isHDR: false)
    
    override func viewDidLoad() {
        super.viewDidLoad()
       
        session = AVCaptureSession()
        setupCamera()
        
        // programatically round button and add border
        shutterButton.layer.cornerRadius = shutterButton.frame.width / 2
        shutterButton.layer.masksToBounds = true
        shutterButton.layer.borderWidth = 2.2
        shutterButton.layer.borderColor = UIColor.black.cgColor
        shutterButton.layer.zPosition = 2
        
        // add ring behind button
        let circleLayer = CAShapeLayer()
        let circleDiameter: CGFloat = shutterButton.frame.width * 1.1
        let circlePath = UIBezierPath(ovalIn: CGRect(x: shutterButton.center.x - circleDiameter / 2, y: shutterButton.center.y - circleDiameter / 2, width: circleDiameter, height: circleDiameter))

        circleLayer.path = circlePath.cgPath
        circleLayer.fillColor = UIColor.white.cgColor
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
                
            } catch {
                print("could not lock device for config")
            }
        }
    }
    
}

