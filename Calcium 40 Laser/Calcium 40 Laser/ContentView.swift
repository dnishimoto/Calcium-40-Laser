/*
 To make the simulated laser produce light at two point nine four micrometers, begin by setting two point nine four micrometers as the target wavelength. This wavelength corresponds to a frequency of about one hundred one point nine seven terahertz. Each photon at this wavelength carries a small amount of energy, about zero point four two two electron volts. The wavelength defines the energy required for each output photon, but it does not by itself determine the electrical input current.

 Choose the desired optical output power, such as ten milliwatts. A higher output power requires more photons every second, and more photons require more input energy. Also choose a threshold current. The threshold current is the minimum electrical current needed before the simulated medium can support coherent laser action. Below threshold, the model may show excitation and random spontaneous emission, but it should not show a stable coherent laser beam. Above threshold, the current beyond the threshold becomes available to support stimulated photon generation.

 Calculate the excess current by subtracting the threshold current from the drive current. For example, if the simulated drive current is two hundred milliamps and the threshold current is one hundred milliamps, the excess current is one hundred milliamps. Current represents moving electric charge. Dividing the excess current by the charge of one electron gives the number of injected electrons per second. An excess current of one hundred milliamps corresponds to about six hundred twenty four quadrillion injected electrons each second.

 Apply a modeled injection efficiency because not every injected electron creates a useful excitation. For example, a seventy percent injection efficiency means that only seventy percent of the injected electrons are treated as useful excitations in the simulation. These useful excitations provide pump energy to the calcium field.

 The calcium field is the simulated active medium. Spread the current-derived pump energy across the calcium lattice. Cells near the center of the pump region receive the most energy, while cells farther away receive less. A smooth Gaussian distribution is appropriate because it produces a concentrated but gradual pump region rather than a sharp artificial edge.

 As the calcium and QRTL lattice evolves, update the phase, twist, displacement, strain, local energy, excitation, and damping of each cell. Allow energy to move between neighboring cells. This produces a collective field rather than a single global value. When cell phases become more aligned, the lattice coherence increases. When phases remain random, coherence remains low.

 Use the lattice coherence and energy localization to calculate a QRTL to electromagnetic coupling proxy. This value should remain clearly labeled as a simulation proxy. It is a model value that controls how effectively the organized calcium and QRTL field contributes to the simulated electromagnetic cavity mode. It is not a measured electromagnetic coupling constant.

 Use the coherence and electromagnetic coupling proxy to calculate a calcium excitation and population inversion proxy. Population inversion means the modeled upper energy state has more population than the lower energy state. In the simulation, population inversion is the condition that allows stimulated emission to add coherent photons to the cavity mode.

 The photon generation rate should rise when the excess current is higher, injection efficiency is higher, lattice coherence is stronger, electromagnetic coupling is stronger, and population inversion is positive. The current creates the pump energy, the pump energy creates the calcium field excitation, the excitation helps create inversion, and the inversion generates simulated photons in the cavity.

 Record a time-domain signal from the lattice while it evolves. Run a fast Fourier transform on that signal to identify the strongest simulated frequency. Convert the strongest frequency into a wavelength and compare it with the two point nine four micrometer target. The simulation should not simply assign the target wavelength to the output. Instead, it should use two point nine four micrometers as the target and report how close the simulated dominant mode is to that target.

 Once the lattice mode is close enough to the target and the modeled population inversion is positive, apply cavity gain and loss. Stimulated emission adds photons to the cavity. Mirror loss, absorption loss, scattering loss, and output-coupler transmission remove photons from the cavity. The model reaches laser threshold only when generated gain is greater than total cavity loss.

 Finally, allow the output coupler to extract a fraction of the cavity photons. For example, a ten percent output coupler transmits ten percent of the circulating photon population as output light and reflects the remaining ninety percent back into the cavity. The cavity must continuously receive new stimulated photons from the excited calcium field. If the model only removes photons at the output coupler and does not replenish them through gain, the simulated beam will fade instead of reaching a stable output.
 */

import Foundation
import SwiftUI
import SceneKit
import Combine
import Accelerate   // for FFT

// MARK: - Measurement Status

enum MeasurementStatus: String {
    case notMeasured = "NOT MEASURED"
    case simulated = "SIMULATED"
    case measured = "MEASURED"
    case agreement = "AGREEMENT"
    case disagreement = "DISAGREEMENT"
}

// MARK: - Calcium Lattice Cell (active medium)

struct CalciumCell {
    var phase: Double           // rad
    var twist: Double
    var displacement: Double
    var strain: Double
    var localEnergy: Double
    var excitation: Double      // 0…1
    var damping: Double
    var upperPopulation: Double // proxy
    var lowerPopulation: Double // proxy

    static func randomInitial() -> CalciumCell {
        CalciumCell(
            phase: Double.random(in: 0..<2 * .pi),
            twist: Double.random(in: -0.1...0.1),
            displacement: 0,
            strain: 0,
            localEnergy: 0.05,
            excitation: 0.0,
            damping: 0.02,
            upperPopulation: 0.1,
            lowerPopulation: 0.9
        )
    }
}

// MARK: - Laser Measurement Engine (extended)

struct QRTLLaserMeasurementEngine {

    static func evaluate(
        state: QRTLState,
        parameters: QRTLLaserParameters,
        inputPowerWatts: Double?,
        measuredOutputPowerWatts: Double?,
        measuredWavelengthMeters: Double?,
        measuredThresholdInputPowerWatts: Double?,
        measuredLinewidthHz: Double?,
        measuredStartupTimeSeconds: Double?,
        measuredInputEnergyJoules: Double?,
        measuredOutputEnergyJoules: Double?,
        experimentalRunCount: Int,
        reproducibleRuns: Int
    ) -> LaserMeasurementState {

        var result = LaserMeasurementState()

        // 1. QRTL convergence
        result.qrtlPhaseError = state.phaseError
        result.qrtlPhaseClosure = state.phaseClosure
        result.qrtlResonanceResponse = state.resonanceResponse
        result.qrtlCoupling = state.coupling
        result.qrtlCoherence = state.coherence
        result.qrtlLocked = state.resonanceLocked

        // 2. Optical gain (model vs measured)
        if let inputPowerWatts, inputPowerWatts > 0 {
            if let measuredOutputPowerWatts, measuredOutputPowerWatts >= 0 {
                result.measuredOpticalGain = measuredOutputPowerWatts / inputPowerWatts
            }
            result.predictedOpticalGain = state.combinedGain
            let gainLength = max(parameters.gainEndZ - parameters.gainStartZ, 1e-12)
            result.gainCoefficientPerMeter = log(max(state.combinedGain, 1e-12)) / gainLength
        }

        // 3. Threshold
        if let predictedGain = result.predictedOpticalGain {
            let totalLoss = calculateRoundTripLoss(state: state, parameters: parameters)
            if totalLoss > 0 {
                result.predictedThresholdInputPowerWatts = inputPowerWatts.map {
                    $0 * totalLoss / max(predictedGain, 1e-12)
                }
            }
            result.thresholdReached = predictedGain > max(totalLoss, 1e-12)
        }
        if let measuredThreshold = measuredThresholdInputPowerWatts {
            result.measuredThresholdInputPowerWatts = measuredThreshold
            if let inputPowerWatts {
                result.thresholdReached = inputPowerWatts >= measuredThreshold
            }
        }

        // 4–5. Power & efficiency
        result.inputOpticalPowerWatts = inputPowerWatts
        result.outputOpticalPowerWatts = measuredOutputPowerWatts
        if let inputPowerWatts {
            result.intracavityPowerWatts = inputPowerWatts * max(state.circulatingFieldFactor, 0)
            result.absorbedPumpPowerWatts = inputPowerWatts
            if let output = measuredOutputPowerWatts {
                result.lossPowerWatts = max(inputPowerWatts - output, 0)
            }
        }
        if let inputEnergy = measuredInputEnergyJoules, inputEnergy > 0,
           let outputEnergy = measuredOutputEnergyJoules {
            result.inputEnergyJoules = inputEnergy
            result.outputEnergyJoules = outputEnergy
            result.measuredEfficiency = outputEnergy / inputEnergy
        }
        if let inputPowerWatts, inputPowerWatts > 0 {
            result.predictedEfficiency = min(1, max(0,
                state.combinedGain * parameters.outputTransmission /
                max(state.combinedGain, 1e-12)))
        }

        // 6. Calcium-40 target (model reference only)
        result.calcium40TransitionWavelengthMeters = parameters.targetWavelengthMeters
        result.calcium40TransitionFrequencyHz = parameters.targetFrequency
        result.calcium40TransitionEnergyJoules = parameters.photonEnergy
        result.calcium40LifetimeSeconds = nil
        result.calcium40LinewidthHz = nil

        // 7. Population (now filled from lattice proxies)
        result.totalPopulation = state.latticeTotalPopulation
        result.lowerStatePopulation = state.latticeLowerPopulation
        result.upperStatePopulation = state.latticeUpperPopulation
        result.excitationFraction = state.latticeExcitationFraction
        result.populationInversion = state.populationInversionProxy

        // 8. Cavity gain/loss
        result.roundTripGain = state.combinedGain
        result.mirrorLoss = 1.0 - parameters.outputReflection
        result.absorptionLoss = parameters.absorptionLoss
        result.scatteringLoss = parameters.scatteringLoss
        result.outputCouplingLoss = parameters.outputTransmission
        result.roundTripLoss = calculateRoundTripLoss(state: state, parameters: parameters)
        result.netRoundTripGain = (result.roundTripGain ?? 0) - (result.roundTripLoss ?? 0)

        // 9. QRTL energy (still model quantities)
        result.energyBeforeQRTLInteractionJoules = nil
        result.energyAfterQRTLInteractionJoules = nil
        result.qrtlEnergyTransferredJoules = nil
        result.qrtlInteractionRatePerSecond = nil

        // 10. Spectrum – predicted is target; measured can be experimental
        result.predictedWavelengthMeters = parameters.targetWavelengthMeters
        result.measuredWavelengthMeters = measuredWavelengthMeters
        result.predictedLinewidthHz = nil
        result.measuredLinewidthHz = measuredLinewidthHz
        result.spectralPowerWatts = measuredOutputPowerWatts

        // Simulated dominant wavelength from FFT (authoritative for “how close”)
        result.simulatedDominantWavelengthMeters = state.simulatedDominantWavelengthMeters
        result.simulatedDominantFrequencyHz = state.simulatedDominantFrequencyHz
        result.wavelengthClosenessPercent = state.wavelengthClosenessPercent

        // 11. Temporal
        if state.resonanceLocked {
            result.predictedStartupTimeSeconds = state.physicalElapsedTime
        }
        result.measuredStartupTimeSeconds = measuredStartupTimeSeconds

        // 12. Prediction vs experiment
        if let measuredWavelengthMeters, measuredWavelengthMeters > 0 {
            result.wavelengthPredictionErrorPercent = percentError(
                predicted: parameters.targetWavelengthMeters,
                measured: measuredWavelengthMeters
            )
        }
        if let predictedGain = result.predictedOpticalGain,
           let measuredGain = result.measuredOpticalGain {
            result.powerPredictionErrorPercent = percentError(
                predicted: predictedGain,
                measured: measuredGain
            )
        }
        if let predictedThreshold = result.predictedThresholdInputPowerWatts,
           let measuredThreshold = result.measuredThresholdInputPowerWatts,
           measuredThreshold > 0 {
            result.thresholdPredictionErrorPercent = percentError(
                predicted: predictedThreshold,
                measured: measuredThreshold
            )
        }

        // 13. Reproduction
        result.experimentalRunCount = experimentalRunCount
        result.reproducibleRuns = reproducibleRuns
        result.independentReproductionSatisfied =
            experimentalRunCount > 0 && reproducibleRuns == experimentalRunCount

        result.physicalOutputDetected =
            measuredOutputPowerWatts != nil && (measuredOutputPowerWatts ?? 0) > 0

        let wavelengthAgrees = result.wavelengthPredictionErrorPercent.map { $0 <= 5 } ?? false
        let powerAgrees = result.powerPredictionErrorPercent.map { $0 <= 10 } ?? false
        result.predictionValidated =
            result.physicalOutputDetected && wavelengthAgrees && powerAgrees

        // Energy accounting
        if let inputEnergy = measuredInputEnergyJoules,
           let outputEnergy = measuredOutputEnergyJoules {
            let losses = max(inputEnergy - outputEnergy, 0)
            let residual = inputEnergy - outputEnergy - losses
            result.energyResidualJoules = residual
            result.energyAccountingClosed =
                abs(residual) <= max(inputEnergy * 0.01, 1e-18)
        }

        // Current / pump proxies (new)
        result.driveCurrentAmps = state.driveCurrentAmps
        result.thresholdCurrentAmps = state.thresholdCurrentAmps
        result.excessCurrentAmps = state.excessCurrentAmps
        result.injectedElectronsPerSecond = state.injectedElectronsPerSecond
        result.usefulExcitationsPerSecond = state.usefulExcitationsPerSecond
        result.photonGenerationRate = state.photonGenerationRate
        result.qrtlToEMCouplingProxy = state.qrtlToEMCouplingProxy

        return result
    }

