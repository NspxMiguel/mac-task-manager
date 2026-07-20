import SwiftUI

final class PerformanceModel: ObservableObject {
    @Published var snapshot = SystemSnapshot(cpuUsage: 0, memoryUsedGB: 0, memoryTotalGB: 0, memoryUsedFraction: 0, diskUsedGB: 0, diskTotalGB: 0, diskUsedFraction: 0)
    @Published var cpuHistory: [Double] = Array(repeating: 0, count: 60)

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
            self.cpuHistory.removeFirst()
            self.cpuHistory.append(s.cpuUsage)
        }
    }
}

struct PerformanceView: View {
    @StateObject private var model = PerformanceModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MetricCard(
                    title: "CPU",
                    valueText: String(format: "%.0f%%", model.snapshot.cpuUsage),
                    fraction: model.snapshot.cpuUsage / 100
                ) {
                    SparklineView(values: model.cpuHistory)
                        .frame(height: 90)
                }

                MetricCard(
                    title: "Memória",
                    valueText: String(format: "%.1f GB / %.1f GB", model.snapshot.memoryUsedGB, model.snapshot.memoryTotalGB),
                    fraction: model.snapshot.memoryUsedFraction
                ) {
                    ProgressBar(fraction: model.snapshot.memoryUsedFraction)
                        .frame(height: 14)
                }

                MetricCard(
                    title: "Disco (/)",
                    valueText: String(format: "%.0f GB / %.0f GB", model.snapshot.diskUsedGB, model.snapshot.diskTotalGB),
                    fraction: model.snapshot.diskUsedFraction
                ) {
                    ProgressBar(fraction: model.snapshot.diskUsedFraction)
                        .frame(height: 14)
                }
            }
            .padding(20)
        }
        .background(Theme.contentBackground)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}

private struct MetricCard<Content: View>: View {
    let title: String
    let valueText: String
    let fraction: Double
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text(valueText).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            content()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.separator, lineWidth: 1))
    }
}

private struct ProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.08))
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(min(max(fraction, 0), 1)))
            }
        }
    }

    private var color: Color {
        fraction > 0.85 ? .red : (fraction > 0.6 ? .orange : Theme.accent)
    }
}

private struct SparklineView: View {
    let values: [Double]

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
                    colors: [Theme.accent.opacity(0.35), Theme.accent.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            linePath.stroke(Theme.accent, lineWidth: 1.5)
        }
    }
}
