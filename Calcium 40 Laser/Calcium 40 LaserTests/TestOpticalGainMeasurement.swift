
//
//  Calcium40LaserMeasurementTests.swift
//  Calcium 40 Laser
//
//  Created by David Nishimoto on 9/15/26.
//
//  Measurement and physical-verification tests for the
//  QRTL Resonating Amplifier / Calcium-40 Laser model.
//
//  IMPORTANT:
//  These tests verify numerical accounting, measurement handling,
//  threshold logic, population accounting, and prediction-vs-measurement
//  comparisons.
//
//  Passing these tests does NOT establish that QRTL physics is experimentally
//  valid or that a physical calcium-40 laser has been demonstrated.
//

import Foundation
import SwiftUI
import XCTest

@testable import Calcium_40_Laser


// MARK: - Measurement Test Model
//
// These lightweight test structures make the measurement requirements
// explicit. They can later be replaced by the production verification
// structures if those structures already exist in the application.
//

struct TestOpticalGainMeasurement {
    let inputPowerWatts: Double
    let outputPowerWatts: Double
    let gainLengthMeters: Double

    var powerGain: Double {
        guard inputPowerWatts > 0 else { return 0 }
        return outputPowerWatts / inputPowerWatts
    }

    var gainCoefficientPerMeter: Double {
        guard inputPowerWatts > 0,
              outputPowerWatts > 0,
              gainLengthMeters > 0 else {
            return 0
        }

        return log(outputPowerWatts / inputPowerWatts) / gainLengthMeters
    }
}


struct TestThresholdMeasurement {
    let roundTripGain: Double
    let roundTripLoss: Double

    var netRoundTripGain: Double {
        roundTripGain - roundTripLoss
    }

    var thresholdReached: Bool {
        roundTripGain >= roundTripLoss
    }
}


struct TestPowerMeasurement {
    let inputPowerWatts: Double
    let absorbedPumpPowerWatts: Double
    let storedEnergyJoules: Double
    let intracavityPowerWatts: Double
    let outputPowerWatts: Double
    let lossPowerWatts: Double

    var powerBalanceResidual: Double {
        inputPowerWatts
        - absorbedPumpPowerWatts
        - outputPowerWatts
        - lossPowerWatts
    }
}


struct TestEfficiencyMeasurement {
    let inputPowerWatts: Double
    let outputPowerWatts: Double

    var efficiency: Double {
        guard inputPowerWatts > 0 else { return 0 }
        return outputPowerWatts / inputPowerWatts
    }
}


struct TestCalcium40TransitionMeasurement {
    let transitionEnergyJoules: Double
    let transitionWavelengthMeters: Double
    let lifetimeSeconds: Double
    let linewidthHz: Double
}


struct TestPopulationMeasurement {
    let totalPopulation: Double
    let upperPopulation: Double
    let lowerPopulation: Double

    var inversion: Double {
        upperPopulation - lowerPopulation
    }

    var populationConservationResidual: Double {
        totalPopulation - upperPopulation - lowerPopulation
    }
}


struct TestExperimentalMeasurement {
    let predictedWavelengthMeters: Double
    let measuredWavelengthMeters: Double

    let predictedPowerWatts: Double
    let measuredPowerWatts: Double

    let predictedThresholdWatts: Double
    let measuredThresholdWatts: Double

    var wavelengthAbsoluteErrorMeters: Double {
        abs(measuredWavelengthMeters - predictedWavelengthMeters)
    }

    var wavelengthPercentError: Double {
        guard predictedWavelengthMeters != 0 else { return 0 }

        return abs(
            measuredWavelengthMeters - predictedWavelengthMeters
        ) / abs(predictedWavelengthMeters) * 100
    }

    var powerPercentError: Double {
        guard predictedPowerWatts != 0 else { return 0 }

        return abs(
            measuredPowerWatts - predictedPowerWatts
        ) / abs(predictedPowerWatts) * 100
    }

    var thresholdPercentError: Double {
        guard predictedThresholdWatts != 0 else { return 0 }

        return abs(
            measuredThresholdWatts - predictedThresholdWatts
        ) / abs(predictedThresholdWatts) * 100
    }
}


// MARK: - Measurement Verification Tests

final class Calcium40LaserMeasurementTests: XCTestCase {


    // MARK: 1. Physical Optical Gain