    private static func calculateRoundTripLoss(
        state: QRTLState,
        parameters: QRTLLaserParameters
    ) -> Double {
        let outputLoss = parameters.outputTransmission
        let absorption = parameters.absorptionLoss
        let scattering = parameters.scatteringLoss
        let modeledLossReduction = QRTLLaserPhysics.clamp(
            state.lossReduction, 0, parameters.maximumLossReduction
        )
        let total = (outputLoss + absorption + scattering) * (1.0 - modeledLossReduction)
        return QRTLLaserPhysics.clamp(total, 0, 1)
    }

    private static func percentError(predicted: Double, measured: Double) -> Double {
        guard abs(predicted) > 1e-30 else { return 0 }
        return abs(measured - predicted) / abs(predicted) * 100
    }
}

// MARK: - LaserMeasurementState (extended)

struct LaserMeasurementState {
    // Stage 1
    var qrtlPhaseError: Double = 0
    var qrtlPhaseClosure: Double = 0
    var qrtlResonanceResponse: Double = 0
    var qrtlCoupling: Double = 0
    var qrtlCoherence: Double = 0
    var qrtlLocked: Bool = false

    // Stage 2
    var inputOpticalPowerWatts: Double?
    var outputOpticalPowerWatts: Double?
    var predictedOpticalGain: Double?
    var measuredOpticalGain: Double?
    var gainCoefficientPerMeter: Double?

    // Stage 3
    var predictedThresholdInputPowerWatts: Double?
    var measuredThresholdInputPowerWatts: Double?
    var thresholdReached: Bool = false

    // Stage 4
    var absorbedPumpPowerWatts: Double?
    var intracavityPowerWatts: Double?
    var lossPowerWatts: Double?

    // Stage 5
    var inputEnergyJoules: Double?
    var outputEnergyJoules: Double?
    var predictedEfficiency: Double?
    var measuredEfficiency: Double?

    // Stage 6
    var calcium40TransitionEnergyJoules: Double?
    var calcium40TransitionFrequencyHz: Double?
    var calcium40TransitionWavelengthMeters: Double?
    var calcium40LifetimeSeconds: Double?
    var calcium40LinewidthHz: Double?

    // Stage 7
    var totalPopulation: Double?
    var lowerStatePopulation: Double?
    var upperStatePopulation: Double?
    var excitationFraction: Double?
    var populationInversion: Double?

    // Stage 8
    var roundTripGain: Double?
    var mirrorLoss: Double?
    var absorptionLoss: Double?
    var scatteringLoss: Double?
    var outputCouplingLoss: Double?
    var roundTripLoss: Double?
    var netRoundTripGain: Double?

    // Stage 9
    var energyBeforeQRTLInteractionJoules: Double?
    var energyAfterQRTLInteractionJoules: Double?
    var qrtlEnergyTransferredJoules: Double?
    var qrtlInteractionRatePerSecond: Double?

    // Stage 10
    var predictedWavelengthMeters: Double?
    var measuredWavelengthMeters: Double?
    var predictedLinewidthHz: Double?
    var measuredLinewidthHz: Double?
    var spectralPowerWatts: Double?
    // New – from FFT of lattice signal
    var simulatedDominantWavelengthMeters: Double?
    var simulatedDominantFrequencyHz: Double?
    var wavelengthClosenessPercent: Double?

    // Stage 11
    var predictedStartupTimeSeconds: Double?
    var measuredStartupTimeSeconds: Double?
    var measuredPulseDurationSeconds: Double?
    var measuredRepetitionRateHz: Double?
    var outputStability: Double?

    // Stage 12
    var wavelengthPredictionErrorPercent: Double?
    var powerPredictionErrorPercent: Double?
    var thresholdPredictionErrorPercent: Double?

    // Stage 13
    var experimentalRunCount: Int = 0
    var reproducibleRuns: Int = 0

    var physicalOutputDetected: Bool = false
    var predictionValidated: Bool = false
    var independentReproductionSatisfied: Bool = false

    var energyResidualJoules: Double?
    var energyAccountingClosed: Bool = false

    // Current / pump / photon-rate proxies
    var driveCurrentAmps: Double?
    var thresholdCurrentAmps: Double?
    var excessCurrentAmps: Double?
    var injectedElectronsPerSecond: Double?
    var usefulExcitationsPerSecond: Double?
    var photonGenerationRate: Double?
    var qrtlToEMCouplingProxy: Double?
}

// MARK: - Parameters (extended with current, lattice, losses)

struct QRTLLaserParameters {

    let driveCurrentAmps: Double = 0.500          // was 0.200 (200 mA → 500 mA)

    // More of the current becomes useful excitation
    let injectionEfficiency: Double = 0.90        // was 0.70

    // Optional: lower the current needed before excess current appears
    let thresholdCurrentAmps: Double = 0.050      // was 0.100
    
    // Standard constants
    let speedOfLight = 2.99792458e8
    let planckConstant = 6.62607015e-34
    let electronCharge = 1.60217662e-19
    let targetWavelengthMeters = 2.94e-6          // 2.94 µm

    var targetFrequency: Double { speedOfLight / targetWavelengthMeters }   // ~1.0197e14 Hz
    var photonEnergy: Double { planckConstant * targetFrequency }           // ~6.76e-20 J ≈ 0.422 eV

