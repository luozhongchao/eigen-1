//
//  MetadataInARViewController.swift
//  Artsy
//
//  Created by Luc Succes on 11/14/18.
//  Copyright © 2018 Artsy. All rights reserved.
//

import SceneKit
import SpriteKit
import ARKit
import UIKit

@available(iOS 11.3, *)
class MetadataInARViewController: UIViewController, ARSCNViewDelegate {
    
    var sceneView: ARSCNView!
    
    var blurView: UIVisualEffectView!
    
    /// The view controller that displays the status and "restart experience" UI.
    var statusViewController: MetadataInARStatusViewController!
    
    var artworkView: MetadataInARArtworkView?
    
    /// A serial queue for thread safety when modifying the SceneKit node graph.
    let updateQueue = DispatchQueue(label: Bundle.main.bundleIdentifier! +
        ".serialSceneKitQueue")
    
    /// Convenience accessor for the session owned by ARSCNView.
    var session: ARSession {
        return sceneView.session
    }
    
    // MARK: - View Controller Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let blurEffect = UIBlurEffect.init(style: .dark)
        blurView =  UIVisualEffectView.init(effect: blurEffect)
        
        statusViewController = MetadataInARStatusViewController()
        addChild(statusViewController)
        
        sceneView = ARSCNView(frame: view.bounds)
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        // Hook up status view controller callback(s).
        statusViewController.restartExperienceHandler = { [unowned self] in
            self.restartExperience()
        }

        view.addSubview(sceneView)
        view.addSubview(statusViewController.view)
        statusViewController.didMove(toParent: self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Prevent the screen from being dimmed to avoid interuppting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Start the AR experience
        resetTracking()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        session.pause()
    }
    
    // MARK: - Session management (Image detection setup)
    
    /// Prevents restarting the session while a restart is in progress.
    var isRestartAvailable = true
    
    /// Creates a new AR configuration to run on the `session`.
    /// - Tag: ARReferenceImage-Loading
    func resetTracking() {
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.detectionImages = referenceImages
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        statusViewController.scheduleMessage("Look around to detect images", inSeconds: 7.5, messageType: .contentPlacement)
    }
    
    func getArtworkCard(referenceImage: ARReferenceImage) -> SCNNode {
        let skScene = SKScene(size: CGSize(width: 200, height: 200))
        skScene.backgroundColor = UIColor.clear
        
        let rectangle = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 200, height: 200), cornerRadius: 10)
        rectangle.fillColor = #colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1)
        rectangle.strokeColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        rectangle.lineWidth = 5
        rectangle.alpha = 1
        let labelNode = SKLabelNode(text: "Lupita")
        labelNode.fontSize = 20
        labelNode.fontName = "San Fransisco"
        labelNode.color = .black
        labelNode.position = CGPoint(x:10, y:20)
        skScene.addChild(rectangle)
        skScene.addChild(labelNode)
        
        let plane = SCNPlane(width: referenceImage.physicalSize.width, height: referenceImage.physicalSize.height)
        let material = SCNMaterial()
        material.isDoubleSided = false
        material.diffuse.contents = skScene
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(1, -1, 1)
        plane.materials = [material]
        
        return SCNNode(geometry: plane)
    }
    
    // MARK: - ARSCNViewDelegate (Image detection results)
    /// - Tag: ARImageAnchor-Visualizing
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        let referenceImage = imageAnchor.referenceImage
        updateQueue.async {
            
            // Create a plane to visualize the initial position of the detected image.
            let plane = SCNPlane(width: referenceImage.physicalSize.width,
                                 height: referenceImage.physicalSize.height)
            let planeNode = SCNNode(geometry: plane)
            planeNode.opacity = 0.25
            
            /*
             `SCNPlane` is vertically oriented in its local coordinate space, but
             `ARImageAnchor` assumes the image is horizontal in its local space, so
             rotate the plane to match.
             */
            planeNode.eulerAngles.x = -.pi / 2
            
            /*
             Image anchors are not tracked after initial detection, so create an
             animation that limits the duration for which the plane visualization appears.
             */
            planeNode.runAction(self.imageHighlightAction)
            
            // TODO: add UI to render
//            let cardNode = self.getArtworkCard(referenceImage: referenceImage)
//            planeNode.addChildNode(cardNode)
            
            // Add the plane visualization to the scene.
            node.addChildNode(planeNode)
        }
        
        DispatchQueue.main.async {
            let artworkId = referenceImage.name ?? ""
            self.statusViewController.cancelAllScheduledMessages()
            self.statusViewController.showMessage("Detected image \(artworkId)")
            
            let artwork = Artwork(artworkID: artworkId)
            
//            if self.artworkView == nil {
//                let artworkView = MetadataInARArtworkView(artwork: artwork)
//                self.view.addSubview(artworkView)
//
//                let bottomPredicate = artworkView.alignBottomEdge(withView: self.view, predicate: "-20")
//                artworkView.alignLeadingEdge(withView: self.view, predicate: "15")
//                artworkView.constrainWidth(toView: self.view, predicate: "-30")
//                artworkView.constrainHeight("200")
//
//                bottomPredicate.constant = 200
//                artworkView.alpha = 0
//
//                UIView.animate(withDuration: 0.3, animations: {
//                    artworkView.alpha = 1
//
//                    self.view.layoutIfNeeded()
//                    bottomPredicate.constant = -30
//
//                    UIView.animate(withDuration: 0.3, animations: {
//                        self.view.layoutIfNeeded()
//                    })
//                })
//
//                self.artworkView = artworkView
//            } else {
//                self.artworkView?.updateWithArtwork(artwork: artwork)
//            }
//            print("\(artwork)")
            
            self.addBottomSheetView(artwork: artwork)
        }
    }
    
    var imageHighlightAction: SCNAction {
        return .sequence([
            .wait(duration: 0.25),
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOpacity(to: 0.15, duration: 0.25),
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOut(duration: 0.25)
            ])
    }
    
    
    func addBottomSheetView(artwork: Artwork) {
        let bottomSheetVC = MetadataInARBottomSheetViewController(artwork: artwork)
        
        addChild(bottomSheetVC)
        view.addSubview(bottomSheetVC.view)
        bottomSheetVC.didMove(toParent: self)
        
        let height = view.frame.height
        let width = view.frame.width
        
        bottomSheetVC.view.frame = CGRect(x: 0, y: view.frame.maxY, width: width, height: height)
    }
}
