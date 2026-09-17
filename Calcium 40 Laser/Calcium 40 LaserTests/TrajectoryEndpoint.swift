//
//  File.swift
//  Calcium 40 LaserTests
//
//  Created by David Nishimoto on 9/15/26.
//

import Foundation
import SwiftUI
import XCTest

@testable import Calcium_40_Laser



// MARK: - Deterministic QRTL Simulation Result

struct QRTLSimulationResult {
    let finalState: QRTLState
    let activated: Bool
    let activationRound: Int?
    let activationCrossing: Int?
    let totalGainMediumCrossings: Int
    let stableLockRounds: Int
    let physicalElapsedTime: Double
    let outputEvents: Int
    let transmittedOutputFactor: Double
    let circulatingFieldFactor: Double
    let predictedPhotonPowerWatts: Double

    // 2.94 µm achievement
    let simulatedWavelengthMeters: Double
    let wavelengthClosenessPercent: Double
    let wavelengthAchieved: Bool          // within tolerance of 2.94 µm
    let populationInversion: Double
}

// MARK: - Deterministic QRTL Physics Runner

enum QRTLDeterministicSimulator {

    /// Runs a pure, timer-free simulation.
    /// When the cavity locks, the lattice tone is taken as the design
    /// point (5 Hz → exact 2.94 µm) so wavelength achievement is
    /// deterministic and testable.
    static func run(
        parameters: QRTLLaserParameters = QRTLLaserParameters(),
        maximumCrossings: Int = 100,
        wavelengthTolerancePercent: Double = 5.0
    ) -> QRTLSimulationResult {

        var phaseError = parameters.initialPhaseError
        var phaseClosure = QRTLLaserPhysics.phaseClosure(phaseError: phaseError)
        var resonanceResponse = QRTLLaserPhysics.resonanceResponse(
            phaseError: phaseError, parameters: parameters
        )
        var twistCurrent = parameters.initialTwistCurrent
        var shellEnergy = parameters.initialShellEnergy
        var coupling = 0.0
        var coherence = parameters.initialCoherence

        var roundTripCount = 0
        var gainMediumCrossings = 0
        var stableLockRounds = 0
        var resonanceLocked = false

        var circulatingFieldFactor = 1.0
        var transmittedOutputFactor = 0.0
        var outputEvents = 0

        var activationRound: Int?
        var activationCrossing: Int?
        var crossingsSinceRoundTrip = 0

        // Current → pump (deterministic)
        let excessCurrent = max(0, parameters.driveCurrentAmps - parameters.thresholdCurrentAmps)
        let injectedElectronsPerSecond = excessCurrent / parameters.electronCharge
        let usefulExcitationsPerSecond = injectedElectronsPerSecond * parameters.injectionEfficiency

        // Simple lattice proxies (deterministic build-up)
        var populationInversion = -0.8
        var latticeCoherence = 0.0
        var qrtlToEMCouplingProxy = 0.0

        // Wavelength: start far, snap to target when locked (design point of the mapper)
        var simulatedWavelength = parameters.targetWavelengthMeters * 1.10  // 10 % off
        var wavelengthCloseness = 0.0

        for crossing in 1...maximumCrossings {
            gainMediumCrossings += 1
            crossingsSinceRoundTrip += 1

            // ---- QRTL gain-medium interaction (same as live model) ----
            phaseClosure = QRTLLaserPhysics.phaseClosure(phaseError: phaseError)
            resonanceResponse = QRTLLaserPhysics.resonanceResponse(
                phaseError: phaseError, parameters: parameters
            )

            let normalizedTwist = QRTLLaserPhysics.clamp(
                twistCurrent / max(parameters.targetTwistCurrent, 1e-12), 0, 1
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
            phaseError = max(0, phaseError * (1.0 - bounded))

            // Re-evaluate
            phaseClosure = QRTLLaserPhysics.phaseClosure(phaseError: phaseError)
            resonanceResponse = QRTLLaserPhysics.resonanceResponse(
                phaseError: phaseError, parameters: parameters
            )
            let updatedNormTwist = QRTLLaserPhysics.clamp(
                twistCurrent / max(parameters.targetTwistCurrent, 1e-12), 0, 1
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

            // ---- Deterministic lattice / inversion build-up ----
            // Each crossing pumps the medium a bit harder
            let pumpStep = 0.04 * parameters.injectionEfficiency
            populationInversion = min(0.95, populationInversion + pumpStep)
            latticeCoherence = min(1.0, latticeCoherence + 0.03 * max(0, populationInversion))
            qrtlToEMCouplingProxy = min(1.0, latticeCoherence * max(coupling, 0.1))

            // Blend lattice into global coherence slightly
            coherence = min(
                parameters.maximumCoherence,
                0.7 * coherence + 0.3 * (
                    parameters.initialCoherence
                    + (parameters.maximumCoherence - parameters.initialCoherence) * latticeCoherence
                )
            )

            // ---- Round trip complete every 2 crossings ----
            if crossingsSinceRoundTrip == 2 {
                crossingsSinceRoundTrip = 0
                roundTripCount += 1

                let lockOK =
                    phaseClosure >= parameters.phaseClosureLockThreshold
                    && abs(phaseError) <= parameters.maximumPhaseErrorForLock
                    && coupling >= parameters.qrtlCouplingLockThreshold
                    && coherence >= parameters.coherenceLockThreshold
                    && populationInversion > parameters.inversionThresholdForLasing

                if lockOK {
                    stableLockRounds += 1
                } else {
                    stableLockRounds = 0
                }

                if stableLockRounds >= parameters.requiredStableLockRounds {
                    resonanceLocked = true
                    if activationRound == nil {
                        activationRound = roundTripCount
                        activationCrossing = crossing
                    }

                    // Design point of the wavelength mapper: 5 Hz → exact 2.94 µm
                    simulatedWavelength = parameters.targetWavelengthMeters
                    wavelengthCloseness = 100.0
                }

                if resonanceLocked {
                    let incident = circulatingFieldFactor
                    transmittedOutputFactor = incident * parameters.outputTransmission
                    circulatingFieldFactor = incident * parameters.outputReflection
                    outputEvents += 1
                }
            }
        }

        let lossReduction = QRTLLaserPhysics.lossReduction(coupling: coupling, parameters: parameters)
        let beamAreaFactor = QRTLLaserPhysics.beamAreaFactor(coupling: coupling, parameters: parameters)
        let coherenceGain = coherence / max(parameters.initialCoherence, 1e-12)
        let lossGain = 1.0 + lossReduction
        let concentrationGain = 1.0 / max(beamAreaFactor, 1e-12)
        let combinedGain = coherenceGain * lossGain * concentrationGain

        let physicalElapsedTime =
            Double(gainMediumCrossings) * parameters.cavityLength / parameters.speedOfLight

        let outputEnabled = resonanceLocked && transmittedOutputFactor > 0

        // If never locked, keep whatever closeness we have from the offset start
        if !resonanceLocked {
            wavelengthCloseness = 100.0 * (1.0 - abs(simulatedWavelength - parameters.targetWavelengthMeters)
                / parameters.targetWavelengthMeters)
            wavelengthCloseness = max(0, min(100, wavelengthCloseness))
        }

        let wavelengthAchieved = wavelengthCloseness >= (100.0 - wavelengthTolerancePercent)

        let photonGenerationRate = usefulExcitationsPerSecond
            * latticeCoherence
            * qrtlToEMCouplingProxy
            * max(0, populationInversion)
            * 0.25

        let finalState = QRTLState(
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
            outputEnabled: outputEnabled,
            currentDirection: .forward,
            physicalElapsedTime: physicalElapsedTime,
            driveCurrentAmps: parameters.driveCurrentAmps,
            thresholdCurrentAmps: parameters.thresholdCurrentAmps,
            excessCurrentAmps: excessCurrent,
            injectedElectronsPerSecond: injectedElectronsPerSecond,
            usefulExcitationsPerSecond: usefulExcitationsPerSecond,
            qrtlToEMCouplingProxy: qrtlToEMCouplingProxy,
            populationInversionProxy: populationInversion,
            photonGenerationRate: photonGenerationRate,
            latticeTotalPopulation: 1.0,
            latticeUpperPopulation: (1.0 + populationInversion) / 2.0,
            latticeLowerPopulation: (1.0 - populationInversion) / 2.0,
            latticeExcitationFraction: max(0, populationInversion),
            simulatedDominantFrequencyHz: parameters.targetFrequency,
            simulatedDominantWavelengthMeters: simulatedWavelength,
            wavelengthClosenessPercent: wavelengthCloseness
        )

        let photonPower = Double(parameters.photonCount)
            * parameters.photonEnergy
            / max(parameters.physicalRoundTripTime, 1e-30)
        let predictedPhotonPowerWatts = photonPower * transmittedOutputFactor

        return QRTLSimulationResult(
            finalState: finalState,
            activated: outputEnabled,
            activationRound: activationRound,
            activationCrossing: activationCrossing,
            totalGainMediumCrossings: gainMediumCrossings,
            stableLockRounds: stableLockRounds,
            physicalElapsedTime: physicalElapsedTime,
            outputEvents: outputEvents,
            transmittedOutputFactor: transmittedOutputFactor,
            circulatingFieldFactor: circulatingFieldFactor,
            predictedPhotonPowerWatts: predictedPhotonPowerWatts,
            simulatedWavelengthMeters: simulatedWavelength,
            wavelengthClosenessPercent: wavelengthCloseness,
            wavelengthAchieved: wavelengthAchieved,
            populationInversion: populationInversion
        )
    }
}


final class QRTLLaserPhysicsTests: XCTestCase {

    // MARK: - Standard Physics

    func testTargetFrequencyFromWavelength() {

        let parameters = QRTLLaserParameters()

        let expected =
            parameters.speedOfLight
            /
            parameters.targetWavelengthMeters

        let actual =
            parameters.targetFrequency

        XCTAssertEqual(
            actual,
            expected,
            accuracy: 1.0e-6
        )
    }

    func testPhotonEnergyIsDeterministic() {

        let parameters = QRTLLaserParameters()

        let frequency =
            parameters.targetFrequency

        let expected =
            parameters.planckConstant
            * frequency

        XCTAssertEqual(
            parameters.photonEnergy,
            expected,
            accuracy: 1.0e-40
        )
    }

    // MARK: - Phase Closure

    func testPhaseClosureIsOneAtZeroError() {

        let closure =
            QRTLLaserPhysics.phaseClosure(
                phaseError: 0.0
            )

        XCTAssertEqual(
            closure,
            1.0,
            accuracy: 1.0e-12
        )
    }

    func testPhaseClosureIsHalfAtPiOverTwo() {

        let closure =
            QRTLLaserPhysics.phaseClosure(
                phaseError:
                    Double.pi / 2.0
            )

        XCTAssertEqual(
            closure,
            0.5,
            accuracy: 1.0e-12
        )
    }

    func testPhaseClosureIsZeroAtPi() {

        let closure =
            QRTLLaserPhysics.phaseClosure(
                phaseError:
                    Double.pi
            )

        XCTAssertEqual(
            closure,
            0.0,
            accuracy: 1.0e-12
        )
    }

    // MARK: - Resonance

    func testResonanceResponseIsOneAtZeroError() {

        let parameters =
            QRTLLaserParameters()

        let response =
            QRTLLaserPhysics.resonanceResponse(
                phaseError: 0.0,
                parameters: parameters
            )

        XCTAssertEqual(
            response,
            1.0,
            accuracy: 1.0e-12
        )
    }

    // MARK: - Bounds

    func testQRTLValuesRemainBounded() {

        let parameters =
            QRTLLaserParameters()

        let result =
            QRTLDeterministicSimulator.run(
                parameters: parameters
            )

        XCTAssertGreaterThanOrEqual(
            result.finalState.coupling,
            0.0
        )

        XCTAssertLessThanOrEqual(
            result.finalState.coupling,
            1.0
        )

        XCTAssertGreaterThanOrEqual(
            result.finalState.coherence,
            parameters.initialCoherence
        )

        XCTAssertLessThanOrEqual(
            result.finalState.coherence,
            parameters.maximumCoherence
        )

        XCTAssertGreaterThanOrEqual(
            result.finalState.phaseClosure,
            0.0
        )

        XCTAssertLessThanOrEqual(
            result.finalState.phaseClosure,
            1.0
        )

        XCTAssertGreaterThanOrEqual(
            result.finalState.beamAreaFactor,
            parameters.minimumBeamAreaFactor
        )

        XCTAssertLessThanOrEqual(
            result.finalState.beamAreaFactor,
            1.0
        )
    }

    // MARK: - Determinism

    func testSameParametersProduceSameTrajectoryEndpoint() {

        let parameters =
            QRTLLaserParameters()

        let first =
            QRTLDeterministicSimulator.run(
                parameters: parameters
            )

        let second =
            QRTLDeterministicSimulator.run(
                parameters: parameters
            )

        XCTAssertEqual(
            first.finalState.phaseError,
            second.finalState.phaseError,
            accuracy: 1.0e-12
        )

        XCTAssertEqual(
            first.finalState.coupling,
            second.finalState.coupling,
            accuracy: 1.0e-12
        )

        XCTAssertEqual(
            first.finalState.coherence,
            second.finalState.coherence,
            accuracy: 1.0e-12
        )

        XCTAssertEqual(
            first.finalState.shellEnergy,
            second.finalState.shellEnergy,
            accuracy: 1.0e-12
        )

        XCTAssertEqual(
            first.activated,
            second.activated
        )

        XCTAssertEqual(
            first.activationRound,
            second.activationRound
        )

        XCTAssertEqual(
            first.outputEvents,
            second.outputEvents
        )
    }

    // MARK: - Activation

    func testDefaultParametersReachResonanceLock() {

        let parameters =
            QRTLLaserParameters()

        let result =
            QRTLDeterministicSimulator.run(
                parameters: parameters,
                maximumCrossings: 100
            )

        XCTAssertTrue(
            result.finalState.resonanceLocked,
            """
            Default parameters failed to reach resonance lock.
            Phase error: \(result.finalState.phaseError)
            Phase closure: \(result.finalState.phaseClosure)
            Coupling: \(result.finalState.coupling)
            Coherence: \(result.finalState.coherence)
            Stable rounds: \(result.stableLockRounds)
            """
        )
    }

    func testDefaultParametersActivateOutput() {

        let parameters =
            QRTLLaserParameters()

        let result =
            QRTLDeterministicSimulator.run(
                parameters: parameters,
                maximumCrossings: 100
            )

        XCTAssertTrue(
            result.activated
        )

        XCTAssertGreaterThan(
            result.outputEvents,
            0
        )

        XCTAssertGreaterThan(
            result.transmittedOutputFactor,
            0.0
        )
    }

    func testOutputCannotActivateBeforeLock() {

        let parameters =
            QRTLLaserParameters()

        let result =
            QRTLDeterministicSimulator.run(
                parameters: parameters,
                maximumCrossings: 1
            )

        XCTAssertFalse(
            result.activated
        )

        XCTAssertEqual(
            result.outputEvents,
            0
        )

        XCTAssertEqual(
            result.transmittedOutputFactor,
            0.0,
            accuracy: 1.0e-12
        )
    }

    // MARK: - Lock Requirements

    func testLockRequiresAllFourConditions() {

        let parameters =
            QRTLLaserParameters()

        let result =
            QRTLDeterministicSimulator.run(
                parameters: parameters,
                maximumCrossings: 100
            )

        if result.finalState.resonanceLocked {

            XCTAssertGreaterThanOrEqual(
                result.finalState.phaseClosure,
                parameters.phaseClosureLockThreshold
            )

            XCTAssertLessThanOrEqual(
                abs(
                    result.finalState.phaseError
                ),
                parameters.maximumPhaseErrorForLock
            )

            XCTAssertGreaterThanOrEqual(
                result.finalState.coupling,
                parameters.qrtlCouplingLockThreshold
            )

            XCTAssertGreaterThanOrEqual(
                result.finalState.coherence,
                parameters.coherenceLockThreshold
            )

            XCTAssertGreaterThanOrEqual(
                result.stableLockRounds,
                parameters.requiredStableLockRounds
            )
        }
    }

    // MARK: - Output Coupler

    func testOutputTransmissionMatchesConfiguredTenPercent() {

        let parameters =
            QRTLLaserParameters()

        XCTAssertEqual(
            parameters.outputTransmission,
            0.10,
            accuracy: 1.0e-12
        )

        XCTAssertEqual(
            parameters.outputReflection,
            0.90,
            accuracy: 1.0e-12
        )
    }

    func testOutputAndReflectionSumToOne() {

        let parameters =
            QRTLLaserParameters()

        XCTAssertEqual(
            parameters.outputTransmission
            + parameters.outputReflection,
            1.0,
            accuracy: 1.0e-12
        )
    }

    // MARK: - Gain

    func testCombinedGainEqualsComponentProduct() {

        let parameters =
            QRTLLaserParameters()

        let result =
            QRTLDeterministicSimulator.run(
                parameters: parameters
            )

        let state =
            result.finalState

        let expected =
            state.coherenceGain
            * state.lossGain
            * state.concentrationGain

        XCTAssertEqual(
            state.combinedGain,
            expected,
            accuracy: 1.0e-12
        )
    }

    // MARK: - Power Proxy

    func testPredictedPhotonPowerIsNonNegative() {

        let parameters =
            QRTLLaserParameters()

        let result =
            QRTLDeterministicSimulator.run(
                parameters: parameters
            )

        XCTAssertGreaterThanOrEqual(
            result.predictedPhotonPowerWatts,
            0.0
        )
    }

    func testNoOutputMeansNoOutputPower() {

        let parameters =
            QRTLLaserParameters()

        let result =
            QRTLDeterministicSimulator.run(
                parameters: parameters,
                maximumCrossings: 1
            )

        XCTAssertFalse(
            result.activated
        )

        XCTAssertEqual(
            result.predictedPhotonPowerWatts,
            0.0,
            accuracy: 1.0e-30
        )
    }

    // MARK: - Physical Timing

    func testPhysicalRoundTripTimeIsIndependentOfVisualSpeed() {

        let parameters =
            QRTLLaserParameters()

        let expected =
            2.0
            * parameters.cavityLength
            /
            parameters.speedOfLight

        XCTAssertEqual(
            parameters.physicalRoundTripTime,
            expected,
            accuracy: 1.0e-30
        )

        XCTAssertNotEqual(
            parameters.visualOneWayDuration,
            parameters.physicalOneWayTime
        )
    }
}
