//
//  QRTLLaserSimulatorView.swift
//  QRTL Resonating Amplifier — 3D photon-alignment laser simulator
//
//  Implements the three-stage QRTL laser prediction:
//    1. Coherence efficiency gain   = newCoherence / oldCoherence
//    2. Loss-reduction gain         = 1 + fractionReduced
//    3. Beam-concentration gain     = 1 / areaReductionFactor
//    combinedGain = coherenceGain * lossGain * concentrationGain
//
//  Default ramp targets (0.70→0.95 coherence, 25% loss reduction,
//  50% area reduction) reproduce the document's ≈3.4× combined gain.
//
//  Target output: 2.94 µm (mid-infrared, invisible to the human eye —
//  photons are rendered in a false-color deep red/orange so the beam
//  is visible in the SceneKit view; this is a visualization choice,
//  not a physical claim about the beam's actual color).
//
//  Drop this file directly into your project. No external assets needed.
//

import SwiftUI
import SceneKit
import Combine
import CoreData

// MARK: - QRTL Physics

struct QRTLLaserPhysics {
    static let speedOfLight: Double = 2.998e8            // m/s
    static let targetWavelengthMeters: Double = 2.94e-6  // 2.94 µm

    static var targetFrequencyHz: Double {
        speedOfLight / targetWavelengthMeters
    }

    static func coherenceGain(oldCoherence: Double, newCoherence: Double) -> Double {
        guard oldCoherence > 0 else { return 1 }
        return newCoherence / oldCoherence
    }

    static func lossReductionGain(fractionReduced: Double) -> Double {
        1.0 + fractionReduced
    }

    static func beamConcentrationGain(areaReductionFactor: Double) -> Double {
        guard areaReductionFactor > 0 else { return 1 }
        return 1.0 / areaReductionFactor
    }

    static func combinedGain(coherenceGain: Double, lossGain: Double, concentrationGain: Double) -> Double {
        coherenceGain * lossGain * concentrationGain
    }
}

// MARK: - Photon State

struct PhotonState: Identifiable {
    let id = UUID()
    var position: SCNVector3
    var baseRadius: Float   // initial lateral offset from cavity axis
    var angle: Float        // angular position around the axis
    var speed: Float        // drift speed along z

    static func random(in cavityLength: Float) -> PhotonState {
        let angle = Float.random(in: 0..<(2 * .pi))
        let radius = Float.random(in: 0.3...1.4)
        let z = Float.random(in: 0...cavityLength)
        return PhotonState(
            position: SCNVector3(cos(angle) * radius, sin(angle) * radius, z),
            baseRadius: radius,
            angle: angle,
            speed: Float.random(in: 2.0...3.2)
        )
    }

    /// alignment: 0 = fully random/divergent, 1 = fully coherent & concentrated
    mutating func advance(dt: Float, alignment: Float, cavityLength: Float) {
        let targetRadius = baseRadius * (1.0 - 0.85 * alignment)
        angle += dt * (0.5 - 0.4 * alignment) // rotation damps out as photons align
        position.x = cos(angle) * targetRadius
        position.y = sin(angle) * targetRadius

        position.z += speed * dt
        if position.z > cavityLength { position.z -= cavityLength }
    }
}

// MARK: - CoreData (programmatic model — fully drop-in, no .xcdatamodeld needed)

@objc(QRTLLaserRun)
final class QRTLLaserRun: NSManagedObject {
    @NSManaged var timestamp: Date
    @NSManaged var finalCoherence: Double
    @NSManaged var finalIntensityGain: Double
    @NSManaged var targetFrequencyHz: Double
}

enum QRTLLaserCoreDataStack {
    static let model: NSManagedObjectModel = {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "QRTLLaserRun"
        entity.managedObjectClassName = NSStringFromClass(QRTLLaserRun.self)

        func attribute(_ name: String, _ type: NSAttributeType) -> NSAttributeDescription {
            let attr = NSAttributeDescription()
            attr.name = name
            attr.attributeType = type
            attr.isOptional = false
            return attr
        }

        entity.properties = [
            attribute("timestamp", .dateAttributeType),
            attribute("finalCoherence", .doubleAttributeType),
            attribute("finalIntensityGain", .doubleAttributeType),
            attribute("targetFrequencyHz", .doubleAttributeType)
        ]
        model.entities = [entity]
        return model
    }()

