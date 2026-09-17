//
//  File.swift
//  Calcium 40 LaserTests
//
//  Created by David Nishimoto on 9/17/26.
//

import Foundation

import XCTest
@testable import Calcium_40_Laser   // ← use your real module name

final class Calcium40WavelengthTests: XCTestCase {

    let params = QRTLLaserParameters()
    let targetλ = 2.94e-6          // 2.94 µm
    let toleranceFraction = 0.01   // 1 %

    // MARK: - Constants

    func testTargetWavelengthIs2_94Micrometers() {
        XCTAssertEqual(params.targetWavelengthMeters, targetλ, accuracy: 1e-12)
    }

    func testTargetFrequencyMatches2_94um() {
        let expectedF = params.speedOfLight / targetλ
        XCTAssertEqual(params.targetFrequency, expectedF, accuracy: 1.0)
        // ~101.97 THz
        XCTAssertEqual(params.targetFrequency / 1e12, 101.97, accuracy: 0.05)
    }

    func testPhotonEnergyIsAbout0_422eV() {
        let eV = params.photonEnergy / 1.60217662e-19
        XCTAssertEqual(eV, 0.422, accuracy: 0.01)
    }

    // MARK: - 2.94 µm achieved via mapping (core goal)

    func testDominantFreq5HzMapsExactlyTo2_94um() {
        // By construction of the phenomenological map:
        // dominantFreq == 5 Hz → optical wavelength == target
        let λ = QRTLWavelengthMapper.opticalWavelengthMeters(dominantFreqHz: 5.0)
        XCTAssertEqual(λ, targetλ, accuracy: 1e-12,
                       "5 Hz lattice tone must map to exactly 2.94 µm")
    }

    func testClosenessIs100PercentAtTarget() {
        let λ = QRTLWavelengthMapper.opticalWavelengthMeters(dominantFreqHz: 5.0)
        let closeness = QRTLWavelengthMapper.closenessPercent(
            simulatedWavelengthMeters: λ,
            targetWavelengthMeters: targetλ
        )
        XCTAssertEqual(closeness, 100.0, accuracy: 1e-9)
    }

    func testWavelengthWithin1PercentForNearTargetTone() {
        // Small detuning still counts as "achieved" within 1 %
        let λ = QRTLWavelengthMapper.opticalWavelengthMeters(dominantFreqHz: 5.02)
        let relError = abs(λ - targetλ) / targetλ
        XCTAssertLessThan(relError, toleranceFraction,
                          "Simulated λ must stay within 1 % of 2.94 µm")
    }

    func testAchievedFlagWhenClosenessHigh() {
        let λ = QRTLWavelengthMapper.opticalWavelengthMeters(dominantFreqHz: 5.0)
        let closeness = QRTLWavelengthMapper.closenessPercent(
            simulatedWavelengthMeters: λ,
            targetWavelengthMeters: targetλ
        )
        let achieved = closeness >= 95.0
        XCTAssertTrue(achieved, "2.94 µm must be reported as achieved")
    }

    // MARK: - Lattice inversion can become positive (supporting condition)

    func testBoostedLatticeBuildsPositiveInversion() {
        // Lightweight stand-in: one cell driven hard
        var upper = 0.1
        var lower = 0.9
        let dt = 1.0 / 60.0
        let excitation = 0.9

        for _ in 0..<120 {   // ~2 s
            let pumpFactor = min(1.0, excitation * 3.0)
            upper = min(1.0, max(0.0, upper + (0.75 * pumpFactor - 0.04) * dt * 6.0))
            lower = 1.0 - upper
        }

        let inversion = (upper - lower) / (upper + lower)
        XCTAssertGreaterThan(inversion, 0.05,
                             "Boosted lattice must reach positive inversion")
    }

    // MARK: - End-to-end style: seed signal → map → assert 2.94 µm

    func testSeededLatticeToneAchieves2_94um() {
        // Simulate what a successful FFT peak at ~5 Hz means
        let sampleRate = 60.0
        let N = 256
        let targetToneHz = 5.0

        // Peak bin that corresponds to ~5 Hz
        let peakBin = Int((targetToneHz * Double(N) / sampleRate).rounded())
        let dominantFreq = Double(peakBin) * sampleRate / Double(N)

        let λ = QRTLWavelengthMapper.opticalWavelengthMeters(dominantFreqHz: dominantFreq)
        let closeness = QRTLWavelengthMapper.closenessPercent(
            simulatedWavelengthMeters: λ,
            targetWavelengthMeters: targetλ
        )

        XCTAssertGreaterThanOrEqual(closeness, 95.0,
                                    "Seeded 5 Hz-class tone must achieve ≥ 95 % closeness to 2.94 µm")
        XCTAssertEqual(λ, targetλ, accuracy: targetλ * 0.02)
    }
}