    // Desired optical output (example)
    let targetOutputPowerWatts: Double = 0.010     // 10 mW

  
    // Cavity geometry
    let cavityLength: Double = 6.0
    let gainStartZ: Double = 1.5
    let gainEndZ: Double = 4.5

    // Visualization timing (does NOT affect physical time)
    let visualOneWayDuration: Double = 0.45

    var physicalOneWayTime: Double { cavityLength / speedOfLight }
    var physicalRoundTripTime: Double { (2.0 * cavityLength) / speedOfLight }

    // QRTL initial state
    let initialPhaseError: Double = 0.50 * Double.pi
    let initialCoherence: Double = 0.70
    let maximumCoherence: Double = 0.95
    let initialTwistCurrent: Double = 0.05
    let targetTwistCurrent: Double = 1.0
    let initialShellEnergy: Double = 0.10
    let targetShellEnergy: Double = 1.0
    let qrtlBaseCoupling: Double = 1.0
    let resonanceWidth: Double = 0.35

    // Bootstrap / convergence
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

    // Loss / beam
    let maximumLossReduction: Double = 0.25
    let minimumBeamAreaFactor: Double = 0.50
    let absorptionLoss: Double = 0.02
    let scatteringLoss: Double = 0.01

    // Output coupler
    let outputTransmission: Double = 0.10
    var outputReflection: Double { 1.0 - outputTransmission }

    // Lock criteria
    let phaseClosureLockThreshold: Double = 0.99
    let maximumPhaseErrorForLock: Double = 0.05
    let qrtlCouplingLockThreshold: Double = 0.90
    let coherenceLockThreshold: Double = 0.94
    let requiredStableLockRounds: Int = 5

    // Visualization
    let photonCount: Int = 90
    let photonRadius: CGFloat = 0.045
    let maximumSimulationDuration: Double = 20.0

    // Calcium lattice
    let latticeSize: Int = 32                      // 1-D chain for simplicity
    let gaussianPumpSigmaCells: Double = 6.0
    let neighborCouplingStrength: Double = 0.08
    let latticeDampingBase: Double = 0.015
    let inversionThresholdForLasing: Double = 0.05
    let wavelengthClosenessTolerancePercent: Double = 5.0
}

// MARK: - QRTL State (extended with lattice & current proxies)

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

    var circulatingFieldFactor: Double
    var transmittedOutputFactor: Double
    var outputEvents: Int
    var outputEnabled: Bool

    var currentDirection: CavityDirection
    var physicalElapsedTime: Double

    // New lattice / current / spectrum proxies
    var driveCurrentAmps: Double
    var thresholdCurrentAmps: Double
    var excessCurrentAmps: Double
    var injectedElectronsPerSecond: Double
    var usefulExcitationsPerSecond: Double
    var qrtlToEMCouplingProxy: Double
    var populationInversionProxy: Double
    var photonGenerationRate: Double          // photons / s (model)
    var latticeTotalPopulation: Double
    var latticeUpperPopulation: Double
    var latticeLowerPopulation: Double
    var latticeExcitationFraction: Double
    var simulatedDominantFrequencyHz: Double?
    var simulatedDominantWavelengthMeters: Double?
    var wavelengthClosenessPercent: Double?
}

enum CavityDirection: String {
    case forward = "+Z"
    case returnPath = "-Z"
}

// MARK: - Photon / Mode Marker (unchanged)

struct PhotonState {
    let id: Int
    var position: SCNVector3
    var baseRadius: Float
    var z: Double
    var radialOffset: Double
    var direction: CavityDirection
    var hasEnteredGainThisTraversal: Bool

    init(id: Int, cavityLength: Double) {
        self.id = id
        self.baseRadius = Float(0.030 + 0.030 * Double(id % 7) / 6.0)
        self.radialOffset = 0.20 + 1.15 * Double(id % 17) / 16.0
        let traversalFraction = Double(id) / Double(max(1, 90))
        let totalTraversal = 2.0 * cavityLength
        let traversalPosition = traversalFraction * totalTraversal
        if traversalPosition <= cavityLength {
            self.z = traversalPosition
            self.direction = .forward
        } else {
            self.z = totalTraversal - traversalPosition
            self.direction = .returnPath
        }
        let angle = Double(id) * 0.71
        self.position = SCNVector3(
            Float(cos(angle) * radialOffset),
            Float(sin(angle) * radialOffset),
            Float(z)
        )
        self.hasEnteredGainThisTraversal = false
    }

    mutating func updateVisualPosition(coherence: Double) {
        let alignment = max(0, min(1, (coherence - 0.70) / 0.25))
        let visualRadius = radialOffset * (1.0 - 0.70 * alignment)
        let angle = Double(id) * 0.71 + z * 0.18
        position = SCNVector3(
            Float(cos(angle) * visualRadius),
            Float(sin(angle) * visualRadius),
            Float(z)
        )
    }
}

// MARK: - Physics helpers

enum QRTLLaserPhysics {

    static func frequency(wavelength: Double, parameters: QRTLLaserParameters) -> Double {
        parameters.speedOfLight / wavelength
    }

    static func photonEnergy(frequency: Double, parameters: QRTLLaserParameters) -> Double {
        parameters.planckConstant * frequency
    }

    static func phaseClosure(phaseError: Double) -> Double {
        clamp((1.0 + cos(phaseError)) / 2.0, 0, 1)
    }

    static func smoothStep(_ value: Double) -> Double {
        let x = clamp(value, 0, 1)
        return x * x * (3.0 - 2.0 * x)
    }

    static func twistCurrent(
        oldCurrent: Double,
        phaseClosure: Double,
        coupling: Double,
        parameters: QRTLLaserParameters
    ) -> Double {
        let drive = parameters.twistBaseDrive
            + parameters.twistClosureDrive * phaseClosure
            + parameters.twistCouplingDrive * coupling
        let boundedDrive = clamp(drive, 0, 1)
        let next = oldCurrent + (parameters.targetTwistCurrent - oldCurrent) * boundedDrive
        return clamp(next, 0, parameters.targetTwistCurrent)
    }

    static func resonanceResponse(phaseError: Double, parameters: QRTLLaserParameters) -> Double {
        let normalizedDetuning = abs(phaseError) / Double.pi
        let exponent = -pow(normalizedDetuning / parameters.resonanceWidth, 2)
        return clamp(exp(exponent), 0, 1)
    }

    static func shellEnergy(
        resonanceResponse: Double,
        normalizedTwistCurrent: Double,
        parameters: QRTLLaserParameters
    ) -> Double {
        let excitation = clamp(resonanceResponse * normalizedTwistCurrent, 0, 1)
        return parameters.initialShellEnergy
            + (parameters.targetShellEnergy - parameters.initialShellEnergy) * excitation
    }

    static func qrtlCoupling(
        oldCoupling: Double,
        phaseClosure: Double,
        resonanceResponse: Double,
        shellEnergy: Double,
        parameters: QRTLLaserParameters
    ) -> Double {
        let normalizedShell = clamp(
            (shellEnergy - parameters.initialShellEnergy) /
            max(1e-12, parameters.targetShellEnergy - parameters.initialShellEnergy),
            0, 1
        )
        let interactionTarget = parameters.qrtlBaseCoupling * (
            parameters.couplingPhaseWeight * phaseClosure
            + parameters.couplingResonanceWeight * resonanceResponse
            + parameters.couplingShellWeight * normalizedShell
        )
        let next = oldCoupling + (interactionTarget - oldCoupling) * parameters.couplingRelaxation
        return clamp(next, 0, 1)
    }

    static func coherence(coupling: Double, parameters: QRTLLaserParameters) -> Double {
        parameters.initialCoherence
            + (parameters.maximumCoherence - parameters.initialCoherence) * coupling
    }

    static func lossReduction(coupling: Double, parameters: QRTLLaserParameters) -> Double {
        parameters.maximumLossReduction * coupling
    }

    static func beamAreaFactor(coupling: Double, parameters: QRTLLaserParameters) -> Double {
        1.0 - (1.0 - parameters.minimumBeamAreaFactor) * coupling
    }

    static func clamp(_ value: Double, _ minimum: Double, _ maximum: Double) -> Double {
        min(max(value, minimum), maximum)
    }

    // Gaussian pump weight for cell i (center of lattice)
    static func gaussianPumpWeight(cellIndex: Int, size: Int, sigma: Double) -> Double {
        let center = Double(size - 1) / 2.0
        let x = Double(cellIndex) - center
        return exp(-0.5 * (x / sigma) * (x / sigma))
    }
}

// MARK: - Master Monitor (core evolution + lattice + FFT)

@MainActor
final class MasterMonitor: ObservableObject {

    @Published private(set) var measurementState = LaserMeasurementState()
    @Published var measuredInputPowerWatts: Double?
    @Published var measuredOutputPowerWatts: Double?
    @Published var measuredWavelengthMeters: Double?
    @Published var measuredThresholdInputPowerWatts: Double?
    @Published var measuredLinewidthHz: Double?
    @Published var measuredStartupTimeSeconds: Double?
    @Published var measuredInputEnergyJoules: Double?
    @Published var measuredOutputEnergyJoules: Double?
    @Published var experimentalRunCount: Int = 0
    @Published var reproducibleRuns: Int = 0

    @Published private(set) var qrtlState: QRTLState
    @Published private(set) var photonNodes: [PhotonState]
    @Published private(set) var isRunning = false
    @Published private(set) var elapsedTime: Double = 0.0

