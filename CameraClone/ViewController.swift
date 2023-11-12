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
  
    @IBOutlet weak var cameraView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
       
        session = AVCaptureSession()
        setupCamera()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = cameraView.bounds
    }
    
    func setupCamera() {
        session = AVCaptureSession()
        guard let session = session else { return }
        
        session.sessionPreset = .high
        
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        else {
            print("back camera unavailable")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            else {
                print("could not add input to camera session")
                return
            }
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            else {
                print ("could not add output to camera session")
                return
            }
        } catch {
            print("could not initialize back camera")
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
}