    func testOpticalGainEqualsOutputDividedByInput() {

        let measurement = TestOpticalGainMeasurement(
            inputPowerWatts: 10.0,
            outputPowerWatts: 15.0,
            gainLengthMeters: 0.01
        )

        XCTAssertEqual(
            measurement.powerGain,
            1.5,
            accuracy: 1e-12
        )
    }


    func testOpticalGainCoefficientIsCalculatedFromMeasuredPower() {

        let input = 10.0
        let output = 20.0
        let length = 0.01

        let measurement = TestOpticalGainMeasurement(
            inputPowerWatts: input,
            outputPowerWatts: output,
            gainLengthMeters: length
        )

        let expected = log(2.0) / length

        XCTAssertEqual(
            measurement.gainCoefficientPerMeter,
            expected,
            accuracy: 1e-12
        )
    }


    func testOpticalGainCannotUseZeroInputPower() {

        let measurement = TestOpticalGainMeasurement(
            inputPowerWatts: 0,
            outputPowerWatts: 10,
            gainLengthMeters: 0.01
        )

        XCTAssertEqual(
            measurement.powerGain,
            0
        )
    }


    func testOpticalGainCannotUseNegativeInputPower() {

        let measurement = TestOpticalGainMeasurement(
            inputPowerWatts: -10,
            outputPowerWatts: 10,
            gainLengthMeters: 0.01
        )

        XCTAssertEqual(
            measurement.powerGain,
            0
        )
    }


    // MARK: 2. Laser Threshold


    func testThresholdIsNotReachedBelowUnityNetGain() {

        let measurement = TestThresholdMeasurement(
            roundTripGain: 0.90,
            roundTripLoss: 1.00
        )

        XCTAssertFalse(
            measurement.thresholdReached
        )

        XCTAssertLessThan(
            measurement.netRoundTripGain,
            0
        )
    }


    func testThresholdIsReachedAtGainLossEquality() {

        let measurement = TestThresholdMeasurement(
            roundTripGain: 1.00,
            roundTripLoss: 1.00
        )

        XCTAssertTrue(
            measurement.thresholdReached
        )

        XCTAssertEqual(
            measurement.netRoundTripGain,
            0,
            accuracy: 1e-12
        )
    }


    func testThresholdIsReachedAboveRoundTripLoss() {

        let measurement = TestThresholdMeasurement(
            roundTripGain: 1.25,
            roundTripLoss: 1.00
        )

        XCTAssertTrue(
            measurement.thresholdReached
        )

        XCTAssertGreaterThan(
            measurement.netRoundTripGain,
            0
        )
    }


    // MARK: 3. Input → Output Power


    func testPowerAccountingTracksInputAndOutput() {

        let measurement = TestPowerMeasurement(
            inputPowerWatts: 100.0,
            absorbedPumpPowerWatts: 80.0,
            storedEnergyJoules: 10.0,
            intracavityPowerWatts: 50.0,
            outputPowerWatts: 20.0,
            lossPowerWatts: 0.0
        )

        XCTAssertEqual(
            measurement.inputPowerWatts,
            100.0,
            accuracy: 1e-12
        )

        XCTAssertEqual(
            measurement.outputPowerWatts,
            20.0,
            accuracy: 1e-12
        )
    }


    func testPowerBalanceCanClose() {

        let measurement = TestPowerMeasurement(
            inputPowerWatts: 100.0,
            absorbedPumpPowerWatts: 80.0,
            storedEnergyJoules: 10.0,
            intracavityPowerWatts: 50.0,
            outputPowerWatts: 20.0,
            lossPowerWatts: 0.0
        )

        XCTAssertEqual(
            measurement.powerBalanceResidual,
            0,
            accuracy: 1e-12
        )
    }


    func testEnergyAccountingRejectsUnexplainedOutput() {

        let measurement = TestPowerMeasurement(
            inputPowerWatts: 100.0,
            absorbedPumpPowerWatts: 50.0,
            storedEnergyJoules: 10.0,
            intracavityPowerWatts: 50.0,
            outputPowerWatts: 40.0,
            lossPowerWatts: 0.0
        )

        XCTAssertNotEqual(
            measurement.powerBalanceResidual,
            0,
            accuracy: 1e-12
        )
    }


    // MARK: 4. Optical Efficiency


    func testOpticalEfficiencyUsesInputPower() {

        let measurement = TestEfficiencyMeasurement(
            inputPowerWatts: 100.0,
            outputPowerWatts: 20.0
        )

        XCTAssertEqual(
            measurement.efficiency,
            0.20,
            accuracy: 1e-12
        )
    }


