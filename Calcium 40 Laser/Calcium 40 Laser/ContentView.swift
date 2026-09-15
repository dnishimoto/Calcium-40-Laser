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

//
//  ContentView.swift
//  QRTL Resonating Amplifier
//
//  Proposed QRTL laser / photon-alignment simulator.
//
//  IMPORTANT:
//  QRTL is a proposed, unvalidated theory. The QRTL equations below are
//  implemented as a model-defined phenomenological system. They should not
//  be represented as experimentally established physics.
//
//  Pipeline:
//
//  QRTL phase state
//      ↓
//  phase closure
//      ↓
//  twist-current
//      ↓
//  resonance response
//      ↓
//  resonance-shell energy
//      ↓
//  QRTL electromagnetic coupling
//      ↓
//  photon phase coherence
//      ↓
//  modeled cavity loss
//      ↓
//  modeled beam-area concentration
//      ↓
//  laser gain
//      ↓
//  2.94 µm output
//
//  Standard physics:
//      f = c / λ
//      E_photon = h f
//
//  QRTL model quantities:
//      phase closure
//      twist current
//      resonance response
//      shell energy
//      QRTL coupling
//      coherence
//      loss factor
//      beam-area factor
//

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

//
//  ContentView.swift
//  QRTL Resonating Amplifier
//
//  Proposed QRTL laser / photon-alignment simulator.
//
//  IMPORTANT:
//  QRTL is a proposed, unvalidated theory. The QRTL equations below are
//  implemented as a model-defined phenomenological system. They should not
//  be represented as experimentally established physics.
//
//  Pipeline:
//
//  QRTL phase state
//      ↓
//  phase closure
//      ↓
//  twist-current
//      ↓
//  resonance response
//      ↓
//  resonance-shell energy
//      ↓
//  QRTL electromagnetic coupling
//      ↓
//  photon phase coherence
//      ↓
//  modeled cavity loss
//      ↓
//  modeled beam-area concentration
//      ↓
//  laser gain
//      ↓
//  2.94 µm output
//
//  Standard physics:
//      f = c / λ
//      E_photon = h f
//
//  QRTL model quantities:
//      phase closure
//      twist current
//      resonance response
//      shell energy
//      QRTL coupling
//      coherence
//      loss factor
//      beam-area factor
//

import SwiftUI
//
// QRTLLaserSimulatorView.swift
// QRTL Resonating Amplifier — 3D photon-alignment laser simulator
//
// IMPORTANT:
// QRTL is a proposed, unvalidated theory.
//
// The QRTL relationships in this file are model-defined,
// phenomenological simulation equations. They are NOT established
// experimental laws of physics.
//
// Standard relationships:
//      f = c / λ
//      E = h f
//
// Proposed simulation pipeline:
//
//      cavity traversal
//          ↓
//      gain-medium crossing
//          ↓
//      phase closure
//          ↓
//      twist current
//          ↓
//      resonance response
//          ↓
//      shell energy
//          ↓
//      QRTL coupling
//          ↓
//      coherence
//          ↓
//      loss reduction
//          ↓
//      beam concentration
//          ↓
//      stable lock
//          ↓
//      output coupler
//          ↓
//      10% transmitted output
//
// Visualization of the 2.94 µm output uses visible false-color
// rendering. This is a visualization choice and is not a claim
// that 2.94 µm radiation is visible to the human eye.
//

import Foundation
import SwiftUI
import SceneKit
import Combine

// MARK: - QRTL Parameters

struct QRTLLaserParameters {

    // ------------------------------------------------------------
    // Standard constants
    // ------------------------------------------------------------

    let speedOfLight = 2.99792458e8
    let planckConstant = 6.62607015e-34
    let targetWavelengthMeters = 2.94e-6

    var targetFrequency: Double {
        speedOfLight / targetWavelengthMeters
    }

    var photonEnergy: Double {
        planckConstant * targetFrequency
    }

    // ------------------------------------------------------------
    // Cavity
    // ------------------------------------------------------------

    let cavityLength: Double = 6.0

    let gainStartZ: Double = 1.5
    let gainEndZ: Double = 4.5

    // ------------------------------------------------------------
    // Visualization timing
    //
    // This controls only the visible animation.
    // It does NOT modify physical cavity timing.
    // ------------------------------------------------------------

    let visualOneWayDuration: Double = 0.45

    // Physical cavity timing:
    //
    // tRT = 2L / c
    //

    var physicalOneWayTime: Double {
        cavityLength / speedOfLight
    }

    var physicalRoundTripTime: Double {
        (2.0 * cavityLength) / speedOfLight
    }

    // ------------------------------------------------------------
    // QRTL initial state
    // ------------------------------------------------------------

    let initialPhaseError: Double = 0.50 * Double.pi
    let initialCoherence: Double = 0.70
    let maximumCoherence: Double = 0.95

    let initialTwistCurrent: Double = 0.05
    let targetTwistCurrent: Double = 1.0

    let initialShellEnergy: Double = 0.10
    let targetShellEnergy: Double = 1.0

    let qrtlBaseCoupling: Double = 1.0

    // Phenomenological resonance width.
    let resonanceWidth: Double = 0.35

    // ------------------------------------------------------------
    // Bootstrap / convergence parameters
    //
    // These are model parameters, not experimental constants.
    // ------------------------------------------------------------

    let phaseCorrectionBase: Double = 0.10
    let phaseCorrectionClosureWeight: Double = 0.12
    let phaseCorrectionCouplingWeight: Double = 0.18

    let couplingPhaseWeight: Double = 0.45
    let couplingResonanceWeight: Double = 0.35
    let couplingShellWeight: Double = 0.20

    let couplingRelaxation: Double = 0.35

    let twistBaseDrive: Double = 0.10
    let twistClosureDrive: Double = 0.18
    let twistCouplingDrive: Double = 0.16

    // ------------------------------------------------------------
    // Loss / beam model
    // ------------------------------------------------------------

    let maximumLossReduction: Double = 0.25
    let minimumBeamAreaFactor: Double = 0.50

    // ------------------------------------------------------------
    // Output coupler
    // ------------------------------------------------------------

    let outputTransmission: Double = 0.10

    var outputReflection: Double {
        1.0 - outputTransmission
    }

    // ------------------------------------------------------------
    // Resonance-lock criteria
    // ------------------------------------------------------------

    let phaseClosureLockThreshold: Double = 0.99
    let maximumPhaseErrorForLock: Double = 0.05
    let qrtlCouplingLockThreshold: Double = 0.90
    let coherenceLockThreshold: Double = 0.94

    // Must remain satisfied for complete round trips.
    let requiredStableLockRounds: Int = 5

    // ------------------------------------------------------------
    // Visualization
    // ------------------------------------------------------------

    let photonCount: Int = 90
    let photonRadius: CGFloat = 0.045

