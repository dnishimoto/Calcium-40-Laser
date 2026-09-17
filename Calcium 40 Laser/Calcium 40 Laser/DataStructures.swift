//
//  DataStructures.swift
//  Calcium 40 Laser
//
//  Created by David Nishimoto on 9/17/26.
//

import Foundation
enum QRTLWavelengthMapper {
    /// Maps a lattice dominant frequency (Hz) to an optical wavelength (m).
    /// When dominantFreqHz == 5.0 the result equals the 2.94 µm target.
    static func opticalWavelengthMeters(
        dominantFreqHz: Double,
        parameters: QRTLLaserParameters = QRTLLaserParameters()
    ) -> Double {
        let opticalFreq = parameters.targetFrequency + (dominantFreqHz - 5.0) * 1e9
        return parameters.speedOfLight / max(opticalFreq, 1.0)
    }

    static func closenessPercent(
        simulatedWavelengthMeters: Double,
        targetWavelengthMeters: Double
    ) -> Double {
        let rel = abs(simulatedWavelengthMeters - targetWavelengthMeters)
            / max(targetWavelengthMeters, 1e-30)
        return max(0, min(100, 100.0 * (1.0 - rel)))
    }
}
