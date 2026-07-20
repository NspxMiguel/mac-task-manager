import Foundation
import Darwin

struct ProcessInfoEntry: Identifiable, Equatable {
    var id: Int32 { pid }
    let pid: Int32
    let ppid: Int32
    let name: String
    let cpuPercent: Double
    let memoryPercent: Double
    let memoryMB: Double
    let user: String
}

/// Snapshots the process table by shelling out to `ps`, which is the same
/// mechanism Activity Monitor's command-line sibling `top`/`ps` use and
/// avoids needing elevated entitlements to read other processes' basic info.
final class ProcessMonitor {
    func snapshot() -> [ProcessInfoEntry] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        // pid, ppid, %cpu, %mem, rss (KB), user, command
        task.arguments = ["-Ao", "pid=,ppid=,pcpu=,pmem=,rss=,user=,comm="]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var results: [ProcessInfoEntry] = []
        for line in output.split(separator: "\n") {
            let fields = line.split(separator: " ", maxSplits: 6, omittingEmptySubsequences: true)
            guard fields.count == 7 else { continue }
            guard let pid = Int32(fields[0]),
                  let ppid = Int32(fields[1]),
                  let cpu = Double(fields[2]),
                  let mem = Double(fields[3]),
                  let rssKB = Double(fields[4]) else { continue }
            let user = String(fields[5])
            let comm = String(fields[6])
            let name = (comm as NSString).lastPathComponent

            results.append(ProcessInfoEntry(
                pid: pid,
                ppid: ppid,
                name: name,
                cpuPercent: cpu,
                memoryPercent: mem,
                memoryMB: rssKB / 1024.0,
                user: user
            ))
        }
        return results
    }

    enum KillSignal {
        case terminate // SIGTERM
        case force     // SIGKILL

        var raw: Int32 {
            switch self {
            case .terminate: return SIGTERM
            case .force: return SIGKILL
            }
        }
    }

    @discardableResult
    func kill(pid: Int32, signal: KillSignal = .force) -> Bool {
        Darwin.kill(pid, signal.raw) == 0
    }
}