    // Safety timeout only.
    //
    // NOTE: This must stay comfortably above the time the QRTL
    // model actually needs to reach resonance lock, or the
    // simulation will always be killed right before it fires.
    //
    // With the current parameters, lock requires 5 consecutive
    // stable round trips, which empirically completes around the
    // 9th round trip (~9 * 2 * visualOneWayDuration ≈ 8.1s). The
    // previous value of 8.0s was *shorter* than that, so the timer
    // always stopped the sim one round trip short of lockOK ever
    // going true for 5 consecutive rounds — the laser could never
    // reach the fire state. 20.0s leaves real margin.
    let maximumSimulationDuration: Double = 20.0
}

// MARK: - QRTL State

struct QRTLState {

    var phaseError: Double
    var phaseClosure: Double
    var twistCurrent: Double
    var resonanceResponse: Double
    var shellEnergy: Double
    var coupling: Double
    var coherence: Double

    var lossReduction: Double
    var beamAreaFactor: Double

    var coherenceGain: Double
    var lossGain: Double
    var concentrationGain: Double
    var combinedGain: Double

    var roundTripCount: Int
    var gainMediumCrossings: Int
    var stableLockRounds: Int

    var resonanceLocked: Bool

    // Authoritative output state.
    var circulatingFieldFactor: Double
    var transmittedOutputFactor: Double
    var outputEvents: Int
    var outputEnabled: Bool

    var currentDirection: CavityDirection

    // Actual modeled physical path time.
    var physicalElapsedTime: Double
}

enum CavityDirection: String {
    case forward = "+Z"
    case returnPath = "-Z"
}

// MARK: - Photon / Mode Marker

struct PhotonState {

    let id: Int

    var position: SCNVector3
    var baseRadius: Float

    var z: Double
    var radialOffset: Double

    var direction: CavityDirection

    // Visualization state only.
    var hasEnteredGainThisTraversal: Bool

    init(
        id: Int,
        cavityLength: Double
    ) {
        self.id = id

        self.baseRadius = Float(
            0.030 + 0.030 * Double(id % 7) / 6.0
        )

        self.radialOffset =
            0.20
            +
            1.15
            * Double(id % 17)
            / 16.0

        // Distribute markers deterministically around the
        // complete cavity traversal rather than randomizing
        // direction/position.

        let traversalFraction =
            Double(id)
            /
            Double(max(1, 90))

        let totalTraversal =
            2.0 * cavityLength

        let traversalPosition =
            traversalFraction * totalTraversal

        if traversalPosition <= cavityLength {
            self.z = traversalPosition
            self.direction = .forward
        } else {
            self.z =
                totalTraversal
                - traversalPosition

            self.direction = .returnPath
        }

        let angle =
            Double(id) * 0.71

        self.position = SCNVector3(
            Float(cos(angle) * radialOffset),
            Float(sin(angle) * radialOffset),
            Float(z)
        )

        self.hasEnteredGainThisTraversal = false
    }

    mutating func updateVisualPosition(
        coherence: Double
    ) {
        let alignment =
            max(
                0.0,
                min(
                    1.0,
                    (coherence - 0.70) / 0.25
                )
            )

        let visualRadius =
            radialOffset
            *
            (1.0 - 0.70 * alignment)

        let angle =
            Double(id) * 0.71
            +
            z * 0.18

        position = SCNVector3(
            Float(cos(angle) * visualRadius),
            Float(sin(angle) * visualRadius),
            Float(z)
        )
    }
}

// MARK: - QRTL Physics

enum QRTLLaserPhysics {

    // ------------------------------------------------------------
    // Standard physics
    // ------------------------------------------------------------

    static func frequency(
        wavelength: Double,
        parameters: QRTLLaserParameters
    ) -> Double {
        parameters.speedOfLight / wavelength
    }

    static func photonEnergy(
        frequency: Double,
        parameters: QRTLLaserParameters
    ) -> Double {
        parameters.planckConstant * frequency
    }

    // ------------------------------------------------------------
    // Proposed QRTL phenomenological equations
    // ------------------------------------------------------------

    /// Phase closure:
    ///
    /// Cφ = (1 + cos(Δφ)) / 2
    ///
    /// 0 = maximally mismatched
    /// 1 = phase closed

    static func phaseClosure(
        phaseError: Double
    ) -> Double {

        let value =
            (1.0 + cos(phaseError)) / 2.0

        return clamp(
            value,
            0.0,
            1.0
        )
    }

    static func smoothStep(
        _ value: Double
    ) -> Double {

        let x =
            clamp(
                value,
                0.0,
                1.0
            )

        return x * x * (3.0 - 2.0 * x)
    }

    // ------------------------------------------------------------
    // Twist current
    // ------------------------------------------------------------

    static func twistCurrent(
        oldCurrent: Double,
        phaseClosure: Double,
        coupling: Double,
        parameters: QRTLLaserParameters
    ) -> Double {

        let drive =
            parameters.twistBaseDrive
            +
            parameters.twistClosureDrive
            * phaseClosure
            +
            parameters.twistCouplingDrive
            * coupling

        let boundedDrive =
            clamp(
                drive,
                0.0,
                1.0
            )

        let next =
            oldCurrent
            +
            (
                parameters.targetTwistCurrent
                -
                oldCurrent
            )
            *
            boundedDrive

        return clamp(
            next,
            0.0,
            parameters.targetTwistCurrent
        )
    }

    // ------------------------------------------------------------
    // Resonance response
    // ------------------------------------------------------------

    static func resonanceResponse(
        phaseError: Double,
        parameters: QRTLLaserParameters
    ) -> Double {

        let normalizedDetuning =
            abs(phaseError) / Double.pi

        let exponent =
            -pow(
                normalizedDetuning
                /
                parameters.resonanceWidth,
                2.0
            )

        return clamp(
            exp(exponent),
            0.0,
            1.0
        )
    }

    // ------------------------------------------------------------
    // Shell energy
    // ------------------------------------------------------------

    static func shellEnergy(
        resonanceResponse: Double,
        normalizedTwistCurrent: Double,
        parameters: QRTLLaserParameters
    ) -> Double {

        let excitation =
            clamp(
                resonanceResponse
                *
                normalizedTwistCurrent,
                0.0,
                1.0
            )

        return
            parameters.initialShellEnergy
            +
            (
                parameters.targetShellEnergy
                -
                parameters.initialShellEnergy
            )
            *
            excitation
    }

    // ------------------------------------------------------------
    // QRTL coupling
    //
    // IMPORTANT:
    //
    // The old multiplicative formula:
    //
    //     closure × resonance × shell
    //
    // created a bootstrap bottleneck.
    //
    // This version first constructs a bounded interaction target
    // from the three QRTL state quantities, then relaxes the
    // existing coupling toward that target.
    //
    // Therefore repeated gain-medium interactions can progressively
    // move the system toward the lock region.
    // ------------------------------------------------------------