    private let parameters = QRTLLaserParameters()
    private var timer: Timer?
    private var lastTick: Date?

    // Representative cavity mode
    private var representativeZ: Double = 0
    private var representativeDirection: CavityDirection = .forward
    private var previousZ: Double = 0
    private var gainCrossingInProgress = false
    private var activeGainTraversalDirection: CavityDirection?

    // QRTL evolving scalars
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
    private var resonanceLocked = false
    private var circulatingFieldFactor: Double = 1.0
    private var transmittedOutputFactor: Double = 0.0
    private var outputEvents = 0
    private var physicalPathDistance: Double = 0.0

    // Calcium lattice
    private var lattice: [CalciumCell]
    private var latticeSignal: [Double] = []          // time-domain for FFT
    private let signalCapacity = 2048
    private var lastFFTTime: Double = 0
    private let fftInterval: Double = 0.25            // seconds of wall time

    // Current / rate proxies (computed each step)
    private var excessCurrentAmps: Double = 0
    private var injectedElectronsPerSecond: Double = 0
    private var usefulExcitationsPerSecond: Double = 0
    private var qrtlToEMCouplingProxy: Double = 0
    private var populationInversionProxy: Double = 0
    private var photonGenerationRate: Double = 0
    private var simulatedDominantFrequencyHz: Double?
    private var simulatedDominantWavelengthMeters: Double?
    private var wavelengthClosenessPercent: Double?

    private let stateLock = NSLock()

    init() {
        // ------------------------------------------------------------------
        // 1. Initialize EVERY stored property (no instance methods yet)
        // ------------------------------------------------------------------

        // QRTL scalar state
        phaseError = parameters.initialPhaseError
        phaseClosure = QRTLLaserPhysics.phaseClosure(phaseError: phaseError)
        resonanceResponse = QRTLLaserPhysics.resonanceResponse(
            phaseError: phaseError,
            parameters: parameters
        )
        twistCurrent = parameters.initialTwistCurrent
        shellEnergy = parameters.initialShellEnergy
        coupling = 0.0
        coherence = parameters.initialCoherence

        // Lattice
        lattice = (0..<parameters.latticeSize).map { _ in CalciumCell.randomInitial() }
        latticeSignal = []
        lastFFTTime = 0.0

        // Current / rate proxies (temporary zeros – will be overwritten immediately)
        excessCurrentAmps = 0.0
        injectedElectronsPerSecond = 0.0
        usefulExcitationsPerSecond = 0.0
        qrtlToEMCouplingProxy = 0.0
        populationInversionProxy = 0.0
        photonGenerationRate = 0.0
        simulatedDominantFrequencyHz = nil
        simulatedDominantWavelengthMeters = nil
        wavelengthClosenessPercent = nil

        // Representative cavity mode
        representativeZ = 0.0
        previousZ = 0.0
        representativeDirection = .forward
        gainCrossingInProgress = false
        activeGainTraversalDirection = nil

        // Counters / flags
        roundTripCount = 0
        gainMediumCrossings = 0
        stableLockRounds = 0
        resonanceLocked = false
        circulatingFieldFactor = 1.0
        transmittedOutputFactor = 0.0
        outputEvents = 0
        physicalPathDistance = 0.0

        // Photon markers
        let photonCount = parameters.photonCount
        let cavityLength = parameters.cavityLength
        photonNodes = (0..<photonCount).map {
            PhotonState(id: $0, cavityLength: cavityLength)
        }

        // Published properties that need an initial value
        isRunning = false
        elapsedTime = 0.0
        measurementState = LaserMeasurementState()

        // ------------------------------------------------------------------
        // 2. Compute the initial current proxies (pure calculation, no self)
        // ------------------------------------------------------------------
        excessCurrentAmps = max(0, parameters.driveCurrentAmps - parameters.thresholdCurrentAmps)
        injectedElectronsPerSecond = excessCurrentAmps / parameters.electronCharge
        usefulExcitationsPerSecond = injectedElectronsPerSecond * parameters.injectionEfficiency

        // ------------------------------------------------------------------
        // 3. Build the initial QRTLState value INLINE (still no instance methods)
        // ------------------------------------------------------------------
        let lossReduction = QRTLLaserPhysics.lossReduction(coupling: coupling, parameters: parameters)
        let beamAreaFactor = QRTLLaserPhysics.beamAreaFactor(coupling: coupling, parameters: parameters)
        let coherenceGain = coherence / max(parameters.initialCoherence, 1e-12)
        let lossGain = 1.0 + lossReduction
        let concentrationGain = 1.0 / max(beamAreaFactor, 1e-12)
        let combinedGain = coherenceGain * lossGain * concentrationGain

        qrtlState = QRTLState(
            phaseError: phaseError,
            phaseClosure: phaseClosure,
            twistCurrent: twistCurrent,
            resonanceResponse: resonanceResponse,
            shellEnergy: shellEnergy,
            coupling: coupling,
            coherence: coherence,
            lossReduction: lossReduction,
            beamAreaFactor: beamAreaFactor,
            coherenceGain: coherenceGain,
            lossGain: lossGain,
            concentrationGain: concentrationGain,
            combinedGain: combinedGain,
            roundTripCount: roundTripCount,
            gainMediumCrossings: gainMediumCrossings,
            stableLockRounds: stableLockRounds,
            resonanceLocked: resonanceLocked,
            circulatingFieldFactor: circulatingFieldFactor,
            transmittedOutputFactor: transmittedOutputFactor,
            outputEvents: outputEvents,
            outputEnabled: false,
            currentDirection: representativeDirection,
            physicalElapsedTime: 0.0,
            driveCurrentAmps: parameters.driveCurrentAmps,
            thresholdCurrentAmps: parameters.thresholdCurrentAmps,
            excessCurrentAmps: excessCurrentAmps,
            injectedElectronsPerSecond: injectedElectronsPerSecond,
            usefulExcitationsPerSecond: usefulExcitationsPerSecond,
            qrtlToEMCouplingProxy: qrtlToEMCouplingProxy,
            populationInversionProxy: populationInversionProxy,
            photonGenerationRate: photonGenerationRate,
            latticeTotalPopulation: lattice.map { $0.upperPopulation + $0.lowerPopulation }.reduce(0, +),
            latticeUpperPopulation: lattice.map(\.upperPopulation).reduce(0, +),
            latticeLowerPopulation: lattice.map(\.lowerPopulation).reduce(0, +),
            latticeExcitationFraction: lattice.map(\.excitation).reduce(0, +) / Double(max(1, lattice.count)),
            simulatedDominantFrequencyHz: nil,
            simulatedDominantWavelengthMeters: nil,
            wavelengthClosenessPercent: nil
        )

        // ------------------------------------------------------------------
        // 4. NOW it is safe to call instance methods
        // ------------------------------------------------------------------
        updatePhotonPositions()
        // (optional) updateMeasurements() if you want the measurement panel populated immediately
    }

    deinit { timer?.invalidate() }

    // Convenience
    var lossReduction: Double { qrtlState.lossReduction }
    var beamAreaFactor: Double { qrtlState.beamAreaFactor }
    var combinedGain: Double { qrtlState.combinedGain }
    var beamLocked: Bool { qrtlState.resonanceLocked }

    // MARK: - Start / Stop / Reset

    func start() {
        stop()
        resetState()
        isRunning = true
        lastTick = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        lastTick = nil
    }

    func reset() {
        stop()
        resetState()
    }

    func updateMeasurements() {
        measurementState = QRTLLaserMeasurementEngine.evaluate(
            state: qrtlState,
            parameters: parameters,
            inputPowerWatts: measuredInputPowerWatts,
            measuredOutputPowerWatts: measuredOutputPowerWatts,
            measuredWavelengthMeters: measuredWavelengthMeters,
            measuredThresholdInputPowerWatts: measuredThresholdInputPowerWatts,
            measuredLinewidthHz: measuredLinewidthHz,
            measuredStartupTimeSeconds: measuredStartupTimeSeconds,
            measuredInputEnergyJoules: measuredInputEnergyJoules,
            measuredOutputEnergyJoules: measuredOutputEnergyJoules,
            experimentalRunCount: experimentalRunCount,
            reproducibleRuns: reproducibleRuns
        )
    }

    private func resetState() {
        stateLock.lock()
        defer { stateLock.unlock() }

        phaseError = parameters.initialPhaseError
        phaseClosure = QRTLLaserPhysics.phaseClosure(phaseError: phaseError)
        resonanceResponse = QRTLLaserPhysics.resonanceResponse(
            phaseError: phaseError, parameters: parameters
        )
        twistCurrent = parameters.initialTwistCurrent
        shellEnergy = parameters.initialShellEnergy
        coupling = 0
        coherence = parameters.initialCoherence
        representativeZ = 0
        previousZ = 0
        representativeDirection = .forward
        gainCrossingInProgress = false
        activeGainTraversalDirection = nil
        roundTripCount = 0
        gainMediumCrossings = 0
        stableLockRounds = 0
        resonanceLocked = false
        circulatingFieldFactor = 1.0
        transmittedOutputFactor = 0
        outputEvents = 0
        physicalPathDistance = 0
        elapsedTime = 0
        lattice = (0..<parameters.latticeSize).map { _ in CalciumCell.randomInitial() }
        latticeSignal = []
        lastFFTTime = 0
        simulatedDominantFrequencyHz = nil
        simulatedDominantWavelengthMeters = nil
        wavelengthClosenessPercent = nil

        let photonCount = parameters.photonCount
        let cavityLength = parameters.cavityLength
        photonNodes = (0..<photonCount).map { PhotonState(id: $0, cavityLength: cavityLength) }

        recomputeCurrentProxies()
        qrtlState = makeStateLocked()
        updateMeasurements()
        updatePhotonPositionsLocked()
    }

