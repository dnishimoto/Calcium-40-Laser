
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

// MARK: - About View

struct AboutView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 24
                ) {
                    header
                    pipelineSection
                    comparisonSection
                    footnote
                }
                .padding()
            }
        }
        .toolbar {
            ToolbarItem(
                placement: .confirmationAction
            ) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: 4
        ) {
            Text("How This Laser Model Works")
                .font(
                    .system(
                        size: 24,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)

            Text(
                "The QRTL convergence pipeline, and how it differs from a real laser"
            )
            .font(.caption)
            .foregroundStyle(.gray)
        }
    }

    // MARK: - Pipeline Section

    private var pipelineSection: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            sectionHeading(
                "THE PIPELINE",
                tint: .orange
            )

            ForEach(Self.pipelineStages) { stage in
                StageCard(
                    index: stage.id,
                    icon: stage.icon,
                    title: stage.title,
                    description: stage.description,
                    tint: .orange
                )
            }
        }
    }

    // MARK: - Comparison Section

    private var comparisonSection: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            sectionHeading(
                "WHY THIS ISN'T AS-IS LASER PHYSICS",
                tint: .cyan
            )

            Text(
                "A real laser reaches threshold through population inversion and stimulated emission, then settles into a continuous, self-saturating steady state. This model instead uses a QRTL convergence loop and a defined resonance-lock condition. The following cards identify where the model differs from established laser physics."
            )
            .font(.footnote)
            .foregroundStyle(.gray)
            .fixedSize(
                horizontal: false,
                vertical: true
            )

            ForEach(Self.comparisonPoints) { point in
                ComparisonCard(
                    icon: point.icon,
                    title: point.title,
                    description: point.description
                )
            }
        }
    }

    // MARK: - Footnote

    private var footnote: some View {
        Text(
            "QRTL is a proposed, unvalidated theoretical framework. These equations are a model-defined phenomenological system, not established physics."
        )
        .font(.caption2)
        .foregroundStyle(.gray)
        .padding(.top, 4)
    }

    // MARK: - Section Heading

    private func sectionHeading(
        _ title: String,
        tint: Color
    ) -> some View {
        Text(title)
            .font(
                .caption
                    .weight(.bold)
            )
            .foregroundStyle(tint)
            .padding(.top, 4)
    }

    // MARK: - Pipeline Stage Data

    private static let pipelineStages: [PipelineStage] = [

        PipelineStage(
            id: 1,
            icon: "dial.low",
            title: "Phase Error — the starting condition",
            description:
                "The simulation begins with a phase mismatch between the circulating light and the QRTL resonance condition. This state becomes the initial error that the convergence process attempts to reduce toward zero."
        ),

        PipelineStage(
            id: 2,
            icon: "circle.dashed",
            title: "Phase Closure",
            description:
                "A normalized zero-to-one measure describes how closely the current phase state approaches the defined closure condition. Values near one represent strong phase alignment."
        ),

        PipelineStage(
            id: 3,
            icon: "waveform.path.ecg",
            title: "Resonance Response",
            description:
                "The resonance response measures how strongly the current phase state satisfies the model's resonance condition. The response decreases as the phase state moves away from the resonant region."
        ),

        PipelineStage(
            id: 4,
            icon: "bolt.fill",
            title: "Twist Current",
            description:
                "The modeled twist current evolves during each gain-medium traversal. Its value is driven toward the configured target according to the current phase closure, coupling, and convergence state."
        ),

        PipelineStage(
            id: 5,
            icon: "atom",
            title: "Shell Energy",
            description:
                "Shell energy combines the current resonance response with the accumulated twist-current state. It represents the modeled excitation of the QRTL resonance shell."
        ),

        PipelineStage(
            id: 6,
            icon: "link",
            title: "QRTL Coupling — the central accumulator",
            description:
                "QRTL coupling evolves toward a target determined by the current phase closure, resonance response, and shell-energy state. Each gain-medium traversal updates the coupling rather than setting it instantaneously."
        ),

        PipelineStage(
            id: 7,
            icon: "sparkles",
            title: "Coherence",
            description:
                "Coherence is calculated from the current coupling state and the configured coherence range. As coupling increases, the modeled coherence moves toward its configured maximum."
        ),

        PipelineStage(
            id: 8,
            icon: "arrow.triangle.2.circlepath",
            title: "Phase Correction — feeds back to Stage 1",
            description:
                "Phase closure and coupling determine the phase-correction response. The correction reduces the phase error, allowing the improved state to influence the next gain-medium traversal."
        ),

        PipelineStage(
            id: 9,
            icon: "repeat",
            title: "Re-evaluation",
            description:
                "The updated phase error becomes the starting state for the next iteration. The resonance, twist current, shell energy, coupling, and coherence are recalculated from the new state."
        ),

        PipelineStage(
            id: 10,
            icon: "chart.line.uptrend.xyaxis",
            title: "Gain Metrics",
            description:
                "The model calculates coherence gain, loss-reduction gain, and beam-concentration gain. These configured model metrics are combined into the reported overall intensity-gain value."
        ),

        PipelineStage(
            id: 11,
            icon: "checkmark.seal",
            title: "Round-Trip Lock Check",
            description:
                "After each complete cavity round trip, the model evaluates the configured lock requirements. Phase closure, phase error, coupling, and coherence must simultaneously satisfy their respective thresholds."
        ),

        PipelineStage(
            id: 12,
            icon: "lock.fill",
            title: "Resonance Lock",
            description:
                "The resonance-lock state is reached only after the required number of consecutive stable round trips satisfies all lock conditions. A failed round resets the stable-round requirement."
        ),

        PipelineStage(
            id: 13,
            icon: "bolt.horizontal.fill",
            title: "Output Coupling — the output beam",
            description:
                "After resonance lock, the configured output-coupling fraction is transmitted through the output coupler while the remaining circulating field stays inside the modeled cavity. Before lock, the model suppresses output transmission."
        )
    ]

    // MARK: - Comparison Point Data

    private static let comparisonPoints: [ArchitectureComparisonPoint] = [

        ArchitectureComparisonPoint(
            id: 1,
            icon: "arrow.left.arrow.right",
            title: "Gain-medium physics is replaced with a convergence loop",
            description:
                "Real lasers derive optical gain from processes such as stimulated emission in an inverted gain medium. This model instead uses a QRTL convergence state consisting of phase error, phase closure, twist current, shell energy, and QRTL coupling. Those quantities are model-defined rather than established laser-physics quantities."
        ),

        ArchitectureComparisonPoint(
            id: 2,
            icon: "wand.and.stars",
            title: "Coherence is computed rather than emergent",
            description:
                "In a physical laser, optical coherence arises from the properties of the electromagnetic field and the emission process. In this model, coherence is explicitly calculated from the QRTL coupling state. It is therefore a model output rather than a simulated population-emission process."
        ),

        ArchitectureComparisonPoint(
            id: 3,
            icon: "togglepower",
            title: "A defined lock condition controls output",
            description:
                "The model uses explicit lock thresholds for phase closure, phase error, coupling, and coherence. These conditions must remain satisfied for the required number of consecutive stable round trips before output coupling is enabled."
        ),

        ArchitectureComparisonPoint(
            id: 4,
            icon: "person.2.wave.2",
            title: "The feedback loop drives phase and QRTL state",
            description:
                "The central feedback mechanism updates phase error, twist current, coupling, resonance response, shell energy, and coherence from one traversal to the next. Photon population dynamics and stimulated-emission population equations are not represented as the central convergence mechanism."
        ),

        ArchitectureComparisonPoint(
            id: 5,
            icon: "infinity",
            title: "The current model does not implement physical gain saturation",
            description:
                "A physical laser requires a gain medium whose population dynamics and depletion determine its steady-state behavior. The QRTL convergence model instead uses configured state updates and lock conditions. Physical gain saturation and medium depletion must not be inferred from the QRTL lock state unless they are explicitly implemented."
        )
    ]
}