    static func qrtlCoupling(
        oldCoupling: Double,
        phaseClosure: Double,
        resonanceResponse: Double,
        shellEnergy: Double,
        parameters: QRTLLaserParameters
    ) -> Double {

        let normalizedShell =
            clamp(
                (
                    shellEnergy
                    -
                    parameters.initialShellEnergy
                )
                /
                max(
                    1.0e-12,
                    parameters.targetShellEnergy
                    -
                    parameters.initialShellEnergy
                ),
                0.0,
                1.0
            )

        let interactionTarget =
            parameters.qrtlBaseCoupling
            *
            (
                parameters.couplingPhaseWeight
                * phaseClosure
                +
                parameters.couplingResonanceWeight
                * resonanceResponse
                +
                parameters.couplingShellWeight
                * normalizedShell
            )

        let next =
            oldCoupling
            +
            (
                interactionTarget
                -
                oldCoupling
            )
            *
            parameters.couplingRelaxation

        return clamp(
            next,
            0.0,
            1.0
        )
    }

    // ------------------------------------------------------------
    // Coherence
    // ------------------------------------------------------------

    static func coherence(
        coupling: Double,
        parameters: QRTLLaserParameters
    ) -> Double {

        parameters.initialCoherence
        +
        (
            parameters.maximumCoherence
            -
            parameters.initialCoherence
        )
        *
        coupling
    }

    // ------------------------------------------------------------
    // Loss
    // ------------------------------------------------------------

    static func lossReduction(
        coupling: Double,
        parameters: QRTLLaserParameters
    ) -> Double {

        parameters.maximumLossReduction
        *
        coupling
    }

    // ------------------------------------------------------------
    // Beam area
    // ------------------------------------------------------------

    static func beamAreaFactor(
        coupling: Double,
        parameters: QRTLLaserParameters
    ) -> Double {

        1.0
        -
        (
            1.0
            -
            parameters.minimumBeamAreaFactor
        )
        *
        coupling
    }

    static func clamp(
        _ value: Double,
        _ minimum: Double,
        _ maximum: Double
    ) -> Double {

        min(
            max(
                value,
                minimum
            ),
            maximum
        )
    }
}

// MARK: - Master Monitor

@MainActor
final class MasterMonitor: ObservableObject {

    @Published private(set) var qrtlState: QRTLState
    @Published private(set) var photonNodes: [PhotonState]

    @Published private(set) var isRunning = false
    @Published private(set) var elapsedTime: Double = 0.0

    private let parameters = QRTLLaserParameters()

    private var timer: Timer?
    private var lastTick: Date?

    // ------------------------------------------------------------
    // Authoritative representative cavity mode
    // ------------------------------------------------------------

    private var representativeZ: Double = 0.0
    private var representativeDirection: CavityDirection = .forward
    private var previousZ: Double = 0.0

    private var gainCrossingInProgress = false
    private var activeGainTraversalDirection: CavityDirection?

    // ------------------------------------------------------------
    // QRTL evolving state
    // ------------------------------------------------------------

    private var phaseError: Double
    private var twistCurrent: Double

    private var coupling: Double
    private var shellEnergy: Double
    private var resonanceResponse: Double
    private var phaseClosure: Double
    private var coherence: Double

    private var roundTripCount = 0
    private var gainMediumCrossings = 0
    private var stableLockRounds = 0

    // ------------------------------------------------------------
    // Authoritative output state
    // ------------------------------------------------------------

    private var circulatingFieldFactor: Double = 1.0
    private var transmittedOutputFactor: Double = 0.0
    private var outputEvents = 0

    // ------------------------------------------------------------
    // Lock
    // ------------------------------------------------------------

    private var resonanceLocked = false

    // ------------------------------------------------------------
    // Physical traversal accounting
    //
    // We accumulate modeled optical path distance and divide by c.
    //
    // This means visual animation speed does not determine physical
    // elapsed time.
    // ------------------------------------------------------------

    private var physicalPathDistance: Double = 0.0

    // ------------------------------------------------------------
    // Thread protection
    // ------------------------------------------------------------

    private let stateLock = NSLock()

    init() {

        phaseError =
            parameters.initialPhaseError

        phaseClosure =
            QRTLLaserPhysics.phaseClosure(
                phaseError: phaseError
            )

        resonanceResponse =
            QRTLLaserPhysics.resonanceResponse(
                phaseError: phaseError,
                parameters: parameters
            )

        twistCurrent =
            parameters.initialTwistCurrent

        shellEnergy =
            parameters.initialShellEnergy

        coupling = 0.0

        coherence =
            parameters.initialCoherence

        qrtlState = QRTLState(
            phaseError: phaseError,
            phaseClosure: phaseClosure,
            twistCurrent: twistCurrent,
            resonanceResponse: resonanceResponse,
            shellEnergy: shellEnergy,
            coupling: coupling,
            coherence: coherence,
            lossReduction: 0.0,
            beamAreaFactor: 1.0,
            coherenceGain: 1.0,
            lossGain: 1.0,
            concentrationGain: 1.0,
            combinedGain: 1.0,
            roundTripCount: 0,
            gainMediumCrossings: 0,
            stableLockRounds: 0,
            resonanceLocked: false,
            circulatingFieldFactor: 1.0,
            transmittedOutputFactor: 0.0,
            outputEvents: 0,
            outputEnabled: false,
            currentDirection: .forward,
            physicalElapsedTime: 0.0
        )

        // Use locals for initialization rather than capturing
        // properties inside the map expression.

        let photonCount =
            parameters.photonCount

        let cavityLength =
            parameters.cavityLength

        photonNodes =
            (0..<photonCount).map {
                id in

                PhotonState(
                    id: id,
                    cavityLength: cavityLength
                )
            }

        representativeZ = 0.0
        previousZ = 0.0
        representativeDirection = .forward

        updatePhotonPositions()
    }

    deinit {
        timer?.invalidate()
    }

   
    var lossReduction: Double {
        qrtlState.lossReduction
    }

    var beamAreaFactor: Double {
        qrtlState.beamAreaFactor
    }

    var combinedGain: Double {
        qrtlState.combinedGain
    }

    var beamLocked: Bool {
        qrtlState.resonanceLocked
    }

    // MARK: Start

    func start() {

        stop()
        resetState()

        isRunning = true
        lastTick = Date()

        timer =
            Timer.scheduledTimer(
                withTimeInterval: 1.0 / 60.0,
                repeats: true
            ) { [weak self] _ in

                self?.tick()
            }
    }

    // MARK: Stop

    func stop() {

        timer?.invalidate()
        timer = nil

        isRunning = false
        lastTick = nil
    }

    // MARK: Reset

    func reset() {

        stop()
        resetState()
    }

    // MARK: Reset State