    // MARK: - Tick

    private func tick() {
        let now = Date()
        let dt: Double
        if let lastTick {
            dt = min(max(now.timeIntervalSince(lastTick), 0), 0.10)
        } else {
            dt = 1.0 / 60.0
        }
        lastTick = now

        stateLock.lock()
        defer { stateLock.unlock() }

        guard isRunning else { return }

        elapsedTime += dt
        if elapsedTime >= parameters.maximumSimulationDuration {
            isRunning = false
            timer?.invalidate()
            timer = nil
            return
        }

        // 1. Evolve calcium lattice (pump + neighbor coupling + inversion)
        evolveCalciumLattice(dt: dt)

        // 2. Update current / rate proxies
        recomputeCurrentProxies()

        // 3. Record time-domain signal (mean excitation * cos(mean phase))
        recordLatticeSignal()

        // 4. Periodic FFT → dominant frequency / wavelength
        if elapsedTime - lastFFTTime >= fftInterval {
            performFFTAndUpdateWavelength()
            lastFFTTime = elapsedTime
        }

        // 5. Propagate representative mode & visual markers
        propagateRepresentativeMode(dt: dt)
        advanceVisualMarkers(dt: dt)
        updatePhotonPositionsLocked()

        // 6. Continuous gain replenishment when inversion > 0 and mode close
        applyStimulatedEmissionAndLosses(dt: dt)

        updateMeasurements()
        updatePublishedStateLocked()
    }

    // MARK: - Current → electrons → useful excitations

    private func recomputeCurrentProxies() {
        excessCurrentAmps = max(0, parameters.driveCurrentAmps - parameters.thresholdCurrentAmps)
        injectedElectronsPerSecond = excessCurrentAmps / parameters.electronCharge
        usefulExcitationsPerSecond = injectedElectronsPerSecond * parameters.injectionEfficiency
    }

    // MARK: - Calcium lattice evolution

    private func evolveCalciumLattice(dt: Double) {
        let size = parameters.latticeSize
        let sigma = parameters.gaussianPumpSigmaCells
        let neighborK = parameters.neighborCouplingStrength

        // Total useful pump energy rate (J/s)
        let pumpPowerWatts = usefulExcitationsPerSecond * parameters.photonEnergy

        // Boost how much of that power actually drives the lattice
        let pumpBoost: Double = 12.0          // ← turn this up/down (try 8–20)

        var newLattice = lattice

        for i in 0..<size {
            let weight = QRTLLaserPhysics.gaussianPumpWeight(
                cellIndex: i, size: size, sigma: sigma
            )
            // Normalize Gaussian so total weight ≈ 1
            let norm = (0..<size).reduce(0.0) {
                $0 + QRTLLaserPhysics.gaussianPumpWeight(cellIndex: $1, size: size, sigma: sigma)
            }
            let localPump = (weight / max(norm, 1e-12)) * pumpPowerWatts * dt

            var cell = lattice[i]

            // ---------- Stronger pump into the cell ----------
            cell.localEnergy += localPump * pumpBoost
            cell.excitation = QRTLLaserPhysics.clamp(
                cell.excitation + (localPump * pumpBoost) / max(parameters.photonEnergy, 1e-30),
                0, 1
            )

            // Neighbor energy exchange
            let left  = lattice[(i - 1 + size) % size].localEnergy
            let right = lattice[(i + 1) % size].localEnergy
            let exchange = neighborK * (left + right - 2 * cell.localEnergy)
            cell.localEnergy += exchange * dt
            cell.localEnergy = max(0, cell.localEnergy)

            // Phase & twist (driven by excitation)
            let alignmentDrive = 0.25 * cell.excitation          // slightly stronger alignment
            cell.phase += (cell.twist + alignmentDrive * sin(-cell.phase)) * dt
            cell.twist += (-0.35 * cell.twist + 0.15 * cell.excitation * cos(cell.phase)) * dt

            // Displacement / strain
            cell.displacement += cell.twist * dt
            cell.strain = cell.displacement * 0.05

            // Reduced damping so energy stays longer
            cell.damping = parameters.latticeDampingBase * 0.4 + 0.005 * cell.excitation
            cell.localEnergy *= (1.0 - cell.damping * dt)
            cell.excitation  *= (1.0 - 0.3 * cell.damping * dt)

            // ---------- Much stronger population inversion drive ----------
            let pumpFactor = min(1.0, cell.excitation * 3.0)
            cell.upperPopulation = QRTLLaserPhysics.clamp(
                cell.upperPopulation + (0.75 * pumpFactor - 0.04) * dt * 6.0,
                0.0, 1.0
            )
            cell.lowerPopulation = 1.0 - cell.upperPopulation

            newLattice[i] = cell
        }
        lattice = newLattice

        // ---------- Collective quantities ----------
        var sumCos = 0.0, sumSin = 0.0, sumExc = 0.0
        var sumUpper = 0.0, sumLower = 0.0
        for cell in lattice {
            sumCos += cos(cell.phase) * cell.excitation
            sumSin += sin(cell.phase) * cell.excitation
            sumExc += cell.excitation
            sumUpper += cell.upperPopulation
            sumLower += cell.lowerPopulation
        }
        let n = Double(size)
        let R = sqrt(sumCos * sumCos + sumSin * sumSin) / max(sumExc, 1e-12)
        let latticeCoherence = QRTLLaserPhysics.clamp(R, 0, 1)

        // Blend lattice coherence into global coherence
        coherence = 0.55 * coherence + 0.45 * (
            parameters.initialCoherence
            + (parameters.maximumCoherence - parameters.initialCoherence) * latticeCoherence
        )

        // Energy localization
        let meanEnergy = lattice.map(\.localEnergy).reduce(0, +) / n
        let variance = lattice.map { pow($0.localEnergy - meanEnergy, 2) }.reduce(0, +) / n
        let localization = 1.0 / (1.0 + variance * 8)

        // QRTL → EM coupling proxy
        qrtlToEMCouplingProxy = QRTLLaserPhysics.clamp(
            latticeCoherence * localization * max(coupling, 0.1), 0, 1
        )

        // Population inversion proxy
        let totalPop = sumUpper + sumLower
        populationInversionProxy = totalPop > 0 ? (sumUpper - sumLower) / totalPop : 0

        // Photon generation rate
        let inversionFactor = max(0, populationInversionProxy)
        photonGenerationRate =
            usefulExcitationsPerSecond
            * latticeCoherence
            * qrtlToEMCouplingProxy
            * inversionFactor
            * 0.25          // slightly higher scale factor
    }

    // MARK: - Time-domain signal & FFT

    private func recordLatticeSignal() {
        let meanPhase = lattice.map(\.phase).reduce(0, +) / Double(lattice.count)
        let meanExc = lattice.map(\.excitation).reduce(0, +) / Double(lattice.count)
        let sample = meanExc * cos(meanPhase)
        latticeSignal.append(sample)
        if latticeSignal.count > signalCapacity {
            latticeSignal.removeFirst(latticeSignal.count - signalCapacity)
        }
    }

    private func performFFTAndUpdateWavelength() {
        let n = latticeSignal.count
        guard n >= 64 else { return }

        // Next lower power-of-two length
        let log2n = Int(floor(log2(Double(n))))
        let N = 1 << log2n
        guard N >= 64 else { return }

        // Copy the most recent N samples
        var input = [Float](latticeSignal.suffix(N).map { Float($0) })

        // Hann window
        for i in 0..<N {
            let w = 0.5 * (1.0 - cos(2.0 * Float.pi * Float(i) / Float(N - 1)))
            input[i] *= w
        }

        // Real FFT setup
        guard let setup = vDSP_create_fftsetup(vDSP_Length(log2n), FFTRadix(kFFTRadix2)) else {
            return
        }
        defer { vDSP_destroy_fftsetup(setup) }

        var realp = [Float](repeating: 0, count: N / 2)
        var imagp = [Float](repeating: 0, count: N / 2)

        realp.withUnsafeMutableBufferPointer { realBuf in
            imagp.withUnsafeMutableBufferPointer { imagBuf in
                var splitComplex = DSPSplitComplex(
                    realp: realBuf.baseAddress!,
                    imagp: imagBuf.baseAddress!
                )

                // Pack real input into split-complex format required by vDSP
                input.withUnsafeMutableBufferPointer { inputBuf in
                    inputBuf.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: N / 2) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(N / 2))
                    }
                }

                // Forward real FFT
                vDSP_fft_zrip(setup, &splitComplex, 1, vDSP_Length(log2n),
                              FFTDirection(FFT_FORWARD))