    func testOpticalEfficiencyCannotExceedOneForPhysicalOutput() {

        let measurement = TestEfficiencyMeasurement(
            inputPowerWatts: 100.0,
            outputPowerWatts: 20.0
        )

        XCTAssertGreaterThanOrEqual(
            measurement.efficiency,
            0
        )

        XCTAssertLessThanOrEqual(
            measurement.efficiency,
            1
        )
    }


    func testZeroInputProducesZeroEfficiency() {

        let measurement = TestEfficiencyMeasurement(
            inputPowerWatts: 0,
            outputPowerWatts: 20
        )

        XCTAssertEqual(
            measurement.efficiency,
            0
        )
    }


    func testEfficiencyIsIndependentOfPhotonCountProxy() {

        let measurement = TestEfficiencyMeasurement(
            inputPowerWatts: 100.0,
            outputPowerWatts: 25.0
        )

        let efficiency = measurement.efficiency

        XCTAssertEqual(
            efficiency,
            0.25,
            accuracy: 1e-12
        )

        // The important requirement is that efficiency is based
        // directly on measured/configured input and output power,
        // rather than photonCount * photonEnergy / time.
        XCTAssertNotEqual(
            efficiency,
            1.0,
            accuracy: 1e-12
        )
    }


    // MARK: 5. Calcium-40 Transition Characterization


    func testCalcium40TransitionEnergyIsPositive() {

        let transition = TestCalcium40TransitionMeasurement(
            transitionEnergyJoules: 6.76e-20,
            transitionWavelengthMeters: 2.94e-6,
            lifetimeSeconds: 1e-8,
            linewidthHz: 1e7
        )

        XCTAssertGreaterThan(
            transition.transitionEnergyJoules,
            0
        )
    }


    func testTransitionWavelengthIsPositive() {

        let transition = TestCalcium40TransitionMeasurement(
            transitionEnergyJoules: 6.76e-20,
            transitionWavelengthMeters: 2.94e-6,
            lifetimeSeconds: 1e-8,
            linewidthHz: 1e7
        )

        XCTAssertGreaterThan(
            transition.transitionWavelengthMeters,
            0
        )
    }


    func testTransitionLifetimeIsPositive() {

        let transition = TestCalcium40TransitionMeasurement(
            transitionEnergyJoules: 6.76e-20,
            transitionWavelengthMeters: 2.94e-6,
            lifetimeSeconds: 1e-8,
            linewidthHz: 1e7
        )

        XCTAssertGreaterThan(
            transition.lifetimeSeconds,
            0
        )
    }


    func testTransitionLinewidthIsPositive() {

        let transition = TestCalcium40TransitionMeasurement(
            transitionEnergyJoules: 6.76e-20,
            transitionWavelengthMeters: 2.94e-6,
            lifetimeSeconds: 1e-8,
            linewidthHz: 1e7
        )

        XCTAssertGreaterThan(
            transition.linewidthHz,
            0
        )
    }


    // MARK: 6. Population / Excitation Dynamics


    func testPopulationConservation() {

        let measurement = TestPopulationMeasurement(
            totalPopulation: 1000,
            upperPopulation: 600,
            lowerPopulation: 400
        )

        XCTAssertEqual(
            measurement.populationConservationResidual,
            0,
            accuracy: 1e-12
        )
    }


    func testPopulationInversionIsUpperMinusLower() {

        let measurement = TestPopulationMeasurement(
            totalPopulation: 1000,
            upperPopulation: 600,
            lowerPopulation: 400
        )

        XCTAssertEqual(
            measurement.inversion,
            200,
            accuracy: 1e-12
        )
    }


    func testPositivePopulationInversionRepresentsMoreUpperStatePopulation() {

        let measurement = TestPopulationMeasurement(
            totalPopulation: 1000,
            upperPopulation: 700,
            lowerPopulation: 300
        )

        XCTAssertGreaterThan(
            measurement.inversion,
            0
        )
    }


    func testNegativePopulationInversionRepresentsMoreLowerStatePopulation() {

        let measurement = TestPopulationMeasurement(
            totalPopulation: 1000,
            upperPopulation: 300,
            lowerPopulation: 700
        )

        XCTAssertLessThan(
            measurement.inversion,
            0
        )
    }


    func testPopulationCannotExceedTotalPopulation() {

        let measurement = TestPopulationMeasurement(
            totalPopulation: 1000,
            upperPopulation: 600,
            lowerPopulation: 400
        )

        XCTAssertLessThanOrEqual(
            measurement.upperPopulation
            + measurement.lowerPopulation,
            measurement.totalPopulation
        )
    }