    private func resetState() {

        stateLock.lock()

        defer {
            stateLock.unlock()
        }

        phaseError =
            parameters.initialPhaseError

        phaseClosure =
            QRTLLaserPhysics.phaseClosure(
                phaseError: phaseError
            )

        resonanceResponse =
            QRTLLaserPhysics.resonanceResponse(
                phaseError: phaseError,
                parameters: parameters
            )

        twistCurrent =
            parameters.initialTwistCurrent

        shellEnergy =
            parameters.initialShellEnergy

        coupling = 0.0

        coherence =
            parameters.initialCoherence

        representativeZ = 0.0
        previousZ = 0.0

        representativeDirection =
            .forward

        gainCrossingInProgress = false
        activeGainTraversalDirection = nil

        roundTripCount = 0
        gainMediumCrossings = 0
        stableLockRounds = 0

        resonanceLocked = false

        circulatingFieldFactor = 1.0
        transmittedOutputFactor = 0.0
        outputEvents = 0

        physicalPathDistance = 0.0
        elapsedTime = 0.0

        let photonCount =
            parameters.photonCount

        let cavityLength =
            parameters.cavityLength

        photonNodes =
            (0..<photonCount).map {
                id in

                PhotonState(
                    id: id,
                    cavityLength: cavityLength
                )
            }

        qrtlState =
            makeStateLocked()

        updatePhotonPositionsLocked()
    }

    // MARK: Tick

    private func tick() {

        let now = Date()

        let dt: Double

        if let lastTick {

            dt =
                min(
                    max(
                        now.timeIntervalSince(lastTick),
                        0.0
                    ),
                    0.10
                )

        } else {

            dt = 1.0 / 60.0
        }

        lastTick = now

        stateLock.lock()

        defer {
            stateLock.unlock()
        }

        guard isRunning else {
            return
        }

        elapsedTime += dt

        // --------------------------------------------------------
        // Safety timeout.
        //
        // This does NOT create resonance lock.
        // --------------------------------------------------------

        if elapsedTime >=
            parameters.maximumSimulationDuration {

            isRunning = false

            timer?.invalidate()
            timer = nil

            return
        }

        propagateRepresentativeMode(
            dt: dt
        )

        advanceVisualMarkers(
            dt: dt
        )

        updatePhotonPositionsLocked()

        updatePublishedStateLocked()
    }

    // MARK: Representative Cavity Mode

    private func propagateRepresentativeMode(
        dt: Double
    ) {

        previousZ =
            representativeZ

        let visualSpeed =
            parameters.cavityLength
            /
            parameters.visualOneWayDuration

        switch representativeDirection {

        case .forward:

            let nextZ =
                representativeZ
                +
                visualSpeed * dt

            let distance =
                max(
                    0.0,
                    min(
                        nextZ,
                        parameters.cavityLength
                    )
                    -
                    representativeZ
                )

            physicalPathDistance += distance

            representativeZ = nextZ

            if representativeZ >=
                parameters.cavityLength {

                representativeZ =
                    parameters.cavityLength

                processOutputCoupler()

                // The surviving circulating component is
                // reflected back toward the gain medium.

                representativeDirection =
                    .returnPath

                gainCrossingInProgress = false
                activeGainTraversalDirection = nil
            }

        case .returnPath:

            let nextZ =
                representativeZ
                -
                visualSpeed * dt

            let distance =
                max(
                    0.0,
                    representativeZ
                    -
                    max(
                        nextZ,
                        0.0
                    )
                )

            physicalPathDistance += distance

            representativeZ = nextZ

            if representativeZ <= 0.0 {

                representativeZ = 0.0

                // Rear mirror is fully reflective.

                representativeDirection =
                    .forward

                gainCrossingInProgress = false
                activeGainTraversalDirection = nil

                completeRoundTrip()
            }
        }

        detectGainMediumCrossing()
    }

    // MARK: Gain Medium Crossing

    private func detectGainMediumCrossing() {

        let z =
            representativeZ

        let insideGain =
            z >= parameters.gainStartZ
            &&
            z <= parameters.gainEndZ

        if insideGain {

            if !gainCrossingInProgress
                ||
                activeGainTraversalDirection
                    != representativeDirection {

                gainCrossingInProgress = true

                activeGainTraversalDirection =
                    representativeDirection

                processGainMediumTraversal(
                    direction: representativeDirection
                )
            }

        } else {

            gainCrossingInProgress = false
            activeGainTraversalDirection = nil
        }
    }

    // MARK: QRTL Gain-Medium Interaction

    private func processGainMediumTraversal(
        direction: CavityDirection
    ) {

        gainMediumCrossings += 1

        // --------------------------------------------------------
        // 1. Current phase closure
        // --------------------------------------------------------

        phaseClosure =
            QRTLLaserPhysics.phaseClosure(
                phaseError: phaseError
            )

        // --------------------------------------------------------
        // 2. Current resonance response
        // --------------------------------------------------------

        resonanceResponse =
            QRTLLaserPhysics.resonanceResponse(
                phaseError: phaseError,
                parameters: parameters
            )

        // --------------------------------------------------------
        // 3. Current shell energy
        // --------------------------------------------------------

        let normalizedTwist =
            QRTLLaserPhysics.clamp(
                twistCurrent
                /
                parameters.targetTwistCurrent,
                0.0,
                1.0
            )

        shellEnergy =
            QRTLLaserPhysics.shellEnergy(
                resonanceResponse:
                    resonanceResponse,
                normalizedTwistCurrent:
                    normalizedTwist,
                parameters:
                    parameters
            )

        // --------------------------------------------------------
        // 4. QRTL coupling progression
        //
        // Unlike the old multiplicative bootstrap, this is an
        // iterative state update.
        // --------------------------------------------------------

        coupling =
            QRTLLaserPhysics.qrtlCoupling(
                oldCoupling: coupling,
                phaseClosure: phaseClosure,
                resonanceResponse:
                    resonanceResponse,
                shellEnergy: shellEnergy,
                parameters: parameters
            )

        // --------------------------------------------------------
        // 5. Coherence
        // --------------------------------------------------------

        coherence =
            QRTLLaserPhysics.coherence(
                coupling: coupling,
                parameters: parameters
            )

        // --------------------------------------------------------
        // 6. Twist current
        // --------------------------------------------------------

        twistCurrent =
            QRTLLaserPhysics.twistCurrent(
                oldCurrent:
                    twistCurrent,
                phaseClosure:
                    phaseClosure,
                coupling:
                    coupling,
                parameters:
                    parameters
            )

        // --------------------------------------------------------
        // 7. Phase convergence
        //
        // The correction contains:
        //
        // - a bounded baseline convergence term
        // - phase-closure contribution
        // - QRTL coupling contribution
        //
        // This creates an actual convergence path rather than
        // requiring coupling to become high before phase can move.
        // --------------------------------------------------------

        let phaseCorrection =
            parameters.phaseCorrectionBase
            +
            parameters.phaseCorrectionClosureWeight
            * phaseClosure
            +
            parameters.phaseCorrectionCouplingWeight
            * coupling

        let boundedPhaseCorrection =
            QRTLLaserPhysics.clamp(
                phaseCorrection,
                0.0,
                0.50
            )

        phaseError *=
            (
                1.0
                -
                boundedPhaseCorrection
            )

        phaseError =
            max(
                0.0,
                phaseError
            )

        // --------------------------------------------------------
        // 8. Re-evaluate complete post-interaction QRTL state.
        // --------------------------------------------------------

        phaseClosure =
            QRTLLaserPhysics.phaseClosure(
                phaseError: phaseError
            )

        resonanceResponse =
            QRTLLaserPhysics.resonanceResponse(
                phaseError: phaseError,
                parameters: parameters
            )

        let updatedNormalizedTwist =
            QRTLLaserPhysics.clamp(
                twistCurrent
                /
                parameters.targetTwistCurrent,
                0.0,
                1.0
            )

        shellEnergy =
            QRTLLaserPhysics.shellEnergy(
                resonanceResponse:
                    resonanceResponse,
                normalizedTwistCurrent:
                    updatedNormalizedTwist,
                parameters:
                    parameters
            )

        // Important:
        // Coupling is updated again from the post-interaction
        // state so that the pipeline is continuous.

        coupling =
            QRTLLaserPhysics.qrtlCoupling(
                oldCoupling:
                    coupling,
                phaseClosure:
                    phaseClosure,
                resonanceResponse:
                    resonanceResponse,
                shellEnergy:
                    shellEnergy,
                parameters:
                    parameters
            )

        coherence =
            QRTLLaserPhysics.coherence(
                coupling:
                    coupling,
                parameters:
                    parameters
            )

        let lossReduction =
            QRTLLaserPhysics.lossReduction(
                coupling:
                    coupling,
                parameters:
                    parameters
            )

        let beamAreaFactor =
            QRTLLaserPhysics.beamAreaFactor(
                coupling:
                    coupling,
                parameters:
                    parameters
            )

        // --------------------------------------------------------
        // 9. Amplification/model metrics
        // --------------------------------------------------------

        let coherenceGain =
            coherence
            /
            max(
                parameters.initialCoherence,
                1.0e-12
            )

        let lossGain =
            1.0
            +
            lossReduction

        let concentrationGain =
            1.0
            /
            max(
                beamAreaFactor,
                1.0e-12
            )

        let combinedGain =
            coherenceGain
            *
            lossGain
            *
            concentrationGain

        qrtlState =
            QRTLState(
                phaseError:
                    phaseError,
                phaseClosure:
                    phaseClosure,
                twistCurrent:
                    twistCurrent,
                resonanceResponse:
                    resonanceResponse,
                shellEnergy:
                    shellEnergy,
                coupling:
                    coupling,
                coherence:
                    coherence,
                lossReduction:
                    lossReduction,
                beamAreaFactor:
                    beamAreaFactor,
                coherenceGain:
                    coherenceGain,
                lossGain:
                    lossGain,
                concentrationGain:
                    concentrationGain,
                combinedGain:
                    combinedGain,
                roundTripCount:
                    roundTripCount,
                gainMediumCrossings:
                    gainMediumCrossings,
                stableLockRounds:
                    stableLockRounds,
                resonanceLocked:
                    resonanceLocked,
                circulatingFieldFactor:
                    circulatingFieldFactor,
                transmittedOutputFactor:
                    transmittedOutputFactor,
                outputEvents:
                    outputEvents,
                outputEnabled:
                    resonanceLocked
                    &&
                    transmittedOutputFactor > 0.0,
                currentDirection:
                    direction,
                physicalElapsedTime:
                    physicalPathDistance
                    /
                    parameters.speedOfLight
            )
    }