    static let container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "QRTLLaserModel", managedObjectModel: model)
        container.loadPersistentStores { _, error in
            if let error = error {
                // A failed store load shouldn't crash the whole simulator —
                // the cavity still runs and animates without persistence,
                // it just won't be able to log run history.
                print("QRTL CoreData store failed to load, run history will not be saved: \(error)")
            }
        }
        return container
    }()

    /// In-memory store for SwiftUI Previews and tests — never touches disk.
    static let preview: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "QRTLLaserModel", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error {
                print("QRTL preview store failed to load: \(error)")
            }
        }
        return container
    }()
}

// MARK: - MasterMonitor (AI/simulation integration layer)

final class MasterMonitor: ObservableObject {
    // Ramp state (mirrors the QRTL document's staged model)
    @Published var coherence: Double = 0.70              // η_c, ramps toward targetCoherence
    @Published var lossReductionFraction: Double = 0.0   // ramps toward targetLossReduction
    @Published var areaReductionFactor: Double = 1.0     // ramps toward targetAreaReductionFactor
    @Published var isRunning: Bool = false
    @Published var elapsedTime: Double = 0
    @Published var photonNodes: [PhotonState] = []
    @Published var beamLocked: Bool = false

    let cavityLength: Float = 6.0
    let photonCount: Int = 90
    let rampDuration: Double = 8.0

    // Baseline + targets taken directly from the QRTL laser document
    let baselineCoherence: Double = 0.70
    let targetCoherence: Double = 0.95
    let targetLossReduction: Double = 0.25
    let targetAreaReductionFactor: Double = 0.5

    private var timerCancellable: AnyCancellable?
    private let context: NSManagedObjectContext?
    private let photonLock = NSLock()

    var coherenceGain: Double {
        QRTLLaserPhysics.coherenceGain(oldCoherence: baselineCoherence, newCoherence: coherence)
    }
    var lossGain: Double {
        QRTLLaserPhysics.lossReductionGain(fractionReduced: lossReductionFraction)
    }
    var concentrationGain: Double {
        QRTLLaserPhysics.beamConcentrationGain(areaReductionFactor: areaReductionFactor)
    }
    var combinedGain: Double {
        QRTLLaserPhysics.combinedGain(coherenceGain: coherenceGain, lossGain: lossGain, concentrationGain: concentrationGain)
    }

    init(context: NSManagedObjectContext? = QRTLLaserCoreDataStack.container.viewContext) {
        self.context = context
        seedPhotons()
    }

    func seedPhotons() {
        let fresh = (0..<photonCount).map { _ in PhotonState.random(in: cavityLength) }
        photonLock.lock()
        photonNodes = fresh
        photonLock.unlock()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        beamLocked = false
        elapsedTime = 0
        coherence = baselineCoherence
        lossReductionFraction = 0
        areaReductionFactor = 1.0
        seedPhotons()

        timerCancellable = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick(dt: 1.0 / 60.0) }
    }

    func stop() {
        isRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func reset() {
        stop()
        seedPhotons()
        coherence = baselineCoherence
        lossReductionFraction = 0
        areaReductionFactor = 1.0
        elapsedTime = 0
        beamLocked = false
    }

    private func tick(dt: Double) {
        elapsedTime += dt
        let progress = min(elapsedTime / rampDuration, 1.0)

        coherence = baselineCoherence + (targetCoherence - baselineCoherence) * progress
        lossReductionFraction = targetLossReduction * progress
        areaReductionFactor = 1.0 - (1.0 - targetAreaReductionFactor) * progress

        photonLock.lock()
        for i in photonNodes.indices {
            photonNodes[i].advance(dt: Float(dt), alignment: Float(progress), cavityLength: cavityLength)
        }
        photonLock.unlock()

        if progress >= 1.0 {
            isRunning = false
            timerCancellable?.cancel()
            if !beamLocked {
                beamLocked = true
                logRun()
            }
        }
    }

    /// Thread-safe snapshot for the SceneKit render thread — never index
    /// `photonNodes` directly from outside the main thread.
    func snapshotPhotonPositions() -> [SCNVector3] {
        photonLock.lock()
        defer { photonLock.unlock() }
        return photonNodes.map { $0.position }
    }

    private func logRun() {
        guard let context = context else { return }
        let run = QRTLLaserRun(context: context)
        run.timestamp = Date()
        run.finalCoherence = coherence
        run.finalIntensityGain = combinedGain
        run.targetFrequencyHz = QRTLLaserPhysics.targetFrequencyHz
        do {
            try context.save()
        } catch {
            print("QRTLLaserRun save failed: \(error)")
        }
    }
}