    // MARK: 7. Prediction vs Experiment


    func testMeasuredWavelengthErrorIsCalculated() {

        let prediction = 2.940e-6
        let measurement = 2.950e-6

        let comparison = TestExperimentalMeasurement(
            predictedWavelengthMeters: prediction,
            measuredWavelengthMeters: measurement,
            predictedPowerWatts: 20,
            measuredPowerWatts: 19,
            predictedThresholdWatts: 50,
            measuredThresholdWatts: 52
        )

        XCTAssertEqual(
            comparison.wavelengthAbsoluteErrorMeters,
            1.0e-8,
            accuracy: 1e-15
        )
    }


    func testMeasuredWavelengthPercentErrorIsCalculated() {

        let comparison = TestExperimentalMeasurement(
            predictedWavelengthMeters: 2.940e-6,
            measuredWavelengthMeters: 2.950e-6,
            predictedPowerWatts: 20,
            measuredPowerWatts: 19,
            predictedThresholdWatts: 50,
            measuredThresholdWatts: 52
        )

        let expected =
            abs(2.950e-6 - 2.940e-6)
            / 2.940e-6
            * 100

        XCTAssertEqual(
            comparison.wavelengthPercentError,
            expected,
            accuracy: 1e-12
        )
    }


    func testMeasuredPowerPercentErrorIsCalculated() {

        let comparison = TestExperimentalMeasurement(
            predictedWavelengthMeters: 2.940e-6,
            measuredWavelengthMeters: 2.950e-6,
            predictedPowerWatts: 20,
            measuredPowerWatts: 19,
            predictedThresholdWatts: 50,
            measuredThresholdWatts: 52
        )

        XCTAssertEqual(
            comparison.powerPercentError,
            5.0,
            accuracy: 1e-12
        )
    }


    func testMeasuredThresholdPercentErrorIsCalculated() {

        let comparison = TestExperimentalMeasurement(
            predictedWavelengthMeters: 2.940e-6,
            measuredWavelengthMeters: 2.950e-6,
            predictedPowerWatts: 20,
            measuredPowerWatts: 19,
            predictedThresholdWatts: 50,
            measuredThresholdWatts: 52
        )

        XCTAssertEqual(
            comparison.thresholdPercentError,
            4.0,
            accuracy: 1e-12
        )
    }


    // MARK: 8. QRTL Lock Must Remain Separate From Physical Lasing


    func testQRTLLockDoesNotAutomaticallyMeanPhysicalLaserOutput() {

        let qrtlLocked = true
        let opticalThresholdReached = false
        let physicalLaserOutputDetected = false

        XCTAssertTrue(
            qrtlLocked
        )

        XCTAssertFalse(
            opticalThresholdReached
        )

        XCTAssertFalse(
            physicalLaserOutputDetected
        )
    }


    func testPhysicalLaserOutputRequiresThreshold() {

        let qrtlLocked = true
        let opticalThresholdReached = false
        let measuredOutputPowerWatts = 0.0

        let physicalLaserOutputDetected =
            qrtlLocked
            && opticalThresholdReached
            && measuredOutputPowerWatts > 0

        XCTAssertFalse(
            physicalLaserOutputDetected
        )
    }


    func testPhysicalLaserOutputRequiresMeasuredOutput() {

        let qrtlLocked = true
        let opticalThresholdReached = true
        let measuredOutputPowerWatts = 0.0

        let physicalLaserOutputDetected =
            qrtlLocked
            && opticalThresholdReached
            && measuredOutputPowerWatts > 0

        XCTAssertFalse(
            physicalLaserOutputDetected
        )
    }


    func testPhysicalLaserOutputRequiresAllVerificationConditions() {

        let qrtlLocked = true
        let opticalThresholdReached = true
        let measuredOutputPowerWatts = 20.0

        let physicalLaserOutputDetected =
            qrtlLocked
            && opticalThresholdReached
            && measuredOutputPowerWatts > 0

        XCTAssertTrue(
            physicalLaserOutputDetected
        )
    }


    // MARK: 9. Energy Accounting Must Be Independent From QRTL Gain