    // MARK: Output Coupler

    private func processOutputCoupler() {

        // --------------------------------------------------------
        // Before lock:
        //
        // No modeled output is transmitted.
        // The entire circulating field remains in the cavity.
        // --------------------------------------------------------

        guard resonanceLocked else {

            transmittedOutputFactor = 0.0
            return
        }

        // --------------------------------------------------------
        // Actual modeled output-coupler event.
        //
        // 10% transmitted
        // 90% reflected
        //
        // The transmitted component becomes the authoritative
        // output state.
        // --------------------------------------------------------

        let incidentField =
            circulatingFieldFactor

        let transmitted =
            incidentField
            *
            parameters.outputTransmission

        let reflected =
            incidentField
            *
            parameters.outputReflection

        transmittedOutputFactor =
            transmitted

        circulatingFieldFactor =
            reflected

        outputEvents += 1
    }

    // MARK: Complete Round Trip

    private func completeRoundTrip() {

        roundTripCount += 1

        // --------------------------------------------------------
        // Evaluate the four required lock conditions.
        // --------------------------------------------------------

        let lockCriteriaSatisfied =
            qrtlState.phaseClosure
                >=
                parameters.phaseClosureLockThreshold

            &&

            abs(
                qrtlState.phaseError
            )
                <=
                parameters.maximumPhaseErrorForLock

            &&

            qrtlState.coupling
                >=
                parameters.qrtlCouplingLockThreshold

            &&

            qrtlState.coherence
                >=
                parameters.coherenceLockThreshold

        if lockCriteriaSatisfied {

            stableLockRounds += 1

        } else {

            stableLockRounds = 0
        }

        // --------------------------------------------------------
        // The ONLY lock trigger.
        //
        // No timer, output event, or visual state can create lock.
        // --------------------------------------------------------

        if stableLockRounds
            >=
            parameters.requiredStableLockRounds {

            resonanceLocked = true
        }

        updatePublishedStateLocked()
    }

    // MARK: Visual Photon Markers

    private func advanceVisualMarkers(
        dt: Double
    ) {

        let visualSpeed =
            parameters.cavityLength
            /
            parameters.visualOneWayDuration

        for index in photonNodes.indices {

            switch photonNodes[index].direction {

            case .forward:

                photonNodes[index].z +=
                    visualSpeed * dt

                if photonNodes[index].z
                    >=
                    parameters.cavityLength {

                    photonNodes[index].z =
                        parameters.cavityLength

                    photonNodes[index].direction =
                        .returnPath

                    photonNodes[index]
                        .hasEnteredGainThisTraversal =
                        false
                }

            case .returnPath:

                photonNodes[index].z -=
                    visualSpeed * dt

                if photonNodes[index].z <= 0.0 {

                    photonNodes[index].z = 0.0

                    photonNodes[index].direction =
                        .forward

                    photonNodes[index]
                        .hasEnteredGainThisTraversal =
                        false
                }
            }
        }
    }

    // MARK: Photon Position Update

    private func updatePhotonPositions() {

        stateLock.lock()

        defer {
            stateLock.unlock()
        }

        updatePhotonPositionsLocked()
    }

    private func updatePhotonPositionsLocked() {

        for index in photonNodes.indices {

            photonNodes[index]
                .updateVisualPosition(
                    coherence:
                        qrtlState.coherence
                )
        }
    }

    // MARK: State Construction