// MARK: - SceneKit View

struct QRTLLaserSceneView: UIViewRepresentable {
    @ObservedObject var monitor: MasterMonitor

    func makeCoordinator() -> Coordinator {
        Coordinator(monitor: monitor)
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = UIColor.black
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false

        let scene = SCNScene()
        scnView.scene = scene
        context.coordinator.buildScene(in: scene)
        scnView.delegate = context.coordinator
        scnView.isPlaying = true
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.monitor = monitor
    }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        var monitor: MasterMonitor
        private var photonNodes: [SCNNode] = []
        private var beamNode: SCNNode?

        init(monitor: MasterMonitor) {
            self.monitor = monitor
        }

        func buildScene(in scene: SCNScene) {
            let cavityLength = monitor.cavityLength

            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.position = SCNVector3(4, 3, -6)
            cameraNode.look(at: SCNVector3(0, 0, cavityLength / 2))
            scene.rootNode.addChildNode(cameraNode)

            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.color = UIColor(white: 0.15, alpha: 1.0)
            scene.rootNode.addChildNode(ambient)

            let keyLight = SCNNode()
            keyLight.light = SCNLight()
            keyLight.light?.type = .omni
            keyLight.light?.intensity = 800
            keyLight.position = SCNVector3(2, 4, -2)
            scene.rootNode.addChildNode(keyLight)

            // Gain medium tube (He:Ne mixture per the QRTL document's recommended gas)
            let gainTube = SCNCylinder(radius: 1.6, height: CGFloat(cavityLength))
            gainTube.firstMaterial?.diffuse.contents = UIColor(red: 0.9, green: 0.4, blue: 0.15, alpha: 0.08)
            gainTube.firstMaterial?.emission.contents = UIColor(red: 0.9, green: 0.4, blue: 0.1, alpha: 1.0)
            gainTube.firstMaterial?.isDoubleSided = true
            gainTube.firstMaterial?.transparency = 0.12
            let gainNode = SCNNode(geometry: gainTube)
            gainNode.eulerAngles.x = Float.pi / 2
            gainNode.position = SCNVector3(0, 0, cavityLength / 2)
            scene.rootNode.addChildNode(gainNode)

            // Rear fully-reflective mirror
            let rearMirror = SCNCylinder(radius: 1.7, height: 0.1)
            rearMirror.firstMaterial?.lightingModel = .physicallyBased
            rearMirror.firstMaterial?.diffuse.contents = UIColor(white: 0.85, alpha: 1)
            rearMirror.firstMaterial?.metalness.contents = 1.0
            rearMirror.firstMaterial?.roughness.contents = 0.05
            let rearNode = SCNNode(geometry: rearMirror)
            rearNode.eulerAngles.x = Float.pi / 2
            rearNode.position = SCNVector3(0, 0, 0)
            scene.rootNode.addChildNode(rearNode)

            // Output-coupler mirror (partially transparent)
            let outMirror = SCNCylinder(radius: 1.7, height: 0.1)
            outMirror.firstMaterial?.lightingModel = .physicallyBased
            outMirror.firstMaterial?.diffuse.contents = UIColor(white: 0.85, alpha: 1)
            outMirror.firstMaterial?.transparency = 0.35
            outMirror.firstMaterial?.metalness.contents = 0.8
            let outNode = SCNNode(geometry: outMirror)
            outNode.eulerAngles.x = Float.pi / 2
            outNode.position = SCNVector3(0, 0, cavityLength)
            scene.rootNode.addChildNode(outNode)

            // Photon spheres — false-colored deep red/orange to represent the
            // invisible 2.94 µm mid-IR emission
            for state in monitor.photonNodes {
                let sphere = SCNSphere(radius: 0.045)
                sphere.firstMaterial?.emission.contents = UIColor(red: 1.0, green: 0.25, blue: 0.1, alpha: 1.0)
                sphere.firstMaterial?.diffuse.contents = UIColor(red: 1.0, green: 0.3, blue: 0.15, alpha: 1.0)
                let node = SCNNode(geometry: sphere)
                node.position = state.position
                scene.rootNode.addChildNode(node)
                photonNodes.append(node)
            }

            // Output beam — grows brighter/wider as coherence locks in
            let beam = SCNCylinder(radius: 0.08, height: 3.0)
            beam.firstMaterial?.emission.contents = UIColor(red: 1.0, green: 0.2, blue: 0.05, alpha: 1.0)
            beam.firstMaterial?.diffuse.contents = UIColor.black
            beam.firstMaterial?.transparency = 0.0
            let beamNode = SCNNode(geometry: beam)
            beamNode.eulerAngles.x = Float.pi / 2
            beamNode.position = SCNVector3(0, 0, cavityLength + 1.5)
            scene.rootNode.addChildNode(beamNode)
            self.beamNode = beamNode
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard monitor.isRunning || monitor.beamLocked else { return }

            let positions = monitor.snapshotPhotonPositions()
            for (i, node) in photonNodes.enumerated() where i < positions.count {
                node.position = positions[i]
            }

            let progress = Float(min(monitor.elapsedTime / monitor.rampDuration, 1.0))
            if let beamGeo = beamNode?.geometry as? SCNCylinder {
                beamGeo.firstMaterial?.transparency = CGFloat(progress) * 0.9
                beamGeo.radius = CGFloat(0.08 + progress * 0.25)
            }
        }
    }
}