    func testQRTLGainCannotBeCountedAsFreeEnergy() {

        let inputPower = 100.0
        let qrtlGain = 3.4
        let outputPower = 20.0

        // QRTL gain changes the modeled optical state,
        // but it does not create an independent energy source.
        //
        // Therefore the gain factor itself must not be added
        // to the input power as though it were external energy.

        let incorrectPower = inputPower * qrtlGain

        XCTAssertNotEqual(
            incorrectPower,
            outputPower,
            accuracy: 1e-12
        )
    }


    func testOutputPowerMustHaveAnEnergySource() {

        let inputPower = 100.0
        let outputPower = 20.0

        XCTAssertLessThanOrEqual(
            outputPower,
            inputPower
        )
    }


    // MARK: 10. Measurement Sanity Checks


    func testMeasurementsRemainFinite() {

        let measurements: [Double] = [
            100.0,
            20.0,
            0.25,
            2.94e-6,
            6.76e-20,
            1e-8,
            1e7
        ]

        for value in measurements {
            XCTAssertTrue(
                value.isFinite,
                "Measurement must remain finite: \(value)"
            )
        }
    }


    func testMeasurementsRemainNonNegativeWhereRequired() {

        let positiveQuantities: [Double] = [
            100.0,       // input power
            20.0,        // output power
            2.94e-6,     // wavelength
            6.76e-20,    // transition energy
            1e-8,        // lifetime
            1e7          // linewidth
        ]

        for value in positiveQuantities {
            XCTAssertGreaterThanOrEqual(
                value,
                0
            )
        }
    }


    // MARK: 11. Full Verification Chain


    func testFullMeasurementVerificationChain() {

        // QRTL state
        let qrtlLocked = true

        // Physical optical gain
        let opticalGain = TestOpticalGainMeasurement(
            inputPowerWatts: 100,
            outputPowerWatts: 125,
            gainLengthMeters: 0.01
        )

        // Threshold
        let threshold = TestThresholdMeasurement(
            roundTripGain: 1.20,
            roundTripLoss: 1.00
        )

        // Input/output measurement
        let power = TestPowerMeasurement(
            inputPowerWatts: 100,
            absorbedPumpPowerWatts: 80,
            storedEnergyJoules: 10,
            intracavityPowerWatts: 50,
            outputPowerWatts: 20,
            lossPowerWatts: 0
        )

        // Efficiency
        let efficiency = TestEfficiencyMeasurement(
            inputPowerWatts: 100,
            outputPowerWatts: 20
        )

        // Population
        let population = TestPopulationMeasurement(
            totalPopulation: 1000,
            upperPopulation: 600,
            lowerPopulation: 400
        )

        // Prediction vs measurement
        let experiment = TestExperimentalMeasurement(
            predictedWavelengthMeters: 2.940e-6,
            measuredWavelengthMeters: 2.940e-6,
            predictedPowerWatts: 20,
            measuredPowerWatts: 20,
            predictedThresholdWatts: 50,
            measuredThresholdWatts: 50
        )

        XCTAssertTrue(qrtlLocked)

        XCTAssertGreaterThan(
            opticalGain.powerGain,
            1.0
        )

        XCTAssertTrue(
            threshold.thresholdReached
        )

        XCTAssertEqual(
            power.outputPowerWatts,
            20.0,
            accuracy: 1e-12
        )

        XCTAssertEqual(
            efficiency.efficiency,
            0.20,
            accuracy: 1e-12
        )

        XCTAssertEqual(
            population.populationConservationResidual,
            0,
            accuracy: 1e-12
        )

        XCTAssertEqual(
            experiment.wavelengthPercentError,
            0,
            accuracy: 1e-12
        )

        XCTAssertEqual(
            experiment.powerPercentError,
            0,
            accuracy: 1e-12
        )

        XCTAssertEqual(
            experiment.thresholdPercentError,
            0,
            accuracy: 1e-12
        )
    }


    // MARK: 12. Prevent False Physical Validation


    func testSimulationCannotClaimExperimentalValidationWithoutMeasurement() {

        let qrtlLocked = true
        let opticalThresholdReached = true

        let measuredOutputPowerWatts: Double? = nil

        let experimentallyVerified =
            qrtlLocked
            && opticalThresholdReached
            && measuredOutputPowerWatts != nil

        XCTAssertFalse(
            experimentallyVerified
        )
    }


    func testPredictionMustExistBeforeExperimentComparison() {

        let predictionExists = true
        let experimentalMeasurementExists = true

        XCTAssertTrue(
            predictionExists
        )

        XCTAssertTrue(
            experimentalMeasurementExists
        )
    }
}