    private func makeStateLocked()
        -> QRTLState {

        let lossReduction =
            QRTLLaserPhysics.lossReduction(
                coupling:
                    coupling,
                parameters:
                    parameters
            )

        let beamAreaFactor =
            QRTLLaserPhysics.beamAreaFactor(
                coupling:
                    coupling,
                parameters:
                    parameters
            )

        let coherenceGain =
            coherence
            /
            max(
                parameters.initialCoherence,
                1.0e-12
            )

        let lossGain =
            1.0
            +
            lossReduction

        let concentrationGain =
            1.0
            /
            max(
                beamAreaFactor,
                1.0e-12
            )

        let combinedGain =
            coherenceGain
            *
            lossGain
            *
            concentrationGain

        return QRTLState(
            phaseError:
                phaseError,
            phaseClosure:
                phaseClosure,
            twistCurrent:
                twistCurrent,
            resonanceResponse:
                resonanceResponse,
            shellEnergy:
                shellEnergy,
            coupling:
                coupling,
            coherence:
                coherence,
            lossReduction:
                lossReduction,
            beamAreaFactor:
                beamAreaFactor,
            coherenceGain:
                coherenceGain,
            lossGain:
                lossGain,
            concentrationGain:
                concentrationGain,
            combinedGain:
                combinedGain,
            roundTripCount:
                roundTripCount,
            gainMediumCrossings:
                gainMediumCrossings,
            stableLockRounds:
                stableLockRounds,
            resonanceLocked:
                resonanceLocked,
            circulatingFieldFactor:
                circulatingFieldFactor,
            transmittedOutputFactor:
                transmittedOutputFactor,
            outputEvents:
                outputEvents,
            outputEnabled:
                resonanceLocked
                &&
                transmittedOutputFactor > 0.0,
            currentDirection:
                representativeDirection,
            physicalElapsedTime:
                physicalPathDistance
                /
                parameters.speedOfLight
        )
    }

    private func updatePublishedStateLocked() {

        qrtlState =
            makeStateLocked()
    }

    // MARK: Thread-safe Snapshot

    func snapshot() -> (
        state: QRTLState,
        photons: [PhotonState],
        running: Bool,
        elapsed: Double
    ) {

        stateLock.lock()

        defer {
            stateLock.unlock()
        }

        return (
            qrtlState,
            photonNodes,
            isRunning,
            elapsedTime
        )
    }
}

// MARK: - SceneKit View

struct QRTLLaserSceneView: UIViewRepresentable {

    @ObservedObject var monitor: MasterMonitor

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(
        context: Context
    ) -> SCNView {

        let view = SCNView()

        view.backgroundColor =
            UIColor(
                red: 0.015,
                green: 0.02,
                blue: 0.035,
                alpha: 1.0
            )

        view.scene =
            makeScene()

        view.allowsCameraControl =
            true

        view.autoenablesDefaultLighting =
            false

        view.antialiasingMode =
            .multisampling4X

        context.coordinator.monitor =
            monitor

        context.coordinator.view =
            view

        return view
    }

    func updateUIView(
        _ view: SCNView,
        context: Context
    ) {

        context.coordinator.monitor =
            monitor

        context.coordinator.updateScene()
    }

    // MARK: Scene

    private func makeScene()
        -> SCNScene {

        let scene =
            SCNScene()

        // --------------------------------------------------------
        // Camera
        // --------------------------------------------------------

        let cameraNode =
            SCNNode()

        let camera =
            SCNCamera()

        camera.fieldOfView =
            55

        cameraNode.camera =
            camera

        cameraNode.position =
            SCNVector3(
                0,
                4.8,
                11.5
            )

        cameraNode.eulerAngles =
            SCNVector3(
                -0.20,
                0,
                0
            )

        scene.rootNode.addChildNode(
            cameraNode
        )

        // --------------------------------------------------------
        // Lights
        // --------------------------------------------------------

        let ambientNode =
            SCNNode()

        let ambient =
            SCNLight()

        ambient.type =
            .ambient

        ambient.intensity =
            500

        ambientNode.light =
            ambient

        scene.rootNode.addChildNode(
            ambientNode
        )

        let keyNode =
            SCNNode()

        let key =
            SCNLight()

        key.type =
            .omni

        key.intensity =
            1000

        keyNode.light =
            key

        keyNode.position =
            SCNVector3(
                2,
                4,
                4
            )

        scene.rootNode.addChildNode(
            keyNode
        )

        // --------------------------------------------------------
        // Cavity axis
        // --------------------------------------------------------

        let axisGeometry =
            SCNCylinder(
                radius: 0.015,
                height: 6.0
            )

        axisGeometry.firstMaterial =
            makeMaterial(
                color: .darkGray,
                emission: .clear
            )

        let axisNode =
            SCNNode(
                geometry:
                    axisGeometry
            )

        axisNode.eulerAngles.x =
            .pi / 2

        scene.rootNode.addChildNode(
            axisNode
        )

        // --------------------------------------------------------
        // Gain medium
        // --------------------------------------------------------

        let gainGeometry =
            SCNCylinder(
                radius: 1.55,
                height: 3.0
            )

        let gainMaterial =
            SCNMaterial()

        gainMaterial.diffuse.contents =
            UIColor(
                red: 0.18,
                green: 0.35,
                blue: 0.75,
                alpha: 0.18
            )

        gainMaterial.emission.contents =
            UIColor(
                red: 0.05,
                green: 0.15,
                blue: 0.55,
                alpha: 0.20
            )

        gainMaterial.transparency =
            0.22

        gainMaterial.isDoubleSided =
            true

        gainGeometry.firstMaterial =
            gainMaterial

        let gainNode =
            SCNNode(
                geometry:
                    gainGeometry
            )

        gainNode.name =
            "GainMedium"

        gainNode.eulerAngles.x =
            .pi / 2

        gainNode.position =
            SCNVector3(
                0,
                0,
                3.0
            )

        scene.rootNode.addChildNode(
            gainNode
        )

        // --------------------------------------------------------
        // Rear mirror
        // --------------------------------------------------------

        scene.rootNode.addChildNode(
            makeMirror(
                name: "RearMirror",
                z: 0.0,
                radius: 1.8
            )
        )

        // --------------------------------------------------------
        // Output coupler
        // --------------------------------------------------------

        scene.rootNode.addChildNode(
            makeMirror(
                name: "OutputCoupler",
                z: 6.0,
                radius: 1.8
            )
        )

        // --------------------------------------------------------
        // Photon markers
        // --------------------------------------------------------

        for id in 0..<90 {

            let geometry =
                SCNSphere(
                    radius: 0.045
                )

            geometry.firstMaterial =
                makeMaterial(
                    color: .systemRed,
                    emission: .systemOrange
                )

            let node =
                SCNNode(
                    geometry:
                        geometry
                )

            node.name =
                "PhotonMarker-\(id)"

            scene.rootNode.addChildNode(
                node
            )
        }

        // --------------------------------------------------------
        // Output beam
        // --------------------------------------------------------

        let beamGeometry =
            SCNCylinder(
                radius: 0.12,
                height: 2.0
            )

        beamGeometry.firstMaterial =
            makeMaterial(
                color: .systemRed,
                emission: .systemRed
            )

        let beamNode =
            SCNNode(
                geometry:
                    beamGeometry
            )

        beamNode.name =
            "OutputBeam"

        beamNode.eulerAngles.x =
            .pi / 2

        beamNode.position =
            SCNVector3(
                0,
                0,
                7.0
            )

        beamNode.opacity =
            0.0

        scene.rootNode.addChildNode(
            beamNode
        )

        addTraversalGuide(
            to: scene
        )

        return scene
    }

