import SwiftUI

/// Privacy-first historical import flow. The user picks how far back to scan
/// HealthKit, taps Start, and we backfill `logged_runs` with full analytics
/// blobs (route polyline + pace/HR/elevation series). Idempotent: re-running
/// with a longer window only inserts workouts that aren't already present.
struct ImportRunHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    enum YearRange: Int, CaseIterable, Identifiable {
        case y1 = 1
        case y2 = 2
        case y3 = 3
        case y5 = 5
        case y10 = 10
        case all = 0  // sentinel — translated to nil at fetch time
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .y1: return "1 year"
            case .y2: return "2 years"
            case .y3: return "3 years"
            case .y5: return "5 years"
            case .y10: return "10 years"
            case .all: return "All time"
            }
        }
        var yearsBack: Int? { self == .all ? nil : rawValue }
    }

    enum ImportState {
        case idle
        case running(FitnessService.ImportProgress)
        case done(FitnessService.ImportResult)
        case failed(String)
    }

    @State private var selectedRange: YearRange = .y2
    @State private var state: ImportState = .idle

    var body: some View {
        VStack(spacing: 0) {
            switch state {
            case .idle:           idleView
            case .running(let p): runningView(progress: p)
            case .done(let r):    doneView(result: r)
            case .failed(let e):  failedView(error: e)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .interactiveDismissDisabled(isRunning)
    }

    private var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    // MARK: - Idle (configure & start)

    private var idleView: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.orange)
                Text("Import Run History")
                    .font(.title2.bold())
                Text("Pull your past Apple Watch and third-party runs from HealthKit so they appear in your heatmap, history, and charts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            Picker("Range", selection: $selectedRange) {
                ForEach(YearRange.allCases) { range in
                    Text(range.label).tag(range)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 130)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task { await runImport() }
            } label: {
                Text("Start Import")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.orange, in: Capsule())
            }
            .buttonStyle(.plain)

            Text("Duplicate runs are skipped automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Running (progress)

    private func runningView(progress: FitnessService.ImportProgress) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.4)
                    .padding(.top, 16)
                Text(progressTitle(progress))
                    .font(.title3.weight(.semibold))
                Text(progressSubtitle(progress))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if progress.total > 0 {
                ProgressView(value: Double(progress.processed), total: Double(progress.total))
                    .tint(Color.orange)
                    .padding(.horizontal, 24)
            }

            Text("Keep this screen open until import finishes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private func progressTitle(_ p: FitnessService.ImportProgress) -> String {
        switch p.phase {
        case .scanning:  return "Scanning HealthKit…"
        case .importing: return "Importing runs…"
        case .done:      return "Finishing up…"
        }
    }

    private func progressSubtitle(_ p: FitnessService.ImportProgress) -> String {
        switch p.phase {
        case .scanning:
            return "Looking through your workout history."
        case .importing:
            return p.total > 0
                ? "\(p.processed) of \(p.total)"
                : "Preparing…"
        case .done:
            return "Almost there."
        }
    }

    // MARK: - Done

    private func doneView(result: FitnessService.ImportResult) -> some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Color.green.opacity(0.15)).frame(width: 80, height: 80)
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Color.green)
            }
            .padding(.top, 8)

            Text("Import Complete")
                .font(.title2.bold())

            VStack(spacing: 10) {
                resultRow(label: "Imported", value: "\(result.imported)", tint: .orange)
                resultRow(label: "Skipped (duplicates)", value: "\(result.skipped)", tint: .secondary)
                if result.failed > 0 {
                    resultRow(label: "Failed", value: "\(result.failed)", tint: .red)
                }
            }
            .padding(16)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))

            Spacer(minLength: 0)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.orange, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func resultRow(label: String, value: String, tint: Color) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(tint)
        }
    }

    // MARK: - Failed

    private func failedView(error: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.red)
                .padding(.top, 16)
            Text("Import Failed")
                .font(.title2.bold())
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                Button {
                    state = .idle
                } label: {
                    Text("Try Again")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange, in: Capsule())
                }
                .buttonStyle(.plain)
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Run

    private func runImport() async {
        let range = selectedRange
        await MainActor.run {
            state = .running(.init(phase: .scanning, processed: 0, total: 0))
        }
        do {
            let result = try await FitnessService.shared.importHealthKitRunHistory(
                yearsBack: range.yearsBack
            ) { progress in
                state = .running(progress)
            }
            await MainActor.run {
                state = .done(result)
            }
        } catch {
            await MainActor.run {
                state = .failed(error.localizedDescription)
            }
        }
    }
}
