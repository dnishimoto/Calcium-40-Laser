
//
//  AboutView.swift
//  Calcium 40 Laser
//
//  Created by David Nishimoto on 9/15/26.
//
//  QRTL Resonating Amplifier
//
//  Explains the QRTL laser pipeline as a sequence of stage cards,
//  followed by analysis cards contrasting this architecture
//  against how a real laser works.
//

import SwiftUI

// MARK: - Pipeline Stage Model

private struct PipelineStage: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let description: String
}

// MARK: - Architecture Comparison Point Model

private struct ArchitectureComparisonPoint: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let description: String
}