    // MARK: Materials

    private func makeMaterial(
        color: UIColor,
        emission: UIColor
    ) -> SCNMaterial {

        let material =
            SCNMaterial()

        material.diffuse.contents =
            color

        material.emission.contents =
            emission

        return material
    }

    private func makeMirror(
        name: String,
        z: Float,
        radius: CGFloat
    ) -> SCNNode {

        let geometry =
            SCNCylinder(
                radius: radius,
                height: 0.08
            )

        geometry.firstMaterial =
            makeMaterial(
                color: .lightGray,
                emission: .clear
            )

        let node =
            SCNNode(
                geometry:
                    geometry
            )

        node.name =
            name

        node.eulerAngles.x =
            .pi / 2

        node.position =
            SCNVector3(
                0,
                0,
                z
            )

        return node
    }

    private func addTraversalGuide(
        to scene: SCNScene
    ) {

        let forwardGeometry =
            SCNCylinder(
                radius: 0.025,
                height: 1.2
            )

        forwardGeometry.firstMaterial =
            makeMaterial(
                color: .systemGreen,
                emission: .systemGreen
            )

        let forward =
            SCNNode(
                geometry:
                    forwardGeometry
            )

        forward.eulerAngles.x =
            .pi / 2

        forward.position =
            SCNVector3(
                2.0,
                0,
                2.5
            )

        scene.rootNode.addChildNode(
            forward
        )

        let returnGeometry =
            SCNCylinder(
                radius: 0.025,
                height: 1.2
            )

        returnGeometry.firstMaterial =
            makeMaterial(
                color: .systemBlue,
                emission: .systemBlue
            )

        let returning =
            SCNNode(
                geometry:
                    returnGeometry
            )

        returning.eulerAngles.x =
            .pi / 2

        returning.position =
            SCNVector3(
                -2.0,
                0,
                4.0
            )

        scene.rootNode.addChildNode(
            returning
        )
    }

    // MARK: Coordinator

    final class Coordinator {

        weak var view: SCNView?
        weak var monitor: MasterMonitor?

        func updateScene() {

            guard
                let scene = view?.scene,
                let monitor
            else {
                return
            }

            let snapshot =
                monitor.snapshot()

            // ----------------------------------------------------
            // Photon marker positions
            // ----------------------------------------------------

            for photon in snapshot.photons {

                guard
                    let node =
                        scene.rootNode.childNode(
                            withName:
                                "PhotonMarker-\(photon.id)",
                            recursively:
                                true
                        )
                else {
                    continue
                }

                node.position =
                    photon.position

                let coherence =
                    snapshot.state.coherence

                let alignment =
                    max(
                        0.0,
                        min(
                            1.0,
                            (
                                coherence - 0.70
                            )
                            /
                            0.25
                        )
                    )

                node.opacity =
                    CGFloat(
                        0.30
                        +
                        0.70 * alignment
                    )
            }

            // ----------------------------------------------------
            // Gain medium intensity
            // ----------------------------------------------------

            if let gain =
                scene.rootNode.childNode(
                    withName:
                        "GainMedium",
                    recursively:
                        true
                ) {

                gain.opacity =
                    CGFloat(
                        0.12
                        +
                        0.35
                        *
                        snapshot.state.coupling
                    )
            }

            // ----------------------------------------------------
            // Output beam
            //
            // It is driven by the authoritative transmitted
            // output state, not merely by resonanceLocked.
            // ----------------------------------------------------

            if let beam =
                scene.rootNode.childNode(
                    withName:
                        "OutputBeam",
                    recursively:
                        true
                ) {

                let transmitted =
                    snapshot.state
                        .transmittedOutputFactor

                let isActive =
                    snapshot.state.resonanceLocked
                    &&
                    transmitted > 0.0

                guard isActive else {

                    beam.opacity =
                        0.0

                    return
                }

                // ------------------------------------------------
                // Normalize the transmitted field for visualization.
                //
                // The actual modeled transmission remains 10%.
                // This normalization only keeps the visualization
                // visible.
                // ------------------------------------------------

                let normalizedOutput =
                    min(
                        1.0,
                        transmitted
                        /
                        max(
                            0.10,
                            1.0
                        )
                    )

                beam.opacity =
                    CGFloat(
                        0.25
                        +
                        0.75
                        *
                        normalizedOutput
                    )

                // Area factor describes beam area.
                // Radius therefore scales approximately with sqrt(A).

                let areaFactor =
                    max(
                        0.01,
                        snapshot.state.beamAreaFactor
                    )

                let radius =
                    CGFloat(
                        0.12
                        *
                        sqrt(areaFactor)
                    )

                if let cylinder =
                    beam.geometry
                    as? SCNCylinder {

                    cylinder.radius =
                        min(
                            radius,
                            0.30
                        )
                }
            }

            // ----------------------------------------------------
            // Output coupler appearance
            // ----------------------------------------------------

            if let coupler =
                scene.rootNode.childNode(
                    withName:
                        "OutputCoupler",
                    recursively:
                        true
                ) {

                if snapshot.state.resonanceLocked {

                    coupler.opacity =
                        0.80

                } else {

                    coupler.opacity =
                        0.45
                }
            }
        }
    }
}

// MARK: - Content View

struct ContentView: View {

    @StateObject private var monitor =
        MasterMonitor()

    @State private var showAbout = false
    private let parameters =
        QRTLLaserParameters()

