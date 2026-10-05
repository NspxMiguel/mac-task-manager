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
                        .font(.system(size: 13))
                }
                .padding(.horizontal, 14)
                .frame(height: 32)
                .frame(maxWidth: 320)
                .background(Capsule().fill(Theme.controlBackground))

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
                    Text(endTaskLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .frame(height: 32)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(model.selectedPIDs.isEmpty ? Color.secondary : Color.white)
                .background(
                    Capsule().fill(model.selectedPIDs.isEmpty ? Theme.controlBackground : Theme.danger)
                )
                .disabled(model.selectedPIDs.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            header

            Divider().overlay(Theme.separator)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.filteredSorted) { proc in
                        ProcessRow(process: proc)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(model.selectedPIDs.contains(proc.pid) ? Theme.accent.opacity(0.22) : Color.clear)
                                    .padding(.horizontal, 10)
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
                    }
                }
                .padding(.vertical, 4)
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
            headerButton(.cpu, width: 84, alignment: .trailing)
            headerButton(.memory, width: 96, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .bold))
        .textCase(.uppercase)
        .tracking(1)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.separator).frame(height: 1) }
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

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                ProcessIcon(pid: process.pid)
                Text(process.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(verbatim: "\(process.pid)")
                .frame(width: 70, alignment: .trailing)
                .foregroundStyle(.tertiary)

            Text(String(format: "%.1f%%", process.cpuPercent))
                .frame(width: 84, alignment: .trailing)
                .padding(.vertical, 3)
                .background(alignment: .trailing) {
                    Capsule().fill(Theme.heat(cpuFraction * 2)).frame(width: 60)
                        .padding(.trailing, -6)
                }
                .foregroundStyle(process.cpuPercent >= 50 ? Theme.danger : .primary)

            Text(process.memoryMB.megabytesText)
                .frame(width: 96, alignment: .trailing)
                .foregroundStyle(process.memoryMB >= 1024 ? .primary : .secondary)
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.horizontal, 24)
        .frame(height: 32)
    }
}

/// The app's own icon for apps, a quiet generic glyph for daemons. Cached by
/// pid so scrolling a few hundred rows does not hit NSWorkspace every frame.
private struct ProcessIcon: View {
    let pid: Int32
    private static var cache: [Int32: NSImage] = [:]

    var body: some View {
        Group {
            if let image = Self.icon(for: pid) {
                Image(nsImage: image).resizable()
            } else {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 18, height: 18)
    }

    private static func icon(for pid: Int32) -> NSImage? {
        if let cached = cache[pid] { return cached }
        guard let app = NSRunningApplication(processIdentifier: pid), app.bundleURL != nil,
              let icon = app.icon else { return nil }
        cache[pid] = icon
        return icon
    }
}