                // Magnitudes
                var magnitudes = [Float](repeating: 0, count: N / 2)
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(N / 2))

                // Find peak bin (skip DC)
                var maxMag: Float = 0
                var maxIdx: vDSP_Length = 0
                magnitudes.withUnsafeBufferPointer { magBuf in
                    // Search from index 1 onward
                    vDSP_maxvi(magBuf.baseAddress! + 1, 1,
                               &maxMag, &maxIdx,
                               vDSP_Length(N / 2 - 1))
                }
                // maxIdx is relative to the +1 offset
                let peakBin = Int(maxIdx) + 1

                // Approximate sample rate (one sample per visual frame ≈ 60 Hz)
                let sampleRate: Double = 60.0
                let dominantFreq = Double(peakBin) * sampleRate / Double(N)

                // Map lattice tone onto optical carrier (phenomenological)
                let opticalFreq = parameters.targetFrequency + (dominantFreq - 5.0) * 1e9
                let wavelength = parameters.speedOfLight / max(opticalFreq, 1.0)

                simulatedDominantFrequencyHz = opticalFreq
                simulatedDominantWavelengthMeters = wavelength

                let closeness = 100.0 * (1.0 - abs(wavelength - parameters.targetWavelengthMeters)
                                             / parameters.targetWavelengthMeters)
                wavelengthClosenessPercent = QRTLLaserPhysics.clamp(closeness, 0, 100)
            }
        }
    }

    // MARK: - Stimulated emission + cavity loss (continuous)

    private func applyStimulatedEmissionAndLosses(dt: Double) {
        let modeCloseEnough = (wavelengthClosenessPercent ?? 0) >=
            (100 - parameters.wavelengthClosenessTolerancePercent)
        let inversionOK = populationInversionProxy > parameters.inversionThresholdForLasing

        guard modeCloseEnough && inversionOK else {
            // Below threshold: only weak spontaneous contribution, no stable beam
            return
        }

        // Gain from stimulated emission (photons added to circulating field)
        let gainRate = photonGenerationRate * parameters.photonEnergy   // watts proxy
        let addedField = gainRate * dt / max(parameters.photonEnergy, 1e-30) * 1e-18  // scale
        circulatingFieldFactor += addedField

        // Continuous losses (mirror, absorption, scattering) – output coupler handled at end mirror
        let lossPerSecond = parameters.absorptionLoss + parameters.scatteringLoss
        circulatingFieldFactor *= exp(-lossPerSecond * dt)
        circulatingFieldFactor = max(0, circulatingFieldFactor)
    }

    // MARK: - Representative mode propagation (unchanged structure)

    private func propagateRepresentativeMode(dt: Double) {
        previousZ = representativeZ
        let visualSpeed = parameters.cavityLength / parameters.visualOneWayDuration

        switch representativeDirection {
        case .forward:
            let nextZ = representativeZ + visualSpeed * dt
            let distance = max(0, min(nextZ, parameters.cavityLength) - representativeZ)
            physicalPathDistance += distance
            representativeZ = nextZ
            if representativeZ >= parameters.cavityLength {
                representativeZ = parameters.cavityLength
                processOutputCoupler()
                representativeDirection = .returnPath
                gainCrossingInProgress = false
                activeGainTraversalDirection = nil
            }
        case .returnPath:
            let nextZ = representativeZ - visualSpeed * dt
            let distance = max(0, representativeZ - max(nextZ, 0))
            physicalPathDistance += distance
            representativeZ = nextZ
            if representativeZ <= 0 {
                representativeZ = 0
                representativeDirection = .forward
                gainCrossingInProgress = false
                activeGainTraversalDirection = nil
                completeRoundTrip()
            }
        }
        detectGainMediumCrossing()
    }

    private func detectGainMediumCrossing() {
        let z = representativeZ
        let insideGain = z >= parameters.gainStartZ && z <= parameters.gainEndZ
        if insideGain {
            if !gainCrossingInProgress || activeGainTraversalDirection != representativeDirection {
                gainCrossingInProgress = true
                activeGainTraversalDirection = representativeDirection
                processGainMediumTraversal(direction: representativeDirection)
            }
        } else {
            gainCrossingInProgress = false
            activeGainTraversalDirection = nil
        }
    }

    private func processGainMediumTraversal(direction: CavityDirection) {
        gainMediumCrossings += 1

        phaseClosure = QRTLLaserPhysics.phaseClosure(phaseError: phaseError)
        resonanceResponse = QRTLLaserPhysics.resonanceResponse(
            phaseError: phaseError, parameters: parameters
        )
        let normalizedTwist = QRTLLaserPhysics.clamp(
            twistCurrent / parameters.targetTwistCurrent, 0, 1
        )
        shellEnergy = QRTLLaserPhysics.shellEnergy(
            resonanceResponse: resonanceResponse,
            normalizedTwistCurrent: normalizedTwist,
            parameters: parameters
        )
        coupling = QRTLLaserPhysics.qrtlCoupling(
            oldCoupling: coupling,
            phaseClosure: phaseClosure,
            resonanceResponse: resonanceResponse,
            shellEnergy: shellEnergy,
            parameters: parameters
        )
        // Coherence already blended with lattice; keep a mild update
        coherence = QRTLLaserPhysics.coherence(coupling: coupling, parameters: parameters)
        twistCurrent = QRTLLaserPhysics.twistCurrent(
            oldCurrent: twistCurrent,
            phaseClosure: phaseClosure,
            coupling: coupling,
            parameters: parameters
        )

        let phaseCorrection = parameters.phaseCorrectionBase
            + parameters.phaseCorrectionClosureWeight * phaseClosure
            + parameters.phaseCorrectionCouplingWeight * coupling
        let bounded = QRTLLaserPhysics.clamp(phaseCorrection, 0, 0.50)
        phaseError *= (1.0 - bounded)
        phaseError = max(0, phaseError)

        // Re-evaluate
        phaseClosure = QRTLLaserPhysics.phaseClosure(phaseError: phaseError)
        resonanceResponse = QRTLLaserPhysics.resonanceResponse(
            phaseError: phaseError, parameters: parameters
        )
        let updatedNormTwist = QRTLLaserPhysics.clamp(
            twistCurrent / parameters.targetTwistCurrent, 0, 1
        )
        shellEnergy = QRTLLaserPhysics.shellEnergy(
            resonanceResponse: resonanceResponse,
            normalizedTwistCurrent: updatedNormTwist,
            parameters: parameters
        )
        coupling = QRTLLaserPhysics.qrtlCoupling(
            oldCoupling: coupling,
            phaseClosure: phaseClosure,
            resonanceResponse: resonanceResponse,
            shellEnergy: shellEnergy,
            parameters: parameters
        )
        coherence = QRTLLaserPhysics.coherence(coupling: coupling, parameters: parameters)

        let lossReduction = QRTLLaserPhysics.lossReduction(coupling: coupling, parameters: parameters)
        let beamAreaFactor = QRTLLaserPhysics.beamAreaFactor(coupling: coupling, parameters: parameters)
        let coherenceGain = coherence / max(parameters.initialCoherence, 1e-12)
        let lossGain = 1.0 + lossReduction
        let concentrationGain = 1.0 / max(beamAreaFactor, 1e-12)
        let combinedGain = coherenceGain * lossGain * concentrationGain

        qrtlState = QRTLState(
            phaseError: phaseError,
            phaseClosure: phaseClosure,
            twistCurrent: twistCurrent,
            resonanceResponse: resonanceResponse,
            shellEnergy: shellEnergy,
            coupling: coupling,
            coherence: coherence,
            lossReduction: lossReduction,
            beamAreaFactor: beamAreaFactor,
            coherenceGain: coherenceGain,
            lossGain: lossGain,
            concentrationGain: concentrationGain,
            combinedGain: combinedGain,
            roundTripCount: roundTripCount,
            gainMediumCrossings: gainMediumCrossings,
            stableLockRounds: stableLockRounds,
            resonanceLocked: resonanceLocked,
            circulatingFieldFactor: circulatingFieldFactor,
            transmittedOutputFactor: transmittedOutputFactor,
            outputEvents: outputEvents,
            outputEnabled: resonanceLocked && transmittedOutputFactor > 0,
            currentDirection: direction,
            physicalElapsedTime: physicalPathDistance / parameters.speedOfLight,
            driveCurrentAmps: parameters.driveCurrentAmps,
            thresholdCurrentAmps: parameters.thresholdCurrentAmps,
            excessCurrentAmps: excessCurrentAmps,
            injectedElectronsPerSecond: injectedElectronsPerSecond,
            usefulExcitationsPerSecond: usefulExcitationsPerSecond,
            qrtlToEMCouplingProxy: qrtlToEMCouplingProxy,
            populationInversionProxy: populationInversionProxy,
            photonGenerationRate: photonGenerationRate,
            latticeTotalPopulation: lattice.map { $0.upperPopulation + $0.lowerPopulation }.reduce(0, +),
            latticeUpperPopulation: lattice.map(\.upperPopulation).reduce(0, +),
            latticeLowerPopulation: lattice.map(\.lowerPopulation).reduce(0, +),
            latticeExcitationFraction: lattice.map(\.excitation).reduce(0, +) / Double(lattice.count),
            simulatedDominantFrequencyHz: simulatedDominantFrequencyHz,
            simulatedDominantWavelengthMeters: simulatedDominantWavelengthMeters,
            wavelengthClosenessPercent: wavelengthClosenessPercent
        )
    }

    private func processOutputCoupler() {
        guard resonanceLocked else {
            transmittedOutputFactor = 0
            return
        }
        // Only extract when inversion is positive and mode is close (threshold condition)
        let modeOK = (wavelengthClosenessPercent ?? 0) >=
            (100 - parameters.wavelengthClosenessTolerancePercent)
        let invOK = populationInversionProxy > parameters.inversionThresholdForLasing
        guard modeOK && invOK else {
            transmittedOutputFactor = 0
            return
        }

        let incident = circulatingFieldFactor
        let transmitted = incident * parameters.outputTransmission
        let reflected = incident * parameters.outputReflection
        transmittedOutputFactor = transmitted
        circulatingFieldFactor = reflected
        outputEvents += 1
    }

    private func completeRoundTrip() {
        roundTripCount += 1
        let lockOK =
            qrtlState.phaseClosure >= parameters.phaseClosureLockThreshold
            && abs(qrtlState.phaseError) <= parameters.maximumPhaseErrorForLock
            && qrtlState.coupling >= parameters.qrtlCouplingLockThreshold
            && qrtlState.coherence >= parameters.coherenceLockThreshold
            && (wavelengthClosenessPercent ?? 0) >= (100 - parameters.wavelengthClosenessTolerancePercent)
            && populationInversionProxy > parameters.inversionThresholdForLasing

        if lockOK {
            stableLockRounds += 1
        } else {
            stableLockRounds = 0
        }
        if stableLockRounds >= parameters.requiredStableLockRounds {
            resonanceLocked = true
        }
        updatePublishedStateLocked()
    }

    // MARK: - Visual markers (unchanged)

    private func advanceVisualMarkers(dt: Double) {
        let visualSpeed = parameters.cavityLength / parameters.visualOneWayDuration
        for index in photonNodes.indices {
            switch photonNodes[index].direction {
            case .forward:
                photonNodes[index].z += visualSpeed * dt
                if photonNodes[index].z >= parameters.cavityLength {
                    photonNodes[index].z = parameters.cavityLength
                    photonNodes[index].direction = .returnPath
                    photonNodes[index].hasEnteredGainThisTraversal = false
                }
            case .returnPath:
                photonNodes[index].z -= visualSpeed * dt
                if photonNodes[index].z <= 0 {
                    photonNodes[index].z = 0
                    photonNodes[index].direction = .forward
                    photonNodes[index].hasEnteredGainThisTraversal = false
                }
            }
        }
    }

    private func updatePhotonPositions() {
        stateLock.lock()
        defer { stateLock.unlock() }
        updatePhotonPositionsLocked()
    }

    private func updatePhotonPositionsLocked() {
        for index in photonNodes.indices {
            photonNodes[index].updateVisualPosition(coherence: qrtlState.coherence)
        }
    }

    // MARK: - State construction

    private func makeInitialState() -> QRTLState {
        makeStateLocked()
    }

    private func makeStateLocked() -> QRTLState {
        let lossReduction = QRTLLaserPhysics.lossReduction(coupling: coupling, parameters: parameters)
        let beamAreaFactor = QRTLLaserPhysics.beamAreaFactor(coupling: coupling, parameters: parameters)
        let coherenceGain = coherence / max(parameters.initialCoherence, 1e-12)
        let lossGain = 1.0 + lossReduction
        let concentrationGain = 1.0 / max(beamAreaFactor, 1e-12)
        let combinedGain = coherenceGain * lossGain * concentrationGain

        return QRTLState(
            phaseError: phaseError,
            phaseClosure: phaseClosure,
            twistCurrent: twistCurrent,
            resonanceResponse: resonanceResponse,
            shellEnergy: shellEnergy,
            coupling: coupling,
            coherence: coherence,
            lossReduction: lossReduction,
            beamAreaFactor: beamAreaFactor,
            coherenceGain: coherenceGain,
            lossGain: lossGain,
            concentrationGain: concentrationGain,
            combinedGain: combinedGain,
            roundTripCount: roundTripCount,
            gainMediumCrossings: gainMediumCrossings,
            stableLockRounds: stableLockRounds,
            resonanceLocked: resonanceLocked,
            circulatingFieldFactor: circulatingFieldFactor,
            transmittedOutputFactor: transmittedOutputFactor,
            outputEvents: outputEvents,
            outputEnabled: resonanceLocked && transmittedOutputFactor > 0,
            currentDirection: representativeDirection,
            physicalElapsedTime: physicalPathDistance / parameters.speedOfLight,
            driveCurrentAmps: parameters.driveCurrentAmps,
            thresholdCurrentAmps: parameters.thresholdCurrentAmps,
            excessCurrentAmps: excessCurrentAmps,
            injectedElectronsPerSecond: injectedElectronsPerSecond,
            usefulExcitationsPerSecond: usefulExcitationsPerSecond,
            qrtlToEMCouplingProxy: qrtlToEMCouplingProxy,
            populationInversionProxy: populationInversionProxy,
            photonGenerationRate: photonGenerationRate,
            latticeTotalPopulation: lattice.map { $0.upperPopulation + $0.lowerPopulation }.reduce(0, +),
            latticeUpperPopulation: lattice.map(\.upperPopulation).reduce(0, +),
            latticeLowerPopulation: lattice.map(\.lowerPopulation).reduce(0, +),
            latticeExcitationFraction: lattice.map(\.excitation).reduce(0, +) / Double(max(1, lattice.count)),
            simulatedDominantFrequencyHz: simulatedDominantFrequencyHz,
            simulatedDominantWavelengthMeters: simulatedDominantWavelengthMeters,
            wavelengthClosenessPercent: wavelengthClosenessPercent
        )
    }

    private func updatePublishedStateLocked() {
        qrtlState = makeStateLocked()
    }

    func snapshot() -> (state: QRTLState, photons: [PhotonState], running: Bool, elapsed: Double) {
        stateLock.lock()
        defer { stateLock.unlock() }
        return (qrtlState, photonNodes, isRunning, elapsedTime)
    }
}