// MARK: - Main View

struct ContentView: View {
    @StateObject private var monitor: MasterMonitor

    init(context: NSManagedObjectContext? = QRTLLaserCoreDataStack.container.viewContext) {
        _monitor = StateObject(wrappedValue: MasterMonitor(context: context))
    }

    var body: some View {
        ZStack(alignment: .top) {
            QRTLLaserSceneView(monitor: monitor)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 6) {
                Text("QRTL Resonating Amplifier")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(String(
                    format: "Target: %.2f µm  (%.3e Hz)",
                    QRTLLaserPhysics.targetWavelengthMeters * 1e6,
                    QRTLLaserPhysics.targetFrequencyHz
                ))
                .font(.caption)
                .foregroundColor(.orange)

                Divider().background(Color.white.opacity(0.3))

                metricRow("Coherence η_c", String(format: "%.1f%%", monitor.coherence * 100))
                metricRow("Coherence gain", String(format: "%.2f×", monitor.coherenceGain))
                metricRow("Loss reduction", String(format: "%.1f%%", monitor.lossReductionFraction * 100))
                metricRow("Loss gain", String(format: "%.2f×", monitor.lossGain))
                metricRow("Beam area factor", String(format: "%.2f×", monitor.areaReductionFactor))
                metricRow("Concentration gain", String(format: "%.2f×", monitor.concentrationGain))
                Divider().background(Color.white.opacity(0.3))
                metricRow("Combined gain", String(format: "%.2f×", monitor.combinedGain))

                if monitor.beamLocked {
                    Text("BEAM LOCKED — coherent output achieved")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.55))
            .cornerRadius(10)
            .padding()

            VStack {
                Spacer()
                HStack(spacing: 16) {
                    Button(monitor.isRunning ? "Aligning…" : "Ignite Cavity") {
                        monitor.start()
                    }
                    .disabled(monitor.isRunning)
                    .buttonStyle(.borderedProminent)

                    Button("Reset") {
                        monitor.reset()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.bottom, 24)
            }
        }
        .onDisappear { monitor.stop() }
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.white.opacity(0.8))
            Spacer()
            Text(value).font(.caption.bold()).foregroundColor(.white)
        }
        .frame(minWidth: 240)
    }
}
