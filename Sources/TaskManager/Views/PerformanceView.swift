import SwiftUI

final class PerformanceModel: ObservableObject {
    @Published var snapshot = SystemSnapshot(cpuUsage: 0, memoryUsedGB: 0, memoryTotalGB: 0, memoryUsedFraction: 0, diskUsedGB: 0, diskTotalGB: 0, diskUsedFraction: 0)
    @Published var cpuHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var memoryHistory: [Double] = Array(repeating: 0, count: 60)

    private var primed = false
    private let reader = SystemStatsReader()
    private var timer: Timer?

    func start() {
        // Prime the CPU delta reader once before showing values.
        _ = reader.snapshot()
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let s = reader.snapshot()
        DispatchQueue.main.async {
            self.snapshot = s
            if !self.primed {
                // Fill the chart with the first reading, so it does not open
                // as a flat line at zero that jumps a minute later.
                self.cpuHistory = Array(repeating: s.cpuUsage, count: self.cpuHistory.count)
                self.memoryHistory = Array(repeating: s.memoryUsedFraction * 100, count: self.memoryHistory.count)
                self.primed = true
            }
            self.cpuHistory.removeFirst()
            self.cpuHistory.append(s.cpuUsage)
            self.memoryHistory.removeFirst()
            self.memoryHistory.append(s.memoryUsedFraction * 100)
        }
    }
}

struct PerformanceView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @StateObject private var model = PerformanceModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                Metric(
                    label: "CPU",
                    value: String(format: "%.0f", model.snapshot.cpuUsage),
                    unit: "%",
                    detail: tr(en: "of every core combined", pt: "de todos os núcleos juntos"),
                    fraction: model.snapshot.cpuUsage / 100
                ) {
                    SparklineView(values: model.cpuHistory, color: Theme.level(model.snapshot.cpuUsage / 100))
                        .frame(height: 110)
                }

                Metric(
                    label: tr(en: "Memory", pt: "Memória"),
                    value: String(format: "%.1f", model.snapshot.memoryUsedGB),
                    unit: "GB",
                    detail: String(format: tr(en: "of %.0f GB", pt: "de %.0f GB"), model.snapshot.memoryTotalGB),
                    fraction: model.snapshot.memoryUsedFraction
                ) {
                    SparklineView(values: model.memoryHistory, color: Theme.level(model.snapshot.memoryUsedFraction))
                        .frame(height: 70)
                }

                Metric(
                    label: tr(en: "Disk", pt: "Disco"),
                    value: String(format: "%.0f", model.snapshot.diskUsedGB),
                    unit: "GB",
                    detail: String(format: tr(en: "of %.0f GB · %.0f GB free", pt: "de %.0f GB · %.0f GB livres"),
                                   model.snapshot.diskTotalGB, model.snapshot.diskTotalGB - model.snapshot.diskUsedGB),
                    fraction: model.snapshot.diskUsedFraction
                ) {
                    ProgressBar(fraction: model.snapshot.diskUsedFraction)
                        .frame(height: 8)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
        }
        .background(Theme.contentBackground)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}

/// A label, one big number, a quiet detail, then the chart. No box around it:
/// the space between metrics is the separation.
private struct Metric<Content: View>: View {
    let label: String
    let value: String
    let unit: String
    let detail: String
    let fraction: Double
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .tracking(-1)
                        .contentTransition(.numericText())
                    Text(unit)
                        .font(.system(size: 20, weight: .semibold))
                }
                .foregroundStyle(fraction > 0.9 ? Theme.danger : .primary)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            content()
        }
    }
}

private struct ProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.controlBackground)
                Capsule()
                    .fill(Theme.level(fraction))
                    .frame(width: geo.size.width * CGFloat(min(max(fraction, 0), 1)))
            }
        }
    }
}

private struct SparklineView: View {
    let values: [Double]
    var color: Color = Theme.accent

    var body: some View {
        GeometryReader { geo in
            let maxV = max(values.max() ?? 1, 100)
            let stepX = geo.size.width / CGFloat(max(values.count - 1, 1))

            let linePath = Path { path in
                for (i, v) in values.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = geo.size.height * (1 - CGFloat(v / maxV))
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }

            let fillPath = Path { path in
                path.addPath(linePath)
                path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                path.closeSubpath()
            }

            fillPath.fill(
                LinearGradient(
                    colors: [color.opacity(0.30), color.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            linePath.stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}