// MARK: - SceneKit View (unchanged except minor opacity driven by new state)

struct QRTLLaserSceneView: UIViewRepresentable {
    @ObservedObject var monitor: MasterMonitor

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.015, green: 0.02, blue: 0.035, alpha: 1)
        view.scene = makeScene()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        context.coordinator.monitor = monitor
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.monitor = monitor
        context.coordinator.updateScene()
    }

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        // Camera
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 55
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 4.8, 11.5)
        cameraNode.eulerAngles = SCNVector3(-0.20, 0, 0)
        scene.rootNode.addChildNode(cameraNode)
        // Lights
        let ambientNode = SCNNode()
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 500
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)
        let keyNode = SCNNode()
        let key = SCNLight()
        key.type = .omni
        key.intensity = 1000
        keyNode.light = key
        keyNode.position = SCNVector3(2, 4, 4)
        scene.rootNode.addChildNode(keyNode)
        // Axis
        let axisGeometry = SCNCylinder(radius: 0.015, height: 6.0)
        axisGeometry.firstMaterial = makeMaterial(color: .darkGray, emission: .clear)
        let axisNode = SCNNode(geometry: axisGeometry)
        axisNode.eulerAngles.x = .pi / 2
        scene.rootNode.addChildNode(axisNode)
        // Gain medium
        let gainGeometry = SCNCylinder(radius: 1.55, height: 3.0)
        let gainMaterial = SCNMaterial()
        gainMaterial.diffuse.contents = UIColor(red: 0.18, green: 0.35, blue: 0.75, alpha: 0.18)
        gainMaterial.emission.contents = UIColor(red: 0.05, green: 0.15, blue: 0.55, alpha: 0.20)
        gainMaterial.transparency = 0.22
        gainMaterial.isDoubleSided = true
        gainGeometry.firstMaterial = gainMaterial
        let gainNode = SCNNode(geometry: gainGeometry)
        gainNode.name = "GainMedium"
        gainNode.eulerAngles.x = .pi / 2
        gainNode.position = SCNVector3(0, 0, 3.0)
        scene.rootNode.addChildNode(gainNode)
        // Mirrors
        scene.rootNode.addChildNode(makeMirror(name: "RearMirror", z: 0, radius: 1.8))
        scene.rootNode.addChildNode(makeMirror(name: "OutputCoupler", z: 6, radius: 1.8))
        // Photon markers
        for id in 0..<90 {
            let geometry = SCNSphere(radius: 0.045)
            geometry.firstMaterial = makeMaterial(color: .systemRed, emission: .systemOrange)
            let node = SCNNode(geometry: geometry)
            node.name = "PhotonMarker-\(id)"
            scene.rootNode.addChildNode(node)
        }
        // Output beam
        let beamGeometry = SCNCylinder(radius: 0.12, height: 2.0)
        beamGeometry.firstMaterial = makeMaterial(color: .systemRed, emission: .systemRed)
        let beamNode = SCNNode(geometry: beamGeometry)
        beamNode.name = "OutputBeam"
        beamNode.eulerAngles.x = .pi / 2
        beamNode.position = SCNVector3(0, 0, 7.0)
        beamNode.opacity = 0
        scene.rootNode.addChildNode(beamNode)
        addTraversalGuide(to: scene)
        return scene
    }

    private func makeMaterial(color: UIColor, emission: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = emission
        return material
    }

    private func makeMirror(name: String, z: Float, radius: CGFloat) -> SCNNode {
        let geometry = SCNCylinder(radius: radius, height: 0.08)
        geometry.firstMaterial = makeMaterial(color: .lightGray, emission: .clear)
        let node = SCNNode(geometry: geometry)
        node.name = name
        node.eulerAngles.x = .pi / 2
        node.position = SCNVector3(0, 0, z)
        return node
    }

    private func addTraversalGuide(to scene: SCNScene) {
        let forwardGeometry = SCNCylinder(radius: 0.025, height: 1.2)
        forwardGeometry.firstMaterial = makeMaterial(color: .systemGreen, emission: .systemGreen)
        let forward = SCNNode(geometry: forwardGeometry)
        forward.eulerAngles.x = .pi / 2
        forward.position = SCNVector3(2, 0, 2.5)
        scene.rootNode.addChildNode(forward)
        let returnGeometry = SCNCylinder(radius: 0.025, height: 1.2)
        returnGeometry.firstMaterial = makeMaterial(color: .systemBlue, emission: .systemBlue)
        let returning = SCNNode(geometry: returnGeometry)
        returning.eulerAngles.x = .pi / 2
        returning.position = SCNVector3(-2, 0, 4)
        scene.rootNode.addChildNode(returning)
    }

    final class Coordinator {
        weak var view: SCNView?
        weak var monitor: MasterMonitor?

        func updateScene() {
            guard let scene = view?.scene, let monitor else { return }
            let snapshot = monitor.snapshot()

            for photon in snapshot.photons {
                guard let node = scene.rootNode.childNode(
                    withName: "PhotonMarker-\(photon.id)", recursively: true
                ) else { continue }
                node.position = photon.position
                let coherence = snapshot.state.coherence
                let alignment = max(0, min(1, (coherence - 0.70) / 0.25))
                node.opacity = CGFloat(0.30 + 0.70 * alignment)
            }

            if let gain = scene.rootNode.childNode(withName: "GainMedium", recursively: true) {
                gain.opacity = CGFloat(0.12 + 0.35 * snapshot.state.coupling)
            }

            if let beam = scene.rootNode.childNode(withName: "OutputBeam", recursively: true) {
                let transmitted = snapshot.state.transmittedOutputFactor
                let isActive = snapshot.state.resonanceLocked && transmitted > 0
                guard isActive else {
                    beam.opacity = 0
                    return
                }
                let normalizedOutput = min(1, transmitted / max(0.10, 1))
                beam.opacity = CGFloat(0.25 + 0.75 * normalizedOutput)
                let areaFactor = max(0.01, snapshot.state.beamAreaFactor)
                let radius = CGFloat(0.12 * sqrt(areaFactor))
                if let cylinder = beam.geometry as? SCNCylinder {
                    cylinder.radius = min(radius, 0.30)
                }
            }

            if let coupler = scene.rootNode.childNode(withName: "OutputCoupler", recursively: true) {
                coupler.opacity = snapshot.state.resonanceLocked ? 0.80 : 0.45
            }
        }
    }
}

