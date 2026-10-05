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
    // `ps` reports %CPU relative to a single core, so a busy process on a
    // multi-core Mac can read e.g. 165%. Windows' Task Manager normalizes
    // per-process CPU to the whole machine's capacity, so we do the same by
    // dividing by the core count — keeps every value within 0...100%.
    private let coreCount = Double(ProcessInfo.processInfo.activeProcessorCount)

    // `ps` %CPU is a decaying average over the process's recent life, so a
    // process that just went idle keeps showing load for a while. Where the
    // kernel lets us (our own processes), CPU comes from the change in CPU
    // time between two snapshots, and memory from the physical footprint —
    // the number Activity Monitor shows, which RSS overstates for shared pages.
    private var previousCPUTime: [Int32: UInt64] = [:]
    private var previousSampleTime: UInt64 = 0
    private let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

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

        let now = mach_absolute_time()
        let elapsedNs = previousSampleTime == 0 ? 0 : machToNs(now &- previousSampleTime)
        var nextCPUTime: [Int32: UInt64] = [:]

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

            var cpuPercent = cpu / coreCount
            var memoryMB = rssKB / 1024.0
            if let usage = resourceUsage(pid: pid) {
                memoryMB = Double(usage.ri_phys_footprint) / 1_048_576
                let cpuTime = machToNs(usage.ri_user_time &+ usage.ri_system_time)
                nextCPUTime[pid] = cpuTime
                if elapsedNs > 0, let previous = previousCPUTime[pid], cpuTime >= previous {
                    cpuPercent = Double(cpuTime - previous) / Double(elapsedNs) * 100 / coreCount
                }
            }

            results.append(ProcessInfoEntry(
                pid: pid,
                ppid: ppid,
                name: name,
                cpuPercent: min(max(cpuPercent, 0), 100),
                memoryPercent: mem,
                memoryMB: memoryMB,
                user: user
            ))
        }
        previousCPUTime = nextCPUTime
        previousSampleTime = now
        return results
    }

    /// rusage times are mach absolute units, which are not nanoseconds on
    /// Apple silicon (the timebase there is 125/3).
    private func machToNs(_ ticks: UInt64) -> UInt64 {
        ticks / UInt64(timebase.denom) * UInt64(timebase.numer)
    }

    /// Fails with EPERM for processes owned by another user; callers fall
    /// back to the `ps` figures for those.
    private func resourceUsage(pid: Int32) -> rusage_info_v4? {
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        return result == 0 ? info : nil
    }

    /// Sends SIGKILL. A polite SIGTERM is easy for a process to ignore, and
    /// "Finalizar tarefa" needs to actually end it.
    @discardableResult
    func kill(pid: Int32) -> Bool {
        Darwin.kill(pid, SIGKILL) == 0
    }
}