// MARK: - Stage Card

private struct StageCard: View {

    let index: Int
    let icon: String
    let title: String
    let description: String
    let tint: Color

    var body: some View {
        HStack(
            alignment: .top,
            spacing: 12
        ) {
            ZStack {
                Circle()
                    .fill(
                        tint.opacity(0.15)
                    )
                    .frame(
                        width: 34,
                        height: 34
                    )

                Text("\(index)")
                    .font(
                        .caption
                            .weight(.bold)
                    )
                    .foregroundStyle(tint)
            }

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                HStack(
                    spacing: 6
                ) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(tint)

                    Text(title)
                        .font(
                            .subheadline
                                .weight(.semibold)
                        )
                        .foregroundStyle(.white)
                }

                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.gray)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }
        }
        .padding(12)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            RoundedRectangle(
                cornerRadius: 14
            )
            .fill(
                Color.white.opacity(0.06)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 14
            )
            .stroke(
                Color.white.opacity(0.08),
                lineWidth: 1
            )
        )
    }
}

// MARK: - Comparison Card

private struct ComparisonCard: View {

    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 6
        ) {
            HStack(
                spacing: 6
            ) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.cyan)

                Text(title)
                    .font(
                        .subheadline
                            .weight(.semibold)
                    )
                    .foregroundStyle(.white)
            }

            Text(description)
                .font(.footnote)
                .foregroundStyle(.gray)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
        }
        .padding(12)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            RoundedRectangle(
                cornerRadius: 14
            )
            .fill(
                Color.cyan.opacity(0.08)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 14
            )
            .stroke(
                Color.cyan.opacity(0.15),
                lineWidth: 1
            )
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AboutView()
    }
    .preferredColorScheme(.dark)
}
