//
//  ViewController.swift
//  TestAR
//
//  Created by Renato Tramontano on 11/12/17.
//  Copyright © 2017 Renato Tramontano. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {
    
    // MARK: IBOutlets
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var sessionInfoView: UIView!
    @IBOutlet weak var sessionInfoLabel: UILabel!
    
    // MARK: - UI Elements
    let photoNode = SCNScene(named: "art.scnassets/photo.scn")?.rootNode.childNode(withName: "Photo", recursively: true)!
    var treeScene: SCNScene?
    var selectedPhoto = ""
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Verifica che l'AR di dipo tracking sia supportato dal dispositivo
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("""
                ARKit is not available on this device. For apps that require ARKit
                for core functionality, use the `arkit` key in the key in the
                `UIRequiredDeviceCapabilities` section of the Info.plist to prevent
                the app from installing. (If the app can't be installed, this error
                can't be triggered in a production scenario.)
                In apps where AR is an additive feature, use `isSupported` to
                determine whether to show UI for launching AR experiences.
            """)
        }
        
        // Imposta un delegato per tenere traccia del feedback dell'interfaccia utente.
        sceneView.delegate = self
        
        // Mostra l'UI di debug (ad esempio i fotogrammi al secondo).
        sceneView.showsStatistics = true
        
        // Mostra una nuvola di punti che rappresentano i risultati intermedi dell'analisi della scena che ARKit utilizza per tracciare la posizione del dispositivo.
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        
        // Abilita una luce di sistema che si pizza davanti la camera
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
       
        let configuration = ARWorldTrackingConfiguration()
    
        configuration.planeDetection = .horizontal
        
        sceneView.session.run(configuration)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    //: MARK: - Private Method
    private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        // Update the UI to provide feedback on the state of the AR experience.
        let message: String
        
        switch trackingState {
        case .normal where frame.anchors.isEmpty:
            // No planes detected; provide instructions for this app's AR interactions.
            message = "Move the device around to detect horizontal surfaces."
            
        case .normal:
            // No feedback needed when tracking is normal and planes are visible.
            message = ""
            
        case .notAvailable:
            message = "Tracking unavailable."
            
        case .limited(.excessiveMotion):
            message = "Tracking limited - Move the device more slowly."
            
        case .limited(.insufficientFeatures):
            message = "Tracking limited - Point the device at an area with visible surface detail, or improve lighting conditions."
            
        case .limited(.initializing):
            message = "Initializing AR session."
            
        }
        
        sessionInfoLabel.text = message
        sessionInfoView.isHidden = message.isEmpty
    }
    
    
    // Callback chiamata quando si "tappa" sullo schermo
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first!
        let touchLocation = touch.location(in: sceneView)
        
        // Crea l'albero se non esiste
        if treeScene == nil {        //Non va bene perchè se la sessione trova un errore il treescene non è di nuovo null di deve creare un altro metodo destroytree in caso di crash della sessione.
            let results = sceneView.hitTest(touchLocation, types: .existingPlaneUsingExtent)
            if let hitResult = results.first {
                createTree(hitResult)
            }
        
        } else {
            // Verifica se è stata premuta una foto
            let hitResults = sceneView.hitTest(touchLocation, options: nil)
            if let result = hitResults.first {
                if let res = photoNode?.childNode(withName: result.node.name!, recursively: true) {
                    selectedPhoto = (result.node.parent?.name)!
                    cameraUtility()
                }
            }
            
        }
    }
    
    
    func createTree(_ hitResult: ARHitTestResult) {
        treeScene = SCNScene(named: "art.scnassets/tree.scn")!
        if let treeNode = treeScene?.rootNode.childNode(withName: "tree", recursively: true) {
            treeNode.position = SCNVector3(
                x: hitResult.worldTransform.columns.3.x,
                y: hitResult.worldTransform.columns.3.y,
                z: hitResult.worldTransform.columns.3.z
            )
            sceneView.scene.rootNode.addChildNode(treeNode)
        }
        
    }
    
}


//: MARK: - ARSCNViewDelegate
extension ViewController: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Posiziona il contenuto solo per gli ancoraggi rilevati dal rilevamento del piano.
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        // Crea un piano 3d per visualizzare l'ancora piana usando la sua posizione e la sua estensione.
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        let planeNode = SCNNode(geometry: plane)
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        // SCNPlane è orientato verticalmente nel suo spazio di coordinate locale, quindi
        // ruotiamo il piano in modo che corrisponda all'orientamento orizzontale di ARPlaneAnchor
        planeNode.eulerAngles.x = -Float.pi/2
        
        // Rendiamo semitrasparente la visualizzazione del piano per mostrare chiaramente il suo posizionamento nel mondo reale.
        planeNode.opacity = 0.25
        
        node.addChildNode(planeNode)
        
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Aggiorna il contenuto solo per ancore e nodi piani creati in renderer(didAdd)
        guard let planeAnchor = anchor as? ARPlaneAnchor,
            let planeNode = node.childNodes.first,
            let plane = planeNode.geometry as? SCNPlane
            else { return }
        
        
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        plane.height = CGFloat(planeAnchor.extent.z)
        plane.width = CGFloat(planeAnchor.extent.x)
        
    }
    
}



//: MARK: - ARSessionDelegate
extension ViewController: ARSessionDelegate {
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
        
    }
    
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
        
    }
    
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        guard let frame = session.currentFrame else { return }
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
        
    }
    
}


//: MARK: - UIImagePickerControllerDelegate
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func cameraUtility () {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = .camera;
            imagePicker.allowsEditing = false
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage
        //        imagepicked.image = image
        let obj = self.sceneView.scene.rootNode.childNode(withName: selectedPhoto, recursively: true)?.childNode(withName: "photo", recursively: true)
        obj?.geometry?.firstMaterial?.diffuse.contents = image
        dismiss(animated:true, completion: nil)
    }
    
}