    var body: some View {
        NavigationStack{
        ZStack {
            
            Color.black
                .ignoresSafeArea()
            
            VStack(
                spacing: 12
            ) {
                
                // ------------------------------------------------
                // Header
                // ------------------------------------------------
                
                VStack(
                    spacing: 4
                ) {
                    
                    Text(
                        "QRTL Resonating Amplifier"
                    )
                    .font(
                        .system(
                            size: 24,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        .white
                    )
                    
                    Text(
                        "2.94 µm cavity resonance simulation"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .gray
                    )
                }
                
                // ------------------------------------------------
                // Scene
                // ------------------------------------------------
                
                QRTLLaserSceneView(
                    monitor:
                        monitor
                )
                .frame(
                    minHeight:
                        330
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius:
                            16
                    )
                )
                
                // ------------------------------------------------
                // State
                // ------------------------------------------------
                
                ScrollView {
                    
                    VStack(
                        alignment:
                                .leading,
                        spacing:
                            8
                    ) {
                        
                        Text(
                            "CAVITY TRAVERSAL"
                        )
                        .font(
                            .caption
                                .weight(.bold)
                        )
                        .foregroundStyle(
                            .gray
                        )
                        
                        metricRow(
                            "Direction",
                            monitor.qrtlState
                                .currentDirection
                                .rawValue
                        )
                        
                        metricRow(
                            "Round trips",
                            "\(monitor.qrtlState.roundTripCount)"
                        )
                        
                        metricRow(
                            "Gain crossings",
                            "\(monitor.qrtlState.gainMediumCrossings)"
                        )
                        
                        metricRow(
                            "Physical round-trip time",
                            formatTime(
                                parameters
                                    .physicalRoundTripTime
                            )
                        )
                        
                        metricRow(
                            "Modeled physical elapsed",
                            formatTime(
                                monitor.qrtlState
                                    .physicalElapsedTime
                            )
                        )
                        
                        Divider()
                        
                        Text(
                            "QRTL STATE"
                        )
                        .font(
                            .caption
                                .weight(.bold)
                        )
                        .foregroundStyle(
                            .gray
                        )
                        
                        metricRow(
                            "Phase error",
                            formatRadians(
                                monitor.qrtlState
                                    .phaseError
                            )
                        )
                        
                        metricRow(
                            "Phase closure",
                            format(
                                monitor.qrtlState
                                    .phaseClosure
                            )
                        )
                        
                        metricRow(
                            "Twist current",
                            format(
                                monitor.qrtlState
                                    .twistCurrent
                            )
                        )
                        
                        metricRow(
                            "Resonance response",
                            format(
                                monitor.qrtlState
                                    .resonanceResponse
                            )
                        )
                        
                        metricRow(
                            "Shell energy",
                            format(
                                monitor.qrtlState
                                    .shellEnergy
                            )
                        )
                        
                        metricRow(
                            "QRTL coupling",
                            format(
                                monitor.qrtlState
                                    .coupling
                            )
                        )
                        
                        metricRow(
                            "Coherence",
                            format(
                                monitor.qrtlState
                                    .coherence
                            )
                        )
                        
                        Divider()
                        
                        Text(
                            "AMPLIFICATION / MODE"
                        )
                        .font(
                            .caption
                                .weight(.bold)
                        )
                        .foregroundStyle(
                            .gray
                        )
                        
                        metricRow(
                            "Coherence gain",
                            format(
                                monitor.qrtlState
                                    .coherenceGain
                            )
                        )
                        
                        metricRow(
                            "Loss gain",
                            format(
                                monitor.qrtlState
                                    .lossGain
                            )
                        )
                        
                        metricRow(
                            "Concentration gain",
                            format(
                                monitor.qrtlState
                                    .concentrationGain
                            )
                        )
                        
                        metricRow(
                            "Combined gain",
                            format(
                                monitor.qrtlState
                                    .combinedGain
                            )
                        )
                        
                        Divider()
                        
                        Text(
                            "RESONANCE LOCK"
                        )
                        .font(
                            .caption
                                .weight(.bold)
                        )
                        .foregroundStyle(
                            .gray
                        )
                        
                        metricRow(
                            "Stable lock rounds",
                            "\(monitor.qrtlState.stableLockRounds)"
                            +
                            " / "
                            +
                            "\(parameters.requiredStableLockRounds)"
                        )
                        
                        metricRow(
                            "Lock status",
                            monitor.qrtlState
                                .resonanceLocked
                            ? "LOCKED"
                            : "ALIGNING"
                        )
                        
                        Divider()
                        
                        Text(
                            "OUTPUT COUPLER"
                        )
                        .font(
                            .caption
                                .weight(.bold)
                        )
                        .foregroundStyle(
                            .gray
                        )
                        
                        metricRow(
                            "Transmission",
                            format(
                                parameters
                                    .outputTransmission
                            )
                        )
                        
                        metricRow(
                            "Reflection",
                            format(
                                parameters
                                    .outputReflection
                            )
                        )
                        
                        metricRow(
                            "Circulating field",
                            format(
                                monitor.qrtlState
                                    .circulatingFieldFactor
                            )
                        )
                        
                        metricRow(
                            "Transmitted output",
                            format(
                                monitor.qrtlState
                                    .transmittedOutputFactor
                            )
                        )
                        
                        metricRow(
                            "Output events",
                            "\(monitor.qrtlState.outputEvents)"
                        )
                        
                        metricRow(
                            "Output",
                            monitor.qrtlState
                                .outputEnabled
                            ? "TRANSMITTING"
                            : "OFF"
                        )
                        
                        Divider()
                        
                        Text(
                            "STANDARD LASER VALUES"
                        )
                        .font(
                            .caption
                                .weight(.bold)
                        )
                        .foregroundStyle(
                            .gray
                        )
                        
                        metricRow(
                            "Wavelength",
                            "2.94 µm"
                        )
                        
                        metricRow(
                            "Frequency",
                            formatFrequency(
                                parameters
                                    .targetFrequency
                            )
                        )
                        
                        metricRow(
                            "Photon energy",
                            String(
                                format:
                                    "%.4e",
                                parameters
                                    .photonEnergy
                            )
                            +
                            " J"
                        )
                        
                        Text(
                            "The 8-second limit is a safety timeout only. "
                            +
                            "It does not determine resonance lock."
                        )
                        .font(
                            .caption2
                        )
                        .foregroundStyle(
                            .orange
                        )
                        .padding(
                            .top,
                            4
                        )
                    }
                    .padding()
                }
                .frame(
                    maxHeight:
                        330
                )
                
                // ------------------------------------------------
                // Controls
                // ------------------------------------------------
                
                HStack(
                    spacing: 12
                ) {
                    
                    Button {
                        
                        monitor.start()
                        
                    } label: {
                        
                        Label(
                            "Ignite Cavity",
                            systemImage:
                                "play.fill"
                        )
                        .frame(
                            maxWidth:
                                    .infinity
                        )
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                    
                    Button {
                        
                        monitor.reset()
                        
                    } label: {
                        
                        Label(
                            "Reset",
                            systemImage:
                                "arrow.counterclockwise"
                        )
                        .frame(
                            maxWidth:
                                    .infinity
                        )
                    }
                    .buttonStyle(
                        .bordered
                    )
                }
                .padding(
                    .horizontal
                )
            }}
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAbout = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("Information")
            }
                    }
            .padding()
            .sheet(
                isPresented: $showAbout
            ) {

                NavigationStack {

                    AboutView()
                }
                .preferredColorScheme(
                    .dark
                )
            }
        }
    }

    // MARK: Metric Row

    private func metricRow(
        _ title: String,
        _ value: String
    ) -> some View {

        HStack {

            Text(title)
                .foregroundStyle(
                    .gray
                )

            Spacer()

            Text(value)
                .font(
                    .system(
                        .body,
                        design:
                            .monospaced
                    )
                )
                .foregroundStyle(
                    .white
                )
        }
    }

    private func format(
        _ value: Double
    ) -> String {

        String(
            format:
                "%.4f",
            value
        )
    }

    private func formatRadians(
        _ value: Double
    ) -> String {

        String(
            format:
                "%.4f rad",
            value
        )
    }

    private func formatFrequency(
        _ value: Double
    ) -> String {

        String(
            format:
                "%.4f THz",
            value / 1.0e12
        )
    }

    private func formatTime(
        _ value: Double
    ) -> String {

        if value < 1.0e-6 {

            return String(
                format:
                    "%.2f ns",
                value * 1.0e9
            )

        } else {

            return String(
                format:
                    "%.4e s",
                value
            )
        }
    }
}