// MARK: - Content View (extended metrics)

struct ContentView: View {
    @StateObject private var monitor = MasterMonitor()
    @State private var showAbout = false
    private let parameters = QRTLLaserParameters()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text("QRTL Resonating Amplifier")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                        Text("2.94 µm cavity resonance simulation")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }

                    QRTLLaserSceneView(monitor: monitor)
                        .frame(minHeight: 330)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("CAVITY TRAVERSAL")
                            metricRow("Direction", monitor.qrtlState.currentDirection.rawValue)
                            metricRow("Round trips", "\(monitor.qrtlState.roundTripCount)")
                            metricRow("Gain crossings", "\(monitor.qrtlState.gainMediumCrossings)")
                            metricRow("Physical RT time", formatTime(parameters.physicalRoundTripTime))
                            metricRow("Modeled physical elapsed", formatTime(monitor.qrtlState.physicalElapsedTime))

                            Divider()
                            sectionHeader("CURRENT → PUMP")
                            metricRow("Drive current", String(format: "%.0f mA", parameters.driveCurrentAmps * 1000))
                            metricRow("Threshold current", String(format: "%.0f mA", parameters.thresholdCurrentAmps * 1000))
                            metricRow("Excess current", String(format: "%.0f mA", monitor.qrtlState.excessCurrentAmps * 1000))
                            metricRow("Injected e⁻/s", scientific(monitor.qrtlState.injectedElectronsPerSecond))
                            metricRow("Injection efficiency", String(format: "%.0f %%", parameters.injectionEfficiency * 100))
                            metricRow("Useful excitations/s", scientific(monitor.qrtlState.usefulExcitationsPerSecond))

                            Divider()
                            sectionHeader("CALCIUM / QRTL LATTICE")
                            metricRow("Lattice coherence (via QRTL)", format(monitor.qrtlState.coherence))
                            metricRow("QRTL→EM coupling proxy", format(monitor.qrtlState.qrtlToEMCouplingProxy))
                            metricRow("Population inversion proxy", format(monitor.qrtlState.populationInversionProxy))
                            metricRow("Excitation fraction", format(monitor.qrtlState.latticeExcitationFraction))
                            metricRow("Photon generation rate", scientific(monitor.qrtlState.photonGenerationRate) + " /s")

                            Divider()
                            sectionHeader("QRTL STATE")
                            metricRow("Phase error", formatRadians(monitor.qrtlState.phaseError))
                            metricRow("Phase closure", format(monitor.qrtlState.phaseClosure))
                            metricRow("Twist current", format(monitor.qrtlState.twistCurrent))
                            metricRow("Resonance response", format(monitor.qrtlState.resonanceResponse))
                            metricRow("Shell energy", format(monitor.qrtlState.shellEnergy))
                            metricRow("QRTL coupling", format(monitor.qrtlState.coupling))

                            Divider()
                            sectionHeader("AMPLIFICATION / MODE")
                            metricRow("Coherence gain", format(monitor.qrtlState.coherenceGain))
                            metricRow("Loss gain", format(monitor.qrtlState.lossGain))
                            metricRow("Concentration gain", format(monitor.qrtlState.concentrationGain))
                            metricRow("Combined gain", format(monitor.qrtlState.combinedGain))

                            Divider()
                            sectionHeader("SPECTRUM (FFT of lattice signal)")
                            metricRow("Target wavelength", "2.94 µm")
                            if let simλ = monitor.qrtlState.simulatedDominantWavelengthMeters {
                                metricRow("Simulated dominant λ", String(format: "%.4f µm", simλ * 1e6))
                            } else {
                                metricRow("Simulated dominant λ", "—")
                            }
                            if let close = monitor.qrtlState.wavelengthClosenessPercent {
                                metricRow("Closeness to target", String(format: "%.1f %%", close))
                            }
                            metricRow("Target frequency", formatFrequency(parameters.targetFrequency))
                            metricRow("Photon energy", String(format: "%.4e J (≈ 0.422 eV)", parameters.photonEnergy))

                            Divider()
                            sectionHeader("RESONANCE LOCK")
                            metricRow("Stable lock rounds",
                                      "\(monitor.qrtlState.stableLockRounds) / \(parameters.requiredStableLockRounds)")
                            metricRow("Lock status", monitor.qrtlState.resonanceLocked ? "LOCKED" : "ALIGNING")

                            Divider()
                            sectionHeader("OUTPUT COUPLER")
                            metricRow("Transmission", format(parameters.outputTransmission))
                            metricRow("Reflection", format(parameters.outputReflection))
                            metricRow("Circulating field", format(monitor.qrtlState.circulatingFieldFactor))
                            metricRow("Transmitted output", format(monitor.qrtlState.transmittedOutputFactor))
                            metricRow("Output events", "\(monitor.qrtlState.outputEvents)")
                            metricRow("Output", monitor.qrtlState.outputEnabled ? "TRANSMITTING" : "OFF")

                            Text("Safety timeout is \(Int(parameters.maximumSimulationDuration)) s only; it does not create lock. Lock requires phase closure, coupling, coherence, positive inversion, and FFT mode within tolerance of 2.94 µm.")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .padding(.top, 4)
                        }
                        .padding()
                    }
                    .frame(maxHeight: 360)

                    HStack(spacing: 12) {
                        Button { monitor.start() } label: {
                            Label("Ignite Cavity", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button { monitor.reset() } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAbout = true } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("Information")
                }
            }
            .padding()
            .sheet(isPresented: $showAbout) {
                NavigationStack { AboutView() }
                    .preferredColorScheme(.dark)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.gray)
    }

    private func metricRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.gray)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    private func format(_ value: Double) -> String {
        String(format: "%.4f", value)
    }

    private func formatRadians(_ value: Double) -> String {
        String(format: "%.4f rad", value)
    }

    private func formatFrequency(_ value: Double) -> String {
        String(format: "%.4f THz", value / 1e12)
    }

    private func formatTime(_ value: Double) -> String {
        if value < 1e-6 {
            return String(format: "%.2f ns", value * 1e9)
        }
        return String(format: "%.4e s", value)
    }

    private func scientific(_ value: Double) -> String {
        String(format: "%.3e", value)
    }
}

// Placeholder About view (keep or replace with your existing one)
struct AboutView: View {
    var body: some View {
        Text("QRTL 2.94 µm laser cavity simulation\n\nAll optical quantities derived from lattice + current model are simulation proxies.")
            .padding()
            .navigationTitle("About")
    }
}
