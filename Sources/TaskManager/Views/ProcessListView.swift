import SwiftUI

enum SortField: String, CaseIterable {
    case name = "Nome"
    case pid = "PID"
    case cpu = "CPU"
    case memory = "Memória"
}

final class ProcessListModel: ObservableObject {
    @Published var processes: [ProcessInfoEntry] = []
    @Published var searchText: String = ""
    @Published var sortField: SortField = .cpu
    @Published var sortAscending: Bool = false
    @Published var selectedPID: Int32?

    private let monitor = ProcessMonitor()
    private var timer: Timer?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let snapshot = monitor.snapshot()
        DispatchQueue.main.async {
            self.processes = snapshot
        }
    }

    var filteredSorted: [ProcessInfoEntry] {
        var list = processes
        if !searchText.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(searchText) || String($0.pid) == searchText }
        }
        list.sort { a, b in
            let result: Bool
            switch sortField {
            case .name: result = a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .pid: result = a.pid < b.pid
            case .cpu: result = a.cpuPercent < b.cpuPercent
            case .memory: result = a.memoryMB < b.memoryMB
            }
            return sortAscending ? result : !result
        }
        return list
    }

    func endTask(pid: Int32, force: Bool) {
        _ = monitor.kill(pid: pid, signal: force ? .force : .terminate)
        // Give the OS a moment, then refresh.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refresh()
        }
    }
}

struct ProcessListView: View {
    @StateObject private var model = ProcessListModel()
    @State private var pendingKillPID: Int32?
    @State private var showKillConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                    TextField("Buscar processo ou PID", text: $model.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.06)))

                Spacer()

                Button {
                    model.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Atualizar agora")

                Button {
                    if let pid = model.selectedPID {
                        pendingKillPID = pid
                        showKillConfirm = true
                    }
                } label: {
                    Label("Finalizar tarefa", systemImage: "xmark.octagon.fill")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(model.selectedPID == nil ? Color.secondary : Color.white)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(model.selectedPID == nil ? Color.white.opacity(0.06) : Color.red.opacity(0.85))
                )
                .disabled(model.selectedPID == nil)
            }
            .padding(12)

            Divider().overlay(Theme.separator)

            header

            Divider().overlay(Theme.separator)

            List(model.filteredSorted, selection: $model.selectedPID) { proc in
                ProcessRow(process: proc)
                    .listRowBackground(
                        model.selectedPID == proc.pid ? Theme.accent.opacity(0.35) : Color.clear
                    )
                    .listRowSeparatorTint(Theme.separator)
                    .tag(proc.pid)
                    .contextMenu {
                        Button("Finalizar tarefa") {
                            pendingKillPID = proc.pid
                            showKillConfirm = true
                        }
                        Button("Forçar encerramento") {
                            model.endTask(pid: proc.pid, force: true)
                        }
                    }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Theme.contentBackground)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .alert("Finalizar esta tarefa?", isPresented: $showKillConfirm, presenting: pendingKillPID) { pid in
            Button("Cancelar", role: .cancel) {}
            Button("Finalizar tarefa", role: .destructive) {
                model.endTask(pid: pid, force: false)
            }
        } message: { pid in
            if let proc = model.processes.first(where: { $0.pid == pid }) {
                Text("O processo \"\(proc.name)\" (PID \(pid)) será encerrado. Trabalho não salvo pode ser perdido.")
            } else {
                Text("PID \(pid) será encerrado.")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            headerButton("Nome", field: .name, width: nil, alignment: .leading)
            headerButton("PID", field: .pid, width: 70, alignment: .trailing)
            headerButton("CPU", field: .cpu, width: 80, alignment: .trailing)
            headerButton("Memória", field: .memory, width: 100, alignment: .trailing)
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 22)
        .padding(.vertical, 6)
    }

    private func headerButton(_ title: String, field: SortField, width: CGFloat?, alignment: Alignment) -> some View {
        Button {
            if model.sortField == field {
                model.sortAscending.toggle()
            } else {
                model.sortField = field
                model.sortAscending = false
            }
        } label: {
            HStack(spacing: 2) {
                Text(title)
                if model.sortField == field {
                    Image(systemName: model.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                }
            }
            .frame(maxWidth: width ?? .infinity, alignment: alignment)
        }
        .buttonStyle(.plain)
    }
}

struct ProcessRow: View {
    let process: ProcessInfoEntry

    private var cpuFraction: Double { process.cpuPercent / 100 }
    private var memFraction: Double { min(process.memoryMB / 1024, 1) }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Theme.accent.opacity(0.6))
                    .frame(width: 6, height: 6)
                Text(process.name)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(process.pid)")
                .frame(width: 70, alignment: .trailing)
                .foregroundStyle(.secondary)

            heatCell(String(format: "%.1f%%", process.cpuPercent), fraction: cpuFraction, width: 80)
                .foregroundStyle(process.cpuPercent > 50 ? .red : .primary)

            heatCell(String(format: "%.0f MB", process.memoryMB), fraction: memFraction, width: 100)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.vertical, 4)
    }

    private func heatCell(_ text: String, fraction: Double, width: CGFloat) -> some View {
        Text(text)
            .frame(width: width, alignment: .trailing)
            .padding(.vertical, 2)
            .background(
                HStack {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.heat(fraction))
                        .frame(width: width)
                }
            )
    }
}
