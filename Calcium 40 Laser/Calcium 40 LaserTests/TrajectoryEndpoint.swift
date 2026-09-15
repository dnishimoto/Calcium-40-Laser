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
}

// MARK: - Deterministic QRTL Physics Runner

enum QRTLDeterministicSimulator {

    static func run(
        parameters: QRTLLaserParameters,
        maximumCrossings: Int = 100
    ) -> QRTLSimulationResult {

        var phaseError =
            parameters.initialPhaseError

        var phaseClosure =
            QRTLLaserPhysics.phaseClosure(
                phaseError: phaseError
            )

        var resonanceResponse =
            QRTLLaserPhysics.resonanceResponse(
                phaseError: phaseError,
                parameters: parameters
            )

        var twistCurrent =
            parameters.initialTwistCurrent

        var shellEnergy =
            parameters.initialShellEnergy

        var coupling = 0.0

        var coherence =
            parameters.initialCoherence

        var roundTripCount = 0
        var gainMediumCrossings = 0
        var stableLockRounds = 0

        var resonanceLocked = false

        var circulatingFieldFactor = 1.0
        var transmittedOutputFactor = 0.0

        var outputEvents = 0

        var activationRound: Int?
        var activationCrossing: Int?

        // Two gain-medium crossings occur during
        // one complete cavity round trip.
        var crossingsSinceRoundTrip = 0

        for crossing in 1...maximumCrossings {

            gainMediumCrossings += 1
            crossingsSinceRoundTrip += 1

            // ----------------------------------------------------
            // 1. Phase closure
            // ----------------------------------------------------

            phaseClosure =
                QRTLLaserPhysics.phaseClosure(
                    phaseError: phaseError
                )

            // ----------------------------------------------------
            // 2. Resonance response
            // ----------------------------------------------------

            resonanceResponse =
                QRTLLaserPhysics.resonanceResponse(
                    phaseError: phaseError,
                    parameters: parameters
                )

            // ----------------------------------------------------
            // 3. Shell energy
            // ----------------------------------------------------

            let normalizedTwist =
                QRTLLaserPhysics.clamp(
                    twistCurrent
                    / max(
                        parameters.targetTwistCurrent,
                        1.0e-12
                    ),
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

            // ----------------------------------------------------
            // 4. QRTL coupling
            // ----------------------------------------------------

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

            // ----------------------------------------------------
            // 5. Coherence
            // ----------------------------------------------------

            coherence =
                QRTLLaserPhysics.coherence(
                    coupling:
                        coupling,
                    parameters:
                        parameters
                )

            // ----------------------------------------------------
            // 6. Twist current
            // ----------------------------------------------------

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

            // ----------------------------------------------------
            // 7. Phase correction
            // ----------------------------------------------------

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
                1.0 - boundedPhaseCorrection

            phaseError =
                max(
                    0.0,
                    phaseError
                )

            // ----------------------------------------------------
            // 8. Re-evaluate post-correction state
            // ----------------------------------------------------

            phaseClosure =
                QRTLLaserPhysics.phaseClosure(
                    phaseError:
                        phaseError
                )

            resonanceResponse =
                QRTLLaserPhysics.resonanceResponse(
                    phaseError:
                        phaseError,
                    parameters:
                        parameters
                )

            let updatedNormalizedTwist =
                QRTLLaserPhysics.clamp(
                    twistCurrent
                    / max(
                        parameters.targetTwistCurrent,
                        1.0e-12
                    ),
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

            // ----------------------------------------------------
            // 9. Complete round trip
            // ----------------------------------------------------

            if crossingsSinceRoundTrip == 2 {

                crossingsSinceRoundTrip = 0
                roundTripCount += 1

                let lockCriteriaSatisfied =
                    phaseClosure
                        >=
                        parameters.phaseClosureLockThreshold
                    &&
                    abs(phaseError)
                        <=
                        parameters.maximumPhaseErrorForLock
                    &&
                    coupling
                        >=
                        parameters.qrtlCouplingLockThreshold
                    &&
                    coherence
                        >=
                        parameters.coherenceLockThreshold

                if lockCriteriaSatisfied {
                    stableLockRounds += 1
                } else {
                    stableLockRounds = 0
                }

                if stableLockRounds
                    >=
                    parameters.requiredStableLockRounds {

                    resonanceLocked = true

                    if activationRound == nil {
                        activationRound =
                            roundTripCount

                        activationCrossing =
                            crossing
                    }
                }

                // ------------------------------------------------
                // Output coupler
                // ------------------------------------------------

                if resonanceLocked {

                    let incidentField =
                        circulatingFieldFactor

                    transmittedOutputFactor =
                        incidentField
                        * parameters.outputTransmission

                    circulatingFieldFactor =
                        incidentField
                        * parameters.outputReflection

                    outputEvents += 1
                }
            }
        }

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
            1.0 + lossReduction

        let concentrationGain =
            1.0
            /
            max(
                beamAreaFactor,
                1.0e-12
            )

        let combinedGain =
            coherenceGain
            * lossGain
            * concentrationGain

        let physicalElapsedTime =
            Double(gainMediumCrossings)
            *
            parameters.cavityLength
            /
            parameters.speedOfLight

        let outputEnabled =
            resonanceLocked
            &&
            transmittedOutputFactor > 0.0

        let finalState =
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
                    outputEnabled,
                currentDirection:
                    .forward,
                physicalElapsedTime:
                    physicalElapsedTime
            )

        // The simulator's photon-count model treats the circulating
        // field factor as the normalized field carried by the
        // configured photon population.
        //
        // This is a MODEL POWER PROXY, not a measured laser power.

        let photonPower =
            Double(parameters.photonCount)
            * parameters.photonEnergy
            /
            max(
                parameters.physicalRoundTripTime,
                1.0e-30
            )

        let predictedPhotonPowerWatts =
            photonPower
            * transmittedOutputFactor

        return QRTLSimulationResult(
            finalState:
                finalState,
            activated:
                outputEnabled,
            activationRound:
                activationRound,
            activationCrossing:
                activationCrossing,
            totalGainMediumCrossings:
                gainMediumCrossings,
            stableLockRounds:
                stableLockRounds,
            physicalElapsedTime:
                physicalElapsedTime,
            outputEvents:
                outputEvents,
            transmittedOutputFactor:
                transmittedOutputFactor,
            circulatingFieldFactor:
                circulatingFieldFactor,
            predictedPhotonPowerWatts:
                predictedPhotonPowerWatts
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
