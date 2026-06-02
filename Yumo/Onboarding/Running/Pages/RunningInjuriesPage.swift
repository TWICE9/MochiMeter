//
//  RunningInjuriesPage.swift
//  Yumo
//
//  Captures any injuries, niggles, or physical limitations so the AI plan
//  generator can dial back intensity / volume where needed. Optional — most
//  users will skip, but the field is high-signal when populated.
//

import SwiftUI

struct RunningInjuriesPage: View {
    @Bindable var flowManager: RunningOnboardingFlowManager
    @Environment(\.colorScheme) private var colorScheme

    private let quickTags: [String] = [
        "Knee pain",
        "Shin splints",
        "Achilles / calf",
        "IT band",
        "Plantar fasciitis",
        "Coming back from injury",
        "Pregnancy / postpartum"
    ]

    var body: some View {
        let primary = OnboardingTheme.primaryText(colorScheme)
        let muted = OnboardingTheme.mutedText(colorScheme)
        let background = OnboardingTheme.cardBackground(colorScheme)
        let stroke = OnboardingTheme.cardStroke(colorScheme)

        OnboardingQuestionView(
            question: "Anything we should know?",
            subtitle: "Injuries, niggles, or limitations help us dial back intensity where needed. Optional.",
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            VStack(spacing: 20) {
                // Quick tags
                FlowingTagGrid(tags: quickTags) { tag in
                    let isOn = flowManager.injuriesOrLimitations
                        .localizedCaseInsensitiveContains(tag)
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        toggleTag(tag)
                    } label: {
                        Text(tag)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(isOn ? Color("AppSecondaryAccent").opacity(0.18) : background)
                                    .overlay(
                                        Capsule()
                                            .stroke(isOn ? Color("AppSecondaryAccent") : stroke,
                                                    lineWidth: isOn ? 1.5 : 1)
                                    )
                            )
                            .foregroundColor(isOn ? Color("AppSecondaryAccent") : primary)
                    }
                    .buttonStyle(.plain)
                }

                // Free-form text
                VStack(alignment: .leading, spacing: 10) {
                    Text("DETAILS (OPTIONAL)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(muted)

                    ZStack(alignment: .topLeading) {
                        if flowManager.injuriesOrLimitations.isEmpty {
                            Text("e.g. tight left hamstring, returning from a 2-month break")
                                .font(.subheadline)
                                .foregroundColor(muted.opacity(0.7))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 16)
                        }

                        TextEditor(text: $flowManager.injuriesOrLimitations)
                            .font(.subheadline)
                            .foregroundColor(primary)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(minHeight: 110)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(background)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(stroke, lineWidth: 1)
                            )
                    )
                }

                Text("Leave blank if you're feeling great — most people do.")
                    .font(.caption)
                    .foregroundColor(muted)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 8)

                ContinueButton(
                    title: "Continue",
                    isEnabled: !flowManager.isNavigating,
                    action: { flowManager.goNext() }
                )
            }
        }
    }

    /// Adds the tag to the notes if not present, removes it if it is.
    /// Keeps the user's free-form text intact alongside tag toggles.
    private func toggleTag(_ tag: String) {
        var current = flowManager.injuriesOrLimitations
        if current.localizedCaseInsensitiveContains(tag) {
            // Remove the tag and any trailing comma/whitespace.
            let pattern = "\(NSRegularExpression.escapedPattern(for: tag))[,\\s]*"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(current.startIndex..., in: current)
                current = regex.stringByReplacingMatches(in: current, range: range, withTemplate: "")
            }
            flowManager.injuriesOrLimitations = current
                .trimmingCharacters(in: CharacterSet(charactersIn: ", \n"))
        } else {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            flowManager.injuriesOrLimitations = trimmed.isEmpty ? tag : "\(trimmed), \(tag)"
        }
    }
}

// MARK: - Flowing tag grid

/// Wraps tags onto multiple lines without a fixed column count.
private struct FlowingTagGrid<TagView: View>: View {
    let tags: [String]
    @ViewBuilder let tagBuilder: (String) -> TagView

    var body: some View {
        // SwiftUI doesn't have a built-in flow layout pre-iOS 16, but we target
        // newer iOS — `Layout` would also work, but `WrappingHStack` via a
        // simple lazy approach is fine here since the tag set is small/fixed.
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                tagBuilder(tag)
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? rowWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
