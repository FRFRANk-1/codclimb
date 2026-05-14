// CodClimb/Views/CragFilterSheet.swift
// Filter crags by rock type, climbing style, sun exposure, and region keyword.

import SwiftUI

// MARK: - Filter state (passed by reference so CragListView reacts)

final class CragFilter: ObservableObject {
    @Published var rockTypes:   Set<String>      = []
    @Published var styles:      Set<CragStyle>   = []
    @Published var sunExposures: Set<SunExposure> = []
    @Published var regionText:  String           = ""

    var isActive: Bool {
        !rockTypes.isEmpty || !styles.isEmpty || !sunExposures.isEmpty || !regionText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var activeCount: Int {
        (rockTypes.isEmpty ? 0 : 1) +
        (styles.isEmpty ? 0 : 1) +
        (sunExposures.isEmpty ? 0 : 1) +
        (regionText.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : 1)
    }

    func apply(to crags: [Crag]) -> [Crag] {
        crags.filter { crag in
            let rockOK   = rockTypes.isEmpty   || rockTypes.contains(crag.rockType)
            let styleOK  = styles.isEmpty      || styles.contains(crag.inferredStyle)
            let sunOK    = sunExposures.isEmpty || sunExposures.contains(crag.sunExposure)
            let regionOK = regionText.trimmingCharacters(in: .whitespaces).isEmpty ||
                           crag.region.localizedCaseInsensitiveContains(regionText)
            return rockOK && styleOK && sunOK && regionOK
        }
    }

    func reset() {
        rockTypes    = []
        styles       = []
        sunExposures = []
        regionText   = ""
    }
}

// MARK: - Filter sheet

struct CragFilterSheet: View {
    @ObservedObject var filter: CragFilter
    @Environment(\.dismiss) private var dismiss

    // All unique rock types across the crag list
    let availableRockTypes: [String]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    // ── Region search ───────────────────────────────────────
                    filterSection("State or Region") {
                        HStack(spacing: 10) {
                            Image(systemName: "map.circle")
                                .foregroundStyle(Theme.Palette.textTertiary)
                            TextField("e.g. New Hampshire, California…", text: $filter.regionText)
                                .font(Theme.Typography.body)
                                .autocorrectionDisabled()
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.Palette.surface)
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.Palette.divider, lineWidth: 1))
                        )
                    }

                    // ── Climbing style ──────────────────────────────────────
                    filterSection("Climbing Style") {
                        FlowLayout(spacing: 8) {
                            ForEach(CragStyle.allCases) { style in
                                FilterChip(
                                    label: style.rawValue,
                                    icon: style.icon,
                                    isSelected: filter.styles.contains(style)
                                ) {
                                    filter.styles.formSymmetricDifference([style])
                                }
                            }
                        }
                    }

                    // ── Rock type ───────────────────────────────────────────
                    filterSection("Rock Type") {
                        FlowLayout(spacing: 8) {
                            ForEach(availableRockTypes, id: \.self) { rock in
                                FilterChip(
                                    label: rock,
                                    icon: "mountain.2",
                                    isSelected: filter.rockTypes.contains(rock)
                                ) {
                                    if filter.rockTypes.contains(rock) {
                                        filter.rockTypes.remove(rock)
                                    } else {
                                        filter.rockTypes.insert(rock)
                                    }
                                }
                            }
                        }
                    }

                    // ── Sun exposure ────────────────────────────────────────
                    filterSection("Sun Exposure") {
                        FlowLayout(spacing: 8) {
                            ForEach(SunExposure.allCases) { exposure in
                                FilterChip(
                                    label: exposure.rawValue,
                                    icon: exposure.icon,
                                    isSelected: filter.sunExposures.contains(exposure)
                                ) {
                                    filter.sunExposures.formSymmetricDifference([exposure])
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Metrics.cardPadding)
                .padding(.bottom, 32)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Filter Crags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { filter.reset() }
                        .tint(Theme.Palette.textSecondary)
                        .disabled(!filter.isActive)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Theme.Palette.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func filterSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
            content()
        }
    }
}

// MARK: - Filter chip

private struct FilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : Theme.Palette.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? Theme.Palette.accent : Theme.Palette.surface)
                    .overlay(Capsule().stroke(
                        isSelected ? Color.clear : Theme.Palette.divider,
                        lineWidth: 1
                    ))
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Simple flow layout (wraps chips to next line)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x)
        }
        return CGSize(width: maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
