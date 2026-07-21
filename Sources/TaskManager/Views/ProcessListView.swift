import SwiftUI
import AppKit

enum SortField: CaseIterable {
    case name, pid, cpu, memory

    var label: String {
        switch self {
        case .name: return tr(en: "Name", pt: "Nome")
        case .pid: return "PID"
        case .cpu: return "CPU"
        case .memory: return tr(en: "Memory", pt: "Memória")
        }
    }
}

final class ProcessListModel: ObservableObject {
    @Published var processes: [ProcessInfoEntry] = []
    @Published var searchText: String = ""
    @Published var sortField: SortField = .cpu
    @Published var sortAscending: Bool = false
    @Published var selectedPIDs: Set<Int32> = []

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

    func selectAll() {
        selectedPIDs = Set(filteredSorted.map(\.pid))
    }

    func endTask(pid: Int32) {
        endTasks([pid])
    }

    func endSelectedTasks() {
        endTasks(selectedPIDs)
    }

    private func endTasks(_ pids: some Sequence<Int32>) {
        for pid in pids {
            _ = monitor.kill(pid: pid)
        }
        selectedPIDs.removeAll()
        // Give the OS a moment, then refresh.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refresh()
        }
    }
}

struct ProcessListView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @StateObject private var model = ProcessListModel()
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                    TextField(tr(en: "Search process or PID", pt: "Buscar processo ou PID"), text: $model.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 7).fill(Theme.controlBackground))

                Spacer()

                Button {
                    model.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(tr(en: "Refresh now", pt: "Atualizar agora"))

                Button {
                    model.endSelectedTasks()
                } label: {
                    Label(endTaskLabel, systemImage: "xmark.octagon.fill")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(model.selectedPIDs.isEmpty ? Color.secondary : Color.white)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(model.selectedPIDs.isEmpty ? Theme.controlBackground : Color.red.opacity(0.85))
                )
                .disabled(model.selectedPIDs.isEmpty)
            }
            .padding(12)

            Divider().overlay(Theme.separator)

            header

            Divider().overlay(Theme.separator)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.filteredSorted) { proc in
                        ProcessRow(process: proc)
                            .background(
                                model.selectedPIDs.contains(proc.pid) ? Theme.accent.opacity(0.35) : Color.clear
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                model.selectedPIDs = [proc.pid]
                            }
                            .contextMenu {
                                Button(tr(en: "End Task", pt: "Finalizar tarefa")) {
                                    model.endTask(pid: proc.pid)
                                }
                            }
                        Divider().overlay(Theme.separator)
                    }
                }
            }
        }
        .background(Theme.contentBackground)
        .onAppear {
            model.start()
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // Cmd+A or Ctrl+A selects every process, like Windows' Task Manager.
                if event.charactersIgnoringModifiers == "a",
                   event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
                    model.selectAll()
                    return nil
                }
                // Delete (forward-delete) or Backspace ends the selected task(s).
                if event.keyCode == 51 || event.keyCode == 117, !model.selectedPIDs.isEmpty {
                    model.endSelectedTasks()
                    return nil
                }
                return event
            }
        }
        .onDisappear {
            model.stop()
            if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
            keyMonitor = nil
        }
    }

    private var endTaskLabel: String {
        let count = model.selectedPIDs.count
        if count > 1 {
            return tr(en: "End \(count) Tasks", pt: "Finalizar \(count) tarefas")
        }
        return tr(en: "End Task", pt: "Finalizar tarefa")
    }

    private var header: some View {
        HStack(spacing: 0) {
            headerButton(.name, width: nil, alignment: .leading)
            headerButton(.pid, width: 70, alignment: .trailing)
            headerButton(.cpu, width: 80, alignment: .trailing)
            headerButton(.memory, width: 100, alignment: .trailing)
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 22)
        .padding(.vertical, 6)
    }

    private func headerButton(_ field: SortField, width: CGFloat?, alignment: Alignment) -> some View {
        Button {
            if model.sortField == field {
                model.sortAscending.toggle()
            } else {
                model.sortField = field
                model.sortAscending = false
            }
        } label: {
            HStack(spacing: 2) {
                Text(field.label)
                if model.sortField == field {
                    Image(systemName: model.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                }
            }
            .frame(maxWidth: width ?? .infinity, alignment: alignment)
            .contentShape(Rectangle())
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
        .padding(.horizontal, 22)
        .padding(.vertical, 6)
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
